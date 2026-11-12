/*
 * The REPORTS2 lane fixtures for the PHP parity stack's MariaDB: the same members, classes, enrolments, sessions, attendance, standard MCQs and quizzes as db/synthetic/reports2-fixtures.sql (read the header there).
 * Loaded by tools/contract-reports2.sh inside the parity lock; resets every row it owns. The coordinators get class_access rows (the new API gets the same reach from rules).
 */
INSERT INTO users (token, email, roleid, provider, createdon)
SELECT v.token, CONCAT('r2.', v.token, '@example.invalid'), 0, 'firebase', NOW() FROM (
  SELECT 921001 AS token UNION ALL SELECT 921002 UNION ALL SELECT 921003 UNION ALL SELECT 921004 UNION ALL SELECT 921005 UNION ALL SELECT 921006 UNION ALL SELECT 921007 UNION ALL SELECT 921008
  UNION ALL SELECT 921011 UNION ALL SELECT 921012 UNION ALL SELECT 921013
  UNION ALL SELECT 921021 UNION ALL SELECT 921022 UNION ALL SELECT 921023 UNION ALL SELECT 921024 UNION ALL SELECT 921025 UNION ALL SELECT 921026 UNION ALL SELECT 921027 UNION ALL SELECT 921028
  UNION ALL SELECT 921029 UNION ALL SELECT 921030 UNION ALL SELECT 921031 UNION ALL SELECT 921032 UNION ALL SELECT 921033 UNION ALL SELECT 921034 UNION ALL SELECT 921035) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users SET email = CONCAT('r2.', token, '@example.invalid'), name = CONCAT('R2 Member ', token), gender = IF(token IN (921003, 921013, 921025), '2', '1'),
  roleid = CASE token WHEN 921001 THEN 1 WHEN 921002 THEN 3 WHEN 921003 THEN 4 WHEN 921004 THEN 5 WHEN 921005 THEN 5 WHEN 921008 THEN 5 ELSE 0 END, mobile = CONCAT('+91000092', RIGHT(token, 4))
WHERE token BETWEEN 921001 AND 921999;

DELETE FROM user_permissions WHERE user_id IN (SELECT id FROM users WHERE token BETWEEN 921001 AND 921999);
INSERT INTO user_permissions (user_id, permission, reason, revoked_at)
SELECT u.id, 'quran-leaderboard:read:all', 'synthetic fixture', NULL FROM users u WHERE u.token IN (921007, 921008);

DELETE FROM class_access WHERE token BETWEEN 921001 AND 921999;
INSERT INTO class_access (class_id, token) VALUES
  (98101, 921004), (98102, 921004), (98104, 921004), (98106, 921004), (98107, 921004), (98101, 921005), (98101, 921008);

DELETE FROM user_notifications WHERE user_token BETWEEN 921000 AND 921999;
DELETE FROM notifications WHERE created_by BETWEEN 921000 AND 921999 OR (JSON_VALUE(target_audience_criteria, '$.type') = 'CC_NUDGE' AND CAST(JSON_VALUE(target_audience_criteria, '$.teacher') AS UNSIGNED) BETWEEN 921000 AND 921999);
DELETE FROM user_devices WHERE id BETWEEN 9710801 AND 9710809 OR token BETWEEN 921000 AND 921999;
INSERT INTO user_devices (id, token, device_id, last_accessed_at, registered_at) VALUES
  (9710801, 921011, 'r2-dev-1', '2019-01-10 00:00:00', '2019-01-01 00:00:00'),
  (9710802, 921011, 'r2-dev-2', '2019-01-10 00:00:00', '2019-01-01 00:00:00'),
  (9710803, 921012, 'r2-dev-3', '2019-01-10 00:00:00', '2019-01-01 00:00:00');

DELETE FROM spot_quiz_responses WHERE spot_quiz_id BETWEEN 9710101 AND 9710199;
DELETE FROM spot_quiz_questions WHERE spot_quiz_id BETWEEN 9710101 AND 9710199;
DELETE FROM spot_quizzes WHERE id BETWEEN 9710101 AND 9710199;
DELETE FROM standard_mcqs WHERE id BETWEEN 9710401 AND 9710499;
DELETE FROM class_attendance WHERE session_id BETWEEN 9710601 AND 9710699;
DELETE FROM class_sessions WHERE id BETWEEN 9710601 AND 9710699 OR class_id BETWEEN 98101 AND 98199;
DELETE FROM class_schedules WHERE class_id BETWEEN 98101 AND 98199;
DELETE FROM class_students WHERE class_id BETWEEN 98101 AND 98199;
DELETE FROM classes WHERE id BETWEEN 98101 AND 98199;

INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (98101, 'R2-G-101', 71, 'r2lnk98101', 'R2 Class One', 3, '2019-01-07', 921011, 1, 'Offline', 'R2solo', 'India', 'R2 Hall', 'A', 900315),
  (98102, 'R2-G-102', 71, 'r2lnk98102', 'R2 Class Two', 2, '2019-01-07', 921011, 1, 'Offline', 'R2ville', 'India', 'R2 Hall', 'A', 900315),
  (98103, 'R2-G-103', 71, 'r2lnk98103', 'R2 Class Three', 1, '2019-01-07', 921012, 1, 'Offline', 'R2elsewhere', 'India', 'R2 Hall', 'A', 900315),
  (98104, 'R2-L-104', 71, 'r2lnk98104', 'R2 Ladies Class', 3, '2019-01-07', 921013, 2, 'Offline', 'R2ville', 'India', 'R2 Hall', 'A', 900315),
  (98105, 'R2-G-105', 71, 'r2lnk98105', 'R2 Closed Class', 3, '2019-01-07', 921011, 1, 'Offline', 'R2elsewhere', 'India', 'R2 Hall', 'I', 900315),
  (98106, 'R2-G-106', 71, 'r2lnk98106', 'R2 Class Six', 3, '2019-01-07', 921099, 1, 'Offline', 'R2ville', 'India', 'R2 Hall', 'A', 900315),
  (98107, 'R2-G-107', 71, 'r2lnk98107', 'R2 Class Seven', 2, '2019-01-07', 921011, 1, 'Offline', 'R2ville', 'India', 'R2 Hall', 'A', 900315);

INSERT INTO class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) VALUES
  (9710001, 98101, 2, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL), (9710002, 98102, 3, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (9710003, 98103, 4, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL), (9710004, 98104, 4, 19, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (9710005, 98107, 5, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL);

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9710501, 98101, 921021, '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710502, 98101, 921023, '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710503, 98101, 921028, '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710504, 98101, 921024, '2019-01-07', 0, '2019-02-15 00:00:00', 'R2 left', 900315, 'I'),
  (9710505, 98101, 921030, '2019-01-07', 0, '2019-02-16 00:00:00', 'R2 left', 900315, 'A'),
  (9710506, 98101, 921031, '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710507, 98101, 921032, '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710508, 98101, 921032, '2019-01-14', 0, NULL, NULL, NULL, 'A'),
  (9710509, 98101, 921033, '2019-01-07', 0, '2019-01-20 00:00:00', 'R2 left', 900315, 'I'),
  (9710510, 98101, 921033, '2019-02-01', 0, NULL, NULL, NULL, 'A'),
  (9710511, 98101, 921034, '2019-01-07', 0, NULL, NULL, NULL, 'I'),
  (9710512, 98102, 921022, '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710513, 98106, 921022, '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710514, 98103, 921026, '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710515, 98104, 921025, '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710516, 98104, 921029, '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710517, 98105, 921027, '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710518, 98107, 921035, '2019-01-07', 0, '2019-02-10 00:00:00', 'R2 left', 900315, 'I');
UPDATE class_students SET created_at = CONCAT(joined_on, ' 08:00:00') WHERE class_id BETWEEN 98101 AND 98107;

INSERT INTO class_sessions (id, class_id, teacher, conducted_on, conducted, non_conduction_reason, duration, attendance, created_by, created_at) VALUES
  (9710601, 98101, 921011, '2019-03-04', 1, NULL, 45, NULL, 921011, '2019-03-04 12:00:00'),
  (9710602, 98101, 921011, '2019-03-11', 1, NULL, 45, NULL, 921011, '2019-03-11 12:00:00'),
  (9710603, 98103, 921012, '2019-03-01', 1, NULL, 45, NULL, 921012, '2019-03-01 12:00:00'),
  (9710604, 98102, 921011, '2019-03-12', 1, NULL, 45, NULL, 921011, '2019-03-12 12:00:00'),
  (9710605, 98101, 921011, '2019-03-31', 1, NULL, 45, NULL, 921011, '2019-03-31 12:00:00'),
  (9710606, 98101, 921011, '2019-04-01', 1, NULL, 45, NULL, 921011, '2019-04-01 12:00:00'),
  (9710607, 98101, 921011, '2019-02-28', 1, NULL, 45, NULL, 921011, '2019-02-28 12:00:00'),
  (9710608, 98104, 921013, '2019-03-06', 1, NULL, 45, NULL, 921013, '2019-03-06 12:00:00'),
  (9710609, 98105, 921011, '2019-03-07', 1, NULL, 45, NULL, 921011, '2019-03-07 12:00:00');

INSERT INTO class_attendance (id, session_id, token, name, extra_student, present, recitation) VALUES
  (9710701, 9710601, 921021, NULL, 0, 1, 300), (9710702, 9710601, 921022, NULL, 0, 1, 100), (9710703, 9710601, 921023, NULL, 0, 1, 150), (9710704, 9710601, 921024, NULL, 0, 1, 500),
  (9710705, 9710601, 921030, NULL, 0, 1, 250), (9710706, 9710601, 921028, NULL, 0, 1, 0),
  (9710707, 9710602, 921021, NULL, 0, 1, 200), (9710708, 9710602, 921022, NULL, 0, 1, 50), (9710709, 9710602, 921023, NULL, 0, 1, 150), (9710710, 9710602, 921024, NULL, 0, 1, 400),
  (9710711, 9710603, 921026, NULL, 0, 1, 400), (9710712, 9710604, 921022, NULL, 0, 1, 150), (9710713, 9710605, 921028, NULL, 0, 1, 0),
  (9710714, 9710606, 921028, NULL, 0, 1, 9999), (9710715, 9710606, 921021, NULL, 0, 1, 9999), (9710716, 9710607, 921029, NULL, 0, 1, 5000),
  (9710717, 9710608, 921025, NULL, 0, 1, 700), (9710718, 9710608, 921029, NULL, 0, 1, 200), (9710719, 9710609, 921027, NULL, 0, 1, 600);

INSERT INTO standard_mcqs (id, code, language_id, level_id, topic, subject, lesson, name, sort_order, created_by, deleted_at) VALUES
  (9710401, 'R2-M1', 71, 3, 'R2 Topic', 'R2 Subject B', 'R2 lesson 1', 'R2 MCQ one', 1, 900315, NULL),
  (9710402, 'R2-M2', 71, 3, 'R2 Topic', 'R2 Subject A', 'R2 lesson 2', 'R2 MCQ two', NULL, 900315, NULL),
  (9710403, 'R2-M3', 71, 3, 'R2 Topic', 'R2 Subject A', 'R2 lesson 3', 'R2 MCQ three', 3, 900315, NULL),
  (9710404, 'R2-M4', 71, 3, 'R2 Topic', 'R2 Subject A', 'R2 lesson 4', 'R2 MCQ four (deleted)', 4, 900315, '2019-01-01 00:00:00'),
  (9710405, 'R2-A1', 71, 2, 'R2 Topic', 'R2 Subject A', 'R2 lesson 5', 'R2 MCQ five', 1, 900315, NULL),
  (9710406, 'R2-A2', 71, 2, 'R2 Topic', 'R2 Subject A', 'R2 lesson 6', 'R2 MCQ six', 2, 900315, NULL),
  (9710407, 'R2-S1', 71, 1, 'R2 Topic', 'R2 Subject A', 'R2 lesson 7', 'R2 MCQ seven', 1, 900315, NULL),
  (9710408, 'R2-S2', 71, 1, 'R2 Topic', 'R2 Subject A', 'R2 lesson 8', 'R2 MCQ eight', 2, 900315, NULL);

INSERT INTO spot_quizzes (id, code, mcq_code, language_id, level_id, name, class_id, restrict_to_class, topic, published_at, published_by, deactivated_at, created_by, created_at) VALUES
  (9710101, 'R2Q9710101', 'R2-M1', 71, 3, 'R2 quiz 1', 98101, 1, 'R2 Topic A', '2019-03-05 10:00:00', 921011, NULL, 921011, '2019-03-05 09:00:00'),
  (9710102, 'R2Q9710102', 'R2-M1', 71, 3, 'R2 quiz 2', 98101, 1, 'r2 topic a', '2019-03-10 10:00:00', 921011, NULL, 921011, '2019-03-10 09:00:00'),
  (9710103, 'R2Q9710103', NULL, 71, 3, 'R2 quiz 3', 98101, 1, 'R2 Topic B', '2019-03-31 00:00:00', 921011, NULL, 921011, '2019-03-30 09:00:00'),
  (9710104, 'R2Q9710104', NULL, 71, 3, 'R2 quiz 4', 98101, 1, 'R2 Topic B', '2019-03-31 23:59:00', 921011, NULL, 921011, '2019-03-31 09:00:00'),
  (9710105, 'R2Q9710105', NULL, 71, 3, 'R2 quiz 5', 98101, 1, NULL, '2019-03-12 10:00:00', 921011, NULL, 921011, '2019-03-12 09:00:00'),
  (9710106, 'R2Q9710106', 'R2-M3', 71, 3, 'R2 quiz 6', 98101, 1, 'R2 Topic C', '2019-03-14 10:00:00', 921011, '2019-03-20 00:00:00', 921011, '2019-03-14 09:00:00'),
  (9710107, 'R2Q9710107', NULL, 71, 3, 'R2 quiz 7', 98101, 1, 'R2 Topic A', '2019-02-28 23:59:00', 921011, NULL, 921011, '2019-02-28 09:00:00'),
  (9710108, 'R2Q9710108', NULL, 71, 3, 'R2 quiz 8', 98101, 1, 'R2 Topic D', '2019-03-01 00:00:00', 921011, NULL, 921011, '2019-02-28 10:00:00'),
  (9710109, 'R2Q9710109', 'R2-M1', 71, 3, 'R2 quiz 9', 98101, 1, NULL, NULL, NULL, NULL, 921011, '2019-03-20 09:00:00'),
  (9710110, 'R2Q9710110', 'R2-M2', 71, 3, 'R2 quiz 10', 98101, 1, NULL, NULL, NULL, NULL, 921011, '2019-03-21 09:00:00'),
  (9710111, 'R2Q9710111', 'R2-M4', 71, 3, 'R2 quiz 11', 98101, 1, 'R2 Topic A', '2019-03-15 10:00:00', 921011, NULL, 921011, '2019-03-15 09:00:00'),
  (9710112, 'R2Q9710112', NULL, 71, 1, 'R2 quiz S1', 98103, 1, 'R2 Topic A', '2019-03-09 10:00:00', 921012, NULL, 921012, '2019-03-09 09:00:00'),
  (9710113, 'R2Q9710113', 'R2-M1', 71, 3, 'R2 quiz C1', 98105, 1, 'R2 Topic A', '2019-03-08 10:00:00', 921011, NULL, 921011, '2019-03-08 09:00:00'),
  (9710114, 'R2Q9710114', 'r2-m1', 71, 3, 'R2 quiz L1', 98104, 1, 'R2 Topic A', '2019-03-08 11:00:00', 921013, NULL, 921013, '2019-03-08 09:00:00'),
  (9710115, 'R2Q9710115', 'R2-M2', 71, 3, 'R2 quiz L2', 98104, 1, NULL, '2019-05-02 10:00:00', 921013, NULL, 921013, '2019-05-02 09:00:00'),
  (9710116, 'R2Q9710116', NULL, 71, 2, 'R2 quiz A1', 98107, 1, 'R2 Topic Z', '2019-03-20 10:00:00', 921011, NULL, 921011, '2019-03-20 09:00:00'),
  (9710117, 'R2Q9710117', 'R2-A1', 71, 2, 'R2 quiz A2', 98102, 1, NULL, '2019-05-03 10:00:00', 921011, NULL, 921011, '2019-05-03 09:00:00'),
  (9710118, 'R2Q9710118', 'R2-A2', 71, 2, 'R2 quiz A3', 98102, 1, NULL, NULL, NULL, NULL, 921011, '2019-05-03 11:00:00'),
  (9710119, 'R2Q9710119', 'R2-M1', 71, 3, 'R2 quiz F1', 98106, 1, NULL, '2019-05-04 10:00:00', 921011, NULL, 921011, '2019-05-04 09:00:00'),
  (9710120, 'R2Q9710120', 'R2-M2', 71, 3, 'R2 quiz F2', 98106, 1, NULL, '2019-05-04 10:00:00', 921011, NULL, 921011, '2019-05-04 09:00:00'),
  (9710121, 'R2Q9710121', 'R2-M3', 71, 3, 'R2 quiz F3', 98106, 1, NULL, '2019-05-04 10:00:00', 921011, NULL, 921011, '2019-05-04 09:00:00'),
  (9710122, 'R2Q9710122', 'R2-S1', 71, 1, 'R2 quiz S2', 98103, 1, NULL, NULL, NULL, NULL, 921012, '2019-05-05 09:00:00'),
  (9710123, 'R2Q9710123', 'R2-M3', 71, 3, 'R2 quiz L3', 98104, 1, NULL, NULL, NULL, NULL, 921013, '2019-05-05 09:00:00');

INSERT INTO spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, answer) VALUES
  (9710201, 9710101, 0, 'R2 q1', 'a', 'b', 1), (9710202, 9710101, 0, 'R2 q2', 'a', 'b', 1), (9710203, 9710101, 0, 'R2 q3', 'a', 'b', 1),
  (9710204, 9710102, 0, 'R2 q4', 'a', 'b', 1), (9710205, 9710102, 0, 'R2 q5', 'a', 'b', 1),
  (9710206, 9710103, 0, 'R2 q6', 'a', 'b', 1), (9710207, 9710103, 0, 'R2 q7', 'a', 'b', 1),
  (9710208, 9710104, 0, 'R2 q8', 'a', 'b', 1), (9710209, 9710104, 0, 'R2 q9', 'a', 'b', 1),
  (9710210, 9710105, 0, 'R2 q10', 'a', 'b', 1), (9710211, 9710106, 0, 'R2 q11', 'a', 'b', 1), (9710212, 9710107, 0, 'R2 q12', 'a', 'b', 1),
  (9710213, 9710111, 0, 'R2 q13', 'a', 'b', 1),
  (9710214, 9710112, 0, 'R2 q14', 'a', 'b', 1), (9710215, 9710112, 0, 'R2 q15', 'a', 'b', 1), (9710216, 9710112, 0, 'R2 q16', 'a', 'b', 1), (9710217, 9710112, 0, 'R2 q17', 'a', 'b', 1), (9710218, 9710112, 0, 'R2 q18', 'a', 'b', 1),
  (9710219, 9710113, 0, 'R2 q19', 'a', 'b', 1),
  (9710220, 9710114, 0, 'R2 q20', 'a', 'b', 1), (9710221, 9710114, 0, 'R2 q21', 'a', 'b', 1),
  (9710222, 9710116, 0, 'R2 q22', 'a', 'b', 1), (9710223, 9710116, 0, 'R2 q23', 'a', 'b', 1);

INSERT INTO spot_quiz_responses (id, spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct) VALUES
  (9710301, 9710101, 9710201, 921021, 'a', 'a', 1), (9710302, 9710101, 9710202, 921021, 'a', 'a', 1), (9710303, 9710101, 9710203, 921021, 'b', 'a', 0),
  (9710304, 9710102, 9710204, 921021, 'a', 'a', 1), (9710305, 9710102, 9710205, 921021, 'a', 'a', 1),
  (9710306, 9710103, 9710206, 921021, 'a', 'a', 1), (9710307, 9710103, 9710207, 921021, 'b', 'a', 0),
  (9710308, 9710105, 9710210, 921021, 'a', 'a', 1), (9710309, 9710111, 9710213, 921021, 'b', 'a', 0),
  (9710310, 9710102, 9710204, 921034, 'a', 'a', 1), (9710311, 9710102, 9710205, 921034, 'a', 'a', 1), (9710312, 9710105, 9710210, 921034, 'a', 'a', 1),
  (9710313, 9710111, 9710213, 921034, 'a', 'a', 1), (9710314, 9710103, 9710206, 921034, 'a', 'a', 1), (9710315, 9710103, 9710207, 921034, 'b', 'a', 0),
  (9710316, 9710101, 9710201, 921032, 'a', 'a', 1), (9710317, 9710101, 9710202, 921032, 'a', 'a', 1), (9710318, 9710101, 9710203, 921032, 'b', 'a', 0),
  (9710319, 9710102, 9710204, 921031, 'a', 'a', 1), (9710320, 9710102, 9710205, 921031, 'a', 'a', 1), (9710321, 9710105, 9710210, 921031, 'a', 'a', 1),
  (9710322, 9710103, 9710206, 921023, 'a', 'a', 1), (9710323, 9710103, 9710207, 921023, 'a', 'a', 1),
  (9710324, 9710106, 9710211, 921033, 'a', 'a', 1),
  (9710325, 9710101, 9710201, 921024, 'a', 'a', 1), (9710326, 9710101, 9710202, 921024, 'a', 'a', 1),
  (9710327, 9710114, 9710220, 921025, 'a', 'a', 1), (9710328, 9710114, 9710221, 921025, 'a', 'a', 1),
  (9710329, 9710112, 9710214, 921026, 'a', 'a', 1), (9710330, 9710112, 9710215, 921026, 'a', 'a', 1), (9710331, 9710112, 9710216, 921026, 'a', 'a', 1), (9710332, 9710112, 9710217, 921026, 'a', 'a', 1), (9710333, 9710112, 9710218, 921026, 'a', 'a', 1),
  (9710334, 9710113, 9710219, 921027, 'a', 'a', 1);

-- classes_before_create replaces the link of every inserted class with a random string; an UPDATE keeps ours.
UPDATE classes SET link = CONCAT('r2lnk', id) WHERE id BETWEEN 98101 AND 98107;
