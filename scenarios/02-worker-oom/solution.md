## סימפטום
הפוד orders-worker ב־CrashLoopBackOff, Last State: OOMKilled, Exit Code 137. ה־lag בקפקא גדל.

## איתור
```bash
kubectl -n shop describe pod -l app=orders-worker | grep -A5 "Last State"
kubectl -n shop get deploy orders-worker -o jsonpath='{.spec.template.spec.containers[0].resources}'; echo
kubectl -n shop top pod
```

## תיקון
```bash
kubectl -n shop set resources deploy/orders-worker -c app --requests=memory=96Mi --limits=memory=192Mi
```
אחרי התיקון ה־lag צריך לרדת לאפס.

## מניעה
לקבוע limits לפי מדידה (Datadog/VPA במצב Off כהמלצה בלבד), התראה על OOMKilled ועל consumer lag.
