-- The reject path, on hand-made staging rows (needs a load run with --keep-staging so the engine exists). Everything is
-- rolled back. Rows the target refuses are counted by reason; the others load; no value appears in the report.
\set ON_ERROR_STOP on
create function pg_temp.expect(label text, ok boolean) returns void language plpgsql as $$
begin
    if ok is not true then raise exception 'ASSERTION FAILED: %', label; end if;
    raise notice 'ok - %', label;
end $$;
begin;
set local staging.source_tz = 'UTC';
delete from staging.report; delete from staging.report_detail;
delete from classes.tags;

create table staging.t_bad (id text, name text, created_at text, updated_at text, deleted_at text, created_by text, updated_by text, deleted_by text, _rn bigint generated always as identity);
insert into staging.source_columns select 't_bad', column_name, data_type from staging.source_columns where table_name = 'tags';
insert into staging.t_bad (id, name, created_at) values
  ('1', 'ok', '2026-01-01 00:00:00'),
  ('2', repeat('x', 51), '2026-01-01 00:00:00'),
  ('3', null, '2026-01-01 00:00:00'),
  ('x', 'bad id', '2026-01-01 00:00:00'),
  ('4', 'dup', '2026-01-01 00:00:00'),
  ('4', 'dup again', '2026-01-01 00:00:00'),
  ('99999999999', 'too big', '2026-01-01 00:00:00'),
  ('5', 'zero date in a required column', '0000-00-00 00:00:00');
select staging.load_table('test', 't_bad', 'classes.tags');

select pg_temp.expect('8 rows in, 2 loaded, 6 rejected', (select source_rows = 8 and loaded_rows = 2 and rejected_rows = 6 from staging.report));
select pg_temp.expect('the loaded rows are the clean ones', (select array_agg(id order by id) = array[1, 4] from classes.tags));
select pg_temp.expect('reasons are counted: length CHECK, NOT NULL, bad number, duplicate key, out of range, zero date',
    (select count(*) = 6 and sum(row_count) = 6 from staging.report_detail where kind = 'rejected')
    and (select row_count = 1 from staging.report_detail where kind = 'rejected' and reason like '23514 constraint ck_tags_name_length')
    and (select row_count = 1 from staging.report_detail where kind = 'rejected' and reason = '23502 column name')
    and (select row_count = 1 from staging.report_detail where kind = 'rejected' and reason = '23502 column created_at')
    and (select row_count = 1 from staging.report_detail where kind = 'rejected' and reason = '22P02')
    and (select row_count = 1 from staging.report_detail where kind = 'rejected' and reason = '22003')
    and (select row_count = 1 from staging.report_detail where kind = 'rejected' and reason like '23505 constraint %'));
select pg_temp.expect('the zero date is named', (select row_count = 1 from staging.report_detail where kind = 'zero_date_in_required_column' and reason = 'created_at'));
select pg_temp.expect('no row value in the report', not exists (select 1 from staging.report_detail where reason like '%dup%' or reason like '%too big%' or reason like '%bad id%'));

-- invalid JSON in a nullable text-JSON column is set to NULL and counted; the row still loads
delete from classes.class_audit_log;
create table staging.t_json (id text, class_id text, action text, details text, performed_by text, performed_at text, _rn bigint generated always as identity);
insert into staging.source_columns select 't_json', column_name, data_type from staging.source_columns where table_name = 'class_audit_log';
insert into staging.t_json (id, class_id, action, details, performed_by, performed_at) values
  ('1', '1', 'created', '{"a":1}', '1', '2026-01-01 00:00:00'),
  ('2', '1', 'created', '{broken', '1', '2026-01-01 00:00:00'),
  ('3', '1', 'created', null, '1', '2026-01-01 00:00:00');
select staging.load_table('test', 't_json', 'classes.class_audit_log');
select pg_temp.expect('invalid JSON is set to NULL, counted, and the row loads',
    (select loaded_rows = 3 and rejected_rows = 0 from staging.report where source_table = 't_json')
    and (select row_count = 1 from staging.report_detail where kind = 'invalid_json_set_null' and reason = 'details')
    and (select count(*) = 2 from classes.class_audit_log where details is null));
rollback;
