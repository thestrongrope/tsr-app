/*
 * The classes REPORT fixtures for the new API's database (batch B5a: the conduction, weekly, summary, subject-conduction and class-sessions reports). tools/parity-php/classes-b5a-fixtures.sql holds the same rows for the PHP
 * parity stack. Loaded last by tools/classes-contract.sh before every run; resets every row it owns by token and id. Read-only for the files (reports write nothing). Synthetic only: tokens 901401 to 901499, emails
 * rp.<token>@example.invalid, classes 9581 to 9589, sessions 958101 and up (explicit ids). Every date is fixed in November 2025, and the Hurl files ask for those weeks explicitly, so a run does not depend on today.
 * Callers from the earlier fixtures: "admin" (role 1), 900501 (gents admin) and 900502 (ladies admin).
 *
 *   901401 a class coordinator (role 5) assigned the classes 9581 and 9582 (new API: a rule for gents classes in the city "Reportville"; PHP: class_access rows): the one caller whose answers are compared in full
 *   901411 teacher of 9581, 9584, 9585, 9586   901412 teacher of the ladies class 9583   901413 teacher of 9582   901421 to 901425 students (901423 left 9581; 901425 is in 9583)
 *   9581 gents, MIQDAD, Reportville, started 2025-01-06, slots Monday and Thursday, extra students "Extra A\nExtra B"; sessions on 2025-11-03 (not held), 11-10, 11-13 (two held days in week 45), 11-17, 11-24 (held), 11-27 (not held, reason "=Rp formula")
 *   9582 gents, ABUZAR, Reportville, slot Tuesday, one held session 2025-11-11   9583 ladies, MIQDAD, Reportville, slot Thursday, one held session 2025-11-12
 *   9584 gents, MIQDAD, city Elsewhere (outside the coordinator's reach), slot Monday, one held session 2025-11-10   9585 gents, closed (status I), one session   9586 gents, code AYD1 (the demo class, when the seed has none)
 */
INSERT INTO identity.users (token, email)
SELECT v.token, 'rp.' || v.token || '@example.invalid' FROM (VALUES
  (901401), (901411), (901412), (901413), (901421), (901422), (901423), (901424), (901425)
) AS v (token)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

UPDATE identity.users u SET email = 'rp.' || u.token || '@example.invalid' WHERE u.token BETWEEN 901401 AND 901499 AND u.email <> 'rp.' || u.token || '@example.invalid';

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id, 'Rp Member ' || v.token, CASE WHEN v.token IN (901412, 901425) THEN '2' ELSE '1' END, '+91000014' || right(v.token::text, 4) FROM (VALUES
  (901401), (901411), (901412), (901413), (901421), (901422), (901423), (901424), (901425)
) AS v (token)
JOIN identity.users u ON u.token = v.token
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token = 901401);
INSERT INTO access.user_roles (user_id, roleid) SELECT id, 5 FROM identity.users WHERE token = 901401;

DELETE FROM access.class_access_rule_conditions WHERE rule_id = 958101;
DELETE FROM access.class_access_rules WHERE id = 958101;
INSERT INTO access.class_access_rules (id, token, gender, note, created_at) VALUES (958101, 901401, 1, 'Rp gents classes of Reportville', now());
INSERT INTO access.class_access_rule_conditions (rule_id, field, negate, value) VALUES (958101, 'city', false, 'Reportville');

DELETE FROM classes.class_attendance WHERE session_id IN (SELECT id FROM classes.class_sessions WHERE class_id BETWEEN 9581 AND 9589);
DELETE FROM classes.class_sessions WHERE class_id BETWEEN 9581 AND 9589;
DELETE FROM classes.class_schedules WHERE class_id BETWEEN 9581 AND 9589;
DELETE FROM classes.class_students WHERE class_id BETWEEN 9581 AND 9589;
DELETE FROM classes.classes WHERE id BETWEEN 9581 AND 9589;

INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by, extra_students) VALUES
  (9581, 'RP-G-581', 1, 'rplnk9581', 'Rp Main Class', 3, DATE '2025-01-06', 901411, 1, 'Offline', 'Reportville', 'India', 'Rp Hall', 'A', 900315, E'Extra A\nExtra B'),
  (9582, 'RP-G-582', 1, 'rplnk9582', 'Rp Second Class', 2, DATE '2025-01-06', 901413, 1, 'Offline', 'Reportville', 'India', 'Rp Hall', 'A', 900315, NULL),
  (9583, 'RP-L-583', 1, 'rplnk9583', 'Rp Ladies Class', 3, DATE '2025-01-06', 901412, 2, 'Offline', 'Reportville', 'India', 'Rp Hall', 'A', 900315, NULL),
  (9584, 'RP-G-584', 1, 'rplnk9584', 'Rp Elsewhere Class', 3, DATE '2025-01-06', 901411, 1, 'Offline', 'Elsewhere', 'India', 'Rp Hall', 'A', 900315, NULL),
  (9585, 'RP-G-585', 1, 'rplnk9585', 'Rp Closed Class', 3, DATE '2025-01-06', 901411, 1, 'Offline', 'Reportville', 'India', 'Rp Hall', 'I', 900315, NULL);
INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by, extra_students)
SELECT 9586, 'AYD1', 1, 'rplnk9586', 'Rp Demo Class', 3, DATE '2025-01-06', 901411, 1, 'Offline', 'Reportville', 'India', 'Rp Hall', 'A', 900315, NULL
WHERE NOT EXISTS (SELECT 1 FROM classes.classes WHERE code = 'AYD1');

INSERT INTO classes.class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) VALUES
  (958101, 9581, 2, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (958102, 9581, 5, 19, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (958103, 9581, 7, 11, 0, 'Asia/Kolkata', 900315, TIMESTAMPTZ '2025-10-01 00:00:00+00', 900315),
  (958104, 9582, 3, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (958105, 9583, 4, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (958106, 9584, 2, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (958107, 9585, 2, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL);
INSERT INTO classes.class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by)
SELECT 958108, 9586, 2, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL WHERE EXISTS (SELECT 1 FROM classes.classes WHERE id = 9586);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (958101, 9581, 901421, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (958102, 9581, 901422, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (958103, 9581, 901423, DATE '2025-01-06', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'Rp left', 900315, 'I'),
  (958104, 9582, 901424, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (958105, 9583, 901425, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A');
UPDATE classes.class_students SET created_at = joined_on + TIME '08:00' AT TIME ZONE 'UTC' WHERE class_id BETWEEN 9581 AND 9589;

INSERT INTO classes.class_sessions (id, class_id, teacher, conducted_on, conducted, non_conduction_reason, duration, attendance, quran_recitation_surah, quran_recitation_verse,
                                    arabic_conducted, aqaed_conducted, ahkam_conducted, akhlaq_conducted, other_conducted, arabic_topic, aqaed_topic, ahkam_topic, created_by, created_at) VALUES
  (958101, 9581, 901411, DATE '2025-11-03', 0, 'Rp rain', NULL, NULL, NULL, NULL, 'N', 'N', 'N', 'N', 'N', NULL, NULL, NULL, 901411, TIMESTAMPTZ '2025-11-03 12:00:00+00'),
  (958102, 9581, 901411, DATE '2025-11-10', 1, NULL, 45, 2, 2, 5, '1', 'Y', 'N', 'N', 'N', 'Alif', NULL, NULL, 901411, TIMESTAMPTZ '2025-11-10 12:00:00+00'),
  (958103, 9581, 901411, DATE '2025-11-13', 1, NULL, 30, 1, NULL, NULL, 'N', 'Y', '1', 'N', 'N', 'Hidden', 'Tawhid', 'Wudu', 901411, TIMESTAMPTZ '2025-11-13 12:00:00+00'),
  (958104, 9581, 901411, DATE '2025-11-17', 1, NULL, 60, 3, 3, NULL, 'Y', 'N', 'N', 'N', 'N', 'Alif', NULL, NULL, 901411, TIMESTAMPTZ '2025-11-17 12:00:00+00'),
  (958105, 9581, 901411, DATE '2025-11-24', 1, NULL, 40, 0, NULL, NULL, 'N', 'N', 'N', 'N', '1', NULL, NULL, NULL, 901411, TIMESTAMPTZ '2025-11-24 12:00:00+00'),
  (958106, 9581, 901411, DATE '2025-11-27', 0, '=Rp formula', NULL, NULL, 2, 0, 'N', 'N', 'N', 'N', 'N', NULL, NULL, NULL, 901411, TIMESTAMPTZ '2025-11-27 12:00:00+00'),
  (958201, 9582, 901413, DATE '2025-11-11', 1, NULL, 50, 1, NULL, NULL, 'N', 'Y', 'N', 'N', 'N', NULL, 'Aqaed Two', NULL, 901413, TIMESTAMPTZ '2025-11-11 12:00:00+00'),
  (958301, 9583, 901412, DATE '2025-11-12', 1, NULL, 20, 1, NULL, NULL, 'N', 'N', 'N', 'N', 'N', NULL, NULL, NULL, 901412, TIMESTAMPTZ '2025-11-12 12:00:00+00'),
  (958401, 9584, 901411, DATE '2025-11-10', 1, NULL, 25, 1, NULL, NULL, 'N', 'N', 'N', 'N', 'N', NULL, NULL, NULL, 901411, TIMESTAMPTZ '2025-11-10 12:00:00+00'),
  (958501, 9585, 901411, DATE '2025-11-10', 1, NULL, 25, 1, NULL, NULL, 'N', 'N', 'N', 'N', 'N', NULL, NULL, NULL, 901411, TIMESTAMPTZ '2025-11-10 12:00:00+00');
INSERT INTO classes.class_sessions (id, class_id, teacher, conducted_on, conducted, non_conduction_reason, duration, attendance, quran_recitation_surah, quran_recitation_verse,
                                    arabic_conducted, aqaed_conducted, ahkam_conducted, akhlaq_conducted, other_conducted, arabic_topic, aqaed_topic, ahkam_topic, created_by, created_at)
SELECT 958601, 9586, 901411, DATE '2025-11-10', 1, NULL, 25, 1, NULL, NULL, 'N', 'N', 'N', 'N', 'N', NULL, NULL, NULL, 901411, TIMESTAMPTZ '2025-11-10 12:00:00+00' WHERE EXISTS (SELECT 1 FROM classes.classes WHERE id = 9586);

INSERT INTO classes.class_attendance (id, session_id, token, name, extra_student, present, recitation) VALUES
  (958101, 958102, 901421, NULL, 0, 1, 3), (958102, 958102, 901422, NULL, 0, 1, 0),
  (958103, 958103, 901421, NULL, 0, 1, 0), (958104, 958103, 901422, NULL, 0, 0, 0),
  (958105, 958104, 901421, NULL, 0, 1, 1), (958106, 958104, 901422, NULL, 0, 1, 0), (958107, 958104, 1, 'Extra A', 1, 1, 0),
  (958201, 958201, 901424, NULL, 0, 1, 0);

SELECT setval(pg_get_serial_sequence('classes.class_sessions', 'id'), greatest((SELECT max(id) FROM classes.class_sessions), 1));
SELECT setval(pg_get_serial_sequence('classes.class_attendance', 'id'), greatest((SELECT max(id) FROM classes.class_attendance), 1));
SELECT setval(pg_get_serial_sequence('classes.class_students', 'id'), greatest((SELECT max(id) FROM classes.class_students), 9499));
SELECT setval(pg_get_serial_sequence('classes.class_schedules', 'id'), greatest((SELECT max(id) FROM classes.class_schedules), 9499));
SELECT setval(pg_get_serial_sequence('classes.classes', 'id'), greatest((SELECT max(id) FROM classes.classes), 1));
