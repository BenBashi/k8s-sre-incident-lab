## סימפטום
לקוח חדש (partner-sync) מציף את ה־API בלי הפסקה. ה־HPA הגיע ל־maxReplicas=6, ה־CPU של הפודים בתקרה, ולקוחות האתר (web-checkout) סובלים.

## איתור
```bash
kubectl -n shop get hpa                          # REPLICAS 6/6, TARGETS הרבה מעל 60%
kubectl -n shop top pods; kubectl top nodes
kubectl -n shop logs deploy/orders-api --since=2m | jq -r .client | sort | uniq -c
kubectl -n shop get pods | grep partner-sync     # מי זה?
```
```
index=* service=orders-api | timechart span=1m count by client
index=* service=orders-api msg="order created" | stats avg(duration_ms) p95(duration_ms) by client
```

## תיקון
```bash
# הקלה מיידית: לעצור את הלקוח החריג (בתיאום עם הבעלים שלו)
kubectl -n shop scale deploy/partner-sync --replicas=0
# ואם התעבורה לגיטימית: להגדיל קיבולת
kubectl -n shop patch hpa orders-api -p '{"spec":{"maxReplicas":10}}'
```
להגיד בקול: לפני שמגדילים קיבולת בודקים אם העומס לגיטימי. הגדלה בלבד לעיתים רק מעבירה את הבעיה ל־DB.

## מניעה
כדאי להוסיף: ‏rate limiting לכל לקוח (API Gateway / ingress), מכסות לשותפים, התראה על HPA ב־max ועל שינוי חד בהתפלגות הלקוחות.
