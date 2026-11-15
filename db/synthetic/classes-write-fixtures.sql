/*
 * The classes WRITE fixtures for the new API's database: members and classes that the write contract files (domains/classes/spec/tests, the PUT and POST ones) change.
 * tools/parity-php/classes-write-fixtures.sql holds the same rows for the PHP parity stack's MariaDB. Each write file owns its rows, so files can run in parallel and run again:
 * tools/classes-contract.sh loads this file before every run, and it resets every row it owns (by token and class id, never by email, so a changed email comes back).
 * Synthetic only: tokens 900331 and 900401 to 900499, emails on .invalid, mobiles +91000000xxxx, class ids 9401 to 9499. No read file asserts on any of them.
 *
 *   900331  write admin (role 1), the caller of every write file; every class POST /classes creates has created_by 900331 and is deleted here
 *   class-student-admin file:  class 9401 (gents), teacher 900401, students 900411 and 900412 (active), 900413 (removed)
 *   class-schedule-update file: class 9402 (gents), teacher 900402, slots 9401 (Monday 08:00) and 9402 (Wednesday 09:30), 9403 deleted
 *   class-update file:  class 9403 (gents, MIQDAD), teacher 900403, tag 9401, slot 9404 (Tuesday 18:00) with topic row 9401, deleted slot 9405; tags 9401 to 9403, topics 9401 and 9402;
 *                       900404 is a valid new teacher (enrolled in class 9404), 900406 is a member who is not
 */
INSERT INTO identity.users (token, email)
SELECT v.token, v.email FROM (VALUES
  (900331, 'wr.admin@example.invalid'), (900401, 'wr.teacher.one@example.invalid'), (900402, 'wr.teacher.two@example.invalid'), (900403, 'wr.teacher.three@example.invalid'),
  (900404, 'wr.candidate@example.invalid'), (900406, 'wr.nonmember@example.invalid'),
  (900411, 'wr.student.one@example.invalid'), (900412, 'wr.student.two@example.invalid'), (900413, 'wr.student.three@example.invalid')
) AS v (token, email)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

UPDATE identity.users u SET email = v.email
FROM (VALUES
  (900331, 'wr.admin@example.invalid'), (900401, 'wr.teacher.one@example.invalid'), (900402, 'wr.teacher.two@example.invalid'), (900403, 'wr.teacher.three@example.invalid'),
  (900404, 'wr.candidate@example.invalid'), (900406, 'wr.nonmember@example.invalid'),
  (900411, 'wr.student.one@example.invalid'), (900412, 'wr.student.two@example.invalid'), (900413, 'wr.student.three@example.invalid')
) AS v (token, email)
WHERE u.token = v.token AND u.email <> v.email;

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id, v.name, v.gender, v.mobile FROM (VALUES
  (900331, 'Wr Admin', '1', ''), (900401, 'Wr Teacher One', '1', '+910000004001'), (900402, 'Wr Teacher Two', '1', '+910000004002'),
  (900403, 'Wr Teacher Three', '1', '+910000004003'), (900404, 'Wr Candidate', '1', '+910000004004'), (900406, 'Wr Nonmember', '1', '+910000004006'),
  (900411, 'Wr Student One', '1', '+910000004011'), (900412, 'Wr Student Two', '1', '+910000004012'), (900413, 'Wr Student Three', '1', '+910000004013')
) AS v (token, name, gender, mobile)
JOIN identity.users u ON u.token = v.token
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

INSERT INTO access.user_roles (user_id, roleid)
SELECT u.id, 1 FROM identity.users u WHERE u.token = 900331 AND NOT EXISTS (SELECT 1 FROM access.user_roles r WHERE r.user_id = u.id);

-- What POST /classes made, then the fixture classes.
DELETE FROM classes.class_schedule_topics WHERE class_schedule_id IN (SELECT id FROM classes.class_schedules WHERE class_id IN (SELECT id FROM classes.classes WHERE created_by = 900331 OR id BETWEEN 9401 AND 9499));
DELETE FROM classes.class_schedules WHERE class_id IN (SELECT id FROM classes.classes WHERE created_by = 900331 OR id BETWEEN 9401 AND 9499);
DELETE FROM classes.class_tags WHERE class_id IN (SELECT id FROM classes.classes WHERE created_by = 900331 OR id BETWEEN 9401 AND 9499);
DELETE FROM classes.class_students WHERE class_id IN (SELECT id FROM classes.classes WHERE created_by = 900331 OR id BETWEEN 9401 AND 9499);
DELETE FROM classes.classes WHERE created_by = 900331 OR id BETWEEN 9401 AND 9499;
DELETE FROM classes.tags WHERE id BETWEEN 9401 AND 9499;
DELETE FROM classes.topics WHERE id BETWEEN 9401 AND 9499;

INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, address, city, country, location, status, created_by) VALUES
  (9401, 'WR-G-001', 1, 'wrlnk9401', 'Wr Class Admin Class', 3, DATE '2025-09-01', 900401, 1, 'Offline', NULL, 'Mumbai', 'India', 'Wr Hall', 'A', 900331),
  (9402, 'WR-G-002', 1, 'wrlnk9402', 'Wr Schedule Class', 3, DATE '2025-09-01', 900402, 1, 'Offline', NULL, 'Mumbai', 'India', 'Wr Hall 2', 'A', 900331),
  (9403, 'WR-G-003', 1, 'wrlnk9403', 'Wr Update Class', 3, DATE '2025-09-01', 900403, 1, 'Offline', 'Wr Address', 'Mumbai', 'India', 'Wr Hall 3', 'A', 900331),
  (9404, 'WR-G-004', 1, 'wrlnk9404', 'Wr Pool Class', 3, DATE '2025-09-01', 900402, 1, 'Offline', NULL, 'Mumbai', 'India', 'Wr Hall 4', 'A', 900331);

INSERT INTO classes.tags (id, name) VALUES (9401, 'wr-alpha'), (9402, 'wr-beta'), (9403, 'wr-gamma');
INSERT INTO classes.topics (id, name, is_vocational, sort_order, created_by) VALUES (9401, 'Wr Topic One', 0, 1, 900331), (9402, 'Wr Topic Two', 0, 2, 900331);
INSERT INTO classes.class_tags (class_id, tag_id, created_by) VALUES (9403, 9401, 900331);

INSERT INTO classes.class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) VALUES
  (9401, 9402, 1, 8, 0, 'Asia/Kolkata', 900331, NULL, NULL),
  (9402, 9402, 3, 9, 30, 'Asia/Dubai', 900331, NULL, NULL),
  (9403, 9402, 5, 10, 0, 'Asia/Kolkata', 900331, now(), 900331),
  (9404, 9403, 2, 18, 0, 'Asia/Kolkata', 900331, NULL, NULL),
  (9405, 9403, 6, 11, 0, 'Asia/Kolkata', 900331, now(), 900331);
INSERT INTO classes.class_schedule_topics (id, class_schedule_id, topic_id, sort_order, created_by) VALUES (9401, 9404, 9401, 1, 900331);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9401, 9401, 900411, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9402, 9401, 900412, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9403, 9401, 900413, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'Wr removed', 900331, 'I'),
  (9404, 9404, 900404, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A');
UPDATE classes.class_students SET created_at = joined_on + TIME '08:00' AT TIME ZONE 'UTC' WHERE class_id BETWEEN 9401 AND 9499;

-- New rows get ids above the fixtures' own (a sequence does not follow explicit ids).
SELECT setval(pg_get_serial_sequence('classes.classes', 'id'), greatest((SELECT max(id) FROM classes.classes), 1));
SELECT setval(pg_get_serial_sequence('classes.class_schedules', 'id'), greatest((SELECT max(id) FROM classes.class_schedules), 1));
SELECT setval(pg_get_serial_sequence('classes.class_schedule_topics', 'id'), greatest((SELECT max(id) FROM classes.class_schedule_topics), 1));
DELETE FROM classes.guides WHERE level_id = 2 AND language_id = 1;
