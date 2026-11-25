## סימפטום
עמודת RESTARTS גבוהה בכל הפודים של orders-api, ואולי חלקם עדיין ב־CrashLoopBackOff. ב־Events: ‏`Liveness probe failed: HTTP probe failed with statuscode: 503` ומיד אחריו `Killing`.

## איתור
```bash
kubectl -n shop get pods -l app=orders-api                    # RESTARTS
kubectl -n shop get events --sort-by=.lastTimestamp | grep -iE "liveness|killing|unhealthy"
kubectl -n shop get deploy orders-api -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}'; echo
# path=/ready  ← אותו endpoint של readiness, שבודק את MySQL
```
```
index=* source=k8s-events reason IN (Unhealthy, Killing) | timechart span=1m count by reason
index=* service=orders-api dependency=mysql | timechart span=1m count by level
```

## שורש הבעיה
בדיקת ה־liveness בודקת את ה־DB. כשה־DB ירד, ה־kubelet הרג את כל הפודים, כי הוא חשב שהם תקועים. הפודים שעלו מחדש לא הצליחו להתחבר ל־DB, ונכנסו ל־backoff שהולך וגדל (עד 5 דקות). לכן ההשבתה נמשכה הרבה אחרי שה־DB חזר.

## תיקון
```bash
kubectl -n shop patch deploy orders-api -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","livenessProbe":{"httpGet":{"path":"/healthz","port":8080},"initialDelaySeconds":30,"periodSeconds":10,"failureThreshold":3,"timeoutSeconds":2}}]}}}}'
kubectl -n shop rollout status deploy/orders-api
```

## הוכחה שזה עובד
```bash
kubectl -n shop scale deploy/mysql --replicas=0; sleep 40
kubectl -n shop get pods -l app=orders-api      # Running 0/1, בלי restarts חדשים: readiness מוציא אותם מהתעבורה
kubectl -n shop scale deploy/mysql --replicas=1; sleep 30
kubectl -n shop get pods -l app=orders-api      # חוזרים ל־1/1 לבד
```
להגיד בקול: ‏liveness בודק רק אם התהליך חי. תלויות שייכות ל־readiness.

## מניעה
כדאי להוסיף: כלל בסטנדרט של הצוות שאוסר תלויות ב־liveness, בדיקת manifests ב־CI, התראה על restarts מרובים בכמה פודים במקביל.
