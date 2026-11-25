## סימפטום
שני השירותים כותבים `kafka connection failed`, NoBrokersAvailable, ויוצאים אחרי 10 ניסיונות.

## איתור
```bash
kubectl -n shop logs deploy/orders-api --previous | grep kafka
kubectl -n shop get cm app-config -o yaml | grep KAFKA
kubectl -n shop get svc kafka                       # 9092 בלבד
kubectl -n shop run nettest --rm -it --image=busybox --restart=Never -- nc -zv kafka 9093
```

## תיקון
```bash
kubectl -n shop patch configmap app-config -p '{"data":{"KAFKA_BOOTSTRAP":"kafka:9092"}}'
kubectl -n shop delete pods -l app=orders-api; kubectl -n shop delete pods -l app=orders-worker
```
ב־MSK: פורט 9092 הוא plaintext ו־9094 הוא TLS. לבדוק גם security groups.

## מניעה
כדאי להוסיף: ConfigMap מנוהל ב־Git עם review, rollout הדרגתי של שינויי קונפיגורציה, התראה על FATAL בלוגים.
