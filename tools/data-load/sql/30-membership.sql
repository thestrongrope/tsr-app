-- Data load, domain membership: one transaction. Row refusals are counted by staging.load_table, never raised.
begin;
select staging.load_table('membership', 'users', 'membership.member_profiles', '{"user_id":"id"}', '{"name":200,"picture":2000}');
select staging.load_table('membership', 'interest_options', 'membership.interest_options', p_mode => 'merge');
select staging.load_table('membership', 'student_interests', 'membership.student_interests');
select staging.load_table('membership', 'class_registrations', 'membership.class_registrations');
select staging.load_table('membership', 'class_registrations_languages', 'membership.class_registrations_languages');
select staging.load_table('membership', 'user_guardians', 'membership.user_guardians');
commit;
