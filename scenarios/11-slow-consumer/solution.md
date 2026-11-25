## סימפטום
צרכן אחד, 3 partitions, כל הודעה לוקחת 1.5 שניות. הקצב נמוך מקצב הייצור, ולכן ה־lag עולה.

## איתור
```bash
kubectl -n shop exec deploy/kafka -- /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group orders-worker
kubectl -n shop logs deploy/orders-worker | head -2      # processing_delay_ms
```
```
index=* service=orders-worker msg="order processed" | timechart span=1m count
```

## תיקון
```bash
# הקלה מיידית: להוסיף צרכנים, עד מספר ה־partitions
kubectl -n shop scale deploy/orders-worker --replicas=3
# שורש הבעיה: התלות האיטית (כאן מדומה ע"י delay)
kubectl -n shop set env deploy/orders-worker PROCESSING_DELAY_MS-
```
יותר מ־3 רפליקות לא יעזרו: צרכנים מעבר למספר ה־partitions נשארים בלי עבודה.

## מניעה
כדאי להוסיף: KEDA לפי lag, ניטור latency לכל הודעה, הגדלת partitions מראש.
