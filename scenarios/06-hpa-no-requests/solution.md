## סימפטום
הפקודה `kubectl get hpa` מציגה `<unknown>/60%`. אירוע: failed to get cpu utilization: missing request for cpu.

## איתור
```bash
kubectl -n shop get hpa
kubectl -n shop describe hpa orders-api | tail
kubectl -n shop get deploy orders-api -o jsonpath='{.spec.template.spec.containers[0].resources}'; echo
kubectl -n shop top pods
```

## תיקון
```bash
kubectl -n shop set resources deploy/orders-api -c app --requests=cpu=100m,memory=128Mi --limits=cpu=500m,memory=256Mi
kubectl -n shop get hpa -w     # צריך לעלות עד 6 פודים
```
העומס הגבוה (BURN_MS=400) מכוון. reset.sh מחזיר אותו.

## מניעה
כדאי להוסיף: policy שמחייב requests (Kyverno/Gatekeeper), התראה על HPA במצב ScalingActive=False.
