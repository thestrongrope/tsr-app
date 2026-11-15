/*
 * The classes CONDUCTION fixtures for the new API's database: what the conduction contract files read and change (batch B3). tools/parity-php/classes-conduction-fixtures.sql holds the same rows for the PHP parity
 * stack. Loaded by tools/classes-contract.sh after the other fixtures, before every run; resets every row it owns by token and class id, including the sessions and attendance a run created. Synthetic only:
 * tokens 900801 to 900849, emails cd.<token>@example.invalid, mobiles +91000008xxxx, classes 9471 to 9489, sessions 947101 and up (explicit ids; the sequences move above them).
 * Callers from the earlier fixtures: 900315 (role 1), 900501 (gents admin), 900502 (ladies admin).
 *
 *   900801 teacher of 9471, 9474, 9476, 9478 (gents)   900802 teacher of 9472   900803 teacher of the ladies class 9473   900804 teacher of 9475
 *   900811, 900812 active in 9471, 900813 removed from it   900821, 900822 active in 9472, 900823 removed from it   900825 ladies, active in 9473   900826 in no class
 *   900831, 900832 active in 9475   900841 active in 9478
 *   9471 READ: three sessions (a '1' flag and a 'Y' flag), extra students "Extra One" and "Extra Two", two live schedule slots (days 2 and 5) and a deleted one (day 7)
 *   9472 POST: no session; extra students "Seed Extra", "Second Extra"      9473 ladies, read by the POST file (an other-gender token)
 *   9474 READ: one schedule slot (Monday), a session on Monday 2025-10-13 and one far in the future (Monday 2099-01-05)
 *   9475 PUT: three sessions (two editable, one made 30 days ago)          9476 READ: no session, started 2025-10-01, no schedule      9478 POST on the new API only (NUL, lengths)
 */
INSERT INTO identity.users (token, email)
SELECT v.token, 'cd.' || v.token || '@example.invalid' FROM (VALUES
  (900801), (900802), (900803), (900804), (900811), (900812), (900813), (900821), (900822), (900823), (900825), (900826), (900831), (900832), (900841)
) AS v (token)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

UPDATE identity.users u SET email = 'cd.' || u.token || '@example.invalid' WHERE u.token BETWEEN 900801 AND 900849 AND u.email <> 'cd.' || u.token || '@example.invalid';

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id, 'Cd Member ' || v.token, CASE WHEN v.token IN (900803, 900825) THEN '2' ELSE '1' END, '+91000008' || right(v.token::text, 4) FROM (VALUES
  (900801), (900802), (900803), (900804), (900811), (900812), (900813), (900821), (900822), (900823), (900825), (900826), (900831), (900832), (900841)
) AS v (token)
JOIN identity.users u ON u.token = v.token
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

DELETE FROM classes.class_attendance WHERE session_id IN (SELECT id FROM classes.class_sessions WHERE class_id BETWEEN 9471 AND 9489);
DELETE FROM classes.class_sessions WHERE class_id BETWEEN 9471 AND 9489;
DELETE FROM classes.class_schedules WHERE class_id BETWEEN 9471 AND 9489;
DELETE FROM classes.class_students WHERE class_id BETWEEN 9471 AND 9489;
DELETE FROM classes.classes WHERE id BETWEEN 9471 AND 9489;

INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by, extra_students) VALUES
  (9471, 'CD-G-071', 1, 'cdlnk9471', 'Cd Read Class', 3, DATE '2025-09-01', 900801, 1, 'Offline', 'Mumbai', 'India', 'Cd Hall', 'A', 900315, E'Extra One, +910000008001\n\nExtra Two\r\n'),
  (9472, 'CD-G-072', 1, 'cdlnk9472', 'Cd Post Class', 3, DATE '2025-09-01', 900802, 1, 'Offline', 'Mumbai', 'India', 'Cd Hall', 'A', 900315, E'Seed Extra, +910000008002\nSecond Extra'),
  (9473, 'CD-L-073', 1, 'cdlnk9473', 'Cd Ladies Class', 3, DATE '2025-09-01', 900803, 2, 'Offline', 'Mumbai', 'India', 'Cd Hall', 'A', 900315, NULL),
  (9474, 'CD-G-074', 1, 'cdlnk9474', 'Cd Week Class', 3, DATE '2025-09-01', 900801, 1, 'Offline', 'Mumbai', 'India', 'Cd Hall', 'A', 900315, NULL),
  (9475, 'CD-G-075', 1, 'cdlnk9475', 'Cd Put Class', 3, DATE '2025-09-01', 900804, 1, 'Offline', 'Mumbai', 'India', 'Cd Hall', 'A', 900315, 'Put Extra'),
  (9476, 'CD-G-076', 1, 'cdlnk9476', 'Cd Empty Class', 3, DATE '2025-10-01', 900801, 1, 'Offline', 'Mumbai', 'India', 'Cd Hall', 'A', 900315, NULL),
  (9478, 'CD-G-078', 1, 'cdlnk9478', 'Cd Limits Class', 3, DATE '2025-09-01', 900801, 1, 'Offline', 'Mumbai', 'India', 'Cd Hall', 'A', 900315, NULL);

INSERT INTO classes.class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) VALUES
  (9471, 9471, 2, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (9472, 9471, 5, 19, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (9473, 9471, 7, 11, 0, 'Asia/Kolkata', 900315, TIMESTAMPTZ '2025-10-01 00:00:00+00', 900315),
  (9474, 9474, 1, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9471, 9471, 900811, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9472, 9471, 900812, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9473, 9471, 900813, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'Cd left', 900315, 'I'),
  (9474, 9472, 900821, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9475, 9472, 900822, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9476, 9472, 900823, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'Cd left', 900315, 'I'),
  (9477, 9473, 900825, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9478, 9475, 900831, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9479, 9475, 900832, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9480, 9478, 900841, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A');
UPDATE classes.class_students SET created_at = joined_on + TIME '08:00' AT TIME ZONE 'UTC' WHERE class_id BETWEEN 9471 AND 9489;

INSERT INTO classes.class_sessions (id, class_id, teacher, conducted_on, conducted, non_conduction_reason, duration, attendance, quran_recitation_surah, quran_recitation_verse,
                                    arabic_conducted, aqaed_conducted, ahkam_conducted, akhlaq_conducted, other_conducted, arabic_topic, aqaed_topic, ahkam_topic, created_by, created_at) VALUES
  (947101, 9471, 900801, DATE '2025-09-06', 1, NULL, 45, 2, 2, 5, '1', 'Y', 'N', 'N', 'N', 'Arabic Seed', 'Aqaed Old', NULL, 900801, now() - interval '30 days'),
  (947102, 9471, 900801, DATE '2025-09-13', 0, 'Seed unwell', NULL, NULL, NULL, NULL, 'N', 'N', 'N', 'N', 'N', NULL, NULL, NULL, 900801, now() - interval '1 day'),
  (947103, 9471, 900801, DATE '2025-09-20', 1, NULL, 30, 3, NULL, NULL, 'N', '1', 'Y', 'N', 'N', NULL, '  Aqaed Newest  ', 'Ahkam Newest', 900802, now() - interval '2 days'),
  (947401, 9474, 900801, DATE '2025-10-13', 1, NULL, 20, 1, NULL, NULL, 'N', '1', 'N', 'N', 'N', NULL, 'Week Seed', NULL, 900801, now() - interval '1 day'),
  (947402, 9474, 900801, DATE '2099-01-05', 1, NULL, 20, 1, NULL, NULL, 'N', '1', 'N', 'N', 'N', NULL, 'Future Seed', NULL, 900801, now() - interval '1 day'),
  (947501, 9475, 900804, DATE '2025-11-03', 1, NULL, 40, 1, NULL, NULL, 'N', '1', 'N', 'N', 'N', NULL, 'Put Seed', NULL, 900804, now() - interval '1 day'),
  (947502, 9475, 900804, DATE '2025-11-04', 0, 'Put seed reason', NULL, NULL, NULL, NULL, 'N', 'N', 'N', 'N', 'N', NULL, NULL, NULL, 900804, now() - interval '1 day'),
  (947503, 9475, 900804, DATE '2025-11-05', 1, NULL, 40, 1, NULL, NULL, 'N', '1', 'N', 'N', 'N', NULL, 'Old Seed', NULL, 900804, now() - interval '30 days');
INSERT INTO classes.class_attendance (id, session_id, token, name, extra_student, present, recitation) VALUES
  (947101, 947101, 900811, NULL, 0, 1, 3), (947102, 947101, 900812, NULL, 0, 1, 0),
  (947103, 947103, 900811, NULL, 0, 1, 5), (947104, 947103, 900812, NULL, 0, 0, 0), (947105, 947103, 1, 'Extra One', 1, 1, 0), (947106, 947103, 900813, NULL, 0, 1, 2),
  (947501, 947501, 900831, NULL, 0, 1, 2), (947502, 947501, 900832, NULL, 0, 0, 0);

SELECT setval(pg_get_serial_sequence('classes.class_sessions', 'id'), greatest((SELECT max(id) FROM classes.class_sessions), 1));
SELECT setval(pg_get_serial_sequence('classes.class_attendance', 'id'), greatest((SELECT max(id) FROM classes.class_attendance), 1));
SELECT setval(pg_get_serial_sequence('classes.class_students', 'id'), greatest((SELECT max(id) FROM classes.class_students), 9499));
SELECT setval(pg_get_serial_sequence('classes.class_schedules', 'id'), greatest((SELECT max(id) FROM classes.class_schedules), 9499));
SELECT setval(pg_get_serial_sequence('classes.classes', 'id'), greatest((SELECT max(id) FROM classes.classes), 1));
