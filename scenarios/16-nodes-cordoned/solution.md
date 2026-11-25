## סימפטום
פודים ב־Pending, Events: 0/3 nodes are available: 1 node(s) had untolerated taint, 2 node(s) were unschedulable.

## איתור
```bash
kubectl -n shop describe pod -l app=orders-api | tail -5
kubectl get nodes        # SchedulingDisabled
```

## תיקון
```bash
kubectl uncordon bootcamp-worker bootcamp-worker2
```

## מניעה
כדאי להוסיף: runbook לתחזוקה שמסתיים ב־uncordon, PodDisruptionBudget, התראה על נודים ב־SchedulingDisabled. ב־EKS: managed node group upgrades עושים את זה אוטומטית.
