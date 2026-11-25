## סימפטום
פודים חדשים ב־CrashLoopBackOff. הלוג האחרון הוא `orders-api starting` בלי שום שגיאה. ב־Events: ‏`Liveness probe failed: ... connection refused` ואחריו `Killing`, שנייה או שתיים אחרי `Started`.

## איתור
```bash
kubectl -n shop get pods -l app=orders-api
kubectl -n shop describe pod <new-pod> | grep -iE "started|liveness|killing"
kubectl -n shop logs <new-pod> --previous                     # מגיע עד "orders-api starting" ונקטע
kubectl -n shop get deploy orders-api -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}'; echo
# initialDelaySeconds=0, periodSeconds=1, failureThreshold=1: שנייה אחת לעלות
```

## שורש הבעיה
האפליקציה צריכה כמה שניות לעלות (חיבור ל־MySQL ולקפקא) לפני שהיא מאזינה לפורט 8080. ה־liveness מתחיל מיד, נכשל פעם אחת, והקונטיינר נהרג. זה חוזר בכל פעם.

## תיקון (הנכון: startupProbe)
```bash
kubectl -n shop patch deploy orders-api -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","startupProbe":{"httpGet":{"path":"/healthz","port":8080},"periodSeconds":5,"failureThreshold":24},"livenessProbe":{"httpGet":{"path":"/healthz","port":8080},"initialDelaySeconds":0,"periodSeconds":10,"failureThreshold":3,"timeoutSeconds":2}}]}}}}'
kubectl -n shop rollout status deploy/orders-api
```
להגיד בקול: ‏startupProbe נותן לאפליקציה עד 2 דקות לעלות, ורק אחר כך ה־liveness נכנס לפעולה. כך לא צריך initialDelaySeconds גדול שמאט את הזיהוי של פוד תקוע.

## מניעה
כדאי להוסיף: ‏failureThreshold=1 כמעט אף פעם לא נכון, מדידה של זמן העלייה האמיתי, ו־startupProbe לכל שירות שעולה לאט.
