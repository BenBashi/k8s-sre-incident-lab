# חיבור Datadog למעבדה

המטרה: לראות את התקלות של המעבדה גם ב־Datadog: פודים, מטריקות, לוגים ושירותים.

## פעם אחת

- הרשמה: לפתוח ניסיון חינמי של 14 יום באתר של Datadog. כדאי לפתוח עכשיו, כי הראיון בחמישי.
- מפתח: ב־Organization Settings ← API Keys להעתיק את ה־API key.
- אזור: לבדוק בכתובת של הדפדפן אם החשבון ב־app.datadoghq.com (אז SITE=datadoghq.com) או ב־app.datadoghq.eu (אז SITE=datadoghq.eu).

## התקנת ה־Agent על אשכול kind

```bash
export DD_API_KEY=<המפתח שלך>
export DD_SITE=datadoghq.com          # או datadoghq.eu
helm repo add datadog https://helm.datadoghq.com && helm repo update
helm install datadog-agent datadog/datadog -n datadog --create-namespace \
  --set datadog.apiKey=$DD_API_KEY \
  --set datadog.site=$DD_SITE \
  --set datadog.clusterName=bootcamp \
  --set datadog.kubelet.tlsVerify=false \
  --set datadog.logs.enabled=true \
  --set datadog.logs.containerCollectAll=true \
  --set clusterAgent.enabled=true
kubectl -n datadog get pods
```

- הערה: ‏`tlsVerify=false` נדרש רק ב־kind. ב־EKS לא צריך אותו.
- אימות: אחרי 2 עד 3 דקות האשכול מופיע ב־Infrastructure ← Kubernetes.

## מה לתרגל אחרי כל ./break.sh

- תצוגה: ‏Infrastructure ← Kubernetes ← Pods: למצוא פוד ב־CrashLoopBackOff או OOMKilled, ולראות restarts.
- לוגים: ‏Logs ← Search: ‏`service:orders-api status:error` או `@level:ERROR`, ואז Group by ‏`@error`.
- מטריקות: ‏Metrics ← Explorer: ‏`kubernetes.cpu.usage.total` לפי pod_name, ‏`kubernetes.containers.restarts`, ‏`kubernetes_state.hpa.current_replicas`.
- התראות: ‏Monitors ← New Monitor: התראה על restarts גבוהים, ועוד אחת על ERROR בלוגים.
- דשבורד: לבנות דשבורד אחד עם 4 גרפים: שגיאות לפי שירות, CPU לפי פוד, רפליקות של ה־HPA, ו־restarts.

## הסרה

```bash
helm uninstall datadog-agent -n datadog
```
