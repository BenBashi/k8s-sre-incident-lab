# תרגול Splunk על הלוגים של המעבדה

המטרה: לחפש ב־Splunk את התקלות שהמעבדה מייצרת, כמו שתעשה בראיון.

## הרמת Splunk מקומי

```bash
docker run -d --name splunk --platform linux/amd64 \
  -p 8000:8000 -p 8088:8088 \
  -e SPLUNK_START_ARGS=--accept-license \
  -e SPLUNK_GENERAL_TERMS=--accept-sgt-current-at-splunk-com \
  -e SPLUNK_PASSWORD='Bootcamp123!' \
  -e SPLUNK_HEC_TOKEN=00000000-0000-0000-0000-000000000001 \
  splunk/splunk:latest
```

- הכניסה: http://localhost:8000 עם admin / Bootcamp123!
- העלייה הראשונה לוקחת כמה דקות. ב־Mac עם M1/M2/M3 ה־image רץ באמולציה ועלול להיות איטי.
- אם הפקודה נכשלת, כדאי לבדוק בדף של splunk/splunk ב־Docker Hub מה משתני הסביבה הנדרשים כרגע.
- חלופה: ‏Splunk Cloud trial חינמי ל־14 יום, ואז לשנות את HEC_URL ואת הטוקן בסקריפט.

## שליחת לוגים

```bash
./tools/splunk/ship-logs.sh
```

- הסקריפט רץ בלולאה: כל 10 שניות הוא שולח את הלוגים של כל הפודים ב־namespace shop ואת ה־Events של Kubernetes.
- כל לוג נכנס עם sourcetype=_json, ו־source הוא שם הפוד.

## שאילתות לתרגול

```
index=main sourcetype=_json level=ERROR | stats count by service, error_type
index=main sourcetype=_json | timechart span=1m count by level
index=main service=loadgen | timechart span=1m count by status
index=main service=orders-api msg="order created" | timechart span=1m avg(duration_ms) p95(duration_ms)
index=main source=k8s-events reason=* | stats count by reason, object
index=main service=orders-worker msg="failed to parse message" | table _time partition offset raw
index=main level=ERROR | head 1 | table _time service msg error
```

- תרגיל: להריץ ./break.sh, ולמצוא את התקלה רק דרך Splunk לפני שנוגעים ב־kubectl.
- תרגיל: לבנות dashboard עם 4 פאנלים (שגיאות לפי שירות, סטטוסים של loadgen, זמני תגובה, אירועי K8s) ו־alert על level=ERROR מעל 20 בדקה.
