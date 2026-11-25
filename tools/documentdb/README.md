# תרגול DocumentDB בתוך ה־VPC של אשכול ה־EKS

המטרה: להתחבר ל־DocumentDB אמיתי מפוד, ולהכיר את התקלות שמבדילות אותו מ־MongoDB.

## לפני שמתחילים

- דרישה: אשכול ה־EKS מ־tools/eks כבר קם, ו־kubectl מחובר אליו.
- עלות: ניסיון חינמי לחודש למי שלא השתמש ב־DocumentDB. אחרת כ־0.11 דולר לשעה.
- חשוב: מוחקים את DocumentDB לפני מחיקת אשכול ה־EKS. אחרת eksctl לא יצליח למחוק את ה־VPC.

## הקמה (כ־15 דקות, רץ ברקע)

```bash
REGION=eu-north-1
read VPC SG <<< $(aws eks describe-cluster --name bootcamp --region $REGION \
  --query 'cluster.resourcesVpcConfig.[vpcId,clusterSecurityGroupId]' --output text)
SUBNETS=$(aws ec2 describe-subnets --region $REGION \
  --filters Name=vpc-id,Values=$VPC Name=tag:kubernetes.io/role/internal-elb,Values=1 \
  --query 'Subnets[].SubnetId' --output text)
echo "VPC=$VPC SG=$SG SUBNETS=$SUBNETS"

aws docdb create-db-subnet-group --region $REGION --db-subnet-group-name bootcamp-docdb \
  --db-subnet-group-description bootcamp --subnet-ids $SUBNETS
aws docdb create-db-cluster --region $REGION --db-cluster-identifier bootcamp-docdb --engine docdb \
  --master-username bootcamp --master-user-password 'Bootcamp2026x' \
  --db-subnet-group-name bootcamp-docdb --vpc-security-group-ids $SG
aws docdb create-db-instance --region $REGION --db-instance-identifier bootcamp-docdb-1 \
  --db-instance-class db.t3.medium --engine docdb --db-cluster-identifier bootcamp-docdb
aws docdb wait db-instance-available --region $REGION --db-instance-identifier bootcamp-docdb-1
DOCDB=$(aws docdb describe-db-clusters --region $REGION --db-cluster-identifier bootcamp-docdb \
  --query 'DBClusters[0].Endpoint' --output text); echo $DOCDB
```

- הסבר: ה־security group של אשכול ה־EKS מאפשר תעבורה בין כל מי שמשויך אליו, ולכן פודים על הנודים יגיעו לפורט 27017.

## פוד עם mongosh ותעודת ה־CA

```bash
curl -sO https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
kubectl create configmap rds-ca --from-file=global-bundle.pem
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: {name: mongosh}
spec:
  containers:
    - name: mongosh
      image: mongo:7
      command: ["sleep", "infinity"]
      volumeMounts: [{name: ca, mountPath: /ca}]
  volumes:
    - name: ca
      configMap: {name: rds-ca}
YAML
kubectl wait --for=condition=Ready pod/mongosh
```

## תרגיל 1: חיבור בלי TLS נכשל

```bash
kubectl exec -it mongosh -- mongosh "mongodb://bootcamp:Bootcamp2026x@$DOCDB:27017/?replicaSet=rs0"
```

- תוצאה צפויה: ניתוק או timeout. ב־DocumentDB, ‏TLS מופעל כברירת מחדל.

## תרגיל 2: חיבור נכון

```bash
kubectl exec -it mongosh -- mongosh "mongodb://bootcamp:Bootcamp2026x@$DOCDB:27017/?tls=true&tlsCAFile=/ca/global-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
```

- פירוק המחרוזת: tls ו־tlsCAFile להצפנה, replicaSet=rs0 קבוע ב־DocumentDB, readPreference מפזר קריאות לרפליקות, retryWrites=false כי DocumentDB לא תומך ב־retryable writes.

## תרגיל 3: ההבדלים מ־MongoDB, בתוך ה־shell

```js
use shop
db.orders.insertOne({ order_id: "a1", qty: 2 })
db.orders.createIndex({ order_id: 1 })
db.orders.find({ order_id: "a1" }).explain()            // IXSCAN, כמו ב־Mongo
db.createUser({ user: "worker", pwd: "WorkerPass1", roles: [{ role: "readWrite", db: "shop" }] })
db.runCommand({ mapReduce: "orders", map: function(){}, reduce: function(){}, out: "x" })   // לא נתמך
```

- תרגיל: להתחבר בלי retryWrites=false ולנסות insertOne. מה השגיאה?
- הנקודה לראיון: אותו driver ואותן פקודות ברוב המקרים, אבל יש פקודות שלא נתמכות, ו־TLS ו־retryWrites הם התקלות הכי נפוצות.

## ניטור (תיאוריה, לפי הקונסול)

- מדדים: ב־CloudWatch: ‏DatabaseConnections, ‏CPUUtilization, ‏BufferCacheHitRatio, ‏FreeableMemory.
- פרופיילר: מפעילים ב־cluster parameter group (profiler=enabled, profiler_threshold_ms), והשאילתות האיטיות נשלחות ל־CloudWatch Logs.
- audit: אותו parameter group, ‏audit_logs=enabled.

## מחיקה (לפני מחיקת ה־EKS)

```bash
kubectl delete pod mongosh; kubectl delete configmap rds-ca
aws docdb delete-db-instance --region $REGION --db-instance-identifier bootcamp-docdb-1
aws docdb wait db-instance-deleted --region $REGION --db-instance-identifier bootcamp-docdb-1
aws docdb delete-db-cluster --region $REGION --db-cluster-identifier bootcamp-docdb --skip-final-snapshot
aws docdb delete-db-subnet-group --region $REGION --db-subnet-group-name bootcamp-docdb
```
