/*
 * The classes WRITE fixtures for the PHP parity stack's MariaDB (tools/classes-contract.sh parity loads it before every run): the same members and classes as
 * db/synthetic/classes-write-fixtures.sql (read that header), so one Hurl file sees one data set on both sides. Resets every row it owns, by token and class id.
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, v.email, v.roleid, 'firebase', NOW(), v.name, v.gender, v.mobile FROM (
  SELECT 900331 AS token, 'wr.admin@example.invalid' AS email, 1 AS roleid, 'Wr Admin' AS name, '1' AS gender, '' AS mobile UNION ALL
  SELECT 900401, 'wr.teacher.one@example.invalid', 0, 'Wr Teacher One', '1', '+910000004001' UNION ALL
  SELECT 900402, 'wr.teacher.two@example.invalid', 0, 'Wr Teacher Two', '1', '+910000004002' UNION ALL
  SELECT 900403, 'wr.teacher.three@example.invalid', 0, 'Wr Teacher Three', '1', '+910000004003' UNION ALL
  SELECT 900404, 'wr.candidate@example.invalid', 0, 'Wr Candidate', '1', '+910000004004' UNION ALL
  SELECT 900406, 'wr.nonmember@example.invalid', 0, 'Wr Nonmember', '1', '+910000004006' UNION ALL
  SELECT 900411, 'wr.student.one@example.invalid', 0, 'Wr Student One', '1', '+910000004011' UNION ALL
  SELECT 900412, 'wr.student.two@example.invalid', 0, 'Wr Student Two', '1', '+910000004012' UNION ALL
  SELECT 900413, 'wr.student.three@example.invalid', 0, 'Wr Student Three', '1', '+910000004013') v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users u JOIN (
  SELECT 900331 AS token, 'wr.admin@example.invalid' AS email, 'Wr Admin' AS name, '' AS mobile UNION ALL
  SELECT 900401, 'wr.teacher.one@example.invalid', 'Wr Teacher One', '+910000004001' UNION ALL
  SELECT 900402, 'wr.teacher.two@example.invalid', 'Wr Teacher Two', '+910000004002' UNION ALL
  SELECT 900403, 'wr.teacher.three@example.invalid', 'Wr Teacher Three', '+910000004003' UNION ALL
  SELECT 900404, 'wr.candidate@example.invalid', 'Wr Candidate', '+910000004004' UNION ALL
  SELECT 900406, 'wr.nonmember@example.invalid', 'Wr Nonmember', '+910000004006' UNION ALL
  SELECT 900411, 'wr.student.one@example.invalid', 'Wr Student One', '+910000004011' UNION ALL
  SELECT 900412, 'wr.student.two@example.invalid', 'Wr Student Two', '+910000004012' UNION ALL
  SELECT 900413, 'wr.student.three@example.invalid', 'Wr Student Three', '+910000004013') v ON v.token = u.token
SET u.email = v.email, u.name = v.name, u.mobile = v.mobile, u.gender = '1';
UPDATE users SET roleid = 1 WHERE token = 900331;

DELETE FROM class_schedule_topics WHERE class_schedule_id IN (SELECT id FROM class_schedules WHERE class_id IN (SELECT id FROM classes WHERE created_by = 900331 OR id BETWEEN 9401 AND 9499));
DELETE FROM class_schedules WHERE class_id IN (SELECT id FROM classes WHERE created_by = 900331 OR id BETWEEN 9401 AND 9499);
DELETE FROM class_tags WHERE class_id IN (SELECT id FROM classes WHERE created_by = 900331 OR id BETWEEN 9401 AND 9499);
DELETE FROM class_students WHERE class_id IN (SELECT id FROM classes WHERE created_by = 900331 OR id BETWEEN 9401 AND 9499);
DELETE FROM classes WHERE created_by = 900331 OR id BETWEEN 9401 AND 9499;
DELETE FROM tags WHERE id BETWEEN 9401 AND 9499;
DELETE FROM topics WHERE id BETWEEN 9401 AND 9499;

INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, address, city, country, location, status, created_by) VALUES
  (9401, 'WR-G-001', 1, 'wrlnk9401', 'Wr Class Admin Class', 3, '2025-09-01', 900401, 1, 'Offline', NULL, 'Mumbai', 'India', 'Wr Hall', 'A', 900331),
  (9402, 'WR-G-002', 1, 'wrlnk9402', 'Wr Schedule Class', 3, '2025-09-01', 900402, 1, 'Offline', NULL, 'Mumbai', 'India', 'Wr Hall 2', 'A', 900331),
  (9403, 'WR-G-003', 1, 'wrlnk9403', 'Wr Update Class', 3, '2025-09-01', 900403, 1, 'Offline', 'Wr Address', 'Mumbai', 'India', 'Wr Hall 3', 'A', 900331),
  (9404, 'WR-G-004', 1, 'wrlnk9404', 'Wr Pool Class', 3, '2025-09-01', 900402, 1, 'Offline', NULL, 'Mumbai', 'India', 'Wr Hall 4', 'A', 900331);

INSERT INTO tags (id, name) VALUES (9401, 'wr-alpha'), (9402, 'wr-beta'), (9403, 'wr-gamma');
INSERT INTO topics (id, name, is_vocational, sort_order, created_by) VALUES (9401, 'Wr Topic One', 0, 1, 900331), (9402, 'Wr Topic Two', 0, 2, 900331);
INSERT INTO class_tags (class_id, tag_id, created_by) VALUES (9403, 9401, 900331);

INSERT INTO class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) VALUES
  (9401, 9402, 1, 8, 0, 'Asia/Kolkata', 900331, NULL, NULL),
  (9402, 9402, 3, 9, 30, 'Asia/Dubai', 900331, NULL, NULL),
  (9403, 9402, 5, 10, 0, 'Asia/Kolkata', 900331, NOW(), 900331),
  (9404, 9403, 2, 18, 0, 'Asia/Kolkata', 900331, NULL, NULL),
  (9405, 9403, 6, 11, 0, 'Asia/Kolkata', 900331, NOW(), 900331);
INSERT INTO class_schedule_topics (id, class_schedule_id, topic_id, sort_order, created_by) VALUES (9401, 9404, 9401, 1, 900331);

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9401, 9401, 900411, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9402, 9401, 900412, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9403, 9401, 900413, '2025-09-01', 0, '2025-10-01 00:00:00', 'Wr removed', 900331, 'I'),
  (9404, 9404, 900404, '2025-09-01', 0, NULL, NULL, NULL, 'A');
UPDATE class_students SET created_at = CONCAT(joined_on, ' 08:00:00') WHERE class_id BETWEEN 9401 AND 9499;
DELETE FROM guides WHERE level_id = 2 AND language_id = 1;
