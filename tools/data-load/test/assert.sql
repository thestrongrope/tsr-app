-- Assertions on a database filled by tools/data-load/load.sh from the S2 scratch source (tools/parity-php/s2-source.sh).
-- They name the invented rows of tools/parity-php/s2-fixtures.sql (ids and tokens 960001 and up). Run with psql; the first
-- failing assertion stops the run with its label. Row values appear in this file only because they are invented.
\set ON_ERROR_STOP on
set client_encoding = 'UTF8';
create function pg_temp.expect(label text, ok boolean) returns void language plpgsql as $$
begin
    if ok is not true then raise exception 'ASSERTION FAILED: %', label; end if;
    raise notice 'ok - %', label;
end $$;

-- timestamptz from a MariaDB datetime read as UTC; a zero date set to NULL; NULL versus empty string; emoji; a cut
select pg_temp.expect('datetime read as UTC', (select createdon = timestamptz '2026-01-15 10:20:30+00' from identity.users where id = 960001));
select pg_temp.expect('zero date in a nullable column is NULL', (select createdon is null from identity.users where id = 960002));
select pg_temp.expect('a non-ASCII and emoji name survives', (select name = 'Zoë 😀 name' from membership.member_profiles where user_id = 960001));
select pg_temp.expect('empty string stays empty', (select last_name = '' and mobile = '' from membership.member_profiles where user_id = 960001));
select pg_temp.expect('NULL stays NULL', (select first_name is null and last_name is null and picture is null from membership.member_profiles where user_id = 960002));
select pg_temp.expect('a 2001 character picture is cut to 2000', (select char_length(picture) = 2000 from membership.member_profiles where user_id = 960001));
select pg_temp.expect('the users split: role to access.user_roles only where roleid <> 0',
    (select count(*) = 1 from access.user_roles where user_id in (960001, 960002) and roleid = 4)
    and (select count(*) = 0 from access.user_roles where user_id = 960002));
select pg_temp.expect('every user has an identity row and a profile row',
    (select count(*) from identity.users) = (select count(*) from membership.member_profiles));

-- text with newline, tab, carriage return, backslash, quotes and the two characters \N; enum; wall-clock and zero dates
select pg_temp.expect('multi-line text with tab, CRLF, backslash, quotes and a literal \N is exact',
    (select description = E'line one\nline two with\ta tab\r\nback\\slash, "quotes", it''s, and \\N as text' from classes.syllabus where id = 960001));
select pg_temp.expect('an enum becomes its text', (select link_type = 'external' from classes.syllabus where id = 960001));
select pg_temp.expect('syllabus: a datetime, a zero date to NULL, a smallint flag',
    (select modified_at = timestamptz '2026-02-03 10:00:00+00' and deleted_at is null and is_active = 1 and sort_order = 1 from classes.syllabus where id = 960001));
select pg_temp.expect('syllabus: empty description, NULL sort order, flag 0, a real deleted_at',
    (select description = '' and sort_order is null and is_active = 0 and deleted_at = timestamptz '2026-04-01 00:00:00+00' from classes.syllabus where id = 960002));
select pg_temp.expect('an emoji tag name', (select name = 'tag 🌙' from classes.tags where id = 960001));

-- SET and enum with spaces, slashes and parentheses; JSON text kept as written, and NULL JSON
select pg_temp.expect('a SET value keeps its commas and spaces',
    (select interests = 'Teaching,Writing (articles / scripts),Devops / Infra' and class_level = 'Primary' from membership.class_registrations where id = 960001));
select pg_temp.expect('JSON text is kept as written (valid JSON, an emoji inside)',
    (select details = '{"note":"😀","n":[1,2,3]}' and details::text is json from classes.class_audit_log where id = 960001));
select pg_temp.expect('a NULL JSON stays NULL', (select details is null from classes.class_audit_log where id = 960002));

-- timestamp column (UTC), wall-clock columns (no zone), NULL versus empty string
select pg_temp.expect('a MariaDB timestamp column is UTC',
    (select last_accessed_at = timestamptz '2026-02-03 04:05:06+00' and registered_at = timestamptz '2026-01-02 03:04:05+00' from notifications.user_devices where id = 960001));
select pg_temp.expect('send_at is wall clock, unchanged',
    (select send_at = timestamp '2026-12-01 09:30:00' and tz = 'Asia/Kolkata' and body = E'first line\nsecond line' and title = 'Once 😀' from notifications.class_scheduled_notifications where id = 960001));
select pg_temp.expect('send_time is wall clock, unchanged',
    (select send_time = time '18:45:00' and weekdays = 'MON,WED' and kind = 'WEEKLY' and repeat_weekly = 1 and status = 'done'
        and last_run_at = timestamptz '2026-11-04 13:15:00+00' from notifications.class_scheduled_notifications where id = 960002));
select pg_temp.expect('skipped_reason: NULL versus empty',
    (select skipped_reason is null from notifications.class_scheduled_notification_runs where id = 960001)
    and (select skipped_reason = '' from notifications.class_scheduled_notification_runs where id = 960002));

-- identity columns continue after the highest id; the orphan rows were loaded, not refused
select pg_temp.expect('classes.tags next id is max + 1',
    (select last_value = (select max(id) + 1 from classes.tags) and not is_called from classes.tags_id_seq));
select pg_temp.expect('an orphan row (class that does not exist) is loaded', (select count(*) = 1 from classes.class_students where id = 960001 and class_id = 987654));
select pg_temp.expect('the orphan is reported', (select row_count >= 1 from staging.report_detail where kind = 'orphan' and target_table = 'classes.class_students' and reason like 'class_id ->%'));
select pg_temp.expect('migration seed rows are kept (merge): permissions',
    (select count(*) >= 101 from access.permissions));
select pg_temp.expect('nothing was rejected in the proof data', (select coalesce(sum(rejected_rows), 0) = 0 from staging.report));
select pg_temp.expect('the cut was counted', (select row_count = 1 from staging.report_detail where target_table = 'membership.member_profiles' and kind = 'truncated_to_2000'));
select pg_temp.expect('zero dates were counted', (select sum(row_count) >= 2 from staging.report_detail where kind = 'zero_date_set_null'));
