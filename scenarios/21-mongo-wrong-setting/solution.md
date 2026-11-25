## סימפטום
ה־worker כותב בהצלחה, אבל לאוסף הלא נכון: order_event במקום order_events. שם האוסף נלקח ממסמך הגדרות ב־MongoDB שמישהו ערך.

## איתור
```bash
kubectl -n shop logs deploy/orders-worker --tail=5        # order processed, אין שגיאות
kubectl -n shop exec -it deploy/mongo -- mongosh -u root -p mongo-pass --authenticationDatabase admin shop
```
```js
db.getCollectionNames()                                   // מופיע אוסף חדש: order_event
db.order_events.countDocuments(); db.order_event.countDocuments()
db.order_events.find().sort({processed_at: -1}).limit(1)    // זמן האירוע האחרון = תחילת התקלה
db.settings.find()                                        // events_collection: "order_event"
```

## תיקון
```js
db.settings.updateOne({ _id: "routing" }, { $set: { events_collection: "order_events", updated_by: "ben-incident-fix" } })
// להחזיר את האירועים שנכתבו למקום הלא נכון:
db.order_event.find().forEach(d => db.order_events.insertOne(d))
db.order_events.countDocuments()
db.order_event.drop()                                     // רק אחרי שמוודאים שהכל הועבר
```
להגיד בקול: קודם עוצרים את הנזק (מתקנים את ההגדרה), אחר כך מתקנים את הנתונים, ומוחקים רק אחרי אימות.

## מניעה
כדאי להוסיף: ‏schema validation על מסמכי הגדרות, הרשאות כתיבה מוגבלות לאוסף settings, התראה על ירידה בקצב הכתיבה לאוסף הראשי.
