# מעבדת Break-Fix לקראת ראיון ה־SRE

מעבדה מקומית על המק שמדמה את המערכת מהראיון: אשכול Kubernetes, ‏Kafka, ‏MongoDB, ‏MySQL ושני מיקרוסרוויסים. סקריפט שובר אותה בכל פעם בדרך אחרת, ואתה מאתר ומתקן כמו בראיון.

## מה רץ במעבדה

```
loadgen ──HTTP──> orders-api ──INSERT──> MySQL
                      │
                      └──produce──> Kafka (topic: orders, 3 partitions)
                                        │
                                        └──consume──> orders-worker ──insert──> MongoDB
```

- הזרימה: ‏loadgen שולח הזמנה כל חצי שנייה ל־orders-api.
- השירות orders-api שומר ב־MySQL ומפרסם הודעה לקפקא. יש לו HPA ‏(2 עד 6 פודים).
- השירות orders-worker צורך מהטופיק וכותב ל־MongoDB.
- כל הלוגים הם JSON בשורה אחת, עם שדות כמו service, ‏level, ‏msg, ‏error, ‏dependency. כך בדיוק נוח לחפש אותם ב־Splunk.

## דרישות מוקדמות (פעם אחת)

```bash
brew install kind kubectl jq
# וגם Docker Desktop או OrbStack, פתוח ורץ
```

- כדאי לתת ל־Docker לפחות 4 CPU ו־6GB זיכרון.

## הקמה

```bash
cd k8s-sre-incident-lab
chmod +x *.sh
./setup.sh
```

- ההקמה הראשונה לוקחת כ־5 עד 10 דקות (הורדת images).
- בסוף תראה את ./status.sh עם הכל ירוק.

## איך מתאמנים

```bash
./break.sh            # תרחיש אקראי, השם מוסתר, כמו בראיון
./break.sh list       # רשימת התרחישים
./break.sh 13         # תרחיש מסוים
./reveal.sh hint      # רמז
./reveal.sh solution  # פתרון מלא + מניעה
./reset.sh            # חזרה למצב תקין
./status.sh           # בדיקה שהתיקון עבד
```

- כל תרגול: להפעיל טיימר של 30 דקות, לדבר בקול, ולעבוד לפי 8 השלבים מהמסמך (סימפטום, השפעה, מה השתנה, מבחוץ פנימה, לוגים+מטריקות, השערה, הקלה ואז תיקון, אימות וסיכום).
- בסוף כל תרחיש: לכתוב 3 שורות של root cause, תיקון ומניעה, ולנסח את שאילתת ה־Splunk וההתראה שהיית מוסיף.
- חשוב: לא להציץ ב־scenarios/ לפני שמנסים. השם של התיקייה כבר מסגיר את התשובה.

## התרחישים (24)

| תרחיש | תחום | מה נשבר (ספוילר) |
| --- | --- | --- |
| תרחיש 01 | סודות ו־DB | סיסמת MySQL שגויה ב־secret של ה־API |
| תרחיש 02 | משאבים | ה־worker מקבל OOMKilled |
| תרחיש 03 | תזמון | פודים ב־Pending בגלל requests ענקיים |
| תרחיש 04 | רשת | בורר (selector) שגוי ב־Service |
| תרחיש 05 | בדיקות | נתיב readiness probe שגוי + Recreate |
| תרחיש 06 | סקיילינג | ה־HPA בלי CPU requests |
| תרחיש 07 | פריסה | תג image שלא קיים |
| תרחיש 08 | קפקא | אין צרכנים |
| תרחיש 09 | קפקא | צרכן על הטופיק הלא נכון |
| תרחיש 10 | קפקא | הודעה מורעלת (poison message) |
| תרחיש 11 | קפקא | צרכן איטי, lag עולה |
| תרחיש 12 | סודות ו־Mongo | סיסמת Mongo שגויה |
| תרחיש 13 | מסד SQL | נעילת טבלה ב־MySQL (כולל פתרון ל־SQL Server) |
| תרחיש 14 | מסד SQL | מיצוי max_connections (כולל פתרון ל־SQL Server) |
| תרחיש 15 | קונפיגורציה | פורט שגוי ל־Kafka |
| תרחיש 16 | נודים | נודים ב־cordon |
| תרחיש 17 | מונגו | שירות Mongo למטה |
| תרחיש 18 | מונגו | אינדקס שנמחק, COLLSCAN על 1.5 מיליון מסמכים |
| תרחיש 19 | מונגו | משתמש ה־worker קיבל הרשאת קריאה בלבד |
| תרחיש 20 | ערך שגוי ב־DB | הגדרה עסקית שגויה בטבלת app_settings ב־MySQL |
| תרחיש 21 | ערך שגוי ב־DB | מסמך הגדרות ב־Mongo מפנה לאוסף הלא נכון |
| תרחיש 22 | עומס | לקוח חדש מציף את ה־API, וה־HPA בתקרה |
| תרחיש 23 | בדיקות בריאות | בדיקת liveness שבודקת את ה־DB גורמת להשבתה מתגלגלת |
| תרחיש 24 | בדיקות בריאות | בדיקת liveness אגרסיבית הורגת את האפליקציה לפני שעלתה |

## למה MySQL ולא SQL Server

- ראש הצוות אמר SQL בלי לציין מנוע, ולכן המעבדה רצה על MySQL (נפוץ ב־AWS כ־RDS/Aurora ורץ טבעי על מק M).
- בתרחישים 13 ו־14 יש גם את הפקודות המקבילות ל־SQL Server, ובמסמך יש פרק השוואה בין שני המנועים.

## תרגול EKS אמיתי (אופציונלי, בתשלום)

- ההסבר נמצא ב־tools/eks/README.md: הקמת אשכול EKS קטן עם eksctl לכמה שעות, התחברות, ותרגול של מה ש־kind לא מכסה.

## חיבור Datadog

- ההסבר נמצא ב־tools/datadog/README.md: התקנת ה־Agent עם helm על אשכול ה־kind.

## תרגול Splunk (חובה לראיון)

- ההסבר נמצא ב־tools/splunk/README.md: הרמת Splunk מקומי ושליחת הלוגים של המעבדה אליו, כדי לתרגל SPL על התקלות האמיתיות.

## שאילתות שכדאי לתרגל גם בלי Splunk

```bash
kubectl -n shop logs deploy/orders-api --since=10m | jq -c 'select(.level=="ERROR")' | head
kubectl -n shop logs deploy/orders-api --since=10m | jq -r 'select(.level=="ERROR") | .error' | sort | uniq -c
kubectl -n shop get events --sort-by=.lastTimestamp | tail -20
```

## ניקוי

```bash
kind delete cluster --name bootcamp
```

## מה המעבדה לא מכסה

- המעבדה רצה מקומית ולא ב־AWS: אין IAM/IRSA, ‏ALB, ‏RDS, ‏MSK או DocumentDB אמיתיים. את אלה מכסה המסמך (פרק AWS ופרק DocumentDB/OpenShift).
- כלי Dynatrace לא מותקן במעבדה: אפשר לפתוח ניסיון חינמי ולחבר אותו לאשכול kind. את Datadog מחברים לפי tools/datadog/README.md.
