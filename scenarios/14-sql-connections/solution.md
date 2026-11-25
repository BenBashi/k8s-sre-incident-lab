## סימפטום
השגיאה היא `(1040, 'Too many connections')`. ‏max_connections=40, ומישהו מחזיק את כל 40 החיבורים.

## איתור (MySQL)
```bash
kubectl -n shop logs deploy/orders-api | grep -i "too many"
kubectl -n shop exec -it deploy/mysql -- mysql -uroot -proot-pass shop      # ל־root יש חיבור שמור, גם כשהשרת מלא
```
```sql
SHOW VARIABLES LIKE 'max_connections';
SHOW STATUS LIKE 'Threads_connected';
SELECT user, SUBSTRING_INDEX(host, ':', 1) AS ip, command, COUNT(*) AS n
FROM information_schema.processlist GROUP BY 1, 2, 3 ORDER BY n DESC;
SELECT ATTR_VALUE AS program, COUNT(*) FROM performance_schema.session_connect_attrs
WHERE ATTR_NAME = 'program_name' GROUP BY 1;
```
```bash
kubectl -n shop get pods -o wide        # ה־IP של report-generator תואם ל־ip בשאילתה
```
```
index=* service=orders-api level=ERROR "Too many connections" | timechart span=1m count
```

## תיקון
```bash
kubectl -n shop scale deploy/report-generator --replicas=0
```
להגיד בקול: מתאמים עם הבעלים של ה־job, ולא מעלים max_connections בעיוורון (כל חיבור עולה זיכרון).

## אותו תרחיש ב־SQL Server
```sql
SELECT login_name, host_name, program_name, COUNT(*) AS n
FROM sys.dm_exec_sessions WHERE is_user_process = 1
GROUP BY login_name, host_name, program_name ORDER BY n DESC;
```

## מניעה
כדאי להוסיף: ‏RDS Proxy או pooler, משתמש DB נפרד לכל שירות עם MAX_USER_CONNECTIONS, התראה על חיבורים מעל 80% (CloudWatch DatabaseConnections).
