-- Run by tools/load/run.sh callers on a LANE's synthetic PostgreSQL (the script refuses a database that is not synthetic).
-- 1. The generated set has one super admin and one admin per gender; fifty users on one row would only measure that row's
--    lock (every request updates the caller's last sign-in). So 50 generated members who are in no class become super
--    admins (25 per gender) and 15 more per gender become that gender's admin. The choice depends only on ids, so a
--    second run changes nothing. Coordinators are not added: the 40 generated ones are used as they are.
-- 2. Prints one JSON document: the callers (email, role, one class id) and the fixed paths of the heavy routes.
--    Emails here are generated ones (.invalid). The file is written under build/ (git-ignored).
with candidate as (
  select u.id, p.gender, row_number() over (partition by p.gender order by u.id) as n
  from identity.users u
  join membership.member_profiles p on p.user_id = u.id
  where u.token between 1 and 899999 and u.email ilike '%.invalid' and p.gender in ('1', '2')
    and not exists (select 1 from classes.class_students s where s.token_no = u.token)
    and not exists (select 1 from classes.classes c where c.teacher = u.token)
    and not exists (select 1 from access.user_roles r where r.user_id = u.id and r.roleid not in (1, 3, 4))
)
insert into access.user_roles (user_id, roleid)
select id, case when n <= 25 then 1 when gender = '1' then 3 else 4 end
from candidate
where n <= 40
on conflict (user_id) do update set roleid = excluded.roleid;

with role_holder as (
  select u.email, u.token,
         case r.roleid when 1 then 'super_admin' when 3 then 'gender_admin' when 4 then 'gender_admin' else 'coordinator' end as role
  from access.user_roles r
  join identity.users u on u.id = r.user_id
  where r.roleid in (1, 3, 4, 5) and u.token between 1 and 899999 and u.email ilike '%.invalid'
),
teacher as (
  select u.email, u.token, min(c.id) as class_id
  from classes.classes c
  join identity.users u on u.token = c.teacher
  where c.status = 'A' and u.token between 1 and 899999 and u.email ilike '%.invalid'
    and not exists (select 1 from access.user_roles r where r.user_id = u.id)
  group by u.email, u.token
  order by u.token
  limit 100
),
member as (
  select u.email, u.token, min(s.class_id) as class_id,
         exists (select 1 from notifications.user_notifications n where n.user_token = u.token) as notified
  from classes.class_students s
  join classes.classes c on c.id = s.class_id and c.status = 'A'
  join identity.users u on u.token = s.token_no
  where s.status = 'A' and s.removed_at is null and u.token between 1 and 899999 and u.email ilike '%.invalid'
    and not exists (select 1 from access.user_roles r where r.user_id = u.id)
    and not exists (select 1 from classes.classes t where t.teacher = u.token)
    and exists (select 1 from classes.class_sessions x where x.class_id = s.class_id and x.deleted_at is null)
  group by u.email, u.token
  order by notified desc, u.token
  limit 300
),
caller as (
  select email, role, null::integer as class_id from role_holder
  union all select email, 'teacher', class_id from teacher
  union all select email, 'member', class_id from member
)
select json_build_object(
  'search_word', 'fe',
  'article_slug', 'the-zorvath-timetable',
  'heavy', json_build_object(
    'xlsx', '/reports/registrations/download?format=xlsx',
    'pdf', '/reports/registrations/download?format=pdf',
    'mis', '/reports/tsr'),
  'callers', (select json_agg(json_build_object('email', email, 'role', role, 'class_id', class_id)) from caller));
