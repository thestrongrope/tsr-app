/*
 * The classes REPORT fixtures of batch B5b (active teachers, students, this week, pending, tsr, students report) for the new API's database. tools/parity-php/classes-b5b-fixtures.sql holds the same rows for the PHP parity
 * stack. Loaded last by tools/classes-contract.sh before every run; resets every row it owns by token and id. Read-only for the files (reports write nothing). Synthetic only: tokens 901501 to 901599, emails
 * rb.<token>@example.invalid, classes 9591 to 9599. Dates are relative to the load time where a report asks about "now" (today minus n days), and fixed (November 2025) where the file passes explicit ranges.
 * Callers from earlier fixtures: "admin" (role 1), 900501 (gents admin) and 900502 (ladies admin).
 *
 *   901501 a class coordinator (role 5) reaching the gents classes 9591 to 9594 (new API: a rule for gents classes in the city "B5bville"; PHP: class_access rows): its answers are compared in full
 *   901511 teacher (gents) of 9591 (MIQDAD) and 9592 (ABUZAR); attends 9593 and 9594 as a student   901512 teacher (gents) of 9593 (SALMAN)   901513 teacher (LADIES member) of the gents class 9594 (MIQDAD)
 *   901514 teacher (ladies) of the ladies class 9595 (MIQDAD)   901521 to 901524 students
 *   9591, 9592, 9593, 9594 gents, B5bville, active   9595 ladies, B5bville   9596 gents, closed, B5bville
 */
INSERT INTO identity.users (token, email)
SELECT v.token, 'rb.' || v.token || '@example.invalid' FROM (VALUES
  (901501), (901511), (901512), (901513), (901514), (901521), (901522), (901523), (901524)
) AS v (token)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

UPDATE identity.users u SET email = 'rb.' || u.token || '@example.invalid' WHERE u.token BETWEEN 901501 AND 901599 AND u.email <> 'rb.' || u.token || '@example.invalid';

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id, 'Rb Member ' || v.token, CASE WHEN v.token IN (901513, 901514) THEN '2' ELSE '1' END, '+91000015' || right(v.token::text, 4) FROM (VALUES
  (901501), (901511), (901512), (901513), (901514), (901521), (901522), (901523), (901524)
) AS v (token)
JOIN identity.users u ON u.token = v.token
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token = 901501);
INSERT INTO access.user_roles (user_id, roleid) SELECT id, 5 FROM identity.users WHERE token = 901501;

DELETE FROM access.class_access_rule_conditions WHERE rule_id = 959101;
DELETE FROM access.class_access_rules WHERE id = 959101;
INSERT INTO access.class_access_rules (id, token, gender, note, created_at) VALUES (959101, 901501, 1, 'Rb gents classes of B5bville', now());
INSERT INTO access.class_access_rule_conditions (rule_id, field, negate, value) VALUES (959101, 'city', false, 'B5bville');

DELETE FROM classes.class_attendance WHERE session_id IN (SELECT id FROM classes.class_sessions WHERE class_id BETWEEN 9591 AND 9599);
DELETE FROM classes.class_sessions WHERE class_id BETWEEN 9591 AND 9599;
DELETE FROM classes.class_schedules WHERE class_id BETWEEN 9591 AND 9599;
DELETE FROM classes.class_students WHERE class_id BETWEEN 9591 AND 9599;
DELETE FROM classes.classes WHERE id BETWEEN 9591 AND 9599;

INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (9591, 'RB-G-591', 1, 'rblnk9591', 'Rb Class One', 3, DATE '2025-01-06', 901511, 1, 'Offline', 'B5bville', 'India', 'Rb Hall', 'A', 900315),
  (9592, 'RB-G-592', 1, 'rblnk9592', 'Rb Class Two', 2, DATE '2025-01-06', 901511, 1, 'Offline', 'B5bville', 'India', 'Rb Hall', 'A', 900315),
  (9593, 'RB-G-593', 1, 'rblnk9593', 'Rb Class Three', 1, DATE '2025-01-06', 901512, 1, 'Offline', 'B5bville', 'India', 'Rb Hall', 'A', 900315),
  (9594, 'RB-G-594', 1, 'rblnk9594', 'Rb Class Four', 3, DATE '2025-01-06', 901513, 1, 'Offline', 'B5bville', 'India', 'Rb Hall', 'A', 900315),
  (9595, 'RB-L-595', 1, 'rblnk9595', 'Rb Ladies Class', 3, DATE '2025-01-06', 901514, 2, 'Offline', 'B5bville', 'India', 'Rb Hall', 'A', 900315),
  (9596, 'RB-G-596', 1, 'rblnk9596', 'Rb Closed Class', 3, DATE '2025-01-06', 901512, 1, 'Offline', 'B5bville', 'India', 'Rb Hall', 'I', 900315);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (959101, 9593, 901511, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (959102, 9594, 901511, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (959103, 9592, 901511, DATE '2025-01-06', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'Rb left', 900315, 'I'),
  (959104, 9596, 901512, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A');
UPDATE classes.class_students SET created_at = joined_on + TIME '08:00' AT TIME ZONE 'UTC' WHERE class_id BETWEEN 9591 AND 9599;

SELECT setval(pg_get_serial_sequence('classes.class_students', 'id'), greatest((SELECT max(id) FROM classes.class_students), 959199));
SELECT setval(pg_get_serial_sequence('classes.classes', 'id'), greatest((SELECT max(id) FROM classes.classes), 1));

/*
 * THIS WEEK (sessions relative to the load time: W0 is the week before this one, W1 the one before it, and so on to W8; the Sunday of W0 is lw)
 *   9591 held every week; arabic left out in W1 and W0 (a quiet subject, 2 weeks); W0 has two held sessions (cell "Yes (2)"; topics Tawhid and Tawhid Two for aqaed, Honesty for akhlaq); attendance 2 of 2 in W0
 *   9592 held W8 to W2, NOT held in W1 and W0 (reason "B5b rain": a streak of 2, a message)
 *   9593 held W8 to W3, no form in W2 to W0 (the newest cell is NF)
 *   9594 held every week, all four subjects; attendance 1 of 3 in W0 (low)   9595 (ladies) held W0   9596 (closed) held W0
 */
INSERT INTO classes.class_sessions (id, class_id, teacher, conducted_on, conducted, non_conduction_reason, duration, attendance, arabic_conducted, aqaed_conducted, ahkam_conducted, akhlaq_conducted, other_conducted,
                                    aqaed_topic, ahkam_topic, akhlaq_topic, created_by, created_at)
SELECT 959200 + (v.cls - 9591) * 20 + v.w * 2 + v.n, v.cls, c.teacher, lw.d - 7 * v.w + 2 + 2 * v.n,
       CASE WHEN v.cls = 9592 AND v.w <= 1 THEN 0 ELSE 1 END, CASE WHEN v.cls = 9592 AND v.w <= 1 THEN 'B5b rain' END, 45, NULL,
       CASE WHEN v.cls = 9591 AND v.w <= 1 THEN 'N' ELSE 'Y' END, 'Y', 'Y', 'Y', 'N',
       CASE WHEN v.cls = 9591 AND v.w = 0 AND v.n = 0 THEN 'B5b Tawhid' WHEN v.cls = 9591 AND v.w = 0 AND v.n = 1 THEN 'B5b Tawhid Two' END,
       CASE WHEN v.cls = 9591 AND v.w = 0 AND v.n = 0 THEN 'B5b Wudu' END,
       CASE WHEN v.cls = 9591 AND v.w = 0 AND v.n = 1 THEN 'B5b Honesty' END,
       c.teacher, now()
FROM (SELECT (current_date - 7) - extract(dow FROM (current_date - 7))::int AS d) lw
CROSS JOIN (
  SELECT 9591 AS cls, w, 0 AS n FROM generate_series(0, 8) w
  UNION ALL SELECT 9591, 0, 1
  UNION ALL SELECT 9592, w, 0 FROM generate_series(0, 8) w
  UNION ALL SELECT 9593, w, 0 FROM generate_series(3, 8) w
  UNION ALL SELECT 9594, w, 0 FROM generate_series(0, 8) w
  UNION ALL SELECT 9595, 0, 0
  UNION ALL SELECT 9596, 0, 0
) v
JOIN classes.classes c ON c.id = v.cls;

INSERT INTO classes.class_attendance (id, session_id, token, name, extra_student, present, recitation) VALUES
  (959301, 959200, 901521, NULL, 0, 1, 0), (959302, 959200, 901522, NULL, 0, 1, 0),
  (959303, 959260, 901521, NULL, 0, 1, 0), (959304, 959260, 901522, NULL, 0, 0, 0), (959305, 959260, 901523, NULL, 0, 0, 0);
SELECT setval(pg_get_serial_sequence('classes.class_sessions', 'id'), greatest((SELECT max(id) FROM classes.class_sessions), 1));
SELECT setval(pg_get_serial_sequence('classes.class_attendance', 'id'), greatest((SELECT max(id) FROM classes.class_attendance), 1));
