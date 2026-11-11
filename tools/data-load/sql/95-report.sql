-- The report body: counts only. Plain lines, no row value. Printed by load.sh to stdout and a file, which add the header
-- (source zone) and the RESULT line (load.sh knows the failed domains; this file does not).
\pset format unaligned
\pset tuples_only on
\pset footer off
select '== Tables: source rows exported, rows filtered by design, loaded, rejected (refused by the target, merge tables too), skipped (merge: kept the seed row)';
select format('%-52s src %9s  filtered %7s  loaded %9s  rejected %7s  skipped %5s%s',
              target_table, source_rows, filtered_rows, loaded_rows, rejected_rows, skipped_rows,
              case when mode = 'merge' then '  [merge]' else '' end)
  from staging.report order by seq;
select format('%-52s src %9s  filtered %7s  loaded %9s  rejected %7s  skipped %5s',
              'TOTAL', coalesce(sum(source_rows), 0), coalesce(sum(filtered_rows), 0), coalesce(sum(loaded_rows), 0),
              coalesce(sum(rejected_rows), 0), coalesce(sum(skipped_rows), 0)) from staging.report;
select '== Details (rejected, cut, set to NULL, orphaned logical references). Counts only.';
select format('%-52s %-30s %-60s %9s', target_table, kind, reason, row_count)
  from staging.report_detail where kind <> 'orphan' order by seq;
select '== Orphaned logical references (rows whose reference names nothing; NULL is not counted; token 0 is looked up like any value)';
select format('%-52s %-60s %9s', target_table, reason, row_count) from staging.report_detail where kind = 'orphan' order by seq;
