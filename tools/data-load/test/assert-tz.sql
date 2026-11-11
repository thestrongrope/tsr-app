-- After a load with --source-tz Asia/Kolkata (+05:30): datetime columns shift, timestamp columns and wall-clock columns do not.
\set ON_ERROR_STOP on
create function pg_temp.expect(label text, ok boolean) returns void language plpgsql as $$
begin
    if ok is not true then raise exception 'ASSERTION FAILED: %', label; end if;
    raise notice 'ok - %', label;
end $$;
select pg_temp.expect('a datetime read in Asia/Kolkata is 5h30 earlier in UTC', (select createdon = timestamptz '2026-01-15 04:50:30+00' from identity.users where id = 960001));
select pg_temp.expect('a timestamp column is still UTC', (select last_accessed_at = timestamptz '2026-02-03 04:05:06+00' from notifications.user_devices where id = 960001));
select pg_temp.expect('wall-clock send_at is unchanged', (select send_at = timestamp '2026-12-01 09:30:00' from notifications.class_scheduled_notifications where id = 960001));
