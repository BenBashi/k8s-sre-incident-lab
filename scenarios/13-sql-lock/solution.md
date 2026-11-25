## סימפטום
שאילתות ה־INSERT ממתינות לנעילה (Waiting for table metadata lock). ה־API לא קורס, רק נתקע. loadgen מקבל 000 אחרי 10 שניות.

## איתור (MySQL)
```bash
kubectl -n shop exec -it deploy/mysql -- mysql -uroot -proot-pass shop
```
```sql
SHOW FULL PROCESSLIST;     -- הרבה INSERT במצב Waiting for table metadata lock, וחיבור אחד ב־User sleep
SELECT * FROM sys.schema_table_lock_waits\G     -- blocking_pid + sql_kill_blocking_connection
SELECT * FROM performance_schema.metadata_locks WHERE OBJECT_NAME = 'orders';
```

## תיקון
```sql
KILL <blocking_pid>;
```
```bash
kubectl -n shop delete job nightly-maintenance
```
להגיד בקול: לפני הריגת session ב־production מוודאים מה הוא עושה ומי הבעלים.

## אותו תרחיש ב־SQL Server
```sql
SELECT session_id, blocking_session_id, wait_type, wait_time, command
FROM sys.dm_exec_requests WHERE blocking_session_id <> 0;
EXEC sp_who2;
KILL <session_id>;
```

## מניעה
כדאי להוסיף: ‏lock_wait_timeout ו־max_execution_time (ב־MSSQL: ‏LOCK_TIMEOUT), חלונות תחזוקה, התראה על שאילתות ארוכות (Datadog DBM / Dynatrace / RDS Performance Insights).
