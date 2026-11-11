/*
 * The membership B5D fixtures for the PHP parity stack's MariaDB: the same members, registrations and enrolments as db/synthetic/membership-b5d-fixtures.sql (read that header). Loaded by
 * tools/membership-contract.sh after the B5B fixtures; resets every row it owns by token and explicit id. The coordinator's reach is a class_access row.
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, CONCAT('b5d.', v.token, '@example.invalid'), 0, 'firebase', '2025-02-10 09:30:00', CONCAT('B5D Member ', v.token), '1', CONCAT('+91000021', RIGHT(v.token, 4)) FROM (
  SELECT 902101 AS token UNION ALL SELECT 902111 UNION ALL SELECT 902112 UNION ALL SELECT 902113 UNION ALL SELECT 902114 UNION ALL SELECT 902115 UNION ALL SELECT 902116 UNION ALL SELECT 902117
  UNION ALL SELECT 902118) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users SET email = CONCAT('b5d.', token, '@example.invalid'), name = CONCAT('B5D Member ', token),
  gender = CASE WHEN token = 902113 THEN '2' WHEN token = 902116 THEN 'Male' WHEN token = 902118 THEN NULL ELSE '1' END,
  age_range = CASE WHEN token = 902113 THEN '2' ELSE '3' END,
  mobile = CONCAT('+91000021', RIGHT(token, 4)), city = 'Pune', state = 'MH', country = 'India', zip = '411001', createdon = '2025-02-10 09:30:00',
  roleid = CASE token WHEN 902101 THEN 5 ELSE 0 END
WHERE token BETWEEN 902101 AND 902199;
UPDATE users SET email = '902117@thestrongrope.com' WHERE token = 902117;

DELETE FROM class_access WHERE token = 902101;
INSERT INTO class_access (class_id, token) VALUES (9561, 902101);

DELETE FROM class_registrations WHERE token BETWEEN 902101 AND 902199;
DELETE FROM class_students WHERE token_no BETWEEN 902101 AND 902199;
UPDATE classes SET extra_students = 'Ali Extra\nBob Extra' WHERE id = 9561;

INSERT INTO class_registrations (id, token, for_classid, preferred_location, residence_location, work_location, birth_year, profession, islamic_study_years, class_level, class_number, interests, other_interests, status, created_at, modified_at) VALUES
  (952101, 902111, 9561, 'B5D Pune', 'B5D Home', 'B5D Office', 1990, 'R &amp; D', 5, 'Primary', 'C1', 'Teaching,Research', 'Tafsir ,Seerah', 'Accepted', '2025-03-01 10:00:00', '2025-03-02 11:15:00'),
  (952102, 902111, NULL, NULL, NULL, NULL, 1991, NULL, NULL, NULL, NULL, NULL, NULL, 'Accepted', '2025-03-03 10:00:00', NULL),
  (952103, 902112, NULL, 'B5D open', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Debates', NULL, 'Accepted', '2025-03-04 10:00:00', NULL),
  (952104, 902113, 9562, 'B5D ladies', NULL, NULL, 1985, NULL, 2, NULL, NULL, NULL, '0', 'Accepted', '2025-03-05 10:00:00', NULL),
  (952105, 902114, 9563, 'B5D closed', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Accepted', '2025-03-06 10:00:00', NULL),
  (952106, 902115, NULL, 'B5D left', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Accepted', '2025-03-07 10:00:00', NULL),
  (952107, 902116, NULL, 'B5D male', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Accepted', '2025-03-08 10:00:00', NULL),
  (952108, 902117, 9561, 'B5D placeholder', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Accepted', '2025-03-09 10:00:00', NULL),
  (952109, 902118, 9561, 'B5D no gender', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Accepted', '2025-03-10 10:00:00', NULL);

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (952121, 9561, 902111, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (952122, 9561, 902112, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (952123, 9562, 902113, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (952124, 9563, 902114, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (952125, 9561, 902115, '2025-09-02', 0, '2025-10-01 00:00:00', 'B5D left', 901101, 'I'),
  (952126, 9561, 902116, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (952127, 9561, 902117, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (952128, 9561, 902118, '2025-09-02', 0, NULL, NULL, NULL, 'A');
UPDATE class_students SET created_at = CONCAT(joined_on, ' 08:00:00') WHERE id BETWEEN 952121 AND 952128;
