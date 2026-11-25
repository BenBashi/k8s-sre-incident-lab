## סימפטום
פודים של orders-api ב־CrashLoopBackOff, אין endpoints, loadgen מקבל 000/503.

## איתור
```bash
kubectl -n shop get pods
kubectl -n shop logs deploy/orders-api --previous | tail
# Access denied for user 'shop'@'10.244.x.x' (using password: YES)
kubectl -n shop get secret api-secrets -o jsonpath='{.data.DB_PASSWORD}' | base64 -d; echo
kubectl -n shop get secret mysql-credentials -o jsonpath='{.data.MYSQL_PASSWORD}' | base64 -d; echo
```
```
index=* service=orders-api dependency=mysql level=ERROR | stats count by error
```

## תיקון
```bash
kubectl -n shop patch secret api-secrets -p '{"stringData":{"DB_PASSWORD":"shop-pass"}}'
kubectl -n shop delete pods -l app=orders-api   # env from secret is read only at pod start
```
אותו דבר ב־SQL Server: ‏`Login failed for user 'shop'` (Error 18456). ב־RDS: לבדוק את הסוד ב־Secrets Manager מול מה שהאפליקציה קיבלה.

## מניעה
כדאי להוסיף: מקור אחד לסודות (Secrets Manager + External Secrets), רוטציה שמעדכנת גם את ה־DB וגם את האפליקציה, התראה על CrashLoopBackOff.
