## סימפטום
ה־worker קורס שוב ושוב על אותה הודעה (poison message). כיוון שה־offset לא נשמר, הוא קורא אותה שוב בכל עלייה.

## איתור
```bash
kubectl -n shop logs deploy/orders-worker --previous | grep "failed to parse"
# "partition": P, "offset": O
```
```
index=* service=orders-worker msg="failed to parse message" | table _time partition offset raw
```

## תיקון
```bash
kubectl -n shop scale deploy/orders-worker --replicas=0
# לחכות כ־15 שניות שה־group יהיה ריק, ואז לדלג על ההודעה:
kubectl -n shop exec deploy/kafka -- /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --group orders-worker --reset-offsets --topic orders:P --to-offset O+1 --execute
kubectl -n shop scale deploy/orders-worker --replicas=1
```
להגיד בקול: מדלגים על הודעה אחת, ולשמור אותה קודם לבדיקה.

## מניעה
כדאי להוסיף: try/except עם DLQ (dead-letter topic), schema registry, התראה על restart loop.
