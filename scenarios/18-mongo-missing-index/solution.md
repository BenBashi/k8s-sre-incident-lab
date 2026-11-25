## סימפטום
בדיקת הכפילויות של ה־worker ‏(`find_one({order_id})`) סורקת את כל האוסף, כ־1.5 מיליון מסמכים, כי האינדקס נמחק. כל הודעה לוקחת מאות מילישניות, וה־lag עולה.

## איתור
```bash
kubectl -n shop logs deploy/orders-worker --tail=5     # mongo_lookup_ms גבוה
kubectl -n shop top pod -l app=mongo
kubectl -n shop exec -it deploy/mongo -- mongosh -u root -p mongo-pass --authenticationDatabase admin shop
```
```js
db.currentOp({ ns: "shop.order_events" }).inprog.map(o => [o.secs_running, o.planSummary])
db.setProfilingLevel(1, { slowms: 100 })
db.system.profile.find().sort({ ts: -1 }).limit(3).forEach(p => printjson([p.millis, p.planSummary, p.docsExamined]))
db.order_events.find({ order_id: "x" }).explain("executionStats").executionStats   // COLLSCAN, totalDocsExamined
db.order_events.getIndexes()                                                       // אין order_id_1
```
```
index=* service=orders-worker msg="order processed" | timechart span=1m avg(mongo_lookup_ms) count
```

## תיקון
```js
db.order_events.createIndex({ order_id: 1 })
db.order_events.find({ order_id: "x" }).explain("executionStats").queryPlanner.winningPlan   // IXSCAN
db.setProfilingLevel(0)
```
אחרי התיקון mongo_lookup_ms יורד לאפס וה־lag מתרוקן.
להגיד בקול: בניית אינדקס על אוסף גדול ב־production מעמיסה. עדיף לבנות מחוץ לשעות השיא ולעקוב אחרי `db.currentOp()`.

## מניעה
כדאי להוסיף: אינדקסים כקוד (migration), בדיקה שמיגרציות לא מוחקות אינדקסים, התראה על COLLSCAN ועל latency (Datadog DBM, ‏Dynatrace, ‏Performance Insights ב־DocumentDB).
