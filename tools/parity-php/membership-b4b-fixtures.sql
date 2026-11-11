/*
 * The membership B4b fixtures for the PHP parity stack's MariaDB: the same rows as db/synthetic/membership-b4b-fixtures.sql (read that header for the legend). Loaded by
 * tools/membership-contract.sh after tools/parity-php/membership-fixtures.sql, before every run; resets every row it owns (by token, class id and explicit row id).
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile, city, state, country, zip, first_name)
SELECT v.token, CONCAT('b4b.', v.token, '@example.invalid'), 0, 'firebase', '2025-01-15 10:00:00', CONCAT('B4B Member ', v.token),
       CASE WHEN v.token IN (901145, 901165, 901171) THEN '2' WHEN v.token IN (901133, 901173) THEN 'Male' WHEN v.token = 901174 THEN '' ELSE '1' END,
       CONCAT('+91000011', RIGHT(v.token, 4)), CASE WHEN v.token = 901184 THEN NULL ELSE 'Pune' END, 'MH', 'India', '411001', CASE WHEN v.token = 901131 THEN 'Kid' END
FROM (SELECT 901101 AS token UNION ALL SELECT 901102 UNION ALL SELECT 901103 UNION ALL SELECT 901104 UNION ALL SELECT 901105 UNION ALL SELECT 901106 UNION ALL SELECT 901107 UNION ALL SELECT 901108
      UNION ALL SELECT 901109 UNION ALL SELECT 901110 UNION ALL SELECT 901111 UNION ALL SELECT 901112 UNION ALL SELECT 901113 UNION ALL SELECT 901114 UNION ALL SELECT 901115
      UNION ALL SELECT 901121 UNION ALL SELECT 901122 UNION ALL SELECT 901131 UNION ALL SELECT 901132 UNION ALL SELECT 901133 UNION ALL SELECT 901134
      UNION ALL SELECT 901141 UNION ALL SELECT 901142 UNION ALL SELECT 901143 UNION ALL SELECT 901144 UNION ALL SELECT 901145 UNION ALL SELECT 901146
      UNION ALL SELECT 901151 UNION ALL SELECT 901152 UNION ALL SELECT 901153 UNION ALL SELECT 901154 UNION ALL SELECT 901155
      UNION ALL SELECT 901161 UNION ALL SELECT 901162 UNION ALL SELECT 901163 UNION ALL SELECT 901164 UNION ALL SELECT 901165 UNION ALL SELECT 901166
      UNION ALL SELECT 901171 UNION ALL SELECT 901172 UNION ALL SELECT 901173 UNION ALL SELECT 901174 UNION ALL SELECT 901175 UNION ALL SELECT 901176
      UNION ALL SELECT 901181 UNION ALL SELECT 901182 UNION ALL SELECT 901183 UNION ALL SELECT 901184) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users SET email = CONCAT('b4b.', token, '@example.invalid'), name = CONCAT('B4B Member ', token), roleid = 0, createdon = '2025-01-15 10:00:00',
  gender = CASE WHEN token IN (901145, 901165, 901171) THEN '2' WHEN token IN (901133, 901173) THEN 'Male' WHEN token = 901174 THEN '' ELSE '1' END,
  mobile = CONCAT('+91000011', RIGHT(token, 4)), city = CASE WHEN token = 901184 THEN NULL ELSE 'Pune' END, state = 'MH', country = 'India', zip = '411001',
  first_name = CASE WHEN token = 901131 THEN 'Kid' END
WHERE token BETWEEN 901101 AND 901199 AND email NOT LIKE 'b4b.%.dup@example.invalid';
UPDATE users SET email = '901166@thestrongrope.com' WHERE token = 901166;
UPDATE users SET name = 'O&#039;Brien &amp; Donor', mobile = '' WHERE token = 901184;
UPDATE users SET roleid = 1 WHERE token BETWEEN 901101 AND 901108;
UPDATE users SET roleid = 3 WHERE token = 901109;

INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT 901153, 'b4b.901153.dup@example.invalid', 0, 'firebase', '2025-01-15 10:00:00', 'B4B Member 901153', '1', '+910000119532'
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.email = 'b4b.901153.dup@example.invalid');

DELETE FROM user_guardians WHERE child_token BETWEEN 901101 AND 901199 OR parent_token BETWEEN 901101 AND 901199;
DELETE FROM class_registrations WHERE token BETWEEN 901101 AND 901199;
DELETE FROM class_students WHERE class_id BETWEEN 9561 AND 9569 OR token_no BETWEEN 901101 AND 901199;
DELETE FROM class_schedules WHERE class_id BETWEEN 9561 AND 9569;
DELETE FROM classes WHERE id BETWEEN 9561 AND 9569;

INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by, completed_on, comments, deleted_at, deleted_by) VALUES
  (9561, 'B4B-G-61', 1, 'b4blnk9561', 'B4B Gents Class', 3, '2025-09-01', 901101, 1, 'Offline', 'Pune', 'India', 'B4B Hall', 'A', 901101, NULL, NULL, NULL, NULL),
  (9562, 'B4B-L-62', 1, 'b4blnk9562', 'B4B Ladies Class', 2, '2025-09-01', 901101, 2, 'Offline', 'Pune', 'India', 'B4B Hall', 'A', 901101, NULL, NULL, NULL, NULL),
  (9563, 'B4B-G-63', 1, 'b4blnk9563', 'B4B Closed Class', 3, '2025-09-01', 901101, 1, 'Offline', 'Pune', 'India', 'B4B Hall', 'I', 901101, NULL, NULL, NULL, NULL);

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (951401, 9561, 901131, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951402, 9563, 901131, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951403, 9561, 901164, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951404, 9561, 901172, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951405, 9563, 901175, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951406, 9561, 901176, '2025-09-02', 0, '2025-10-01 00:00:00', 'B4B left', 901101, 'I'),
  (951407, 9561, 901181, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951408, 9562, 901181, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951409, 9563, 901182, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951410, 9561, 901183, '2025-09-02', 0, '2025-10-01 00:00:00', 'B4B left', 901101, 'I'),
  (951411, 9561, 901184, '2025-09-02', 0, NULL, NULL, NULL, 'A');
UPDATE class_students SET created_at = CONCAT(joined_on, ' 08:00:00') WHERE class_id BETWEEN 9561 AND 9569;

INSERT INTO user_guardians (id, parent_token, child_token, relationship, status, source, code, expires_at, created_by, created_at, activated_at, revoked_by, revoked_at)
SELECT v.id, v.parent_token, v.child_token, v.relationship, v.status, v.source, v.code,
       CASE v.expiry WHEN 'live' THEN NOW() + INTERVAL 30 DAY WHEN 'past' THEN NOW() - INTERVAL 1 DAY END,
       (SELECT id FROM users WHERE token = v.created_by ORDER BY id LIMIT 1), '2026-01-10 09:00:00',
       CASE WHEN v.status IN ('active', 'revoked') THEN '2026-01-10 09:00:00' END,
       (SELECT id FROM users WHERE token = v.revoked_by ORDER BY id LIMIT 1), CASE WHEN v.status = 'revoked' THEN '2026-01-11 09:00:00' END
FROM (
  SELECT 951201 AS id, 901121 AS parent_token, 901131 AS child_token, 'father' AS relationship, 'active' AS status, 'token_entry' AS source, NULL AS code, NULL AS expiry, 901101 AS created_by, NULL AS revoked_by UNION ALL
  SELECT 951202, 901121, 901132, 'mother', 'active', 'token_entry', NULL, NULL, 901101, NULL UNION ALL
  SELECT 951203, 901121, 901133, 'guardian', 'active', 'token_entry', NULL, NULL, 901101, NULL UNION ALL
  SELECT 951204, 901121, 901134, 'father', 'revoked', 'token_entry', NULL, NULL, 901101, 901134 UNION ALL
  SELECT 951211, NULL, 901112, NULL, 'invited', 'link', 'b4bcap0000000000000000000000011', 'live', 901104, NULL UNION ALL
  SELECT 951212, NULL, 901112, NULL, 'invited', 'link', 'b4bcap0000000000000000000000012', 'live', 901104, NULL UNION ALL
  SELECT 951213, NULL, 901112, NULL, 'invited', 'link', 'b4bcap0000000000000000000000013', 'live', 901104, NULL UNION ALL
  SELECT 951214, NULL, 901112, NULL, 'invited', 'link', 'b4bcap0000000000000000000000014', 'live', 901104, NULL UNION ALL
  SELECT 951215, NULL, 901112, NULL, 'invited', 'link', 'b4bcap0000000000000000000000015', 'live', 901104, NULL UNION ALL
  SELECT 951221, NULL, 901113, NULL, 'invited', 'link', 'b4blist000000000000000000000021', 'live', 901101, NULL UNION ALL
  SELECT 951222, NULL, 901113, NULL, 'invited', 'link', 'b4blist000000000000000000000022', 'past', 901101, NULL UNION ALL
  SELECT 951223, NULL, 901113, NULL, 'invited', 'link', 'b4blist000000000000000000000023', 'live', 901104, NULL UNION ALL
  SELECT 951224, NULL, 901113, NULL, 'invited', 'link', 'b4blist000000000000000000000024', NULL, 901105, NULL UNION ALL
  SELECT 951231, NULL, 901115, NULL, 'invited', 'link', 'b4bcanc00000000000000000000031', 'live', 901104, NULL UNION ALL
  SELECT 951232, NULL, 901115, NULL, 'invited', 'link', 'b4bcanc00000000000000000000032', 'live', 901104, NULL UNION ALL
  SELECT 951233, NULL, 901115, NULL, 'invited', 'link', 'b4bcanc00000000000000000000033', 'past', 901104, NULL UNION ALL
  SELECT 951234, NULL, 901115, NULL, 'revoked', 'link', 'b4bcanc00000000000000000000034', 'live', 901104, 901104 UNION ALL
  SELECT 951235, NULL, 901115, NULL, 'invited', 'link', 'b4bcanc00000000000000000000035', 'live', 901104, NULL UNION ALL
  SELECT 951241, 901151, 901142, 'father', 'active', 'token_entry', NULL, NULL, 901103, NULL UNION ALL
  SELECT 951242, 901152, 901143, 'mother', 'revoked', 'token_entry', NULL, NULL, 901103, 901143) v;

INSERT INTO class_registrations (id, token, for_classid, preferred_location, status, status_reason, created_at) VALUES
  (951301, 901161, 9561, 'B4B first form', 'Pending', NULL, '2025-03-01 10:00:00'),
  (951302, 901161, NULL, 'B4B second form', 'Pending', NULL, '2025-03-02 10:00:00'),
  (951303, 901162, NULL, 'B4B validation', 'Pending', NULL, '2025-03-03 10:00:00'),
  (951304, 901163, NULL, 'B4B rejected', 'Rejected', 'B4B earlier', '2025-03-03 10:00:00'),
  (951305, 901164, NULL, 'B4B enrolled', 'Pending', NULL, '2025-03-03 10:00:00'),
  (951306, 901165, NULL, 'B4B ladies', 'Pending', NULL, '2025-03-03 10:00:00'),
  (951307, 901166, NULL, 'B4B placeholder', 'Pending', NULL, '2025-03-03 10:00:00'),
  (951311, 901171, 9562, 'B4B older', 'Pending', NULL, '2025-03-01 10:00:00'),
  (951312, 901171, 9561, 'B4B latest', 'Pending', NULL, '2025-03-04 10:00:00'),
  (951313, 901174, 99999999, 'B4B gone class', 'Pending', NULL, '2025-03-05 10:00:00');
