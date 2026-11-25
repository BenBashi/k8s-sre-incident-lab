## סימפטום
הלקוחות מקבלים 422. בלוג: `order rejected`, ‏reason=qty_limit_exceeded. הגבול נשמר בטבלה app_settings ב־MySQL, ומישהו שינה אותו מ־10 ל־1. ההזמנות של loadgen הן עם qty=2.

## איתור
```bash
kubectl -n shop logs deploy/orders-api --tail=20 | grep rejected
```
```
index=* service=orders-api msg="order rejected" | stats count by reason, client
index=* service=loadgen | timechart span=1m count by status
```
```bash
kubectl -n shop exec -it deploy/mysql -- mysql -uroot -proot-pass shop
```
```sql
SELECT * FROM app_settings;          -- v=1, updated_by=pricing-sync-job, updated_at = תחילת התקלה
```
להגיד בקול: זמן העדכון בטבלה תואם לזמן שבו התחילו ה־422 ב־Splunk. זה הקשר בין הנתונים לתקלה.

## תיקון
```sql
UPDATE app_settings SET v = '10', updated_by = 'ben-incident-fix' WHERE k = 'max_qty_per_order';
```
אחרי כ־5 שניות (cache) ה־422 נעלמים. לאמת ב־loadgen ובגרף של Splunk.

## אותו דבר ב־SQL Server
```sql
SELECT * FROM app_settings;
UPDATE app_settings SET v = '10' WHERE k = 'max_qty_per_order';
```

## מניעה
כדאי להוסיף: ‏audit table או CDC לשינויי קונפיגורציה ב־DB, ולידציה על ערכים (CHECK constraint), התראה על קפיצה בשיעור ה־4xx, ולוג שמציג גם את הערך שנבדק.
