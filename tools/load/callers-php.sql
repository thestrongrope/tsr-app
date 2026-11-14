-- The callers of the PHP side of the load test, read from the parity stack's synthetic MariaDB (tsr_synth). SELECT only:
-- nothing is written and no role can be added here. The generated set has one super admin and two gender admins, so the
-- admin pools also take the contract fixtures' admins (tokens of 900000 and above, .invalid emails, a gender set, no
-- deletion request); the members are generated ones only. Same shape as tools/load/callers.sql prints.
select json_object(
  'search_word', 'fe',
  'article_slug', 'the-zorvath-timetable',
  'heavy', json_object('xlsx', '/reports/registrations/download?format=xlsx', 'pdf', '', 'mis', '/reports/tsr'),
  'callers', (
    select json_arrayagg(json_object('email', email, 'role', role, 'class_id', class_id))
    from (
      (select u.email, case u.roleid when 1 then 'super_admin' when 5 then 'coordinator' else 'gender_admin' end as role, null as class_id
       from users u
       where u.roleid in (1, 3, 4, 5) and u.token > 0 and (u.token < 900000 or u.roleid <> 5) and u.email like '%.invalid'
         and u.gender in ('1', '2') and not exists (select 1 from account_deletion_requests d where d.token = u.token))
      union all
      (select u.email, 'member', min(s.class_id)
       from class_students s
       join classes c on c.id = s.class_id and c.status = 'A'
       join users u on u.token = s.token_no
       where s.status = 'A' and s.removed_at is null and u.roleid = 0 and u.token between 1 and 899999 and u.email like '%.invalid'
         and not exists (select 1 from classes t where t.teacher = u.token)
         and exists (select 1 from class_sessions x where x.class_id = s.class_id and x.deleted_at is null)
       group by u.email, u.token
       order by u.token
       limit 300)
    ) caller));
