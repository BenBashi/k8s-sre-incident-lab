## סימפטום
פוד ה־worker ב־ErrImagePull / ImagePullBackOff, ה־lag גדל.

## איתור
```bash
kubectl -n shop get pods -l app=orders-worker
kubectl -n shop describe pod -l app=orders-worker | tail -8    # pull access denied / not found
kubectl -n shop rollout history deploy/orders-worker
```

## תיקון
```bash
kubectl -n shop rollout undo deploy/orders-worker
```
ב־EKS: לבדוק שה־tag קיים ב־ECR ושלנוד יש הרשאה (IAM role של ה־node group).

## מניעה
כדאי להוסיף: pipeline שמוודא שה־image קיים לפני deploy, RollingUpdate במקום Recreate, התראה על ImagePullBackOff.
