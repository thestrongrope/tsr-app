/*
 * The classes REPORT fixtures of batch B5b for the PHP parity stack's MariaDB: the same members, classes, sessions and attendance as db/synthetic/classes-b5b-fixtures.sql (read that header). Loaded last by
 * tools/classes-contract.sh before every run; resets every row it owns. The coordinator 901501 is assigned the classes 9591 to 9594 through class_access rows (the new API gets the same reach from a rule).
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, CONCAT('rb.', v.token, '@example.invalid'), 0, 'firebase', NOW(), CONCAT('Rb Member ', v.token), IF(v.token IN (901513, 901514), '2', '1'), CONCAT('+91000015', RIGHT(v.token, 4)) FROM (
  SELECT 901501 AS token UNION ALL SELECT 901511 UNION ALL SELECT 901512 UNION ALL SELECT 901513 UNION ALL SELECT 901514 UNION ALL SELECT 901521 UNION ALL SELECT 901522 UNION ALL SELECT 901523 UNION ALL SELECT 901524) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users SET email = CONCAT('rb.', token, '@example.invalid'), name = CONCAT('Rb Member ', token), gender = IF(token IN (901513, 901514), '2', '1'), roleid = IF(token = 901501, 5, 0), mobile = CONCAT('+91000015', RIGHT(token, 4))
WHERE token BETWEEN 901501 AND 901599;

DELETE FROM class_access WHERE token = 901501;
DELETE FROM class_attendance WHERE session_id IN (SELECT id FROM class_sessions WHERE class_id BETWEEN 9591 AND 9599);
DELETE FROM class_sessions WHERE class_id BETWEEN 9591 AND 9599;
DELETE FROM class_schedules WHERE class_id BETWEEN 9591 AND 9599;
DELETE FROM class_students WHERE class_id BETWEEN 9591 AND 9599;
DELETE FROM classes WHERE id BETWEEN 9591 AND 9599;

INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (9591, 'RB-G-591', 1, 'rblnk9591', 'Rb Class One', 3, '2025-01-06', 901511, 1, 'Offline', 'B5bville', 'India', 'Rb Hall', 'A', 900315),
  (9592, 'RB-G-592', 1, 'rblnk9592', 'Rb Class Two', 2, '2025-01-06', 901511, 1, 'Offline', 'B5bville', 'India', 'Rb Hall', 'A', 900315),
  (9593, 'RB-G-593', 1, 'rblnk9593', 'Rb Class Three', 1, '2025-01-06', 901512, 1, 'Offline', 'B5bville', 'India', 'Rb Hall', 'A', 900315),
  (9594, 'RB-G-594', 1, 'rblnk9594', 'Rb Class Four', 3, '2025-01-06', 901513, 1, 'Offline', 'B5bville', 'India', 'Rb Hall', 'A', 900315),
  (9595, 'RB-L-595', 1, 'rblnk9595', 'Rb Ladies Class', 3, '2025-01-06', 901514, 2, 'Offline', 'B5bville', 'India', 'Rb Hall', 'A', 900315),
  (9596, 'RB-G-596', 1, 'rblnk9596', 'Rb Closed Class', 3, '2025-01-06', 901512, 1, 'Offline', 'B5bville', 'India', 'Rb Hall', 'I', 900315);
-- classes_before_create replaces the link of every inserted class with a random string; an UPDATE keeps ours.
UPDATE classes SET link = CONCAT('rblnk', id) WHERE id BETWEEN 9591 AND 9599;

INSERT INTO class_access (class_id, token) VALUES (9591, 901501), (9592, 901501), (9593, 901501), (9594, 901501);

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (959101, 9593, 901511, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (959102, 9594, 901511, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (959103, 9592, 901511, '2025-01-06', 0, '2025-10-01 00:00:00', 'Rb left', 900315, 'I'),
  (959104, 9596, 901512, '2025-01-06', 0, NULL, NULL, NULL, 'A');
UPDATE class_students SET created_at = CONCAT(joined_on, ' 08:00:00') WHERE class_id BETWEEN 9591 AND 9599;

/* THIS WEEK: the same sessions as db/synthetic/classes-b5b-fixtures.sql (read the comment there), dates relative to the load time. */
INSERT INTO class_sessions (id, class_id, teacher, conducted_on, conducted, non_conduction_reason, duration, attendance, arabic_conducted, aqaed_conducted, ahkam_conducted, akhlaq_conducted, other_conducted,
                            aqaed_topic, ahkam_topic, akhlaq_topic, created_by, created_at)
SELECT 959200 + (v.cls - 9591) * 20 + v.w * 2 + v.n, v.cls, c.teacher, DATE_ADD(lw.d, INTERVAL (2 + 2 * v.n - 7 * v.w) DAY),
       CASE WHEN v.cls = 9592 AND v.w <= 1 THEN 0 ELSE 1 END, CASE WHEN v.cls = 9592 AND v.w <= 1 THEN 'B5b rain' END, 45, NULL,
       CASE WHEN v.cls = 9591 AND v.w <= 1 THEN 'N' ELSE 'Y' END, 'Y', 'Y', 'Y', 'N',
       CASE WHEN v.cls = 9591 AND v.w = 0 AND v.n = 0 THEN 'B5b Tawhid' WHEN v.cls = 9591 AND v.w = 0 AND v.n = 1 THEN 'B5b Tawhid Two' END,
       CASE WHEN v.cls = 9591 AND v.w = 0 AND v.n = 0 THEN 'B5b Wudu' END,
       CASE WHEN v.cls = 9591 AND v.w = 0 AND v.n = 1 THEN 'B5b Honesty' END,
       c.teacher, NOW()
FROM (SELECT DATE_SUB(DATE_SUB(CURDATE(), INTERVAL 7 DAY), INTERVAL (DAYOFWEEK(DATE_SUB(CURDATE(), INTERVAL 7 DAY)) - 1) DAY) AS d) lw
CROSS JOIN (
  SELECT 9591 AS cls, w.w, 0 AS n FROM (SELECT 0 AS w UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8) w
  UNION ALL SELECT 9591, 0, 1
  UNION ALL SELECT 9592, w.w, 0 FROM (SELECT 0 AS w UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8) w
  UNION ALL SELECT 9593, w.w, 0 FROM (SELECT 3 AS w UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8) w
  UNION ALL SELECT 9594, w.w, 0 FROM (SELECT 0 AS w UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8) w
  UNION ALL SELECT 9595, 0, 0
  UNION ALL SELECT 9596, 0, 0
) v
JOIN classes c ON c.id = v.cls;

INSERT INTO class_attendance (id, session_id, token, name, extra_student, present, recitation) VALUES
  (959301, 959200, 901521, NULL, 0, 1, 0), (959302, 959200, 901522, NULL, 0, 1, 0),
  (959303, 959260, 901521, NULL, 0, 1, 0), (959304, 959260, 901522, NULL, 0, 0, 0), (959305, 959260, 901523, NULL, 0, 0, 0);
