-- Data load, domain platform: one transaction. Row refusals are counted by staging.load_table, never raised.
begin;
select staging.load_table('platform', 'genders', 'platform.genders');
select staging.load_table('platform', 'languages', 'platform.languages');
select staging.load_table('platform', 'lookups', 'platform.lookups', p_mode => 'merge');
select staging.load_table('platform', 'admin_access_log', 'platform.admin_access_log');
select staging.load_table('platform', 'feedback', 'platform.feedback');
select staging.load_table('platform', 'outbound_messages', 'platform.outbound_messages');
commit;
