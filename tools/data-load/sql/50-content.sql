-- Data load, domain content: one transaction. Row refusals are counted by staging.load_table, never raised.
begin;
select staging.load_table('content', 'holy_quran', 'content.holy_quran');
commit;
