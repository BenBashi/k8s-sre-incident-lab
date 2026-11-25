## סימפטום
פודים תקינים, אבל ל־Service אין endpoints. loadgen מקבל 000.

## איתור
```bash
kubectl -n shop get endpoints orders-api            # <none>
kubectl -n shop get svc orders-api -o jsonpath='{.spec.selector}'; echo
kubectl -n shop get pods --show-labels | grep orders-api
```

## תיקון
```bash
kubectl -n shop patch svc orders-api -p '{"spec":{"selector":{"app":"orders-api"}}}'
```

## מניעה
כדאי להוסיף: GitOps (Argo CD) מונע שינויים ידניים, synthetic check מבחוץ, התראה על Service בלי endpoints.
