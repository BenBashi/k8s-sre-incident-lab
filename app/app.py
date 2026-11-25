"""Shop app for the SRE bootcamp lab.

One image, several roles (env ROLE):
  api     - HTTP API: POST /orders -> insert into MySQL + produce to Kafka
  worker  - Kafka consumer: reads orders -> writes events to MongoDB
  hog     - opens many MySQL connections and holds them (used by a break scenario)

All logs are single-line JSON on stdout, so they search well in Splunk.
"""
import json
import logging
import os
import sys
import time
import uuid
from datetime import datetime, timezone

ROLE = os.getenv("ROLE", "api")
SERVICE = os.getenv("SERVICE_NAME", ROLE)


def log(level, msg, **kw):
    rec = {"ts": datetime.now(timezone.utc).isoformat(), "level": level, "service": SERVICE, "msg": msg}
    rec.update(kw)
    print(json.dumps(rec, default=str), flush=True)


def retry(name, fn, attempts=10, delay=3):
    for i in range(1, attempts + 1):
        try:
            return fn()
        except Exception as e:  # noqa: BLE001
            log("ERROR", f"{name} connection failed", dependency=name, attempt=i,
                error=str(e).strip(), error_type=type(e).__name__)
            time.sleep(delay)
    log("FATAL", f"giving up on {name} after {attempts} attempts", dependency=name)
    sys.exit(1)


def mysql_connect():
    import pymysql
    return pymysql.connect(
        host=os.environ["DB_HOST"], database=os.environ["DB_NAME"],
        user=os.environ["DB_USER"], password=os.environ["DB_PASSWORD"],
        connect_timeout=3, autocommit=True, program_name=SERVICE,
    )


def run_api():
    from flask import Flask, jsonify, request
    from kafka import KafkaProducer

    def sql(query, args=None):
        conn = mysql_connect()
        try:
            with conn.cursor() as cur:
                cur.execute(query, args)
                return cur.fetchall()
        finally:
            conn.close()

    def init_db():
        sql("CREATE TABLE IF NOT EXISTS orders ("
            " id VARCHAR(36) PRIMARY KEY, item VARCHAR(100), qty INT,"
            " created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)")
        sql("CREATE TABLE IF NOT EXISTS app_settings ("
            " k VARCHAR(64) PRIMARY KEY, v VARCHAR(255), updated_by VARCHAR(64),"
            " updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)")
        sql("INSERT IGNORE INTO app_settings (k, v, updated_by) VALUES ('max_qty_per_order', '10', 'init')")

    settings_cache = {"t": 0.0, "max_qty": 10}

    def max_qty():
        # Business limit stored in the DB, cached for 5 seconds.
        if time.time() - settings_cache["t"] > 5:
            rows = sql("SELECT v FROM app_settings WHERE k = 'max_qty_per_order'")
            settings_cache.update(t=time.time(), max_qty=int(rows[0][0]) if rows else 10)
        return settings_cache["max_qty"]

    retry("mysql", init_db)
    producer = retry(
        "kafka",
        lambda: KafkaProducer(
            bootstrap_servers=os.environ["KAFKA_BOOTSTRAP"],
            value_serializer=lambda v: json.dumps(v).encode(),
            acks="all",
            request_timeout_ms=5000,
        ),
    )
    topic = os.environ["KAFKA_TOPIC"]

    app = Flask(__name__)
    logging.getLogger("werkzeug").setLevel(logging.WARNING)

    @app.get("/healthz")
    def healthz():
        return "ok"

    @app.get("/ready")
    def ready():
        try:
            sql("SELECT 1")
            return "ready"
        except Exception as e:  # noqa: BLE001
            log("WARN", "readiness check failed", dependency="mysql", error=str(e).strip())
            return jsonify(error=str(e)), 503

    @app.post("/orders")
    def create_order():
        body = request.get_json(silent=True) or {}
        oid = str(uuid.uuid4())
        item = body.get("item", "widget")
        qty = int(body.get("qty", 1))
        client = request.headers.get("X-Client", "unknown")
        t0 = time.time()
        try:
            if qty > max_qty():
                log("WARN", "order rejected", order_id=oid, client=client, reason="qty_limit_exceeded", status=422)
                return jsonify(error="quantity not allowed"), 422
            sql("INSERT INTO orders (id, item, qty) VALUES (%s, %s, %s)", (oid, item, qty))
            producer.send(topic, {"order_id": oid, "item": item, "qty": qty}).get(timeout=5)
        except Exception as e:  # noqa: BLE001
            log("ERROR", "order failed", order_id=oid, client=client, error=str(e).strip(), error_type=type(e).__name__,
                duration_ms=int((time.time() - t0) * 1000), status=500)
            return jsonify(error=str(e)), 500
        log("INFO", "order created", order_id=oid, client=client, duration_ms=int((time.time() - t0) * 1000), status=201)
        return jsonify(id=oid), 201

    @app.get("/burn")
    def burn():
        ms = int(request.args.get("ms", 200))
        end = time.time() + ms / 1000
        x = 0
        while time.time() < end:
            x += 1
        return "burned"

    log("INFO", "orders-api starting", port=8080, topic=topic)
    app.run(host="0.0.0.0", port=8080, threaded=True)


def run_worker():
    from kafka import KafkaConsumer
    from pymongo import MongoClient

    uri = (
        f"mongodb://{os.environ['MONGO_USER']}:{os.environ['MONGO_PASSWORD']}"
        f"@{os.environ['MONGO_HOST']}:27017/?authSource={os.getenv('MONGO_AUTH_SOURCE', 'admin')}"
    )
    client = MongoClient(uri, serverSelectionTimeoutMS=4000)
    retry("mongo", lambda: client["shop"].command("ping"))
    db = client["shop"]
    coll = db["order_events"]
    db["settings"].update_one({"_id": "routing"}, {"$setOnInsert": {"events_collection": "order_events"}}, upsert=True)
    routing = {"t": 0.0, "name": "order_events"}

    def events_coll():
        # Target collection comes from a settings document, cached for 5 seconds.
        if time.time() - routing["t"] > 5:
            doc = db["settings"].find_one({"_id": "routing"}) or {}
            routing.update(t=time.time(), name=doc.get("events_collection", "order_events"))
        return db[routing["name"]]

    try:
        coll.create_index("order_id", name="order_id_1")
    except Exception as e:  # noqa: BLE001
        log("WARN", "could not ensure index on order_id", dependency="mongo", error=str(e))

    topic = os.environ["KAFKA_TOPIC"]
    delay = int(os.getenv("PROCESSING_DELAY_MS", "0")) / 1000
    consumer = retry(
        "kafka",
        lambda: KafkaConsumer(
            topic,
            bootstrap_servers=os.environ["KAFKA_BOOTSTRAP"],
            group_id=os.getenv("CONSUMER_GROUP", "orders-worker"),
            auto_offset_reset="earliest",
            enable_auto_commit=False,
        ),
    )
    log("INFO", "worker started", topic=topic, processing_delay_ms=int(delay * 1000))

    for msg in consumer:
        try:
            event = json.loads(msg.value)
        except Exception as e:  # noqa: BLE001
            # Deliberately no skip / DLQ: a bad message crashes the worker (poison message).
            log("ERROR", "failed to parse message", topic=msg.topic, partition=msg.partition,
                offset=msg.offset, error=str(e), raw=msg.value[:100].decode(errors="replace"))
            raise
        if delay:
            time.sleep(delay)
        t0 = time.time()
        coll = events_coll()
        # Idempotency check: needs the order_id index to be fast.
        if coll.find_one({"order_id": event.get("order_id")}, {"_id": 1}):
            consumer.commit()
            log("WARN", "duplicate order skipped", order_id=event.get("order_id"))
            continue
        lookup_ms = int((time.time() - t0) * 1000)
        event.update(partition=msg.partition, offset=msg.offset, processed_at=datetime.now(timezone.utc))
        coll.insert_one(event)
        consumer.commit()
        log("INFO", "order processed", order_id=event.get("order_id"), partition=msg.partition,
            offset=msg.offset, mongo_lookup_ms=lookup_ms)


def run_hog():
    n = int(os.getenv("HOG_CONNECTIONS", "38"))
    conns = []
    for _ in range(n):
        try:
            conns.append(mysql_connect())
        except Exception as e:  # noqa: BLE001
            log("WARN", "could not open connection", error=str(e).strip())
            break
    log("INFO", "report job running", open_connections=len(conns))
    while True:
        time.sleep(30)
        log("INFO", "report job still running", open_connections=len(conns))


if __name__ == "__main__":
    {"api": run_api, "worker": run_worker, "hog": run_hog}[ROLE]()
