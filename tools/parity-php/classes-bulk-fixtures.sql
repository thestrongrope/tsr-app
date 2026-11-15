/*
 * The classes bulk-add fixtures for the PHP parity stack's MariaDB: the same rows as db/synthetic/classes-bulk-fixtures.sql (read that header, it also says how the members a run created are deleted first).
 * Loaded by tools/classes-contract.sh after the other classes fixtures, before every run.
 */

INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, CONCAT('bk.', v.token, '@example.invalid'), v.roleid, 'firebase', NOW(), v.name, v.gender, v.mobile FROM (
  SELECT 900701 AS token, 3 AS roleid, 'Bulk Admin A' AS name, '1' AS gender, '+910000070701' AS mobile UNION ALL
  SELECT 900702, 3, 'Bulk Admin B', '1', '+910000070702' UNION ALL
  SELECT 900703, 3, 'Bulk Admin C', '1', '+910000070703' UNION ALL
  SELECT 900704, 3, 'Bulk Admin D', '1', '+910000070704' UNION ALL
  SELECT 900705, 4, 'Bulk Admin E', '2', '+910000070705' UNION ALL
  SELECT 900706, 3, 'Bulk Admin F', '1', '+910000070706' UNION ALL
  SELECT 900711, 0, 'Bulk Teacher Gents', '1', '+910000070711' UNION ALL
  SELECT 900712, 0, 'Bulk Teacher Ladies', '2', '+910000070712' UNION ALL
  SELECT 900721, 0, 'Bulk Existing', '1', '+910000070721' UNION ALL
  SELECT 900722, 0, 'Gents Freeman', '1', '+910000070722' UNION ALL
  SELECT 900723, 0, 'Ladies Freewoman', '2', '+910000070723' UNION ALL
  SELECT 900724, 0, 'Nogender Person', NULL, '+910000070724' UNION ALL
  SELECT 900725, 0, 'Short Number', '1', '9007250' UNION ALL
  SELECT 900726, 0, 'Format Member', '1', '+91 00000-70726') v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users u JOIN (
  SELECT 900701 AS token, 3 AS roleid, 'Bulk Admin A' AS name, '1' AS gender, '+910000070701' AS mobile UNION ALL
  SELECT 900702, 3, 'Bulk Admin B', '1', '+910000070702' UNION ALL
  SELECT 900703, 3, 'Bulk Admin C', '1', '+910000070703' UNION ALL
  SELECT 900704, 3, 'Bulk Admin D', '1', '+910000070704' UNION ALL
  SELECT 900705, 4, 'Bulk Admin E', '2', '+910000070705' UNION ALL
  SELECT 900706, 3, 'Bulk Admin F', '1', '+910000070706' UNION ALL
  SELECT 900711, 0, 'Bulk Teacher Gents', '1', '+910000070711' UNION ALL
  SELECT 900712, 0, 'Bulk Teacher Ladies', '2', '+910000070712' UNION ALL
  SELECT 900721, 0, 'Bulk Existing', '1', '+910000070721' UNION ALL
  SELECT 900722, 0, 'Gents Freeman', '1', '+910000070722' UNION ALL
  SELECT 900723, 0, 'Ladies Freewoman', '2', '+910000070723' UNION ALL
  SELECT 900724, 0, 'Nogender Person', NULL, '+910000070724' UNION ALL
  SELECT 900725, 0, 'Short Number', '1', '9007250' UNION ALL
  SELECT 900726, 0, 'Format Member', '1', '+91 00000-70726') v ON v.token = u.token
SET u.email = CONCAT('bk.', v.token, '@example.invalid'), u.name = v.name, u.gender = v.gender, u.roleid = v.roleid, u.mobile = v.mobile;

DELETE FROM class_registrations WHERE token BETWEEN 900701 AND 900799;
DELETE FROM class_students WHERE class_id BETWEEN 9451 AND 9469;
DELETE FROM classes WHERE id BETWEEN 9451 AND 9469;

INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (9451, 'BK-G-051', 1, 'bklnk9451', 'Bk Gents Class', 3, '2025-09-01', 900711, 1, 'Offline', 'Mumbai', 'India', 'Bk Hall', 'A', 900331),
  (9452, 'BK-L-052', 1, 'bklnk9452', 'Bk Ladies Class', 3, '2025-09-01', 900712, 2, 'Offline', 'Mumbai', 'India', 'Bk Hall', 'A', 900331),
  (9453, 'BK-G-053', 1, 'bklnk9453', 'Bk Second Gents Class', 3, '2025-09-01', 900711, 1, 'Offline', 'Mumbai', 'India', 'Bk Hall', 'A', 900331);

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9451, 9451, 900721, '2025-09-01', 0, NULL, NULL, NULL, 'A');
UPDATE class_students SET created_at = CONCAT(joined_on, ' 08:00:00') WHERE class_id BETWEEN 9451 AND 9469;
UPDATE classes SET link = CONCAT('bklnk', id) WHERE id BETWEEN 9451 AND 9469;
