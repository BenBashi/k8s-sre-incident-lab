## סימפטום
פודים Running 0/1, אין endpoints, Events: Readiness probe failed: HTTP probe failed with statuscode: 404.

## איתור
```bash
kubectl -n shop get pods -l app=orders-api
kubectl -n shop describe pod -l app=orders-api | grep -i readiness
kubectl -n shop get deploy orders-api -o yaml | grep -A4 readinessProbe
```

## תיקון
```bash
kubectl -n shop rollout undo deploy/orders-api
# או לתקן את ה־path ל־/ready ולהחזיר strategy RollingUpdate
```

## מניעה
שני שינויים מסוכנים יחד: נתיב probe שגוי ו־Recreate שהפיל את כל הפודים בבת אחת. בדיקת probes ב־staging, RollingUpdate עם maxUnavailable נמוך, PodDisruptionBudget.
