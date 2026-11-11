-- Data load, domain identity: one transaction. Row refusals are counted by staging.load_table, never raised.
begin;
select staging.load_table('identity', 'users', 'identity.users');
select staging.load_table('identity', 'account_deletion_requests', 'identity.account_deletion_requests');
commit;
