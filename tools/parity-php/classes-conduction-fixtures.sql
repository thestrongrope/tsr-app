/*
 * The classes CONDUCTION fixtures for the PHP parity stack's MariaDB: the same members, classes, sessions and attendance as db/synthetic/classes-conduction-fixtures.sql (read that header). Loaded by
 * tools/classes-contract.sh after the other fixtures, before every run; resets every row it owns, including the sessions and attendance a run created.
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, CONCAT('cd.', v.token, '@example.invalid'), 0, 'firebase', NOW(), CONCAT('Cd Member ', v.token), IF(v.token IN (900803, 900825), '2', '1'), CONCAT('+91000008', RIGHT(v.token, 4)) FROM (
  SELECT 900801 AS token UNION ALL SELECT 900802 UNION ALL SELECT 900803 UNION ALL SELECT 900804 UNION ALL SELECT 900811 UNION ALL SELECT 900812 UNION ALL SELECT 900813 UNION ALL SELECT 900821
  UNION ALL SELECT 900822 UNION ALL SELECT 900823 UNION ALL SELECT 900825 UNION ALL SELECT 900826 UNION ALL SELECT 900831 UNION ALL SELECT 900832 UNION ALL SELECT 900841) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users SET email = CONCAT('cd.', token, '@example.invalid'), name = CONCAT('Cd Member ', token), gender = IF(token IN (900803, 900825), '2', '1'), roleid = 0, mobile = CONCAT('+91000008', RIGHT(token, 4))
WHERE token BETWEEN 900801 AND 900849;

DELETE FROM class_attendance WHERE session_id IN (SELECT id FROM class_sessions WHERE class_id BETWEEN 9471 AND 9489);
DELETE FROM class_sessions WHERE class_id BETWEEN 9471 AND 9489;
DELETE FROM class_schedules WHERE class_id BETWEEN 9471 AND 9489;
DELETE FROM class_students WHERE class_id BETWEEN 9471 AND 9489;
DELETE FROM classes WHERE id BETWEEN 9471 AND 9489;

INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by, extra_students) VALUES
  (9471, 'CD-G-071', 1, 'cdlnk9471', 'Cd Read Class', 3, '2025-09-01', 900801, 1, 'Offline', 'Mumbai', 'India', 'Cd Hall', 'A', 900315, CONCAT('Extra One, +910000008001', CHAR(10), CHAR(10), 'Extra Two', CHAR(13), CHAR(10))),
  (9472, 'CD-G-072', 1, 'cdlnk9472', 'Cd Post Class', 3, '2025-09-01', 900802, 1, 'Offline', 'Mumbai', 'India', 'Cd Hall', 'A', 900315, CONCAT('Seed Extra, +910000008002', CHAR(10), 'Second Extra')),
  (9473, 'CD-L-073', 1, 'cdlnk9473', 'Cd Ladies Class', 3, '2025-09-01', 900803, 2, 'Offline', 'Mumbai', 'India', 'Cd Hall', 'A', 900315, NULL),
  (9474, 'CD-G-074', 1, 'cdlnk9474', 'Cd Week Class', 3, '2025-09-01', 900801, 1, 'Offline', 'Mumbai', 'India', 'Cd Hall', 'A', 900315, NULL),
  (9475, 'CD-G-075', 1, 'cdlnk9475', 'Cd Put Class', 3, '2025-09-01', 900804, 1, 'Offline', 'Mumbai', 'India', 'Cd Hall', 'A', 900315, 'Put Extra'),
  (9476, 'CD-G-076', 1, 'cdlnk9476', 'Cd Empty Class', 3, '2025-10-01', 900801, 1, 'Offline', 'Mumbai', 'India', 'Cd Hall', 'A', 900315, NULL),
  (9478, 'CD-G-078', 1, 'cdlnk9478', 'Cd Limits Class', 3, '2025-09-01', 900801, 1, 'Offline', 'Mumbai', 'India', 'Cd Hall', 'A', 900315, NULL);
-- classes_before_create replaces the link of every inserted class with a random string; an UPDATE keeps ours.
UPDATE classes SET link = CONCAT('cdlnk', id) WHERE id BETWEEN 9471 AND 9489;

INSERT INTO class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) VALUES
  (9471, 9471, 2, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (9472, 9471, 5, 19, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (9473, 9471, 7, 11, 0, 'Asia/Kolkata', 900315, '2025-10-01 00:00:00', 900315),
  (9474, 9474, 1, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL);

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9471, 9471, 900811, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9472, 9471, 900812, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9473, 9471, 900813, '2025-09-01', 0, '2025-10-01 00:00:00', 'Cd left', 900315, 'I'),
  (9474, 9472, 900821, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9475, 9472, 900822, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9476, 9472, 900823, '2025-09-01', 0, '2025-10-01 00:00:00', 'Cd left', 900315, 'I'),
  (9477, 9473, 900825, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9478, 9475, 900831, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9479, 9475, 900832, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9480, 9478, 900841, '2025-09-01', 0, NULL, NULL, NULL, 'A');
UPDATE class_students SET created_at = CONCAT(joined_on, ' 08:00:00') WHERE class_id BETWEEN 9471 AND 9489;

INSERT INTO class_sessions (id, class_id, teacher, conducted_on, conducted, non_conduction_reason, duration, attendance, quran_recitation_surah, quran_recitation_verse,
                            arabic_conducted, aqaed_conducted, ahkam_conducted, akhlaq_conducted, other_conducted, arabic_topic, aqaed_topic, ahkam_topic, created_by, created_at) VALUES
  (947101, 9471, 900801, '2025-09-06', 1, NULL, 45, 2, 2, 5, '1', 'Y', 'N', 'N', 'N', 'Arabic Seed', 'Aqaed Old', NULL, 900801, NOW() - INTERVAL 30 DAY),
  (947102, 9471, 900801, '2025-09-13', 0, 'Seed unwell', NULL, NULL, NULL, NULL, 'N', 'N', 'N', 'N', 'N', NULL, NULL, NULL, 900801, NOW() - INTERVAL 1 DAY),
  (947103, 9471, 900801, '2025-09-20', 1, NULL, 30, 3, NULL, NULL, 'N', '1', 'Y', 'N', 'N', NULL, '  Aqaed Newest  ', 'Ahkam Newest', 900802, NOW() - INTERVAL 2 DAY),
  (947401, 9474, 900801, '2025-10-13', 1, NULL, 20, 1, NULL, NULL, 'N', '1', 'N', 'N', 'N', NULL, 'Week Seed', NULL, 900801, NOW() - INTERVAL 1 DAY),
  (947402, 9474, 900801, '2099-01-05', 1, NULL, 20, 1, NULL, NULL, 'N', '1', 'N', 'N', 'N', NULL, 'Future Seed', NULL, 900801, NOW() - INTERVAL 1 DAY),
  (947501, 9475, 900804, '2025-11-03', 1, NULL, 40, 1, NULL, NULL, 'N', '1', 'N', 'N', 'N', NULL, 'Put Seed', NULL, 900804, NOW() - INTERVAL 1 DAY),
  (947502, 9475, 900804, '2025-11-04', 0, 'Put seed reason', NULL, NULL, NULL, NULL, 'N', 'N', 'N', 'N', 'N', NULL, NULL, NULL, 900804, NOW() - INTERVAL 1 DAY),
  (947503, 9475, 900804, '2025-11-05', 1, NULL, 40, 1, NULL, NULL, 'N', '1', 'N', 'N', 'N', NULL, 'Old Seed', NULL, 900804, NOW() - INTERVAL 30 DAY);
INSERT INTO class_attendance (id, session_id, token, name, extra_student, present, recitation) VALUES
  (947101, 947101, 900811, NULL, 0, 1, 3), (947102, 947101, 900812, NULL, 0, 1, 0),
  (947103, 947103, 900811, NULL, 0, 1, 5), (947104, 947103, 900812, NULL, 0, 0, 0), (947105, 947103, 1, 'Extra One', 1, 1, 0), (947106, 947103, 900813, NULL, 0, 1, 2),
  (947501, 947501, 900831, NULL, 0, 1, 2), (947502, 947501, 900832, NULL, 0, 0, 0);
