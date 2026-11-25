## סימפטום
פודים חדשים ב־Pending, rollout תקוע, הפודים הישנים עדיין מגישים תעבורה.

## איתור
```bash
kubectl -n shop get pods | grep Pending
kubectl -n shop describe pod <pending-pod> | tail -5    # 0/3 nodes are available: Insufficient cpu
kubectl -n shop rollout history deploy/orders-api
```

## תיקון
```bash
kubectl -n shop set resources deploy/orders-api -c app --requests=cpu=100m,memory=128Mi --limits=cpu=500m,memory=256Mi
# או: kubectl -n shop rollout undo deploy/orders-api
```

## מניעה
כדאי להוסיף: LimitRange / ResourceQuota, בדיקת manifests ב־CI, התראה על פודים ב־Pending יותר מ־5 דקות. ב־EKS: לבדוק גם Cluster Autoscaler/Karpenter.
