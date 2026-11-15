/*
 * The classes REPORT fixtures of batch B5c for the PHP parity stack's MariaDB: the same members, classes, sessions, attendance, quizzes and standard MCQs as db/synthetic/classes-b5c-fixtures.sql (read the header there).
 * Loaded last by tools/classes-contract.sh before every run; resets every row it owns. The coordinator 901901 is assigned the classes 9564, 9565 and 9567 through class_access rows (the new API gets the same reach from two rules).
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, CONCAT('rc.', v.token, '@example.invalid'), 0, 'firebase', NOW(), CONCAT('Rc Member ', v.token), IF(v.token IN (901913, 901925), '2', '1'), CONCAT('+91000019', RIGHT(v.token, 4)) FROM (
  SELECT 901901 AS token UNION ALL SELECT 901911 UNION ALL SELECT 901912 UNION ALL SELECT 901913 UNION ALL SELECT 901921 UNION ALL SELECT 901922 UNION ALL SELECT 901923 UNION ALL SELECT 901924
  UNION ALL SELECT 901925 UNION ALL SELECT 901926 UNION ALL SELECT 901927 UNION ALL SELECT 901928) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users SET email = CONCAT('rc.', token, '@example.invalid'), name = CONCAT('Rc Member ', token), gender = IF(token IN (901913, 901925), '2', '1'), roleid = IF(token = 901901, 5, 0), mobile = CONCAT('+91000019', RIGHT(token, 4))
WHERE token BETWEEN 901901 AND 901999;

DELETE FROM class_access WHERE token = 901901;
INSERT INTO class_access (class_id, token) VALUES (9564, 901901), (9565, 901901), (9567, 901901);

DELETE FROM spot_quiz_responses WHERE spot_quiz_id BETWEEN 961401 AND 961499;
DELETE FROM spot_quiz_questions WHERE spot_quiz_id BETWEEN 961401 AND 961499;
DELETE FROM spot_quizzes WHERE id BETWEEN 961401 AND 961499;
DELETE FROM standard_mcqs WHERE id BETWEEN 961701 AND 961799;
DELETE FROM class_attendance WHERE session_id IN (SELECT id FROM class_sessions WHERE class_id BETWEEN 9564 AND 9568);
DELETE FROM class_sessions WHERE class_id BETWEEN 9564 AND 9568;
DELETE FROM class_schedules WHERE class_id BETWEEN 9564 AND 9568;
DELETE FROM class_students WHERE class_id BETWEEN 9564 AND 9568;
DELETE FROM classes WHERE id BETWEEN 9564 AND 9568;

INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (9564, 'RC-G-564', 9, 'rclnk9564', 'Rc Class One', 3, '2025-01-06', 901911, 1, 'Offline', 'B5cville', 'India', 'Rc Hall', 'A', 900315),
  (9565, 'RC-G-565', 9, 'rclnk9565', 'Rc Class Two', 2, '2025-01-06', 901911, 1, 'Offline', 'B5cville', 'India', 'Rc Hall', 'A', 900315),
  (9566, 'RC-G-566', 9, 'rclnk9566', 'Rc Class Three', 1, '2025-01-06', 901912, 1, 'Offline', 'B5celsewhere', 'India', 'Rc Hall', 'A', 900315),
  (9567, 'RC-L-567', 9, 'rclnk9567', 'Rc Ladies Class', 3, '2025-01-06', 901913, 2, 'Offline', 'B5cville', 'India', 'Rc Hall', 'A', 900315),
  (9568, 'RC-G-568', 9, 'rclnk9568', 'Rc Closed Class', 3, '2025-01-06', 901912, 1, 'Offline', 'B5cville', 'India', 'Rc Hall', 'I', 900315);

INSERT INTO class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) VALUES
  (961001, 9564, 2, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL), (961002, 9564, 5, 19, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (961003, 9565, 3, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL), (961004, 9566, 4, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (961005, 9567, 4, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL), (961006, 9568, 2, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL);

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (961101, 9564, 901921, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (961102, 9564, 901922, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (961103, 9564, 901923, '2025-01-06', 0, '2025-10-15 00:00:00', 'Rc left', 900315, 'I'),
  (961104, 9564, 901924, '2025-01-06', 0, NULL, NULL, NULL, 'I'),
  (961105, 9565, 901922, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (961106, 9566, 901928, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (961107, 9567, 901925, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (961108, 9567, 901926, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (961109, 9568, 901927, '2025-01-06', 0, NULL, NULL, NULL, 'A');
UPDATE class_students SET created_at = CONCAT(joined_on, ' 08:00:00') WHERE class_id BETWEEN 9564 AND 9568;

INSERT INTO class_sessions (id, class_id, teacher, conducted_on, conducted, non_conduction_reason, duration, attendance, created_by, created_at) VALUES
  (961201, 9564, 901911, '2025-10-02', 1, NULL, 45, NULL, 901911, '2025-10-02 12:00:00'),
  (961202, 9564, 901911, '2025-10-06', 1, NULL, 45, NULL, 901911, '2025-10-06 12:00:00'),
  (961203, 9564, 901911, '2025-10-13', 1, NULL, 45, NULL, 901911, '2025-10-13 12:00:00'),
  (961204, 9564, 901911, '2025-10-20', 0, 'Rc rain', NULL, NULL, 901911, '2025-10-20 12:00:00'),
  (961205, 9564, 901911, '2025-10-27', 1, NULL, 45, NULL, 901911, '2025-10-27 12:00:00'),
  (961206, 9564, 901911, '2025-11-03', 1, NULL, 45, NULL, 901911, '2025-11-03 12:00:00'),
  (961211, 9565, 901911, '2025-10-07', 1, NULL, 30, NULL, 901911, '2025-10-07 12:00:00'),
  (961212, 9565, 901911, '2025-10-14', 1, NULL, 30, NULL, 901911, '2025-10-14 12:00:00'),
  (961221, 9566, 901912, '2025-10-06', 1, NULL, 30, NULL, 901912, '2025-10-06 12:00:00'),
  (961231, 9567, 901913, '2025-10-08', 1, NULL, 30, NULL, 901913, '2025-10-08 12:00:00'),
  (961232, 9567, 901913, '2025-10-15', 1, NULL, 30, NULL, 901913, '2025-10-15 12:00:00'),
  (961241, 9568, 901912, '2025-10-10', 1, NULL, 30, NULL, 901912, '2025-10-10 12:00:00');

INSERT INTO class_attendance (id, session_id, token, name, extra_student, present, recitation) VALUES
  (961301, 961201, 901921, NULL, 0, 1, 3000), (961302, 961201, 901922, NULL, 0, 1, 0), (961303, 961201, 901924, NULL, 0, 1, 4000),
  (961304, 961202, 901921, NULL, 0, 1, 2000), (961305, 961202, 901922, NULL, 0, 0, 1000), (961306, 961202, 901923, NULL, 0, 1, 6000), (961307, 961202, 901924, NULL, 0, 0, 0),
  (961308, 961203, 901921, NULL, 0, 1, 0), (961309, 961204, 901921, NULL, 0, 1, 100000), (961310, 961205, 901921, NULL, 0, 0, 0), (961311, 961206, 901921, NULL, 0, 1, 5000),
  (961312, 961211, 901922, NULL, 0, 1, 0), (961313, 961212, 901922, NULL, 0, 1, 2000),
  (961314, 961221, 901928, NULL, 0, 0, 6000),
  (961315, 961231, 901925, NULL, 0, 1, 2000), (961316, 961231, 901926, NULL, 0, 1, 7000), (961317, 961232, 901925, NULL, 0, 1, 1000),
  (961318, 961241, 901927, NULL, 0, 1, 9000);

INSERT INTO standard_mcqs (id, code, language_id, level_id, topic, subject, lesson, name, sort_order, created_by, deleted_at) VALUES
  (961701, 'B5C-M1', 9, 3, 'Rc topic', 'Rc subject', 'Rc lesson 1', 'Rc MCQ one', 1, 900315, NULL),
  (961702, 'B5C-M2', 9, 3, 'Rc topic', 'Rc subject', 'Rc lesson 2', 'Rc MCQ two', 2, 900315, NULL),
  (961703, 'B5C-M3', 9, 3, 'Rc topic', 'Rc subject', 'Rc lesson 3', 'Rc MCQ three', 3, 900315, NULL),
  (961704, 'B5C-M4', 9, 3, 'Rc topic', 'Rc subject', 'Rc lesson 4', 'Rc MCQ four (deleted)', 4, 900315, '2025-09-01 00:00:00'),
  (961705, 'B5C-A1', 9, 2, 'Rc topic', 'Rc subject', 'Rc lesson 5', 'Rc MCQ five', 1, 900315, NULL);

INSERT INTO spot_quizzes (id, code, mcq_code, language_id, level_id, name, class_id, restrict_to_class, published_at, published_by, deactivated_at, created_by, created_at) VALUES
  (961401, 'RCQ961401', 'B5C-M1', 9, 3, 'Rc quiz one', 9564, 1, '2025-10-10 10:00:00', 901911, NULL, 901911, '2025-10-10 09:00:00'),
  (961402, 'RCQ961402', 'B5C-M1', 9, 3, 'Rc quiz two', 9564, 1, '2025-10-20 10:00:00', 901911, NULL, 901911, '2025-10-20 09:00:00'),
  (961403, 'RCQ961403', 'B5C-M1', 9, 3, 'Rc quiz three', 9564, 1, NULL, NULL, '2025-10-25 00:00:00', 901911, '2025-10-24 09:00:00'),
  (961404, 'RCQ961404', 'B5C-M2', 9, 3, 'Rc quiz four', 9564, 1, NULL, NULL, NULL, 901911, '2025-10-21 09:00:00'),
  (961405, 'RCQ961405', NULL, 9, 3, 'Rc quiz five', 9564, 1, '2025-11-05 12:00:00', 901911, NULL, 901911, '2025-11-05 11:00:00'),
  (961406, 'RCQ961406', 'b5c-m1', 9, 3, 'Rc quiz six', 9567, 1, '2025-10-12 10:00:00', 901913, NULL, 901913, '2025-10-12 09:00:00'),
  (961407, 'RCQ961407', 'B5C-M2', 9, 3, 'Rc quiz seven', 9567, 1, NULL, NULL, NULL, 901913, '2025-10-13 09:00:00'),
  (961408, 'RCQ961408', 'B5C-M1', 9, 3, 'Rc quiz eight', 9568, 1, '2025-10-11 10:00:00', 901912, NULL, 901912, '2025-10-11 09:00:00');
INSERT INTO spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, answer) VALUES
  (961501, 961401, 0, 'Rc q1', 'a', 'b', 1), (961502, 961401, 0, 'Rc q2', 'a', 'b', 1), (961503, 961401, 0, 'Rc q3', 'a', 'b', 1),
  (961504, 961402, 0, 'Rc q4', 'a', 'b', 1), (961505, 961402, 0, 'Rc q5', 'a', 'b', 1),
  (961506, 961405, 0, 'Rc q6', 'a', 'b', 1),
  (961507, 961406, 0, 'Rc q7', 'a', 'b', 1), (961508, 961406, 0, 'Rc q8', 'a', 'b', 1),
  (961509, 961408, 0, 'Rc q9', 'a', 'b', 1);
INSERT INTO spot_quiz_responses (id, spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct) VALUES
  (961601, 961401, 961501, 901921, 'a', 'a', 1), (961602, 961401, 961502, 901921, 'a', 'a', 1), (961603, 961401, 961503, 901921, 'b', 'a', 0),
  (961604, 961402, 961504, 901921, 'a', 'a', 1), (961605, 961402, 961505, 901921, 'a', 'a', 1),
  (961606, 961405, 961506, 901921, 'a', 'a', 1),
  (961607, 961401, 961501, 901922, 'a', 'a', 1), (961608, 961401, 961502, 901922, 'b', 'a', 0),
  (961609, 961406, 961507, 901925, 'a', 'a', 1), (961610, 961406, 961508, 901925, 'b', 'a', 0);

-- classes_before_create replaces the link of every inserted class with a random string; an UPDATE keeps ours.
UPDATE classes SET link = CONCAT('rclnk', id) WHERE id BETWEEN 9564 AND 9568;
