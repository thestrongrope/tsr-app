/*
 * The membership B4b fixtures for the new API's database: what the contract files of the staff parent links, GET /me/children, reject, donors and the subscriber card read and change.
 * tools/parity-php/membership-b4b-fixtures.sql holds the same rows for the PHP parity stack. Loaded by tools/membership-contract.sh after db/synthetic/membership-fixtures.sql, before every run;
 * resets every row it owns (by token, class id and explicit row id), including what a run created. Synthetic only: tokens 901101 to 901199, emails b4b.<token>@example.invalid, classes 9561 to 9563,
 * guardian rows 951201 and up, registrations 951301 and up, enrolments 951401 and up. A token that no file changes can be shared by files; a changed one belongs to ONE file.
 *
 *   STAFF   901101 admin (invite create, list)  901102 admin (candidate, 3 counted lookups a run)  901103 admin (add direct)  901104 admin (cancel, the invites' creator)  901105 admin (cancel as manager)
 *           901106 admin (donors)  901107 admin (subscriber card)  901108 admin (reject)  901109 gents admin, role 3 (reject refused, add direct by gender, candidate by gender)  901110 plain member
 *   INVITES 901111 child (create; none seeded)  901112 child with 5 live invites (the cap)  901113 child (list: 951221 live by 901101, 951222 expired, 951223 live by 901104, 951224 no expiry by 901105)
 *           901114 student creating for themselves  901115 child (cancel: 951231 to 951236)
 *   CHILDREN parent 901121 with 901131 (classes 9561 live, 9563 closed), 901132 (no class), 901133 (gender Male), 901134 (revoked link)  parent 901122 with none
 *   DIRECT  children 901141 (add), 901142 (parent 901151 linked already), 901143 (parent 901152 was removed by the child), 901144 (validation, candidate), 901145 ladies, 901146 gents (added by role 3)
 *           parents 901151, 901152, 901153 (token held by two members), 901154, 901155
 *   REJECT  901161 waiting (two rows)  901162 waiting (validation only)  901163 already rejected  901164 in class 9561  901165 ladies waiting  901166 email is the bulk-add placeholder form <token>@thestrongrope.com, the one non-.invalid address the synthetic guard accepts
 *   CARDS   901171 ladies, registered for 9561 (latest of two)  901172 in 9561  901173 gender Male, no registration  901174 no gender, registration for a class that is gone  901175 only a closed class  901176 enrolment removed
 *   DONORS  901181 in 9561 and 9562  901182 only closed 9563  901183 removed  901184 entity name, no city
 */
INSERT INTO identity.users (token, email)
SELECT v.token, 'b4b.' || v.token || '@example.invalid' FROM generate_series(901101, 901199) AS v (token)
WHERE v.token IN (
  901101, 901102, 901103, 901104, 901105, 901106, 901107, 901108, 901109, 901110, 901111, 901112, 901113, 901114, 901115,
  901121, 901122, 901131, 901132, 901133, 901134, 901141, 901142, 901143, 901144, 901145, 901146, 901151, 901152, 901153, 901154, 901155,
  901161, 901162, 901163, 901164, 901165, 901166, 901171, 901172, 901173, 901174, 901175, 901176, 901181, 901182, 901183, 901184)
  AND NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);
UPDATE identity.users SET email = 'b4b.' || token || '@example.invalid' WHERE token BETWEEN 901101 AND 901199 AND email NOT LIKE 'b4b.%.dup@example.invalid' AND email <> 'b4b.' || token || '@example.invalid';
UPDATE identity.users SET email = '901166@thestrongrope.com' WHERE token = 901166;
UPDATE identity.users SET createdon = TIMESTAMPTZ '2025-01-15 10:00:00+00' WHERE token BETWEEN 901101 AND 901199;
INSERT INTO identity.users (token, email)
SELECT 901153, 'b4b.901153.dup@example.invalid' WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.email = 'b4b.901153.dup@example.invalid');

INSERT INTO membership.member_profiles (user_id, name, gender, mobile, city, state, country, zip, first_name)
SELECT u.id, 'B4B Member ' || u.token,
       CASE WHEN u.token IN (901145, 901165, 901171) THEN '2' WHEN u.token IN (901133, 901173) THEN 'Male' WHEN u.token = 901174 THEN '' ELSE '1' END,
       '+91000011' || right(u.token::text, 4),
       CASE WHEN u.token = 901184 THEN NULL ELSE 'Pune' END, 'MH', 'India', '411001',
       CASE WHEN u.token = 901131 THEN 'Kid' END
FROM identity.users u WHERE u.token BETWEEN 901101 AND 901199
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile, city = excluded.city, state = excluded.state, country = excluded.country,
  zip = excluded.zip, first_name = excluded.first_name;
UPDATE membership.member_profiles SET name = 'O&#039;Brien &amp; Donor', mobile = '' WHERE user_id IN (SELECT id FROM identity.users WHERE token = 901184);

DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 901101 AND 901199);
INSERT INTO access.user_roles (user_id, roleid) SELECT u.id, CASE WHEN u.token = 901109 THEN 3 ELSE 1 END FROM identity.users u WHERE u.token BETWEEN 901101 AND 901108 OR u.token = 901109;

DELETE FROM membership.user_guardians WHERE child_token BETWEEN 901101 AND 901199 OR parent_token BETWEEN 901101 AND 901199;
DELETE FROM membership.class_registrations WHERE token BETWEEN 901101 AND 901199;
DELETE FROM classes.class_students WHERE class_id BETWEEN 9561 AND 9569 OR token_no BETWEEN 901101 AND 901199;
DELETE FROM classes.class_schedules WHERE class_id BETWEEN 9561 AND 9569;
DELETE FROM classes.classes WHERE id BETWEEN 9561 AND 9569;

INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by, completed_on, comments, deleted_at, deleted_by) VALUES
  (9561, 'B4B-G-61', 1, 'b4blnk9561', 'B4B Gents Class', 3, DATE '2025-09-01', 901101, 1, 'Offline', 'Pune', 'India', 'B4B Hall', 'A', 901101, NULL, NULL, NULL, NULL),
  (9562, 'B4B-L-62', 1, 'b4blnk9562', 'B4B Ladies Class', 2, DATE '2025-09-01', 901101, 2, 'Offline', 'Pune', 'India', 'B4B Hall', 'A', 901101, NULL, NULL, NULL, NULL),
  (9563, 'B4B-G-63', 1, 'b4blnk9563', 'B4B Closed Class', 3, DATE '2025-09-01', 901101, 1, 'Offline', 'Pune', 'India', 'B4B Hall', 'I', 901101, NULL, NULL, NULL, NULL);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (951401, 9561, 901131, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951402, 9563, 901131, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951403, 9561, 901164, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951404, 9561, 901172, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951405, 9563, 901175, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951406, 9561, 901176, DATE '2025-09-02', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'B4B left', 901101, 'I'),
  (951407, 9561, 901181, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951408, 9562, 901181, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951409, 9563, 901182, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951410, 9561, 901183, DATE '2025-09-02', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'B4B left', 901101, 'I'),
  (951411, 9561, 901184, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A');
UPDATE classes.class_students SET created_at = joined_on + TIME '08:00' AT TIME ZONE 'UTC' WHERE class_id BETWEEN 9561 AND 9569;

INSERT INTO membership.user_guardians (id, parent_token, child_token, relationship, status, source, code, expires_at, created_by, created_at, activated_at, revoked_by, revoked_at)
SELECT v.id, v.parent_token, v.child_token, v.relationship, v.status, v.source, v.code,
       CASE v.expiry WHEN 'live' THEN now() + interval '30 days' WHEN 'past' THEN now() - interval '1 day' END,
       (SELECT id FROM identity.users WHERE token = v.created_by ORDER BY id LIMIT 1), TIMESTAMPTZ '2026-01-10 09:00:00+00',
       CASE WHEN v.status = 'active' OR v.status = 'revoked' THEN TIMESTAMPTZ '2026-01-10 09:00:00+00' END,
       (SELECT id FROM identity.users WHERE token = v.revoked_by ORDER BY id LIMIT 1), CASE WHEN v.status = 'revoked' THEN TIMESTAMPTZ '2026-01-11 09:00:00+00' END
FROM (VALUES
  (951201, 901121, 901131, 'father', 'active', 'token_entry', NULL, NULL, 901101, NULL),
  (951202, 901121, 901132, 'mother', 'active', 'token_entry', NULL, NULL, 901101, NULL),
  (951203, 901121, 901133, 'guardian', 'active', 'token_entry', NULL, NULL, 901101, NULL),
  (951204, 901121, 901134, 'father', 'revoked', 'token_entry', NULL, NULL, 901101, 901134),
  (951211, NULL, 901112, NULL, 'invited', 'link', 'b4bcap0000000000000000000000011', 'live', 901104, NULL),
  (951212, NULL, 901112, NULL, 'invited', 'link', 'b4bcap0000000000000000000000012', 'live', 901104, NULL),
  (951213, NULL, 901112, NULL, 'invited', 'link', 'b4bcap0000000000000000000000013', 'live', 901104, NULL),
  (951214, NULL, 901112, NULL, 'invited', 'link', 'b4bcap0000000000000000000000014', 'live', 901104, NULL),
  (951215, NULL, 901112, NULL, 'invited', 'link', 'b4bcap0000000000000000000000015', 'live', 901104, NULL),
  (951221, NULL, 901113, NULL, 'invited', 'link', 'b4blist000000000000000000000021', 'live', 901101, NULL),
  (951222, NULL, 901113, NULL, 'invited', 'link', 'b4blist000000000000000000000022', 'past', 901101, NULL),
  (951223, NULL, 901113, NULL, 'invited', 'link', 'b4blist000000000000000000000023', 'live', 901104, NULL),
  (951224, NULL, 901113, NULL, 'invited', 'link', 'b4blist000000000000000000000024', NULL, 901105, NULL),
  (951231, NULL, 901115, NULL, 'invited', 'link', 'b4bcanc00000000000000000000031', 'live', 901104, NULL),
  (951232, NULL, 901115, NULL, 'invited', 'link', 'b4bcanc00000000000000000000032', 'live', 901104, NULL),
  (951233, NULL, 901115, NULL, 'invited', 'link', 'b4bcanc00000000000000000000033', 'past', 901104, NULL),
  (951234, NULL, 901115, NULL, 'revoked', 'link', 'b4bcanc00000000000000000000034', 'live', 901104, 901104),
  (951235, NULL, 901115, NULL, 'invited', 'link', 'b4bcanc00000000000000000000035', 'live', 901104, NULL),
  (951241, 901151, 901142, 'father', 'active', 'token_entry', NULL, NULL, 901103, NULL),
  (951242, 901152, 901143, 'mother', 'revoked', 'token_entry', NULL, NULL, 901103, 901143)
) AS v (id, parent_token, child_token, relationship, status, source, code, expiry, created_by, revoked_by);

INSERT INTO membership.class_registrations (id, token, for_classid, preferred_location, status, status_reason, created_at) VALUES
  (951301, 901161, 9561, 'B4B first form', 'Pending', NULL, TIMESTAMPTZ '2025-03-01 10:00:00+00'),
  (951302, 901161, NULL, 'B4B second form', 'Pending', NULL, TIMESTAMPTZ '2025-03-02 10:00:00+00'),
  (951303, 901162, NULL, 'B4B validation', 'Pending', NULL, TIMESTAMPTZ '2025-03-03 10:00:00+00'),
  (951304, 901163, NULL, 'B4B rejected', 'Rejected', 'B4B earlier', TIMESTAMPTZ '2025-03-03 10:00:00+00'),
  (951305, 901164, NULL, 'B4B enrolled', 'Pending', NULL, TIMESTAMPTZ '2025-03-03 10:00:00+00'),
  (951306, 901165, NULL, 'B4B ladies', 'Pending', NULL, TIMESTAMPTZ '2025-03-03 10:00:00+00'),
  (951307, 901166, NULL, 'B4B placeholder', 'Pending', NULL, TIMESTAMPTZ '2025-03-03 10:00:00+00'),
  (951311, 901171, 9562, 'B4B older', 'Pending', NULL, TIMESTAMPTZ '2025-03-01 10:00:00+00'),
  (951312, 901171, 9561, 'B4B latest', 'Pending', NULL, TIMESTAMPTZ '2025-03-04 10:00:00+00'),
  (951313, 901174, 9599, 'B4B gone class', 'Pending', NULL, TIMESTAMPTZ '2025-03-05 10:00:00+00');
