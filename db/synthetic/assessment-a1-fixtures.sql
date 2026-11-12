/*
 * The assessment A1 fixtures (a member takes a quiz and reads scores) for the new API's database. tools/parity-php/assessment-a1-fixtures.sql holds the same rows for the PHP parity stack.
 * Loaded by tools/assessment-contract.sh before every run; resets every row it owns, so the submit file can run again. Synthetic only: tokens 902401 to 902499, emails qz.<token>@example.invalid,
 * classes 9621 to 9624 (city A1ville, language 9), enrolments 962301 and up, quizzes 962401 to 962499 (code A1Q<id>), questions 962501 and up, responses 962601 and up.
 *
 *   902401 reader (classes 9621 and 9624): answered 962401 (3 of 4), 962404 (2 of 2, deactivated now), 962406 (0 of 2)   902402 fresh (9621, answered nothing)   902403 left 9621 (removed)   902404 enrolment status I
 *   902409 student of 9623 who answered nothing   902405 stranger (no class)   902406 teacher of 9621 to 9624   902407 enrolled in 9621, no gender, answered 962401 (4 of 4)   902408 student of the closed class 9623
 *   902410 parent of 902401 (active)   902411 parent of 902401 (revoked)   902412 parent of 902402   902413 parent of 902403 (removed from 9621)   902414 parent of 902405 (no class)
 *   902421 to 902429 students of the submit class 9622, one per case of the submit files (a file that answers a quiz as a member is the only one that does)
 *   9621 quizzes: 962401 answered, 962402 open (5 options, Arabic, a blank option), 962403 draft, 962404 deactivated and answered, 962405 deactivated, 962406 zero score, 962407 no questions
 *   9624: 962411 open   9623 (closed class): 962421   9622 (submit): 962431 plain, 962432 duplicate, 962433 invalid, 962434 deactivated, 962435 draft, 962436 no questions, 962437 scoring, 962438 odd input
 */
INSERT INTO identity.users (token, email)
SELECT v.token, 'qz.' || v.token || '@example.invalid' FROM (VALUES
  (902401), (902402), (902403), (902404), (902405), (902406), (902407), (902408), (902409), (902410), (902411), (902412), (902413), (902414), (902421), (902422), (902423), (902424), (902425), (902426), (902427), (902428), (902429)
) AS v (token)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

UPDATE identity.users u SET email = 'qz.' || u.token || '@example.invalid' WHERE u.token BETWEEN 902401 AND 902499 AND u.email <> 'qz.' || u.token || '@example.invalid';

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id, 'Qz Member ' || v.token, v.gender, '+91000024' || right(v.token::text, 4) FROM (VALUES
  (902401, '1'),
  (902402, '1'),
  (902403, '1'),
  (902404, '1'),
  (902405, '1'),
  (902406, '1'),
  (902407, NULL),
  (902408, '1'),
  (902409, '1'),
  (902410, '1'),
  (902411, '1'),
  (902412, '1'),
  (902413, '1'),
  (902414, '1'),
  (902421, '1'),
  (902422, '1'),
  (902423, '1'),
  (902424, '1'),
  (902425, '1'),
  (902426, '1'),
  (902427, '1'),
  (902428, '1'),
  (902429, '1')
) AS v (token, gender)
JOIN identity.users u ON u.token = v.token
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

DELETE FROM assessment.spot_quiz_responses WHERE spot_quiz_id BETWEEN 962401 AND 962499;
DELETE FROM assessment.spot_quiz_questions WHERE spot_quiz_id BETWEEN 962401 AND 962499;
DELETE FROM assessment.spot_quizzes WHERE id BETWEEN 962401 AND 962499;
DELETE FROM classes.class_students WHERE class_id BETWEEN 9621 AND 9629;
DELETE FROM classes.classes WHERE id BETWEEN 9621 AND 9629;

INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (9621, 'A1-G-621', 9, 'a1lnk9621', 'A1 Class Live', 3, DATE '2025-01-06', 902406, 1, 'Offline', 'A1ville', 'India', 'A1 Hall', 'A', 900315),
  (9622, 'A1-G-622', 9, 'a1lnk9622', 'A1 Submit Class', 3, DATE '2025-01-06', 902406, 1, 'Offline', 'A1ville', 'India', 'A1 Hall', 'A', 900315),
  (9623, 'A1-G-623', 9, 'a1lnk9623', 'A1 Closed Class', 3, DATE '2025-01-06', 902406, 1, 'Offline', 'A1ville', 'India', 'A1 Hall', 'I', 900315),
  (9624, 'A1-G-624', 9, 'a1lnk9624', 'A1 Second Class', 3, DATE '2025-01-06', 902406, 1, 'Offline', 'A1ville', 'India', 'A1 Hall', 'A', 900315);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (962301, 9621, 902401, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (962302, 9621, 902402, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (962303, 9621, 902403, DATE '2025-01-06', 0, TIMESTAMPTZ '2026-01-12 00:00:00+00', 'A1 left', 900315, 'I'),
  (962304, 9621, 902404, DATE '2025-01-06', 0, NULL, NULL, NULL, 'I'),
  (962305, 9621, 902407, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (962306, 9624, 902401, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (962307, 9623, 902408, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (962308, 9623, 902409, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (962311, 9622, 902421, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (962312, 9622, 902422, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (962313, 9622, 902423, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (962314, 9622, 902424, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (962315, 9622, 902425, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (962316, 9622, 902426, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (962317, 9622, 902427, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (962318, 9622, 902428, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (962319, 9622, 902429, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A');

INSERT INTO assessment.spot_quizzes (id, code, mcq_code, name, topic, published_at, deactivated_at, created_by, class_id, language_id, level_id, restrict_to_class, created_at) VALUES
  (962401, 'A1Q962401', NULL, 'A1 Quiz Live Answered', 'A1 topic one', TIMESTAMPTZ '2026-01-10 10:00:00+00', NULL, 902406, 9621, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (962402, 'A1Q962402', NULL, 'A1 Quiz Live Open', NULL, TIMESTAMPTZ '2026-01-20 10:00:00+00', NULL, 902406, 9621, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (962403, 'A1Q962403', NULL, 'A1 Quiz Draft', 'A1 topic draft', NULL, NULL, 902406, 9621, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (962404, 'A1Q962404', NULL, 'A1 Quiz Deactivated Answered', 'A1 topic two', TIMESTAMPTZ '2026-01-05 10:00:00+00', TIMESTAMPTZ '2026-01-15 10:00:00+00', 902406, 9621, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (962405, 'A1Q962405', NULL, 'A1 Quiz Deactivated Open', NULL, TIMESTAMPTZ '2026-01-06 10:00:00+00', TIMESTAMPTZ '2026-01-16 10:00:00+00', 902406, 9621, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (962406, 'A1Q962406', NULL, 'A1 Quiz Zero Score', 'A1 topic three', TIMESTAMPTZ '2026-01-07 10:00:00+00', NULL, 902406, 9621, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (962407, 'A1Q962407', NULL, 'A1 Quiz No Questions', NULL, TIMESTAMPTZ '2026-01-08 10:00:00+00', NULL, 902406, 9621, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (962411, 'A1Q962411', NULL, 'A1 Second Class Quiz', NULL, TIMESTAMPTZ '2026-02-10 08:00:00+00', NULL, 902406, 9624, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (962421, 'A1Q962421', NULL, 'A1 Closed Class Quiz', NULL, TIMESTAMPTZ '2026-01-09 10:00:00+00', NULL, 902406, 9623, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (962431, 'A1Q962431', NULL, 'A1 Submit Plain', NULL, TIMESTAMPTZ '2026-01-10 10:00:00+00', NULL, 902406, 9622, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (962432, 'A1Q962432', NULL, 'A1 Submit Duplicate', NULL, TIMESTAMPTZ '2026-01-10 10:00:00+00', NULL, 902406, 9622, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (962433, 'A1Q962433', NULL, 'A1 Submit Invalid', NULL, TIMESTAMPTZ '2026-01-10 10:00:00+00', NULL, 902406, 9622, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (962434, 'A1Q962434', NULL, 'A1 Submit Deactivated', NULL, TIMESTAMPTZ '2026-01-10 10:00:00+00', TIMESTAMPTZ '2026-01-11 10:00:00+00', 902406, 9622, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (962435, 'A1Q962435', NULL, 'A1 Submit Draft', NULL, NULL, NULL, 902406, 9622, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (962436, 'A1Q962436', NULL, 'A1 Submit Empty', NULL, TIMESTAMPTZ '2026-01-10 10:00:00+00', NULL, 902406, 9622, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (962437, 'A1Q962437', NULL, 'A1 Submit Scoring', NULL, TIMESTAMPTZ '2026-01-10 10:00:00+00', NULL, 902406, 9622, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (962438, 'A1Q962438', NULL, 'A1 Submit Weird', NULL, TIMESTAMPTZ '2026-01-10 10:00:00+00', NULL, 902406, 9622, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00');

INSERT INTO assessment.spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, option3, option4, option5, answer) VALUES
  (962501, 962401, false, 'A1 q1', 'a', 'b', NULL, NULL, NULL, 1),
  (962502, 962401, false, 'A1 q2', 'a', 'b', NULL, NULL, NULL, 1),
  (962503, 962401, false, 'A1 q3', 'a', 'b', NULL, NULL, NULL, 1),
  (962504, 962401, false, 'A1 q4', 'a', 'b', NULL, NULL, NULL, 1),
  (962505, 962402, false, 'Which is first?', 'Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon', 3),
  (962506, 962402, true, 'ما هو؟', 'نعم', 'لا', NULL, NULL, NULL, 1),
  (962507, 962402, false, 'Solo?', 'Solo', '  ', NULL, NULL, NULL, 1),
  (962508, 962403, false, 'A1 draft q1', 'a', 'b', NULL, NULL, NULL, 1),
  (962509, 962403, false, 'A1 draft q2', 'a', 'b', NULL, NULL, NULL, 1),
  (962510, 962404, false, 'A1 deact q1', 'a', 'b', NULL, NULL, NULL, 1),
  (962511, 962404, false, 'A1 deact q2', 'a', 'b', NULL, NULL, NULL, 1),
  (962512, 962405, false, 'A1 deact open q1', 'a', 'b', NULL, NULL, NULL, 1),
  (962513, 962405, false, 'A1 deact open q2', 'a', 'b', NULL, NULL, NULL, 1),
  (962514, 962406, false, 'A1 zero q1', 'a', 'b', NULL, NULL, NULL, 1),
  (962515, 962406, false, 'A1 zero q2', 'a', 'b', NULL, NULL, NULL, 1),
  (962516, 962411, false, 'A1 second q1', 'a', 'b', NULL, NULL, NULL, 1),
  (962517, 962411, false, 'A1 second q2', 'a', 'b', NULL, NULL, NULL, 1),
  (962518, 962421, false, 'A1 closed q1', 'a', 'b', NULL, NULL, NULL, 1),
  (962531, 962431, false, 'First?', 'Alpha', 'Beta', 'Gamma', NULL, NULL, 1),
  (962532, 962431, false, 'Colour?', 'Red', 'Green', 'Blue', NULL, NULL, 2),
  (962533, 962431, true, 'عربي؟', 'نعم', 'لا', NULL, NULL, NULL, 1),
  (962534, 962432, false, 'A1 dup q1', 'a', 'b', NULL, NULL, NULL, 1),
  (962535, 962432, false, 'A1 dup q2', 'a', 'b', NULL, NULL, NULL, 1),
  (962536, 962433, false, 'A1 invalid q1', 'a', 'b', NULL, NULL, NULL, 1),
  (962537, 962433, false, 'A1 invalid q2', 'a', 'b', NULL, NULL, NULL, 1),
  (962538, 962434, false, 'A1 submit deact q1', 'a', 'b', NULL, NULL, NULL, 1),
  (962539, 962435, false, 'A1 submit draft q1', 'a', 'b', NULL, NULL, NULL, 1),
  (962540, 962437, false, 'Case?', 'Alpha', 'Beta', NULL, NULL, NULL, 1),
  (962541, 962437, false, 'Entity?', 'Rock&Roll', 'Other', NULL, NULL, NULL, 1),
  (962542, 962437, false, 'Number?', '1', '2', NULL, NULL, NULL, 1),
  (962543, 962437, true, 'Arabic?', 'نعم', 'لا', NULL, NULL, NULL, 1),
  (962544, 962437, false, 'Second option?', 'Coffee', 'Tea', NULL, NULL, NULL, 2),
  (962545, 962438, false, 'A1 weird q1', 'a', 'b', NULL, NULL, NULL, 1);

INSERT INTO assessment.spot_quiz_responses (id, spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct, created_at) VALUES
  (962601, 962401, 962501, 902401, 'a', 'a', 1, TIMESTAMPTZ '2026-02-01 09:00:01+00'),
  (962602, 962401, 962502, 902401, 'a', 'a', 1, TIMESTAMPTZ '2026-02-01 09:00:02+00'),
  (962603, 962401, 962503, 902401, 'b', 'a', 0, TIMESTAMPTZ '2026-02-01 09:00:03+00'),
  (962604, 962401, 962504, 902401, 'a', 'a', 1, TIMESTAMPTZ '2026-02-01 09:00:04+00'),
  (962605, 962404, 962510, 902401, 'a', 'a', 1, TIMESTAMPTZ '2026-02-02 10:00:00+00'),
  (962606, 962404, 962511, 902401, 'a', 'a', 1, TIMESTAMPTZ '2026-02-02 10:00:00+00'),
  (962607, 962406, 962514, 902401, 'b', 'a', 0, TIMESTAMPTZ '2026-02-03 11:00:00+00'),
  (962608, 962406, 962515, 902401, 'b', 'a', 0, TIMESTAMPTZ '2026-02-03 11:00:00+00'),
  (962611, 962401, 962501, 902407, 'a', 'a', 1, TIMESTAMPTZ '2026-02-04 09:00:01+00'),
  (962612, 962401, 962502, 902407, 'a', 'a', 1, TIMESTAMPTZ '2026-02-04 09:00:02+00'),
  (962613, 962401, 962503, 902407, 'a', 'a', 1, TIMESTAMPTZ '2026-02-04 09:00:03+00'),
  (962614, 962401, 962504, 902407, 'a', 'a', 1, TIMESTAMPTZ '2026-02-04 09:00:04+00'),
  (962615, 962421, 962518, 902408, 'a', 'a', 1, TIMESTAMPTZ '2026-02-05 09:00:00+00');

DELETE FROM membership.user_guardians WHERE parent_token BETWEEN 902401 AND 902499;
INSERT INTO membership.user_guardians (parent_token, child_token, relationship, status, source, code, expires_at, created_by, created_at, activated_at, revoked_by, revoked_at)
SELECT v.parent, v.child, 'father', v.status, 'token_entry', NULL, NULL, p.id, TIMESTAMPTZ '2026-01-10 09:00:00+00', TIMESTAMPTZ '2026-01-10 09:00:00+00',
       CASE WHEN v.status = 'revoked' THEN p.id END, CASE WHEN v.status = 'revoked' THEN TIMESTAMPTZ '2026-01-11 09:00:00+00' END
FROM (VALUES (902410, 902401, 'active'), (902411, 902401, 'revoked'), (902412, 902402, 'active'), (902413, 902403, 'active'), (902414, 902405, 'active')) AS v (parent, child, status)
JOIN identity.users p ON p.token = v.parent;

SELECT setval(pg_get_serial_sequence('assessment.spot_quiz_responses', 'id'), greatest((SELECT max(id) FROM assessment.spot_quiz_responses), 1));
SELECT setval(pg_get_serial_sequence('assessment.spot_quizzes', 'id'), greatest((SELECT max(id) FROM assessment.spot_quizzes), 1));
SELECT setval(pg_get_serial_sequence('assessment.spot_quiz_questions', 'id'), greatest((SELECT max(id) FROM assessment.spot_quiz_questions), 1));
SELECT setval(pg_get_serial_sequence('classes.class_students', 'id'), greatest((SELECT max(id) FROM classes.class_students), 1));
