## סימפטום
ה־worker כותב `mongo connection failed` עם `Authentication failed` ואחרי 10 ניסיונות יוצא.

## איתור
```bash
kubectl -n shop logs deploy/orders-worker --previous | grep mongo
kubectl -n shop get secret worker-secrets -o jsonpath='{.data.MONGO_PASSWORD}' | base64 -d; echo
kubectl -n shop exec deploy/mongo -- mongosh -u worker -p worker-pass --authenticationDatabase shop --quiet --eval 'db.runCommand({ping:1})'
```
```
index=* service=orders-worker dependency=mongo level=ERROR | stats count by error
```

## תיקון
```bash
kubectl -n shop patch secret worker-secrets -p '{"stringData":{"MONGO_PASSWORD":"worker-pass"}}'
kubectl -n shop delete pods -l app=orders-worker
```
ב־DocumentDB: לבדוק גם TLS (CA bundle), ‏authSource ו־retryWrites=false במחרוזת החיבור.

## מניעה
כדאי להוסיף: מקור אחד לסודות ורוטציה מתואמת, כמו בתרחיש 01.
