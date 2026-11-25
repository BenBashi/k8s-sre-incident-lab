## סימפטום
ההתחברות וה־ping מצליחים, אבל ה־insert נכשל: `not authorized on shop to execute command { insert: "order_events" ...`. ה־worker קורס על השגיאה.

## איתור
```bash
kubectl -n shop logs deploy/orders-worker --previous | tail -5
kubectl -n shop exec -it deploy/mongo -- mongosh -u root -p mongo-pass --authenticationDatabase admin shop
```
```js
db.getUser("worker")      // roles: [ { role: "read", db: "shop" } ]
```
```
index=* service=orders-worker "not authorized" | stats count by error
```

## תיקון
```js
db.grantRolesToUser("worker", [{ role: "readWrite", db: "shop" }])
db.revokeRolesFromUser("worker", [{ role: "read", db: "shop" }])
```
```bash
kubectl -n shop delete pods -l app=orders-worker
```
אותן פקודות עובדות גם ב־DocumentDB.

## מניעה
כדאי להוסיף: הרשאות DB כקוד עם review, בדיקת הרשאות ב־staging לפני שינוי, טיפול בשגיאות הרשאה בקוד במקום קריסה.
