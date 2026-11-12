/*
 * The grants lane fixtures (the ten /admin/permissions and /admin/class-access routes) for the new API's database. tools/parity-php/grants-fixtures.sql holds the same rows
 * for the PHP parity stack's MariaDB. Loaded by tools/contract-grants.sh before every run; resets every row it owns. Synthetic only: tokens 925000 to 925999
 * (emails gr.<token>@example.invalid), classes 98500 to 98599, every other id 9750000 to 9759999. Rows a run CREATES (grants, rules, conditions) get sequence ids and are
 * deleted here by the fixture tokens.
 *
 * Operators: 925001 super admin (role 1) 925002 super admin for the self-grant case 925003 gents admin (role 3) 925004 ladies admin (role 4) 925005 second gents admin
 *   925006 class admin (role 5) 925007 finance (role 7) 925008 plain member 925009 teacher role (6) 925010 holder of only a named grant (standard-mcqs:update:all)
 *   925011 super admin who revokes in the revoke files 925012 super admin for the effect files
 * Permission subjects: 925021 grant file 925022 revoke file (grants 9750011 live, 9750012 revoked, 9750013 live) 925023 effect file 925024 reasons file
 *   925031 to 925034 search names (a % in 925031, an _ in 925032) 925060 to 925084 twenty-five "Gsrch Many nn" members
 * Class access subjects (gents unless said): 925041 grant file 925042 revoke file (rules 9750021 and 9750022, a revoked 9750024) 925043 ladies 925044 no gender 925045 gents admin (peer)
 *   925046 super admin (peer) 925047 teacher role (6) 925048 guards file 925049 versions file 925050 read-only (rules 9750031 gents, 9750032 ladies, 9750033 either gender, 9750034 revoked)
 *   925051 revoke refusals (rules 9750041 ladies on a gents member, 9750042 either gender) 925052 revoke by a gents admin of a ladies member's rule (ladies member, rule 9750043)
 * Classes (language 7, gents unless said): 98501 A GRville Grland level 2 tag gr-tag-a 98502 A GRville Grland level 3 tag gr-tag-a 98503 A GRother Grland level 2 98504 CLOSED GRville level 2
 *   98505 ladies A GRville level 2 tag gr-tag-b 98506 ladies A GRlady Grland level 4
 */
INSERT INTO identity.users (token, email)
SELECT v.token, 'gr.' || v.token || '@example.invalid' FROM (
  SELECT t AS token FROM generate_series(925001, 925012) t UNION ALL SELECT t FROM generate_series(925021, 925024) t UNION ALL SELECT t FROM generate_series(925031, 925034) t
  UNION ALL SELECT t FROM generate_series(925041, 925052) t UNION ALL SELECT t FROM generate_series(925060, 925084) t) v
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);
UPDATE identity.users SET email = 'gr.' || token || '@example.invalid' WHERE token BETWEEN 925000 AND 925999 AND email <> 'gr.' || token || '@example.invalid';

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id,
  CASE u.token WHEN 925031 THEN 'Gsrch Percent 50% Off' WHEN 925032 THEN 'Gsrch Under_Score' WHEN 925033 THEN 'Gsrch Plain' WHEN 925034 THEN 'Gsrch NoPercent 50 Off'
    ELSE CASE WHEN u.token BETWEEN 925060 AND 925084 THEN 'Gsrch Many ' || lpad((u.token - 925059)::text, 2, '0') ELSE 'Gr Member ' || u.token END END,
  CASE WHEN u.token IN (925004, 925043, 925052) THEN '2' WHEN u.token = 925044 THEN NULL ELSE '1' END,
  '+9100092' || right(u.token::text, 4)
FROM identity.users u WHERE u.token BETWEEN 925000 AND 925999
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

DELETE FROM access.class_access_rule_conditions WHERE rule_id IN (SELECT id FROM access.class_access_rules WHERE token BETWEEN 925000 AND 925999);
DELETE FROM access.class_access_rules WHERE token BETWEEN 925000 AND 925999;
DELETE FROM access.user_permissions WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 925000 AND 925999);
DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 925000 AND 925999);
INSERT INTO access.user_roles (user_id, roleid)
SELECT u.id, CASE u.token WHEN 925001 THEN 1 WHEN 925002 THEN 1 WHEN 925011 THEN 1 WHEN 925012 THEN 1 WHEN 925046 THEN 1 WHEN 925003 THEN 3 WHEN 925005 THEN 3 WHEN 925045 THEN 3 WHEN 925004 THEN 4
  WHEN 925006 THEN 5 WHEN 925042 THEN 5 WHEN 925050 THEN 5 WHEN 925051 THEN 5 WHEN 925052 THEN 5 WHEN 925007 THEN 7 WHEN 925009 THEN 6 WHEN 925047 THEN 6 END
FROM identity.users u WHERE u.token IN (925001, 925002, 925011, 925012, 925046, 925003, 925005, 925045, 925004, 925006, 925042, 925050, 925051, 925052, 925007, 925009, 925047);

INSERT INTO access.user_permissions (id, user_id, permission, granted_by, reason, revoked_at, revoked_by, revoke_reason)
SELECT 9750001, u.id, 'standard-mcqs:update:all', s.id, 'Gr fixture grant', NULL::timestamptz, NULL::int, NULL::text FROM identity.users u, identity.users s WHERE u.token = 925010 AND s.token = 925001
UNION ALL SELECT 9750011, u.id, 'api-docs:read:all', s.id, 'Gr live grant', NULL, NULL, NULL FROM identity.users u, identity.users s WHERE u.token = 925022 AND s.token = 925001
UNION ALL SELECT 9750012, u.id, 'summary-report:read:all', s.id, 'Gr revoked grant', TIMESTAMPTZ '2026-01-01 00:00:00+00', s.id, 'Gr fixture revoke' FROM identity.users u, identity.users s WHERE u.token = 925022 AND s.token = 925001
UNION ALL SELECT 9750013, u.id, 'standard-mcqs:update:all', s.id, 'Gr second live grant', NULL, NULL, NULL FROM identity.users u, identity.users s WHERE u.token = 925022 AND s.token = 925001;

DELETE FROM classes.class_tags WHERE class_id BETWEEN 98500 AND 98599;
DELETE FROM classes.classes WHERE id BETWEEN 98500 AND 98599;
DELETE FROM classes.tags WHERE id BETWEEN 9750001 AND 9759999;
INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (98501, 'GR-G-501', 7, 'grlnk98501', 'Gr Class One', 2, DATE '2025-01-06', 925001, 1, 'Offline', 'GRville', 'Grland', 'Gr Hall', 'A', 925001),
  (98502, 'GR-G-502', 7, 'grlnk98502', 'Gr Class Two', 3, DATE '2025-01-06', 925001, 1, 'Offline', 'GRville', 'Grland', 'Gr Hall', 'A', 925001),
  (98503, 'GR-G-503', 7, 'grlnk98503', 'Gr Class Three', 2, DATE '2025-01-06', 925001, 1, 'Offline', 'GRother', 'Grland', 'Gr Hall', 'A', 925001),
  (98504, 'GR-G-504', 7, 'grlnk98504', 'Gr Class Closed', 2, DATE '2025-01-06', 925001, 1, 'Offline', 'GRville', 'Grland', 'Gr Hall', 'I', 925001),
  (98505, 'GR-L-505', 7, 'grlnk98505', 'Gr Ladies One', 2, DATE '2025-01-06', 925001, 2, 'Offline', 'GRville', 'Grland', 'Gr Hall', 'A', 925001),
  (98506, 'GR-L-506', 7, 'grlnk98506', 'Gr Ladies Two', 4, DATE '2025-01-06', 925001, 2, 'Offline', 'GRlady', 'Grland', 'Gr Hall', 'A', 925001);
INSERT INTO classes.tags (id, name) VALUES (9750001, 'gr-tag-a'), (9750002, 'gr-tag-b');
INSERT INTO classes.class_tags (class_id, tag_id, created_by) VALUES (98501, 9750001, 925001), (98502, 9750001, 925001), (98505, 9750002, 925001);

INSERT INTO access.class_access_rules (id, token, gender, note, created_at, granted_by, reason, revoked_at, revoked_by, revoke_reason) VALUES
  (9750021, 925042, 1, 'Gents, GRville', now(), (SELECT id FROM identity.users WHERE token = 925001), 'Gr fixture', NULL, NULL, NULL),
  (9750022, 925042, 1, 'Gents, level 2, Grland', now(), (SELECT id FROM identity.users WHERE token = 925001), 'Gr fixture', NULL, NULL, NULL),
  (9750024, 925042, 1, 'Gents, GRother', now(), (SELECT id FROM identity.users WHERE token = 925001), 'Gr fixture', now(), (SELECT id FROM identity.users WHERE token = 925001), 'Gr fixture revoke'),
  (9750031, 925050, 1, 'Gents, GRville', now(), (SELECT id FROM identity.users WHERE token = 925001), 'Gr fixture', NULL, NULL, NULL),
  (9750032, 925050, 2, 'Ladies, GRville', now(), (SELECT id FROM identity.users WHERE token = 925001), 'Gr fixture', NULL, NULL, NULL),
  (9750033, 925050, NULL, 'Any gender, GRville', now(), (SELECT id FROM identity.users WHERE token = 925001), 'Gr fixture', NULL, NULL, NULL),
  (9750034, 925050, 1, 'Gents, GRother', now(), (SELECT id FROM identity.users WHERE token = 925001), 'Gr fixture', now(), (SELECT id FROM identity.users WHERE token = 925001), 'Gr fixture revoke'),
  (9750041, 925051, 2, 'Ladies, GRville', now(), (SELECT id FROM identity.users WHERE token = 925001), 'Gr fixture', NULL, NULL, NULL),
  (9750042, 925051, NULL, 'Any gender, GRville', now(), (SELECT id FROM identity.users WHERE token = 925001), 'Gr fixture', NULL, NULL, NULL),
  (9750043, 925052, 2, 'Ladies, GRville', now(), (SELECT id FROM identity.users WHERE token = 925001), 'Gr fixture', NULL, NULL, NULL);
INSERT INTO access.class_access_rule_conditions (rule_id, field, negate, value, level_id) VALUES
  (9750021, 'city', false, 'GRville', NULL), (9750022, 'level', false, NULL, 2), (9750022, 'country', false, 'Grland', NULL), (9750024, 'city', false, 'GRother', NULL),
  (9750031, 'city', false, 'GRville', NULL), (9750032, 'city', false, 'GRville', NULL), (9750033, 'city', false, 'GRville', NULL), (9750034, 'city', false, 'GRother', NULL),
  (9750041, 'city', false, 'GRville', NULL), (9750042, 'city', false, 'GRville', NULL), (9750043, 'city', false, 'GRville', NULL);
