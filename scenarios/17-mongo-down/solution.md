## סימפטום
ה־worker כותב `mongo connection failed` עם ServerSelectionTimeoutError. ל־Service של mongo אין endpoints.

## איתור
```bash
kubectl -n shop logs deploy/orders-worker --previous | grep mongo
kubectl -n shop get endpoints mongo
kubectl -n shop get deploy mongo           # 0/0
```

## תיקון
```bash
kubectl -n shop scale deploy/mongo --replicas=1
kubectl -n shop delete pods -l app=orders-worker     # כדי לא לחכות ל־backoff
```
להגיד בקול: במעבדה אין volume, ולכן הנתונים ב־Mongo נמחקו. ב־production זה StatefulSet עם PVC, או DocumentDB מנוהל.

## מניעה
התראה על Deployment עם 0 רפליקות זמינות, RBAC שמגביל scale ל־datastores.
