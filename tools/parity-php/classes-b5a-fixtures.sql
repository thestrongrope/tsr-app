/*
 * The classes REPORT fixtures for the PHP parity stack's MariaDB: the same members, classes, sessions and attendance as db/synthetic/classes-b5a-fixtures.sql (read that header). Loaded last by tools/classes-contract.sh
 * before every run; resets every row it owns. The coordinator 901401 is assigned the classes 9581 and 9582 through class_access rows (the new API gets the same reach from a rule).
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, CONCAT('rp.', v.token, '@example.invalid'), 0, 'firebase', NOW(), CONCAT('Rp Member ', v.token), IF(v.token IN (901412, 901425), '2', '1'), CONCAT('+91000014', RIGHT(v.token, 4)) FROM (
  SELECT 901401 AS token UNION ALL SELECT 901411 UNION ALL SELECT 901412 UNION ALL SELECT 901413 UNION ALL SELECT 901421 UNION ALL SELECT 901422 UNION ALL SELECT 901423 UNION ALL SELECT 901424 UNION ALL SELECT 901425) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users SET email = CONCAT('rp.', token, '@example.invalid'), name = CONCAT('Rp Member ', token), gender = IF(token IN (901412, 901425), '2', '1'), roleid = IF(token = 901401, 5, 0), mobile = CONCAT('+91000014', RIGHT(token, 4))
WHERE token BETWEEN 901401 AND 901499;

DELETE FROM class_access WHERE token = 901401;
DELETE FROM class_attendance WHERE session_id IN (SELECT id FROM class_sessions WHERE class_id BETWEEN 9581 AND 9589);
DELETE FROM class_sessions WHERE class_id BETWEEN 9581 AND 9589;
DELETE FROM class_schedules WHERE class_id BETWEEN 9581 AND 9589;
DELETE FROM class_students WHERE class_id BETWEEN 9581 AND 9589;
DELETE FROM classes WHERE id BETWEEN 9581 AND 9589;

INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by, extra_students) VALUES
  (9581, 'RP-G-581', 1, 'rplnk9581', 'Rp Main Class', 3, '2025-01-06', 901411, 1, 'Offline', 'Reportville', 'India', 'Rp Hall', 'A', 900315, CONCAT('Extra A', CHAR(10), 'Extra B')),
  (9582, 'RP-G-582', 1, 'rplnk9582', 'Rp Second Class', 2, '2025-01-06', 901413, 1, 'Offline', 'Reportville', 'India', 'Rp Hall', 'A', 900315, NULL),
  (9583, 'RP-L-583', 1, 'rplnk9583', 'Rp Ladies Class', 3, '2025-01-06', 901412, 2, 'Offline', 'Reportville', 'India', 'Rp Hall', 'A', 900315, NULL),
  (9584, 'RP-G-584', 1, 'rplnk9584', 'Rp Elsewhere Class', 3, '2025-01-06', 901411, 1, 'Offline', 'Elsewhere', 'India', 'Rp Hall', 'A', 900315, NULL),
  (9585, 'RP-G-585', 1, 'rplnk9585', 'Rp Closed Class', 3, '2025-01-06', 901411, 1, 'Offline', 'Reportville', 'India', 'Rp Hall', 'I', 900315, NULL);
INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by, extra_students)
SELECT 9586, 'AYD1', 1, 'rplnk9586', 'Rp Demo Class', 3, '2025-01-06', 901411, 1, 'Offline', 'Reportville', 'India', 'Rp Hall', 'A', 900315, NULL
FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM classes WHERE code = 'AYD1');
-- classes_before_create replaces the link of every inserted class with a random string; an UPDATE keeps ours.
UPDATE classes SET link = CONCAT('rplnk', id) WHERE id BETWEEN 9581 AND 9589;

INSERT INTO class_access (class_id, token) VALUES (9581, 901401), (9582, 901401);

INSERT INTO class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) VALUES
  (958101, 9581, 2, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (958102, 9581, 5, 19, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (958103, 9581, 7, 11, 0, 'Asia/Kolkata', 900315, '2025-10-01 00:00:00', 900315),
  (958104, 9582, 3, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (958105, 9583, 4, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (958106, 9584, 2, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (958107, 9585, 2, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL);
INSERT INTO class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by)
SELECT 958108, 9586, 2, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL FROM DUAL WHERE EXISTS (SELECT 1 FROM classes WHERE id = 9586);

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (958101, 9581, 901421, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (958102, 9581, 901422, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (958103, 9581, 901423, '2025-01-06', 0, '2025-10-01 00:00:00', 'Rp left', 900315, 'I'),
  (958104, 9582, 901424, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (958105, 9583, 901425, '2025-01-06', 0, NULL, NULL, NULL, 'A');
UPDATE class_students SET created_at = CONCAT(joined_on, ' 08:00:00') WHERE class_id BETWEEN 9581 AND 9589;

INSERT INTO class_sessions (id, class_id, teacher, conducted_on, conducted, non_conduction_reason, duration, attendance, quran_recitation_surah, quran_recitation_verse,
                            arabic_conducted, aqaed_conducted, ahkam_conducted, akhlaq_conducted, other_conducted, arabic_topic, aqaed_topic, ahkam_topic, created_by, created_at) VALUES
  (958101, 9581, 901411, '2025-11-03', 0, 'Rp rain', NULL, NULL, NULL, NULL, 'N', 'N', 'N', 'N', 'N', NULL, NULL, NULL, 901411, '2025-11-03 12:00:00'),
  (958102, 9581, 901411, '2025-11-10', 1, NULL, 45, 2, 2, 5, '1', 'Y', 'N', 'N', 'N', 'Alif', NULL, NULL, 901411, '2025-11-10 12:00:00'),
  (958103, 9581, 901411, '2025-11-13', 1, NULL, 30, 1, NULL, NULL, 'N', 'Y', '1', 'N', 'N', 'Hidden', 'Tawhid', 'Wudu', 901411, '2025-11-13 12:00:00'),
  (958104, 9581, 901411, '2025-11-17', 1, NULL, 60, 3, 3, NULL, 'Y', 'N', 'N', 'N', 'N', 'Alif', NULL, NULL, 901411, '2025-11-17 12:00:00'),
  (958105, 9581, 901411, '2025-11-24', 1, NULL, 40, 0, NULL, NULL, 'N', 'N', 'N', 'N', '1', NULL, NULL, NULL, 901411, '2025-11-24 12:00:00'),
  (958106, 9581, 901411, '2025-11-27', 0, '=Rp formula', NULL, NULL, 2, 0, 'N', 'N', 'N', 'N', 'N', NULL, NULL, NULL, 901411, '2025-11-27 12:00:00'),
  (958201, 9582, 901413, '2025-11-11', 1, NULL, 50, 1, NULL, NULL, 'N', 'Y', 'N', 'N', 'N', NULL, 'Aqaed Two', NULL, 901413, '2025-11-11 12:00:00'),
  (958301, 9583, 901412, '2025-11-12', 1, NULL, 20, 1, NULL, NULL, 'N', 'N', 'N', 'N', 'N', NULL, NULL, NULL, 901412, '2025-11-12 12:00:00'),
  (958401, 9584, 901411, '2025-11-10', 1, NULL, 25, 1, NULL, NULL, 'N', 'N', 'N', 'N', 'N', NULL, NULL, NULL, 901411, '2025-11-10 12:00:00'),
  (958501, 9585, 901411, '2025-11-10', 1, NULL, 25, 1, NULL, NULL, 'N', 'N', 'N', 'N', 'N', NULL, NULL, NULL, 901411, '2025-11-10 12:00:00');
INSERT INTO class_sessions (id, class_id, teacher, conducted_on, conducted, non_conduction_reason, duration, attendance, quran_recitation_surah, quran_recitation_verse,
                            arabic_conducted, aqaed_conducted, ahkam_conducted, akhlaq_conducted, other_conducted, arabic_topic, aqaed_topic, ahkam_topic, created_by, created_at)
SELECT 958601, 9586, 901411, '2025-11-10', 1, NULL, 25, 1, NULL, NULL, 'N', 'N', 'N', 'N', 'N', NULL, NULL, NULL, 901411, '2025-11-10 12:00:00' FROM DUAL WHERE EXISTS (SELECT 1 FROM classes WHERE id = 9586);

INSERT INTO class_attendance (id, session_id, token, name, extra_student, present, recitation) VALUES
  (958101, 958102, 901421, NULL, 0, 1, 3), (958102, 958102, 901422, NULL, 0, 1, 0),
  (958103, 958103, 901421, NULL, 0, 1, 0), (958104, 958103, 901422, NULL, 0, 0, 0),
  (958105, 958104, 901421, NULL, 0, 1, 1), (958106, 958104, 901422, NULL, 0, 1, 0), (958107, 958104, 1, 'Extra A', 1, 1, 0),
  (958201, 958201, 901424, NULL, 0, 1, 0);
