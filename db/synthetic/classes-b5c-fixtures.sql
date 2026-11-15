/*
 * The classes REPORT fixtures of batch B5c (pending, TSR at a glance, students) for the new API's database. tools/parity-php/classes-b5c-fixtures.sql holds the same rows for the PHP parity stack. Loaded last by
 * tools/classes-contract.sh before every run; resets every row it owns by token and id. Read-only for the files (reports write nothing). Synthetic only: tokens 901901 to 901999, emails rc.<token>@example.invalid,
 * classes 9564 to 9568 (a free gap below the classes the other fixtures and class-create use), language 9 (so the seeded standard MCQs of either side never match them), spot quizzes, questions and responses
 * 961401 and up, standard MCQs 961701 and up, sessions 961201 and up. Every date is fixed in October and November 2025 and the files ask for those ranges explicitly. Callers from earlier fixtures: "admin" (role 1),
 * 900501 (gents admin) and 900502 (ladies admin).
 *
 *   901901 a class coordinator (role 5) assigned the classes 9564, 9565 (gents) and 9567 (ladies): no gender lock. New API: two rules (gents and ladies classes of the city "B5cville"); PHP: class_access rows. Compared in full.
 *   901911 teacher (gents) of 9564, 9565   901912 teacher (gents) of 9566 and the closed 9568   901913 teacher (LADIES member) of 9567   901921 to 901928 students
 *   9564 gents MIQDAD, Mondays and Thursdays   9565 gents ABUZAR, Tuesdays   9566 gents SALMAN, city B5celsewhere (outside the coordinator's reach), Wednesdays   9567 ladies MIQDAD, Wednesdays   9568 gents MIQDAD, closed
 *   Standard MCQs of MIQDAD in language 9: B5C-M1, B5C-M2, B5C-M3 and a deleted B5C-M4; of ABUZAR: B5C-A1. 9564 copied M1 (twice, published; a third copy deactivated) and M2 (not published); 9567 copied "b5c-m1" (published)
 *   and M2 (not published); 9568 copied M1.
 *   Students: 901921 (9564), 901922 (9564 and 9565), 901923 (left 9564), 901924 (9564, status I but not removed), 901925 (ladies, 9567), 901926 (9567, member gender gents), 901927 (closed 9568), 901928 (9566)
 */
INSERT INTO identity.users (token, email)
SELECT v.token, 'rc.' || v.token || '@example.invalid' FROM (VALUES
  (901901), (901911), (901912), (901913), (901921), (901922), (901923), (901924), (901925), (901926), (901927), (901928)
) AS v (token)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

UPDATE identity.users u SET email = 'rc.' || u.token || '@example.invalid' WHERE u.token BETWEEN 901901 AND 901999 AND u.email <> 'rc.' || u.token || '@example.invalid';

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id, 'Rc Member ' || v.token, CASE WHEN v.token IN (901913, 901925) THEN '2' ELSE '1' END, '+91000019' || right(v.token::text, 4) FROM (VALUES
  (901901), (901911), (901912), (901913), (901921), (901922), (901923), (901924), (901925), (901926), (901927), (901928)
) AS v (token)
JOIN identity.users u ON u.token = v.token
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token = 901901);
INSERT INTO access.user_roles (user_id, roleid) SELECT id, 5 FROM identity.users WHERE token = 901901;

DELETE FROM access.class_access_rule_conditions WHERE rule_id IN (961001, 961002);
DELETE FROM access.class_access_rules WHERE id IN (961001, 961002);
INSERT INTO access.class_access_rules (id, token, gender, note, created_at) VALUES
  (961001, 901901, 1, 'Rc gents classes of B5cville', now()), (961002, 901901, 2, 'Rc ladies classes of B5cville', now());
INSERT INTO access.class_access_rule_conditions (rule_id, field, negate, value) VALUES (961001, 'city', false, 'B5cville'), (961002, 'city', false, 'B5cville');

DELETE FROM assessment.spot_quiz_responses WHERE spot_quiz_id BETWEEN 961401 AND 961499;
DELETE FROM assessment.spot_quiz_questions WHERE spot_quiz_id BETWEEN 961401 AND 961499;
DELETE FROM assessment.spot_quizzes WHERE id BETWEEN 961401 AND 961499;
DELETE FROM assessment.standard_mcqs WHERE id BETWEEN 961701 AND 961799;
DELETE FROM classes.class_attendance WHERE session_id IN (SELECT id FROM classes.class_sessions WHERE class_id BETWEEN 9564 AND 9568);
DELETE FROM classes.class_sessions WHERE class_id BETWEEN 9564 AND 9568;
DELETE FROM classes.class_schedules WHERE class_id BETWEEN 9564 AND 9568;
DELETE FROM classes.class_students WHERE class_id BETWEEN 9564 AND 9568;
DELETE FROM classes.classes WHERE id BETWEEN 9564 AND 9568;

INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (9564, 'RC-G-564', 9, 'rclnk9564', 'Rc Class One', 3, DATE '2025-01-06', 901911, 1, 'Offline', 'B5cville', 'India', 'Rc Hall', 'A', 900315),
  (9565, 'RC-G-565', 9, 'rclnk9565', 'Rc Class Two', 2, DATE '2025-01-06', 901911, 1, 'Offline', 'B5cville', 'India', 'Rc Hall', 'A', 900315),
  (9566, 'RC-G-566', 9, 'rclnk9566', 'Rc Class Three', 1, DATE '2025-01-06', 901912, 1, 'Offline', 'B5celsewhere', 'India', 'Rc Hall', 'A', 900315),
  (9567, 'RC-L-567', 9, 'rclnk9567', 'Rc Ladies Class', 3, DATE '2025-01-06', 901913, 2, 'Offline', 'B5cville', 'India', 'Rc Hall', 'A', 900315),
  (9568, 'RC-G-568', 9, 'rclnk9568', 'Rc Closed Class', 3, DATE '2025-01-06', 901912, 1, 'Offline', 'B5cville', 'India', 'Rc Hall', 'I', 900315);

INSERT INTO classes.class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) VALUES
  (961001, 9564, 2, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL), (961002, 9564, 5, 19, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (961003, 9565, 3, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL), (961004, 9566, 4, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL),
  (961005, 9567, 4, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL), (961006, 9568, 2, 18, 0, 'Asia/Kolkata', 900315, NULL, NULL);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (961101, 9564, 901921, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (961102, 9564, 901922, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (961103, 9564, 901923, DATE '2025-01-06', 0, TIMESTAMPTZ '2025-10-15 00:00:00+00', 'Rc left', 900315, 'I'),
  (961104, 9564, 901924, DATE '2025-01-06', 0, NULL, NULL, NULL, 'I'),
  (961105, 9565, 901922, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (961106, 9566, 901928, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (961107, 9567, 901925, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (961108, 9567, 901926, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (961109, 9568, 901927, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A');
UPDATE classes.class_students SET created_at = joined_on + TIME '08:00' AT TIME ZONE 'UTC' WHERE class_id BETWEEN 9564 AND 9568;

INSERT INTO classes.class_sessions (id, class_id, teacher, conducted_on, conducted, non_conduction_reason, duration, attendance, created_by, created_at) VALUES
  (961201, 9564, 901911, DATE '2025-10-02', 1, NULL, 45, NULL, 901911, TIMESTAMPTZ '2025-10-02 12:00:00+00'),
  (961202, 9564, 901911, DATE '2025-10-06', 1, NULL, 45, NULL, 901911, TIMESTAMPTZ '2025-10-06 12:00:00+00'),
  (961203, 9564, 901911, DATE '2025-10-13', 1, NULL, 45, NULL, 901911, TIMESTAMPTZ '2025-10-13 12:00:00+00'),
  (961204, 9564, 901911, DATE '2025-10-20', 0, 'Rc rain', NULL, NULL, 901911, TIMESTAMPTZ '2025-10-20 12:00:00+00'),
  (961205, 9564, 901911, DATE '2025-10-27', 1, NULL, 45, NULL, 901911, TIMESTAMPTZ '2025-10-27 12:00:00+00'),
  (961206, 9564, 901911, DATE '2025-11-03', 1, NULL, 45, NULL, 901911, TIMESTAMPTZ '2025-11-03 12:00:00+00'),
  (961211, 9565, 901911, DATE '2025-10-07', 1, NULL, 30, NULL, 901911, TIMESTAMPTZ '2025-10-07 12:00:00+00'),
  (961212, 9565, 901911, DATE '2025-10-14', 1, NULL, 30, NULL, 901911, TIMESTAMPTZ '2025-10-14 12:00:00+00'),
  (961221, 9566, 901912, DATE '2025-10-06', 1, NULL, 30, NULL, 901912, TIMESTAMPTZ '2025-10-06 12:00:00+00'),
  (961231, 9567, 901913, DATE '2025-10-08', 1, NULL, 30, NULL, 901913, TIMESTAMPTZ '2025-10-08 12:00:00+00'),
  (961232, 9567, 901913, DATE '2025-10-15', 1, NULL, 30, NULL, 901913, TIMESTAMPTZ '2025-10-15 12:00:00+00'),
  (961241, 9568, 901912, DATE '2025-10-10', 1, NULL, 30, NULL, 901912, TIMESTAMPTZ '2025-10-10 12:00:00+00');

INSERT INTO classes.class_attendance (id, session_id, token, name, extra_student, present, recitation) VALUES
  (961301, 961201, 901921, NULL, 0, 1, 3000), (961302, 961201, 901922, NULL, 0, 1, 0), (961303, 961201, 901924, NULL, 0, 1, 4000),
  (961304, 961202, 901921, NULL, 0, 1, 2000), (961305, 961202, 901922, NULL, 0, 0, 1000), (961306, 961202, 901923, NULL, 0, 1, 6000), (961307, 961202, 901924, NULL, 0, 0, 0),
  (961308, 961203, 901921, NULL, 0, 1, 0), (961309, 961204, 901921, NULL, 0, 1, 100000), (961310, 961205, 901921, NULL, 0, 0, 0), (961311, 961206, 901921, NULL, 0, 1, 5000),
  (961312, 961211, 901922, NULL, 0, 1, 0), (961313, 961212, 901922, NULL, 0, 1, 2000),
  (961314, 961221, 901928, NULL, 0, 0, 6000),
  (961315, 961231, 901925, NULL, 0, 1, 2000), (961316, 961231, 901926, NULL, 0, 1, 7000), (961317, 961232, 901925, NULL, 0, 1, 1000),
  (961318, 961241, 901927, NULL, 0, 1, 9000);

INSERT INTO assessment.standard_mcqs (id, code, language_id, level_id, topic, subject, lesson, name, sort_order, created_by, deleted_at) VALUES
  (961701, 'B5C-M1', 9, 3, 'Rc topic', 'Rc subject', 'Rc lesson 1', 'Rc MCQ one', 1, 900315, NULL),
  (961702, 'B5C-M2', 9, 3, 'Rc topic', 'Rc subject', 'Rc lesson 2', 'Rc MCQ two', 2, 900315, NULL),
  (961703, 'B5C-M3', 9, 3, 'Rc topic', 'Rc subject', 'Rc lesson 3', 'Rc MCQ three', 3, 900315, NULL),
  (961704, 'B5C-M4', 9, 3, 'Rc topic', 'Rc subject', 'Rc lesson 4', 'Rc MCQ four (deleted)', 4, 900315, TIMESTAMPTZ '2025-09-01 00:00:00+00'),
  (961705, 'B5C-A1', 9, 2, 'Rc topic', 'Rc subject', 'Rc lesson 5', 'Rc MCQ five', 1, 900315, NULL);

INSERT INTO assessment.spot_quizzes (id, code, mcq_code, language_id, level_id, name, class_id, restrict_to_class, published_at, published_by, deactivated_at, created_by, created_at) VALUES
  (961401, 'RCQ961401', 'B5C-M1', 9, 3, 'Rc quiz one', 9564, 1, TIMESTAMPTZ '2025-10-10 10:00:00+00', 901911, NULL, 901911, TIMESTAMPTZ '2025-10-10 09:00:00+00'),
  (961402, 'RCQ961402', 'B5C-M1', 9, 3, 'Rc quiz two', 9564, 1, TIMESTAMPTZ '2025-10-20 10:00:00+00', 901911, NULL, 901911, TIMESTAMPTZ '2025-10-20 09:00:00+00'),
  (961403, 'RCQ961403', 'B5C-M1', 9, 3, 'Rc quiz three', 9564, 1, NULL, NULL, TIMESTAMPTZ '2025-10-25 00:00:00+00', 901911, TIMESTAMPTZ '2025-10-24 09:00:00+00'),
  (961404, 'RCQ961404', 'B5C-M2', 9, 3, 'Rc quiz four', 9564, 1, NULL, NULL, NULL, 901911, TIMESTAMPTZ '2025-10-21 09:00:00+00'),
  (961405, 'RCQ961405', NULL, 9, 3, 'Rc quiz five', 9564, 1, TIMESTAMPTZ '2025-11-05 12:00:00+00', 901911, NULL, 901911, TIMESTAMPTZ '2025-11-05 11:00:00+00'),
  (961406, 'RCQ961406', 'b5c-m1', 9, 3, 'Rc quiz six', 9567, 1, TIMESTAMPTZ '2025-10-12 10:00:00+00', 901913, NULL, 901913, TIMESTAMPTZ '2025-10-12 09:00:00+00'),
  (961407, 'RCQ961407', 'B5C-M2', 9, 3, 'Rc quiz seven', 9567, 1, NULL, NULL, NULL, 901913, TIMESTAMPTZ '2025-10-13 09:00:00+00'),
  (961408, 'RCQ961408', 'B5C-M1', 9, 3, 'Rc quiz eight', 9568, 1, TIMESTAMPTZ '2025-10-11 10:00:00+00', 901912, NULL, 901912, TIMESTAMPTZ '2025-10-11 09:00:00+00');
INSERT INTO assessment.spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, answer) VALUES
  (961501, 961401, FALSE, 'Rc q1', 'a', 'b', 1), (961502, 961401, FALSE, 'Rc q2', 'a', 'b', 1), (961503, 961401, FALSE, 'Rc q3', 'a', 'b', 1),
  (961504, 961402, FALSE, 'Rc q4', 'a', 'b', 1), (961505, 961402, FALSE, 'Rc q5', 'a', 'b', 1),
  (961506, 961405, FALSE, 'Rc q6', 'a', 'b', 1),
  (961507, 961406, FALSE, 'Rc q7', 'a', 'b', 1), (961508, 961406, FALSE, 'Rc q8', 'a', 'b', 1),
  (961509, 961408, FALSE, 'Rc q9', 'a', 'b', 1);
INSERT INTO assessment.spot_quiz_responses (id, spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct) VALUES
  (961601, 961401, 961501, 901921, 'a', 'a', 1), (961602, 961401, 961502, 901921, 'a', 'a', 1), (961603, 961401, 961503, 901921, 'b', 'a', 0),
  (961604, 961402, 961504, 901921, 'a', 'a', 1), (961605, 961402, 961505, 901921, 'a', 'a', 1),
  (961606, 961405, 961506, 901921, 'a', 'a', 1),
  (961607, 961401, 961501, 901922, 'a', 'a', 1), (961608, 961401, 961502, 901922, 'b', 'a', 0),
  (961609, 961406, 961507, 901925, 'a', 'a', 1), (961610, 961406, 961508, 901925, 'b', 'a', 0);

SELECT setval(pg_get_serial_sequence('classes.class_students', 'id'), greatest((SELECT max(id) FROM classes.class_students), 961199));
SELECT setval(pg_get_serial_sequence('classes.class_sessions', 'id'), greatest((SELECT max(id) FROM classes.class_sessions), 1));
SELECT setval(pg_get_serial_sequence('classes.class_attendance', 'id'), greatest((SELECT max(id) FROM classes.class_attendance), 1));
SELECT setval(pg_get_serial_sequence('assessment.spot_quizzes', 'id'), greatest((SELECT max(id) FROM assessment.spot_quizzes), 1));
SELECT setval(pg_get_serial_sequence('assessment.standard_mcqs', 'id'), greatest((SELECT max(id) FROM assessment.standard_mcqs), 1));
