# דף עזר: Kafka בתקלה

## איך בונים כל פקודה (לא משננים, מרכיבים)

כל פקודת CLI של Kafka בנויה מאותם חלקים:

| חלק | מה כותבים | למה |
| --- | --- | --- |
| כלי | `kafka-consumer-groups.sh` או `kafka-topics.sh` | קבוצות צרכנים או טופיקים |
| כתובת | `--bootstrap-server localhost:9092` | לאיזה ברוקר להתחבר. תמיד חובה |
| על מה | `--group orders-worker` או `--topic orders` | איזו קבוצה או איזה טופיק |
| פעולה | `--describe` / `--list` / `--reset-offsets` / `--create` / `--delete` | מה לעשות |
| היקף | `--topic orders:0` | רק פרטישן 0. בלי `:0` = כל הפרטישנים |
| יעד | `--to-offset N` / `--shift-by 1` / `--to-latest` / `--to-earliest` | לאן להזיז את הסימן |
| ביצוע | `--execute` | בלי זה הפקודה רק מציגה (dry run) |

## איך מוצאים את הכלים כשלא זוכרים

```bash
kubectl -n shop exec deploy/kafka -- ls /opt/kafka/bin | grep -E "topics|groups"
kubectl -n shop exec deploy/kafka -- /opt/kafka/bin/kafka-consumer-groups.sh --help 2>&1 | grep -A2 -E "reset-offsets|shift-by|to-offset|execute"
```

## הפקודות שצריך בתקלה

```bash
# כתובת קבועה, כדי לא להקליד כל פעם
K="kubectl -n shop exec deploy/kafka -- /opt/kafka/bin"

# מצב הקבוצה וה־lag לכל פרטישן
$K/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group orders-worker

# כל הקבוצות / כל הטופיקים
$K/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list
$K/kafka-topics.sh --bootstrap-server localhost:9092 --list

# פרטי טופיק: פרטישנים, leader, ISR
$K/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic orders

# דילוג על הודעה אחת בפרטישן 0 (הקבוצה חייבת להיות ריקה)
$K/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group orders-worker \
  --reset-offsets --topic orders:0 --shift-by 1             # בדיקה
$K/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group orders-worker \
  --reset-offsets --topic orders:0 --shift-by 1 --execute   # ביצוע
```

## הדרך בממשק (Kafka UI)

- דילוג על הודעה: ‏Consumers ← הקבוצה ← שלוש נקודות ← Reset offsets. בוחרים טופיק, פרטישן, וסוג OFFSET עם הערך החדש. עובד רק כשהקבוצה EMPTY.
- מציאת ההודעה: ‏Topics ← orders ← Messages, בוחרים פרטישן, משנים את Newest ל־Offset ומקלידים את המספר.

## חתימות של תקלות

| מה רואים | המשמעות |
| --- | --- |
| מצב EMPTY, ‏0 חברים, lag עולה בכל הפרטישנים | אין צרכן: ה־worker למטה או ב־0 רפליקות |
| מצב STABLE, צרכן קיים, lag עולה | הצרכן איטי, או קורא מטופיק אחר |
| מצב מתחלף ל־PREPARING_REBALANCE, פרטישן אחד קפוא | הודעה מורעלת, הצרכן קורס עליה |
| שגיאת NoBrokersAvailable באפליקציה | כתובת או פורט לא נכונים, או security group חוסם |
