/*
 * The membership B5B fixtures for the PHP parity stack's MariaDB: the same members, registrations and enrolments as db/synthetic/membership-b5b-fixtures.sql (read that header). Loaded by
 * tools/membership-contract.sh after the B4b fixtures; resets every row it owns by token and explicit id.
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, CONCAT('b5b.', v.token, '@example.invalid'), 0, 'firebase', '2025-01-15 10:00:00', CONCAT('B5B Member ', v.token), '1', CONCAT('+91000018', RIGHT(v.token, 4)) FROM (
  SELECT 901801 AS token UNION ALL SELECT 901802 UNION ALL SELECT 901803 UNION ALL SELECT 901804 UNION ALL SELECT 901811 UNION ALL SELECT 901812 UNION ALL SELECT 901813 UNION ALL SELECT 901814
  UNION ALL SELECT 901815 UNION ALL SELECT 901816 UNION ALL SELECT 901817 UNION ALL SELECT 901818 UNION ALL SELECT 901819) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users SET email = CONCAT('b5b.', token, '@example.invalid'), name = CONCAT('B5B Member ', token),
  gender = CASE WHEN token IN (901803, 901814) THEN '2' WHEN token = 901818 THEN 'Male' ELSE '1' END,
  mobile = CONCAT('+91000018', RIGHT(token, 4)), city = 'Pune', state = 'MH', country = 'India', zip = '411001',
  roleid = CASE token WHEN 901801 THEN 1 WHEN 901802 THEN 3 WHEN 901803 THEN 4 ELSE 0 END
WHERE token BETWEEN 901801 AND 901899;
UPDATE users SET email = '901815@thestrongrope.com' WHERE token = 901815;
UPDATE users SET mobile = '' WHERE token = 901819;

DELETE FROM class_registrations WHERE token BETWEEN 901801 AND 901899;
DELETE FROM class_students WHERE token_no BETWEEN 901801 AND 901899;

INSERT INTO class_registrations (id, token, for_classid, preferred_location, residence_location, birth_year, profession, islamic_study_years, class_level, status, created_at) VALUES
  (951501, 901811, 9561, 'B5B Pune &amp; Co', 'B5B Home', 1990, 'Engineer', 5, 'Primary', 'Pending', '2025-04-01 10:00:00'),
  (951502, 901811, NULL, NULL, NULL, 1991, NULL, NULL, NULL, 'Accepted', '2025-04-03 10:00:00'),
  (951503, 901812, NULL, 'B5B rejected', NULL, NULL, NULL, NULL, NULL, 'Rejected', '2025-04-02 10:00:00'),
  (951504, 901812, NULL, 'B5B pending', NULL, NULL, NULL, NULL, NULL, 'Pending', '2025-04-04 10:00:00'),
  (951505, 901813, NULL, 'B5B enrolled', NULL, NULL, NULL, NULL, NULL, 'Pending', '2025-04-05 10:00:00'),
  (951506, 901814, 9562, 'B5B ladies', NULL, 1985, NULL, 2, NULL, 'Pending', '2025-04-06 10:00:00'),
  (951507, 901815, NULL, 'B5B placeholder', NULL, NULL, NULL, NULL, NULL, 'Pending', '2025-04-07 10:00:00'),
  (951508, 901816, 9563, 'B5B closed class', NULL, NULL, NULL, NULL, NULL, 'Pending', '2025-05-01 10:00:00'),
  (951509, 901817, NULL, 'B5B left', NULL, NULL, NULL, NULL, NULL, 'Pending', '2025-04-02 12:00:00'),
  (951510, 901818, NULL, 'B5B male', NULL, NULL, NULL, NULL, NULL, 'Pending', '2025-04-08 10:00:00'),
  (951511, 901819, 99999999, 'B5B gone class', NULL, NULL, 'Tom &amp; Jerry', NULL, NULL, 'Pending', '2025-04-09 10:00:00');

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (951521, 9561, 901813, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951522, 9561, 901817, '2025-09-02', 0, '2025-10-01 00:00:00', 'B5B left', 901101, 'I');
UPDATE class_students SET created_at = CONCAT(joined_on, ' 08:00:00') WHERE id IN (951521, 951522);
