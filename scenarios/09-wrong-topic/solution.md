## סימפטום
בקבוצה orders-worker על הטופיק orders אין צרכן פעיל, ה־lag עולה. ה־worker מאזין לטופיק אחר.

## איתור
```bash
kubectl -n shop logs deploy/orders-worker | head -3          # "worker started", "topic": "order-events"
kubectl -n shop set env deploy/orders-worker --list | grep TOPIC
kubectl -n shop exec deploy/kafka -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```

## תיקון
```bash
kubectl -n shop set env deploy/orders-worker KAFKA_TOPIC-    # מסיר את ה־override, חוזר ל־ConfigMap
```

## מניעה
לבטל auto.create.topics.enable, להגדיר טופיקים כקוד, וללוג בעלייה איזה טופיק נצרך (כמו כאן).
