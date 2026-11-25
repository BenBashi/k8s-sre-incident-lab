## סימפטום
ב־consumer group אין CONSUMER-ID, ה־LAG עולה בכל partition.

## איתור
```bash
kubectl -n shop exec deploy/kafka -- /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group orders-worker
kubectl -n shop get deploy orders-worker       # 0/0
```

## תיקון
```bash
kubectl -n shop scale deploy/orders-worker --replicas=1
```
אפשר לעלות עד 3 (מספר ה־partitions) כדי לרוקן את ה־lag מהר יותר.

## מניעה
התראה על lag וגם על group בלי חברים, HPA/KEDA לפי lag, minReplicas.
