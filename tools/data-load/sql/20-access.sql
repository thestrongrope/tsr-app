-- Data load, domain access: one transaction. Row refusals are counted by staging.load_table, never raised.
begin;
select staging.load_table('access', 'users', 'access.user_roles', '{"user_id":"id"}', '{}', 'roleid <> ''0''');
select staging.load_table('access', 'permissions', 'access.permissions', p_mode => 'merge');
select staging.load_table('access', 'role_permissions', 'access.role_permissions', p_mode => 'merge');
select staging.load_table('access', 'class_access_rules', 'access.class_access_rules');
select staging.load_table('access', 'class_access_rule_conditions', 'access.class_access_rule_conditions');
select staging.load_table('access', 'user_permissions', 'access.user_permissions');
commit;
