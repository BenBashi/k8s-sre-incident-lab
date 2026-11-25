# תרגול EKS אמיתי

המטרה: לתרגל את מה ש־kind ו־kubeadm לא מלמדים: התחברות דרך IAM, הרשאות לפודים, ECR, נודים מנוהלים ולוגים של ה־control plane.

## לפני שמתחילים

- עלות: בערך 0.25 דולר לשעה (control plane, שני נודי spot ו־NAT אחד). סשן של 4 שעות עולה בערך דולר. ה־Free Tier לא מכסה EKS.
- חשבון: להשתמש בחשבון AWS פרטי, לא בחשבון של העבודה.
- כלים: `brew install awscli eksctl helm`
- מחיקה: בסוף כל סשן `eksctl delete cluster -f tools/eks/cluster.yaml`. כדאי גם להגדיר AWS Budget עם התראה על 10 דולר.

## הקמה

```bash
aws configure                      # או aws configure sso
aws sts get-caller-identity        # מי אני ב־AWS?
eksctl create cluster -f tools/eks/cluster.yaml    # כ־15 עד 20 דקות
```

## תרגיל 1: התחברות לאשכול (הכי חשוב לראיון)

```bash
aws eks list-clusters --region eu-north-1
aws eks describe-cluster --name bootcamp --region eu-north-1 --query 'cluster.{status:status,version:version,endpoint:endpoint}'
aws eks update-kubeconfig --name bootcamp --region eu-north-1
kubectl config current-context
kubectl get nodes -o wide
kubectl config view --minify | grep -A8 exec      # רואים ש־kubectl מריץ aws eks get-token
```

- הזרימה: ‏kubectl מריץ `aws eks get-token`, מקבל טוקן חתום לפי ה־IAM identity שלך, ה־API server של EKS מאמת אותו מול IAM, ואז ממפה את ה־identity ל־Kubernetes דרך access entries או ה־ConfigMap ‏aws-auth. משם RBAC רגיל.
- בראיון: אם `kubectl` מחזיר `You must be logged in to the server (Unauthorized)`, הבעיה היא ב־IAM או ב־access entry, לא ב־RBAC. אם הוא מחזיר `Forbidden`, האימות עבר ו־RBAC חוסם.

## תרגיל 2: משתמש בלי גישה (Unauthorized)

```bash
# ליצור IAM role חדש (בקונסול או ב־CLI) ולעשות assume אליו, ואז:
kubectl get pods                       # Unauthorized
# התיקון, כמשתמש המנהל:
aws eks create-access-entry --cluster-name bootcamp --principal-arn <ROLE_ARN> --region eu-north-1
aws eks associate-access-policy --cluster-name bootcamp --principal-arn <ROLE_ARN> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy --access-scope type=cluster --region eu-north-1
aws eks list-access-entries --cluster-name bootcamp --region eu-north-1
kubectl -n kube-system get configmap aws-auth -o yaml    # השיטה הישנה, עדיין נפוצה בארגונים
```

## תרגיל 3: פוד שמקבל AccessDenied מ־AWS

```bash
kubectl create namespace shop
kubectl -n shop create serviceaccount s3-reader
kubectl -n shop run awscli --image=amazon/aws-cli --restart=Never \
  --overrides='{"spec":{"serviceAccountName":"s3-reader"}}' --command -- aws s3 ls
kubectl -n shop logs awscli            # AccessDenied / Unable to locate credentials
kubectl -n shop delete pod awscli
# תיקון עם Pod Identity (השיטה החדשה):
eksctl create podidentityassociation --cluster bootcamp --region eu-north-1 --namespace shop \
  --service-account-name s3-reader --permission-policy-arns arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
# או עם IRSA (השיטה הנפוצה בארגונים קיימים):
# eksctl create iamserviceaccount --cluster bootcamp --namespace shop --name s3-reader \
#   --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --approve --override-existing-serviceaccounts
kubectl -n shop get sa s3-reader -o yaml    # ב־IRSA תראה את ה־annotation eks.amazonaws.com/role-arn
```

- בראיון: פוד מקבל AccessDenied, אז בודקים איזה service account יש לו, איזה role משויך אליו, את ה־trust policy של ה־role ואת ה־permissions. ‏CloudTrail מראה מי ניסה ומה נדחה.

## תרגיל 4: ECR והמעבדה על EKS

```bash
ACCOUNT=$(aws sts get-caller-identity --query Account --output text); REGION=eu-north-1
aws ecr create-repository --repository-name shop-app --region $REGION
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com
docker build --platform linux/amd64 -t $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/shop-app:1.0 app
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/shop-app:1.0
```

- המשך: להחליף ב־k8s/20-app.yaml את `bootcamp/shop-app:1.0` בכתובת ה־ECR, ולהריץ את הקבצים של k8s (בלי kind). רוב התרחישים עובדים גם כאן.
- שימו לב: ה־image נבנה ל־amd64 כי נודי t3 הם x86. ‏image של ARM על נוד x86 נותן `exec format error`, תקלה קלאסית כשבונים על מק.

## תרגיל 5: נודים וקיבולת

```bash
kubectl -n shop create deployment big --image=nginx --replicas=20
kubectl -n shop set resources deployment big --requests=cpu=500m
kubectl -n shop get pods | grep Pending          # אין מקום
eksctl get nodegroup --cluster bootcamp --region eu-north-1
eksctl scale nodegroup --cluster bootcamp --name ng-spot --nodes 3 --region eu-north-1
kubectl describe node <node> | grep -A6 Allocated
kubectl -n shop delete deployment big
```

- בראיון: ב־production זה Cluster Autoscaler או Karpenter. בודקים את הלוגים שלהם ואת ה־max של ה־node group.
- עוד דבר שחשוב לזכור: כל פוד ב־EKS מקבל IP אמיתי מה־VPC (VPC CNI). כשנגמרים ה־IPs ב־subnet, או שה־instance הגיע למקסימום ENIs, פודים נתקעים ב־ContainerCreating עם `failed to assign an IP address`.

## תרגיל 6: מי שינה מה (audit logs)

```bash
eksctl utils update-cluster-logging --cluster bootcamp --region eu-north-1 --enable-types audit,authenticator --approve
kubectl -n shop delete deployment big --ignore-not-found
```

- המשך: ב־CloudWatch Logs Insights, על log group ‏/aws/eks/bootcamp/cluster:

```
fields @timestamp, user.username, verb, objectRef.resource, objectRef.name
| filter verb in ["delete","patch","update"] and objectRef.namespace = "shop"
| sort @timestamp desc | limit 20
```

## מחיקה (לא לשכוח)

```bash
eksctl delete cluster -f tools/eks/cluster.yaml
aws ecr delete-repository --repository-name shop-app --force --region eu-north-1
```

- בדיקה: בקונסול של EC2 לוודא שאין Load Balancers, ‏NAT Gateways או volumes שנשארו.
