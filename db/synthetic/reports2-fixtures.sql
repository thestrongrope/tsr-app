/*
 * The REPORTS2 lane fixtures (MCQ summary, MCQ adherence, Quran leaderboard, pending nudge) for the new API's database. tools/parity-php/reports2-fixtures.sql holds the same rows for the PHP parity stack.
 * Loaded by tools/contract-reports2.sh before every run; resets every row it owns by token and id. Synthetic only. The lane block (TSR_STACK 1): tokens 921001 to 921999 (emails r2.<token>@example.invalid),
 * classes 98101 to 98107, every other row id 9710000 to 9719999, standard MCQs in language 71 (no other fixture uses it), every date in March to May 2019 (no other fixture or seed touches 2019, so the leaderboard's
 * global ranks are ours alone) and the files ask for 2019-03-01 to 2019-03-31 explicitly.
 *
 * Callers: 921001 super admin (role 1)   921002 gents admin (3)   921003 ladies admin (4)   921004 coordinator "r2_coord" (role 5; gents R2solo and R2ville classes and ladies R2ville classes: 98101 98102 98104 98106 98107)
 *   921005 coordinator "r2_one" (gents class 98101 only)   921006 plain member   921007 holder of the named grant quran-leaderboard:read:all only   921008 coordinator "r2_grant" (role 5 + that grant; class 98101 only)
 * Teachers: 921011 (gents, 98101 98102 98105 98107; two devices)   921012 (gents, 98103, outside r2_coord's reach; one device)   921013 (ladies member, 98104; no device)   98106's teacher 921099 has NO member row.
 * Classes (level 1 SALMAN, 2 ABUZAR, 3 MIQDAD): 98101 gents MIQDAD city R2solo   98102 gents ABUZAR R2ville   98103 gents SALMAN R2elsewhere   98104 LADIES MIQDAD R2ville   98105 gents MIQDAD R2elsewhere CLOSED
 *   98106 gents MIQDAD R2ville (teacher without a member row)   98107 gents ABUZAR R2ville.
 * Standard MCQs (language 71): MIQDAD R2-M1 (subject B), R2-M2 (subject A, no sort order), R2-M3 (subject A), R2-M4 deleted; ABUZAR R2-A1, R2-A2; SALMAN R2-S1, R2-S2.
 * Adherence: 98101 M1 conducted (two published copies and a newer unpublished one), M2 pending, M3 skipped (deactivated copy) = 33.3; 98102 A1 conducted, A2 pending = 50; 98103 0; 98104 "r2-m1" and M2 conducted = 66.7; 98106 all three = 100; 98107 0.
 * Summary (2019-03-01 to 2019-03-31): 98101 has 7 quizzes in range (topics "R2 Topic A" twice with a case difference, B at the midnight edge, one with none, one deactivated, one with no questions, one of a deleted MCQ) and
 *   seven students with distinct scores 6 5 4 3 2 1 0; 98107 has a quiz and only a removed student; 98104 a quiz; 98103 and 98105 (closed) quizzes that must stay out of r2_coord's answers.
 * Leaderboard (the same window): totals 921024 900 (removed: status I), 921025 700 (ladies), 921027 600 (closed class), 921021 500, 921026 400, 921022 300 (two classes) and 921023 300 (tie), 921030 250 (removed_at set, status A),
 *   921029 200 (ladies class, member gender gents), 921028 0; out-of-window marks of 9999 and 5000 must change nothing.
 */
INSERT INTO identity.users (token, email)
SELECT v.token, 'r2.' || v.token || '@example.invalid' FROM (VALUES
  (921001), (921002), (921003), (921004), (921005), (921006), (921007), (921008), (921011), (921012), (921013),
  (921021), (921022), (921023), (921024), (921025), (921026), (921027), (921028), (921029), (921030), (921031), (921032), (921033), (921034), (921035)
) AS v (token)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

UPDATE identity.users u SET email = 'r2.' || u.token || '@example.invalid' WHERE u.token BETWEEN 921001 AND 921999 AND u.email <> 'r2.' || u.token || '@example.invalid';

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id, 'R2 Member ' || v.token, CASE WHEN v.token IN (921003, 921013, 921025) THEN '2' ELSE '1' END, '+91000092' || right(v.token::text, 4) FROM (VALUES
  (921001), (921002), (921003), (921004), (921005), (921006), (921007), (921008), (921011), (921012), (921013),
  (921021), (921022), (921023), (921024), (921025), (921026), (921027), (921028), (921029), (921030), (921031), (921032), (921033), (921034), (921035)
) AS v (token)
JOIN identity.users u ON u.token = v.token
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 921001 AND 921999);
INSERT INTO access.user_roles (user_id, roleid)
SELECT u.id, v.roleid FROM (VALUES (921001, 1), (921002, 3), (921003, 4), (921004, 5), (921005, 5), (921008, 5)) AS v (token, roleid) JOIN identity.users u ON u.token = v.token;

DELETE FROM access.user_permissions WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 921001 AND 921999);
INSERT INTO access.user_permissions (user_id, permission, reason, revoked_at)
SELECT u.id, 'quran-leaderboard:read:all', 'synthetic fixture', NULL FROM identity.users u WHERE u.token IN (921007, 921008);

DELETE FROM access.class_access_rule_conditions WHERE rule_id BETWEEN 9710001 AND 9710009;
DELETE FROM access.class_access_rules WHERE id BETWEEN 9710001 AND 9710009;
INSERT INTO access.class_access_rules (id, token, gender, note, created_at) VALUES
  (9710001, 921004, 1, 'R2 gents R2ville', now()), (9710002, 921004, 1, 'R2 gents R2solo', now()), (9710003, 921004, 2, 'R2 ladies R2ville', now()),
  (9710004, 921005, 1, 'R2 one R2solo', now()), (9710005, 921008, 1, 'R2 grant R2solo', now());
INSERT INTO access.class_access_rule_conditions (rule_id, field, negate, value) VALUES
  (9710001, 'city', false, 'R2ville'), (9710002, 'city', false, 'R2solo'), (9710003, 'city', false, 'R2ville'), (9710004, 'city', false, 'R2solo'), (9710005, 'city', false, 'R2solo');

-- What a nudge run wrote, reset here so the 24 hour rule starts clean.
DELETE FROM platform.outbound_messages WHERE recipient LIKE 'r2-dev-%';
DELETE FROM notifications.user_notifications WHERE user_token BETWEEN 921000 AND 921999;
DELETE FROM notifications.notifications WHERE created_by BETWEEN 921000 AND 921999 OR (target_audience_criteria::text::jsonb ->> 'type' = 'CC_NUDGE' AND (target_audience_criteria::text::jsonb ->> 'teacher')::int BETWEEN 921000 AND 921999);
DELETE FROM platform.outbox WHERE event_type = 'classes.teacher_nudged' AND payload::text ~ '"[tT]eacherToken": ?921[0-9]{3}';
DELETE FROM notifications.user_devices WHERE id BETWEEN 9710801 AND 9710809 OR token BETWEEN 921000 AND 921999;
INSERT INTO notifications.user_devices (id, token, device_id, registered_at, last_accessed_at) VALUES
  (9710801, 921011, 'r2-dev-1', TIMESTAMPTZ '2019-01-01 00:00:00+00', TIMESTAMPTZ '2019-01-10 00:00:00+00'),
  (9710802, 921011, 'r2-dev-2', TIMESTAMPTZ '2019-01-01 00:00:00+00', TIMESTAMPTZ '2019-01-10 00:00:00+00'),
  (9710803, 921012, 'r2-dev-3', TIMESTAMPTZ '2019-01-01 00:00:00+00', TIMESTAMPTZ '2019-01-10 00:00:00+00');

DELETE FROM assessment.spot_quiz_responses WHERE spot_quiz_id BETWEEN 9710101 AND 9710199;
DELETE FROM assessment.spot_quiz_questions WHERE spot_quiz_id BETWEEN 9710101 AND 9710199;
DELETE FROM assessment.spot_quizzes WHERE id BETWEEN 9710101 AND 9710199;
DELETE FROM assessment.standard_mcqs WHERE id BETWEEN 9710401 AND 9710499;
DELETE FROM classes.class_attendance WHERE session_id BETWEEN 9710601 AND 9710699;
DELETE FROM classes.class_sessions WHERE id BETWEEN 9710601 AND 9710699 OR class_id BETWEEN 98101 AND 98199;
DELETE FROM classes.class_schedules WHERE class_id BETWEEN 98101 AND 98199;
DELETE FROM classes.class_students WHERE class_id BETWEEN 98101 AND 98199;
DELETE FROM classes.classes WHERE id BETWEEN 98101 AND 98199;

INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (98101, 'R2-G-101', 71, 'r2lnk98101', 'R2 Class One', 3, DATE '2019-01-07', 921011, 1, 'Offline', 'R2solo', 'India', 'R2 Hall', 'A', 900315),
  (98102, 'R2-G-102', 71, 'r2lnk98102', 'R2 Class Two', 2, DATE '2019-01-07', 921011, 1, 'Offline', 'R2ville', 'India', 'R2 Hall', 'A', 900315),
  (98103, 'R2-G-103', 71, 'r2lnk98103', 'R2 Class Three', 1, DATE '2019-01-07', 921012, 1, 'Offline', 'R2elsewhere', 'India', 'R2 Hall', 'A', 900315),
  (98104, 'R2-L-104', 71, 'r2lnk98104', 'R2 Ladies Class', 3, DATE '2019-01-07', 921013, 2, 'Offline', 'R2ville', 'India', 'R2 Hall', 'A', 900315),
  (98105, 'R2-G-105', 71, 'r2lnk98105', 'R2 Closed Class', 3, DATE '2019-01-07', 921011, 1, 'Offline', 'R2elsewhere', 'India', 'R2 Hall', 'I', 900315),
  (98106, 'R2-G-106', 71, 'r2lnk98106', 'R2 Class Six', 3, DATE '2019-01-07', 921099, 1, 'Offline', 'R2ville', 'India', 'R2 Hall', 'A', 900315),
  (98107, 'R2-G-107', 71, 'r2lnk98107', 'R2 Class Seven', 2, DATE '2019-01-07', 921011, 1, 'Offline', 'R2ville', 'India', 'R2 Hall', 'A', 900315);

INSERT INTO classes.class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) VALUES
  (9710001, 98101, 2, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL), (9710002, 98102, 3, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (9710003, 98103, 4, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL), (9710004, 98104, 4, 19, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (9710005, 98107, 5, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9710501, 98101, 921021, DATE '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710502, 98101, 921023, DATE '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710503, 98101, 921028, DATE '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710504, 98101, 921024, DATE '2019-01-07', 0, TIMESTAMPTZ '2019-02-15 00:00:00+00', 'R2 left', 900315, 'I'),
  (9710505, 98101, 921030, DATE '2019-01-07', 0, TIMESTAMPTZ '2019-02-16 00:00:00+00', 'R2 left', 900315, 'A'),
  (9710506, 98101, 921031, DATE '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710507, 98101, 921032, DATE '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710508, 98101, 921032, DATE '2019-01-14', 0, NULL, NULL, NULL, 'A'),
  (9710509, 98101, 921033, DATE '2019-01-07', 0, TIMESTAMPTZ '2019-01-20 00:00:00+00', 'R2 left', 900315, 'I'),
  (9710510, 98101, 921033, DATE '2019-02-01', 0, NULL, NULL, NULL, 'A'),
  (9710511, 98101, 921034, DATE '2019-01-07', 0, NULL, NULL, NULL, 'I'),
  (9710512, 98102, 921022, DATE '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710513, 98106, 921022, DATE '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710514, 98103, 921026, DATE '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710515, 98104, 921025, DATE '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710516, 98104, 921029, DATE '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710517, 98105, 921027, DATE '2019-01-07', 0, NULL, NULL, NULL, 'A'),
  (9710518, 98107, 921035, DATE '2019-01-07', 0, TIMESTAMPTZ '2019-02-10 00:00:00+00', 'R2 left', 900315, 'I');
UPDATE classes.class_students SET created_at = joined_on + TIME '08:00' AT TIME ZONE 'UTC' WHERE class_id BETWEEN 98101 AND 98107;

INSERT INTO classes.class_sessions (id, class_id, teacher, conducted_on, conducted, non_conduction_reason, duration, attendance, created_by, created_at) VALUES
  (9710601, 98101, 921011, DATE '2019-03-04', 1, NULL, 45, NULL, 921011, TIMESTAMPTZ '2019-03-04 12:00:00+00'),
  (9710602, 98101, 921011, DATE '2019-03-11', 1, NULL, 45, NULL, 921011, TIMESTAMPTZ '2019-03-11 12:00:00+00'),
  (9710603, 98103, 921012, DATE '2019-03-01', 1, NULL, 45, NULL, 921012, TIMESTAMPTZ '2019-03-01 12:00:00+00'),
  (9710604, 98102, 921011, DATE '2019-03-12', 1, NULL, 45, NULL, 921011, TIMESTAMPTZ '2019-03-12 12:00:00+00'),
  (9710605, 98101, 921011, DATE '2019-03-31', 1, NULL, 45, NULL, 921011, TIMESTAMPTZ '2019-03-31 12:00:00+00'),
  (9710606, 98101, 921011, DATE '2019-04-01', 1, NULL, 45, NULL, 921011, TIMESTAMPTZ '2019-04-01 12:00:00+00'),
  (9710607, 98101, 921011, DATE '2019-02-28', 1, NULL, 45, NULL, 921011, TIMESTAMPTZ '2019-02-28 12:00:00+00'),
  (9710608, 98104, 921013, DATE '2019-03-06', 1, NULL, 45, NULL, 921013, TIMESTAMPTZ '2019-03-06 12:00:00+00'),
  (9710609, 98105, 921011, DATE '2019-03-07', 1, NULL, 45, NULL, 921011, TIMESTAMPTZ '2019-03-07 12:00:00+00');

INSERT INTO classes.class_attendance (id, session_id, token, name, extra_student, present, recitation) VALUES
  (9710701, 9710601, 921021, NULL, 0, 1, 300), (9710702, 9710601, 921022, NULL, 0, 1, 100), (9710703, 9710601, 921023, NULL, 0, 1, 150), (9710704, 9710601, 921024, NULL, 0, 1, 500),
  (9710705, 9710601, 921030, NULL, 0, 1, 250), (9710706, 9710601, 921028, NULL, 0, 1, 0),
  (9710707, 9710602, 921021, NULL, 0, 1, 200), (9710708, 9710602, 921022, NULL, 0, 1, 50), (9710709, 9710602, 921023, NULL, 0, 1, 150), (9710710, 9710602, 921024, NULL, 0, 1, 400),
  (9710711, 9710603, 921026, NULL, 0, 1, 400), (9710712, 9710604, 921022, NULL, 0, 1, 150), (9710713, 9710605, 921028, NULL, 0, 1, 0),
  (9710714, 9710606, 921028, NULL, 0, 1, 9999), (9710715, 9710606, 921021, NULL, 0, 1, 9999), (9710716, 9710607, 921029, NULL, 0, 1, 5000),
  (9710717, 9710608, 921025, NULL, 0, 1, 700), (9710718, 9710608, 921029, NULL, 0, 1, 200), (9710719, 9710609, 921027, NULL, 0, 1, 600);

INSERT INTO assessment.standard_mcqs (id, code, language_id, level_id, topic, subject, lesson, name, sort_order, created_by, deleted_at) VALUES
  (9710401, 'R2-M1', 71, 3, 'R2 Topic', 'R2 Subject B', 'R2 lesson 1', 'R2 MCQ one', 1, 900315, NULL),
  (9710402, 'R2-M2', 71, 3, 'R2 Topic', 'R2 Subject A', 'R2 lesson 2', 'R2 MCQ two', NULL, 900315, NULL),
  (9710403, 'R2-M3', 71, 3, 'R2 Topic', 'R2 Subject A', 'R2 lesson 3', 'R2 MCQ three', 3, 900315, NULL),
  (9710404, 'R2-M4', 71, 3, 'R2 Topic', 'R2 Subject A', 'R2 lesson 4', 'R2 MCQ four (deleted)', 4, 900315, TIMESTAMPTZ '2019-01-01 00:00:00+00'),
  (9710405, 'R2-A1', 71, 2, 'R2 Topic', 'R2 Subject A', 'R2 lesson 5', 'R2 MCQ five', 1, 900315, NULL),
  (9710406, 'R2-A2', 71, 2, 'R2 Topic', 'R2 Subject A', 'R2 lesson 6', 'R2 MCQ six', 2, 900315, NULL),
  (9710407, 'R2-S1', 71, 1, 'R2 Topic', 'R2 Subject A', 'R2 lesson 7', 'R2 MCQ seven', 1, 900315, NULL),
  (9710408, 'R2-S2', 71, 1, 'R2 Topic', 'R2 Subject A', 'R2 lesson 8', 'R2 MCQ eight', 2, 900315, NULL);

INSERT INTO assessment.spot_quizzes (id, code, mcq_code, language_id, level_id, name, class_id, restrict_to_class, topic, published_at, published_by, deactivated_at, created_by, created_at) VALUES
  (9710101, 'R2Q9710101', 'R2-M1', 71, 3, 'R2 quiz 1', 98101, 1, 'R2 Topic A', TIMESTAMPTZ '2019-03-05 10:00:00+00', 921011, NULL, 921011, TIMESTAMPTZ '2019-03-05 09:00:00+00'),
  (9710102, 'R2Q9710102', 'R2-M1', 71, 3, 'R2 quiz 2', 98101, 1, 'r2 topic a', TIMESTAMPTZ '2019-03-10 10:00:00+00', 921011, NULL, 921011, TIMESTAMPTZ '2019-03-10 09:00:00+00'),
  (9710103, 'R2Q9710103', NULL, 71, 3, 'R2 quiz 3', 98101, 1, 'R2 Topic B', TIMESTAMPTZ '2019-03-31 00:00:00+00', 921011, NULL, 921011, TIMESTAMPTZ '2019-03-30 09:00:00+00'),
  (9710104, 'R2Q9710104', NULL, 71, 3, 'R2 quiz 4', 98101, 1, 'R2 Topic B', TIMESTAMPTZ '2019-03-31 23:59:00+00', 921011, NULL, 921011, TIMESTAMPTZ '2019-03-31 09:00:00+00'),
  (9710105, 'R2Q9710105', NULL, 71, 3, 'R2 quiz 5', 98101, 1, NULL, TIMESTAMPTZ '2019-03-12 10:00:00+00', 921011, NULL, 921011, TIMESTAMPTZ '2019-03-12 09:00:00+00'),
  (9710106, 'R2Q9710106', 'R2-M3', 71, 3, 'R2 quiz 6', 98101, 1, 'R2 Topic C', TIMESTAMPTZ '2019-03-14 10:00:00+00', 921011, TIMESTAMPTZ '2019-03-20 00:00:00+00', 921011, TIMESTAMPTZ '2019-03-14 09:00:00+00'),
  (9710107, 'R2Q9710107', NULL, 71, 3, 'R2 quiz 7', 98101, 1, 'R2 Topic A', TIMESTAMPTZ '2019-02-28 23:59:00+00', 921011, NULL, 921011, TIMESTAMPTZ '2019-02-28 09:00:00+00'),
  (9710108, 'R2Q9710108', NULL, 71, 3, 'R2 quiz 8', 98101, 1, 'R2 Topic D', TIMESTAMPTZ '2019-03-01 00:00:00+00', 921011, NULL, 921011, TIMESTAMPTZ '2019-02-28 10:00:00+00'),
  (9710109, 'R2Q9710109', 'R2-M1', 71, 3, 'R2 quiz 9', 98101, 1, NULL, NULL, NULL, NULL, 921011, TIMESTAMPTZ '2019-03-20 09:00:00+00'),
  (9710110, 'R2Q9710110', 'R2-M2', 71, 3, 'R2 quiz 10', 98101, 1, NULL, NULL, NULL, NULL, 921011, TIMESTAMPTZ '2019-03-21 09:00:00+00'),
  (9710111, 'R2Q9710111', 'R2-M4', 71, 3, 'R2 quiz 11', 98101, 1, 'R2 Topic A', TIMESTAMPTZ '2019-03-15 10:00:00+00', 921011, NULL, 921011, TIMESTAMPTZ '2019-03-15 09:00:00+00'),
  (9710112, 'R2Q9710112', NULL, 71, 1, 'R2 quiz S1', 98103, 1, 'R2 Topic A', TIMESTAMPTZ '2019-03-09 10:00:00+00', 921012, NULL, 921012, TIMESTAMPTZ '2019-03-09 09:00:00+00'),
  (9710113, 'R2Q9710113', 'R2-M1', 71, 3, 'R2 quiz C1', 98105, 1, 'R2 Topic A', TIMESTAMPTZ '2019-03-08 10:00:00+00', 921011, NULL, 921011, TIMESTAMPTZ '2019-03-08 09:00:00+00'),
  (9710114, 'R2Q9710114', 'r2-m1', 71, 3, 'R2 quiz L1', 98104, 1, 'R2 Topic A', TIMESTAMPTZ '2019-03-08 11:00:00+00', 921013, NULL, 921013, TIMESTAMPTZ '2019-03-08 09:00:00+00'),
  (9710115, 'R2Q9710115', 'R2-M2', 71, 3, 'R2 quiz L2', 98104, 1, NULL, TIMESTAMPTZ '2019-05-02 10:00:00+00', 921013, NULL, 921013, TIMESTAMPTZ '2019-05-02 09:00:00+00'),
  (9710116, 'R2Q9710116', NULL, 71, 2, 'R2 quiz A1', 98107, 1, 'R2 Topic Z', TIMESTAMPTZ '2019-03-20 10:00:00+00', 921011, NULL, 921011, TIMESTAMPTZ '2019-03-20 09:00:00+00'),
  (9710117, 'R2Q9710117', 'R2-A1', 71, 2, 'R2 quiz A2', 98102, 1, NULL, TIMESTAMPTZ '2019-05-03 10:00:00+00', 921011, NULL, 921011, TIMESTAMPTZ '2019-05-03 09:00:00+00'),
  (9710118, 'R2Q9710118', 'R2-A2', 71, 2, 'R2 quiz A3', 98102, 1, NULL, NULL, NULL, NULL, 921011, TIMESTAMPTZ '2019-05-03 11:00:00+00'),
  (9710119, 'R2Q9710119', 'R2-M1', 71, 3, 'R2 quiz F1', 98106, 1, NULL, TIMESTAMPTZ '2019-05-04 10:00:00+00', 921011, NULL, 921011, TIMESTAMPTZ '2019-05-04 09:00:00+00'),
  (9710120, 'R2Q9710120', 'R2-M2', 71, 3, 'R2 quiz F2', 98106, 1, NULL, TIMESTAMPTZ '2019-05-04 10:00:00+00', 921011, NULL, 921011, TIMESTAMPTZ '2019-05-04 09:00:00+00'),
  (9710121, 'R2Q9710121', 'R2-M3', 71, 3, 'R2 quiz F3', 98106, 1, NULL, TIMESTAMPTZ '2019-05-04 10:00:00+00', 921011, NULL, 921011, TIMESTAMPTZ '2019-05-04 09:00:00+00'),
  (9710122, 'R2Q9710122', 'R2-S1', 71, 1, 'R2 quiz S2', 98103, 1, NULL, NULL, NULL, NULL, 921012, TIMESTAMPTZ '2019-05-05 09:00:00+00'),
  (9710123, 'R2Q9710123', 'R2-M3', 71, 3, 'R2 quiz L3', 98104, 1, NULL, NULL, NULL, NULL, 921013, TIMESTAMPTZ '2019-05-05 09:00:00+00');

INSERT INTO assessment.spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, answer) VALUES
  (9710201, 9710101, FALSE, 'R2 q1', 'a', 'b', 1), (9710202, 9710101, FALSE, 'R2 q2', 'a', 'b', 1), (9710203, 9710101, FALSE, 'R2 q3', 'a', 'b', 1),
  (9710204, 9710102, FALSE, 'R2 q4', 'a', 'b', 1), (9710205, 9710102, FALSE, 'R2 q5', 'a', 'b', 1),
  (9710206, 9710103, FALSE, 'R2 q6', 'a', 'b', 1), (9710207, 9710103, FALSE, 'R2 q7', 'a', 'b', 1),
  (9710208, 9710104, FALSE, 'R2 q8', 'a', 'b', 1), (9710209, 9710104, FALSE, 'R2 q9', 'a', 'b', 1),
  (9710210, 9710105, FALSE, 'R2 q10', 'a', 'b', 1), (9710211, 9710106, FALSE, 'R2 q11', 'a', 'b', 1), (9710212, 9710107, FALSE, 'R2 q12', 'a', 'b', 1),
  (9710213, 9710111, FALSE, 'R2 q13', 'a', 'b', 1),
  (9710214, 9710112, FALSE, 'R2 q14', 'a', 'b', 1), (9710215, 9710112, FALSE, 'R2 q15', 'a', 'b', 1), (9710216, 9710112, FALSE, 'R2 q16', 'a', 'b', 1), (9710217, 9710112, FALSE, 'R2 q17', 'a', 'b', 1), (9710218, 9710112, FALSE, 'R2 q18', 'a', 'b', 1),
  (9710219, 9710113, FALSE, 'R2 q19', 'a', 'b', 1),
  (9710220, 9710114, FALSE, 'R2 q20', 'a', 'b', 1), (9710221, 9710114, FALSE, 'R2 q21', 'a', 'b', 1),
  (9710222, 9710116, FALSE, 'R2 q22', 'a', 'b', 1), (9710223, 9710116, FALSE, 'R2 q23', 'a', 'b', 1);

INSERT INTO assessment.spot_quiz_responses (id, spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct) VALUES
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
