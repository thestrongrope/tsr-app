/*
 * The classes B2c fixtures for the new API's database: what the deactivate and edit-a-student write contract files change. tools/parity-php/classes-b2c-fixtures.sql holds the same rows for the PHP parity
 * stack. Loaded by tools/classes-contract.sh after the enrolment fixtures, before every run; resets every row it owns (by token and class id). Synthetic only: tokens 900601 to 900699, emails
 * en.<token>@example.invalid, mobiles +91000006xxxx, class ids 9431 to 9449 (inside the write fixtures' reset range, which deletes their rows first). Callers come from the earlier fixtures:
 * 900331 (role 1, the only holder of deactivated-classes:manage), 900501 (gents admin), 900502 (ladies admin), 900511 (a gents teacher), the ladies class 9414.
 *
 *   900601 teacher of the gents classes below
 *   deactivate  class 9431 (gents, active; schedule slots 9431 (with topic row 9431) and 9432 live, 9433 already deleted; students 900611, 900612 active, 900613 removed before), 9432 (gents, already inactive)
 *   edit        class 9433 (gents): 900621 and 900622 active, 900623 removed; class 9434 (gents): 900624
 */
INSERT INTO identity.users (token, email)
SELECT v.token, 'en.' || v.token || '@example.invalid' FROM (VALUES
  (900601), (900611), (900612), (900613), (900621), (900622), (900623), (900624)
) AS v (token)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

UPDATE identity.users u SET email = 'en.' || u.token || '@example.invalid' WHERE u.token BETWEEN 900601 AND 900699 AND u.email <> 'en.' || u.token || '@example.invalid';

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id, 'Bc Member ' || v.token, '1', '+91000006' || right(v.token::text, 4) FROM (VALUES
  (900601), (900611), (900612), (900613), (900621), (900622), (900623), (900624)
) AS v (token)
JOIN identity.users u ON u.token = v.token
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

DELETE FROM classes.class_audit_log WHERE class_id BETWEEN 9431 AND 9449;
DELETE FROM classes.class_schedule_topics WHERE class_schedule_id IN (SELECT id FROM classes.class_schedules WHERE class_id BETWEEN 9431 AND 9449);
DELETE FROM classes.class_schedules WHERE class_id BETWEEN 9431 AND 9449;
DELETE FROM classes.class_students WHERE class_id BETWEEN 9431 AND 9449;
DELETE FROM classes.classes WHERE id BETWEEN 9431 AND 9449;

INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (9431, 'BC-G-031', 1, 'bclnk9431', 'Bc Deactivate Class', 3, DATE '2025-09-01', 900601, 1, 'Offline', 'Mumbai', 'India', 'Bc Hall', 'A', 900331),
  (9432, 'BC-G-032', 1, 'bclnk9432', 'Bc Inactive Class', 3, DATE '2025-09-01', 900601, 1, 'Offline', 'Mumbai', 'India', 'Bc Hall', 'I', 900331),
  (9433, 'BC-G-033', 1, 'bclnk9433', 'Bc Edit Class', 3, DATE '2025-09-01', 900601, 1, 'Offline', 'Mumbai', 'India', 'Bc Hall', 'A', 900331),
  (9434, 'BC-G-034', 1, 'bclnk9434', 'Bc Other Class', 3, DATE '2025-09-01', 900601, 1, 'Offline', 'Mumbai', 'India', 'Bc Hall', 'A', 900331);

INSERT INTO classes.class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) VALUES
  (9431, 9431, 2, 18, 0, 'Asia/Kolkata', 900331, NULL, NULL),
  (9432, 9431, 4, 19, 0, 'Asia/Kolkata', 900331, NULL, NULL),
  (9433, 9431, 6, 11, 0, 'Asia/Kolkata', 900331, TIMESTAMPTZ '2025-10-01 00:00:00+00', 900331);
INSERT INTO classes.class_schedule_topics (id, class_schedule_id, topic_id, sort_order, created_by) VALUES (9431, 9431, 9401, 1, 900331);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9431, 9431, 900611, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9432, 9431, 900612, DATE '2025-09-01', 1, NULL, NULL, NULL, 'A'),
  (9433, 9431, 900613, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'Bc left', 900331, 'I'),
  (9434, 9433, 900621, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9435, 9433, 900622, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9436, 9433, 900623, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'Bc left', 900331, 'I'),
  (9437, 9434, 900624, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A');
UPDATE classes.class_students SET created_at = joined_on + TIME '08:00' AT TIME ZONE 'UTC' WHERE class_id BETWEEN 9431 AND 9449;
UPDATE classes.class_students SET notes = 'Bc note' WHERE id = 9434;

SELECT setval(pg_get_serial_sequence('classes.class_students', 'id'), greatest((SELECT max(id) FROM classes.class_students), 9499));
SELECT setval(pg_get_serial_sequence('classes.class_schedules', 'id'), greatest((SELECT max(id) FROM classes.class_schedules), 9499));
SELECT setval(pg_get_serial_sequence('classes.class_schedule_topics', 'id'), greatest((SELECT max(id) FROM classes.class_schedule_topics), 9499));
SELECT setval(pg_get_serial_sequence('classes.class_audit_log', 'id'), greatest((SELECT coalesce(max(id), 1) FROM classes.class_audit_log), 1));
SELECT setval(pg_get_serial_sequence('classes.classes', 'id'), greatest((SELECT max(id) FROM classes.classes), 1));
