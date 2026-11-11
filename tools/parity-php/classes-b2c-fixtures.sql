/*
 * The classes B2c fixtures for the PHP parity stack's MariaDB: what the deactivate and edit-a-student write contract files change. db/synthetic/classes-b2c-fixtures.sql holds the same rows for the new API's
 * database (read that header). Loaded by tools/classes-contract.sh after the enrolment fixtures, before every run; resets every row it owns (by token and class id).
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, CONCAT('en.', v.token, '@example.invalid'), 0, 'firebase', NOW(), CONCAT('Bc Member ', v.token), '1', CONCAT('+91000006', RIGHT(v.token, 4)) FROM (
  SELECT 900601 AS token UNION ALL SELECT 900611 UNION ALL SELECT 900612 UNION ALL SELECT 900613 UNION ALL SELECT 900621 UNION ALL SELECT 900622 UNION ALL SELECT 900623 UNION ALL SELECT 900624) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users SET email = CONCAT('en.', token, '@example.invalid'), name = CONCAT('Bc Member ', token), gender = '1', roleid = 0, mobile = CONCAT('+91000006', RIGHT(token, 4))
WHERE token BETWEEN 900601 AND 900699;

DELETE FROM class_audit_log WHERE class_id BETWEEN 9431 AND 9449;
DELETE FROM class_schedule_topics WHERE class_schedule_id IN (SELECT id FROM class_schedules WHERE class_id BETWEEN 9431 AND 9449);
DELETE FROM class_schedules WHERE class_id BETWEEN 9431 AND 9449;
DELETE FROM class_students WHERE class_id BETWEEN 9431 AND 9449;
DELETE FROM classes WHERE id BETWEEN 9431 AND 9449;

INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (9431, 'BC-G-031', 1, 'bclnk9431', 'Bc Deactivate Class', 3, '2025-09-01', 900601, 1, 'Offline', 'Mumbai', 'India', 'Bc Hall', 'A', 900331),
  (9432, 'BC-G-032', 1, 'bclnk9432', 'Bc Inactive Class', 3, '2025-09-01', 900601, 1, 'Offline', 'Mumbai', 'India', 'Bc Hall', 'I', 900331),
  (9433, 'BC-G-033', 1, 'bclnk9433', 'Bc Edit Class', 3, '2025-09-01', 900601, 1, 'Offline', 'Mumbai', 'India', 'Bc Hall', 'A', 900331),
  (9434, 'BC-G-034', 1, 'bclnk9434', 'Bc Other Class', 3, '2025-09-01', 900601, 1, 'Offline', 'Mumbai', 'India', 'Bc Hall', 'A', 900331);

INSERT INTO class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) VALUES
  (9431, 9431, 2, 18, 0, 'Asia/Kolkata', 900331, NULL, NULL),
  (9432, 9431, 4, 19, 0, 'Asia/Kolkata', 900331, NULL, NULL),
  (9433, 9431, 6, 11, 0, 'Asia/Kolkata', 900331, '2025-10-01 00:00:00', 900331);
INSERT INTO class_schedule_topics (id, class_schedule_id, topic_id, sort_order, created_by) VALUES (9431, 9431, 9401, 1, 900331);

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9431, 9431, 900611, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9432, 9431, 900612, '2025-09-01', 1, NULL, NULL, NULL, 'A'),
  (9433, 9431, 900613, '2025-09-01', 0, '2025-10-01 00:00:00', 'Bc left', 900331, 'I'),
  (9434, 9433, 900621, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9435, 9433, 900622, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9436, 9433, 900623, '2025-09-01', 0, '2025-10-01 00:00:00', 'Bc left', 900331, 'I'),
  (9437, 9434, 900624, '2025-09-01', 0, NULL, NULL, NULL, 'A');
UPDATE class_students SET created_at = CONCAT(joined_on, ' 08:00:00') WHERE class_id BETWEEN 9431 AND 9449;
UPDATE class_students SET notes = 'Bc note' WHERE id = 9434;
-- classes_before_create replaces the link of every inserted class with a random string; an UPDATE keeps ours.
UPDATE classes SET link = CONCAT('bclnk', id) WHERE id BETWEEN 9431 AND 9449;
