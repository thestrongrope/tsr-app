/*
 * The quizwrites fixtures (test lane 2: the eight assessment routes that create, copy, score, enter offline, print and publish a class's quizzes) for the new API's database.
 * tools/parity-php/quizwrites-fixtures.sql holds the same rows for the PHP parity stack. Loaded by tools/contract-quizwrites.sh before every run; resets every row it owns (everything of the classes 98200 to 98299,
 * including the quizzes, questions, answers and notifications a run created). Synthetic only: tokens 922001 to 922021, emails qw.<token>@example.invalid (922011 is the placeholder 922011@thestrongrope.com: an "offline" student),
 * classes 98201 to 98205 (language 7, level 3), enrolments 9720301 and up, quizzes 9720001 to 9720013, submissions 9720401 and up, questions 9720501 and up, answers 9720601 and up, standard MCQs 9720101 and up (codes QW-S*).
 *
 *   922001 teacher of 98201 and 98202   922002 class admin (mcq_admin) of 98201   922003 plain student of 98201   922004 teacher of 98203 and 98205   922005 class admin of 98201 who was REMOVED
 *   922006 student of 98203 only   922007 super admin   922008 gents admin (role 3)   922009 ladies admin (role 4)   922010 nobody   922011 offline student of 98201 (email @thestrongrope.com)
 *   922012 student of 98201 who answered quizzes 9720002 and 9720004 ON THEIR PHONE (answers, no submission row)   922013, 922014 students of 98201 (offline save targets)   922015 student of 98201 with an offline submission on 9720002 and 9720003
 *   922016 student REMOVED from 98201   922017 class admin of 98203   922018 current student of 98202   922019 removed student of 98202   922020, 922021 two members called "Qw Twin" (answered 9720001; in no class)
 *   98201 (gents, active): 9720001 scores (published, 3 questions, answered by 922003, 922012, the twins and a token without a user row)   9720002 offline GET (published; orders: none, '3,1,2', a blank option)
 *        9720003 offline save   9720004 offline save, phone-answered   9720005 sheet (markup and Arabic)   9720006 sheet with no questions   9720007 publish target   9720009 copy source (a copy of QW-S1)   9720011 copy source (duplicate in 98202)
 *   98202 (gents, active): 9720008 publish target (twice)   9720010 same name and topic as 9720011 (topic in another case)   98203 (gents, teacher 922004)   98204 (gents, CLOSED): 9720012   98205 (LADIES, teacher 922004): 9720013
 *   standard MCQs (level 99, language 99, so no real class lists them and another lane's standard lists stay as they were): QW-S1 (2 questions), QW-S2 (1 question)
 */
INSERT INTO identity.users (token, email)
SELECT v.token, CASE WHEN v.token = 922011 THEN '922011@thestrongrope.com' ELSE 'qw.' || v.token || '@example.invalid' END FROM (VALUES
  (922001), (922002), (922003), (922004), (922005), (922006), (922007), (922008), (922009), (922010), (922011), (922012), (922013), (922014), (922015), (922016), (922017), (922018), (922019), (922020), (922021)
) AS v (token)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id, CASE WHEN v.token IN (922020, 922021) THEN 'Qw Twin' ELSE 'Qw Member ' || v.token END, CASE WHEN v.token = 922009 THEN '2' ELSE '1' END, '+91000092' || right(v.token::text, 4) FROM (VALUES
  (922001), (922002), (922003), (922004), (922005), (922006), (922007), (922008), (922009), (922010), (922011), (922012), (922013), (922014), (922015), (922016), (922017), (922018), (922019), (922020), (922021)
) AS v (token)
JOIN identity.users u ON u.token = v.token
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 922001 AND 922021);
INSERT INTO access.user_roles (user_id, roleid) SELECT id, 1 FROM identity.users WHERE token = 922007;
INSERT INTO access.user_roles (user_id, roleid) SELECT id, 3 FROM identity.users WHERE token = 922008;
INSERT INTO access.user_roles (user_id, roleid) SELECT id, 4 FROM identity.users WHERE token = 922009;

DELETE FROM notifications.user_notifications WHERE notification_id IN (SELECT notification_id FROM notifications.notifications WHERE created_by BETWEEN 922000 AND 922999);
DELETE FROM notifications.notifications WHERE created_by BETWEEN 922000 AND 922999;
DELETE FROM platform.outbound_messages WHERE created_by BETWEEN 922000 AND 922999;
DELETE FROM assessment.spot_quiz_submissions WHERE spot_quiz_id IN (SELECT id FROM assessment.spot_quizzes WHERE class_id BETWEEN 98200 AND 98299);
DELETE FROM assessment.spot_quiz_responses WHERE spot_quiz_id IN (SELECT id FROM assessment.spot_quizzes WHERE class_id BETWEEN 98200 AND 98299);
DELETE FROM assessment.spot_quiz_questions WHERE spot_quiz_id IN (SELECT id FROM assessment.spot_quizzes WHERE class_id BETWEEN 98200 AND 98299);
DELETE FROM assessment.spot_quizzes WHERE class_id BETWEEN 98200 AND 98299;
DELETE FROM assessment.standard_mcq_questions WHERE mcq_code LIKE 'QW-S%';
DELETE FROM assessment.standard_mcqs WHERE code LIKE 'QW-S%';
DELETE FROM classes.class_students WHERE class_id BETWEEN 98200 AND 98299;
DELETE FROM classes.classes WHERE id BETWEEN 98200 AND 98299;

INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (98201, 'QW-G-201', 7, 'qwlnk98201', 'Qw Class Main', 3, DATE '2025-01-06', 922001, 1, 'Offline', 'Qwville', 'India', 'Qw Hall', 'A', 900315),
  (98202, 'QW-G-202', 7, 'qwlnk98202', 'Qw Class Second', 3, DATE '2025-01-06', 922001, 1, 'Offline', 'Qwville', 'India', 'Qw Hall', 'A', 900315),
  (98203, 'QW-G-203', 7, 'qwlnk98203', 'Qw Class Other', 3, DATE '2025-01-06', 922004, 1, 'Offline', 'Qwville', 'India', 'Qw Hall', 'A', 900315),
  (98204, 'QW-G-204', 7, 'qwlnk98204', 'Qw Class Closed', 3, DATE '2025-01-06', 922001, 1, 'Offline', 'Qwville', 'India', 'Qw Hall', 'I', 900315),
  (98205, 'QW-L-205', 7, 'qwlnk98205', 'Qw Ladies Class', 3, DATE '2025-01-06', 922004, 2, 'Offline', 'Qwville', 'India', 'Qw Hall', 'A', 900315);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9720301, 98201, 922002, DATE '2025-01-06', 1, NULL, NULL, NULL, 'A'),
  (9720302, 98201, 922003, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9720303, 98201, 922005, DATE '2025-01-06', 1, TIMESTAMPTZ '2026-01-12 00:00:00+00', 'Qw left', 900315, 'I'),
  (9720304, 98201, 922011, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9720305, 98201, 922012, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9720306, 98201, 922013, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9720307, 98201, 922014, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9720308, 98201, 922015, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9720309, 98201, 922016, DATE '2025-01-06', 0, TIMESTAMPTZ '2026-01-12 00:00:00+00', 'Qw left', 900315, 'I'),
  (9720310, 98202, 922018, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9720311, 98202, 922019, DATE '2025-01-06', 0, TIMESTAMPTZ '2026-01-12 00:00:00+00', 'Qw left', 900315, 'I'),
  (9720312, 98203, 922006, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9720313, 98203, 922017, DATE '2025-01-06', 1, NULL, NULL, NULL, 'A');

INSERT INTO assessment.standard_mcqs (id, code, language_id, level_id, topic, subject, lesson, name, sort_order, created_by, deleted_at) VALUES
  (9720101, 'QW-S1', 99, 99, 'Qw Topic Beta', 'Qw Subject Two', 'Qw lesson 1', 'Qw standard one', 1, 900315, NULL),
  (9720102, 'QW-S2', 99, 99, 'Qw Topic Alpha', 'Qw Subject One', 'Qw lesson 2', 'Qw standard two', 2, 900315, NULL);

INSERT INTO assessment.standard_mcq_questions (id, mcq_code, question, answer, option1, option2, option3, sort_order, created_by) VALUES
  (9720111, 'QW-S1', 'S1 q1', 'Right1', 'Wrong1a', 'Wrong1b', NULL, 1, 900315),
  (9720112, 'QW-S1', 'S1 q2', 'Right2', 'Wrong2a', NULL, NULL, 2, 900315),
  (9720113, 'QW-S2', 'S2 q1', 'Right3', 'Wrong3a', 'Wrong3b', 'Wrong3c', 1, 900315);

INSERT INTO assessment.spot_quizzes (id, code, mcq_code, name, topic, published_at, published_by, deactivated_at, created_by, class_id, language_id, level_id, restrict_to_class, created_at) VALUES
  (9720001, 'QWQ9720001', NULL, 'Qw Scores', 'Qw topic scores', TIMESTAMPTZ '2026-01-10 10:00:00+00', 922001, NULL, 922001, 98201, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (9720002, 'QWQ9720002', NULL, 'Qw Offline Read', 'Qw topic offline', TIMESTAMPTZ '2026-01-10 10:00:00+00', 922001, NULL, 922001, 98201, 9, 3, 1, TIMESTAMPTZ '2026-01-02 09:00:00+00'),
  (9720003, 'QWQ9720003', NULL, 'Qw Offline Save', 'Qw topic offline', TIMESTAMPTZ '2026-01-10 10:00:00+00', 922001, NULL, 922001, 98201, 9, 3, 1, TIMESTAMPTZ '2026-01-03 09:00:00+00'),
  (9720004, 'QWQ9720004', NULL, 'Qw Offline Phone', 'Qw topic offline', TIMESTAMPTZ '2026-01-10 10:00:00+00', 922001, NULL, 922001, 98201, 9, 3, 1, TIMESTAMPTZ '2026-01-04 09:00:00+00'),
  (9720005, 'QWQ9720005', NULL, 'Qw Sheet <b>"x"</b>', 'Qw topic sheet', NULL, NULL, NULL, 922001, 98201, 9, 3, 1, TIMESTAMPTZ '2026-01-05 09:00:00+00'),
  (9720006, 'QWQ9720006', NULL, 'Qw Sheet Empty', 'Qw topic sheet', NULL, NULL, NULL, 922001, 98201, 9, 3, 1, TIMESTAMPTZ '2026-01-06 09:00:00+00'),
  (9720007, 'QWQ9720007', NULL, 'Qw Publish A', 'Qw topic publish', NULL, NULL, NULL, 922001, 98201, 9, 3, 1, TIMESTAMPTZ '2026-01-07 09:00:00+00'),
  (9720008, 'QWQ9720008', NULL, 'Qw Publish B', NULL, NULL, NULL, NULL, 922001, 98202, 9, 3, 1, TIMESTAMPTZ '2026-01-08 09:00:00+00'),
  (9720009, 'QWQ9720009', 'QW-S1', 'Qw Copy Source', 'Qw copy topic', NULL, NULL, NULL, 922001, 98201, 9, 3, 0, TIMESTAMPTZ '2026-01-09 09:00:00+00'),
  (9720010, 'QWQ9720010', NULL, 'Qw Dup Source', 'QW DUP TOPIC', NULL, NULL, NULL, 922001, 98202, 9, 3, 1, TIMESTAMPTZ '2026-01-09 10:00:00+00'),
  (9720011, 'QWQ9720011', NULL, 'Qw Dup Source', 'Qw dup topic', NULL, NULL, NULL, 922001, 98201, 9, 3, 1, TIMESTAMPTZ '2026-01-09 11:00:00+00'),
  (9720012, 'QWQ9720012', NULL, 'Qw Closed Class Quiz', 'Qw topic closed', NULL, NULL, NULL, 922001, 98204, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00'),
  (9720013, 'QWQ9720013', NULL, 'Qw Ladies Quiz', 'Qw topic ladies', NULL, NULL, NULL, 922004, 98205, 9, 3, 1, TIMESTAMPTZ '2026-01-01 09:00:00+00');

INSERT INTO assessment.spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, option3, option4, option5, answer, option_display_order) VALUES
  (9720501, 9720001, false, 'Qw score q1', 'Right a', 'Wrong b', NULL, NULL, NULL, 1, NULL),
  (9720502, 9720001, false, 'Qw score q2', 'Right x', 'Wrong y', NULL, NULL, NULL, 1, NULL),
  (9720503, 9720001, false, 'Qw score q3', 'Right m', 'Wrong n', NULL, NULL, NULL, 1, NULL),
  (9720504, 9720002, false, 'Qw offline q1', 'Right a', 'Wrong b', 'Wrong c', 'Wrong d', NULL, 1, NULL),
  (9720505, 9720002, false, 'Qw offline q2', 'Right x', 'Wrong y', 'Wrong z', NULL, NULL, 1, '3,1,2'),
  (9720506, 9720002, false, 'Qw offline q3', 'Right m', '', 'Wrong n', NULL, 'Wrong five', 1, NULL),
  (9720507, 9720003, false, 'Qw save q1', 'Right a', 'Wrong b', NULL, NULL, NULL, 1, NULL),
  (9720508, 9720003, false, 'Qw save q2', 'Right x', 'Wrong y', NULL, NULL, NULL, 1, NULL),
  (9720509, 9720003, false, 'Qw save q3', 'Right m', 'Wrong n', NULL, NULL, NULL, 1, NULL),
  (9720510, 9720004, false, 'Qw phone q1', 'Right a', 'Wrong b', NULL, NULL, NULL, 1, NULL),
  (9720511, 9720004, false, 'Qw phone q2', 'Right x', 'Wrong y', NULL, NULL, NULL, 1, NULL),
  (9720512, 9720005, false, 'Qw <script>alert("1")</script> & ''quote''', 'Right <i>a</i>', 'Wrong "b"', 'Wrong & c', 'ما هو الجواب؟', NULL, 1, NULL),
  (9720513, 9720005, true, 'ما هو؟', 'نعم', 'لا', NULL, NULL, NULL, 1, NULL),
  (9720514, 9720007, false, 'Qw publish q1', 'Right a', 'Wrong b', 'Wrong c', NULL, NULL, 1, NULL),
  (9720515, 9720007, false, 'Qw publish q2', 'Right x', 'Wrong y', NULL, NULL, NULL, 1, NULL),
  (9720516, 9720009, true, 'Qw copy q1', 'Right a', 'Wrong b', 'Wrong c', 'Wrong d', 'Wrong e', 1, '2,1'),
  (9720517, 9720009, false, 'Qw copy q2', 'Right x', 'Wrong y', NULL, NULL, NULL, 1, NULL),
  (9720518, 9720011, false, 'Qw dup q1', 'Right a', 'Wrong b', NULL, NULL, NULL, 1, NULL),
  (9720519, 9720008, false, 'Qw publish b q1', 'Right a', 'Wrong b', NULL, NULL, NULL, 1, NULL);

INSERT INTO assessment.spot_quiz_submissions (id, spot_quiz_id, token, created_at, modified_at) VALUES
  (9720401, 9720002, 922015, TIMESTAMPTZ '2026-02-01 09:00:00+00', TIMESTAMPTZ '2026-02-01 09:00:00+00'),
  (9720402, 9720003, 922015, TIMESTAMPTZ '2026-02-01 09:00:00+00', TIMESTAMPTZ '2026-02-01 09:00:00+00');

INSERT INTO assessment.spot_quiz_responses (id, spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct, created_at) VALUES
  (9720601, 9720001, 9720501, 922003, 'Right a', 'Right a', 1, TIMESTAMPTZ '2026-02-01 09:00:01+00'),
  (9720602, 9720001, 9720502, 922003, 'Wrong y', 'Right x', 0, TIMESTAMPTZ '2026-02-01 09:00:02+00'),
  (9720603, 9720001, 9720503, 922003, 'Right m', 'Right m', 1, TIMESTAMPTZ '2026-02-01 09:00:03+00'),
  (9720604, 9720001, 9720501, 922012, 'Right a', 'Right a', 1, TIMESTAMPTZ '2026-02-02 09:00:01+00'),
  (9720605, 9720001, 9720502, 922012, 'Right x', 'Right x', 1, TIMESTAMPTZ '2026-02-02 09:00:02+00'),
  (9720606, 9720001, 9720503, 922012, 'Right m', 'Right m', 1, TIMESTAMPTZ '2026-02-02 09:00:03+00'),
  (9720607, 9720001, 9720501, 922020, 'Right a', 'Right a', 1, TIMESTAMPTZ '2026-02-03 09:00:01+00'),
  (9720608, 9720001, 9720502, 922020, 'Right x', 'Right x', 1, TIMESTAMPTZ '2026-02-03 09:00:02+00'),
  (9720609, 9720001, 9720501, 922021, 'Wrong b', 'Right a', 0, TIMESTAMPTZ '2026-02-03 09:00:03+00'),
  (9720610, 9720001, 9720501, 922099, 'Right a', 'Right a', 1, TIMESTAMPTZ '2026-02-04 09:00:01+00'),
  (9720611, 9720002, 9720504, 922012, 'Right a', 'Right a', 1, TIMESTAMPTZ '2026-02-01 09:00:01+00'),
  (9720612, 9720003, 9720507, 922015, 'Right a', 'Right a', 1, TIMESTAMPTZ '2026-02-01 09:00:01+00'),
  (9720613, 9720003, 9720508, 922015, NULL, 'Right x', 0, TIMESTAMPTZ '2026-02-01 09:00:01+00'),
  (9720614, 9720003, 9720509, 922015, NULL, 'Right m', 0, TIMESTAMPTZ '2026-02-01 09:00:01+00'),
  (9720615, 9720004, 9720510, 922012, 'Right a', 'Right a', 1, TIMESTAMPTZ '2026-02-01 09:00:01+00'),
  (9720616, 9720004, 9720511, 922012, 'Wrong y', 'Right x', 0, TIMESTAMPTZ '2026-02-01 09:00:02+00');

SELECT setval(pg_get_serial_sequence('assessment.spot_quiz_responses', 'id'), greatest((SELECT max(id) FROM assessment.spot_quiz_responses), 1));
SELECT setval(pg_get_serial_sequence('assessment.spot_quiz_submissions', 'id'), greatest((SELECT max(id) FROM assessment.spot_quiz_submissions), 1));
SELECT setval(pg_get_serial_sequence('assessment.spot_quizzes', 'id'), greatest((SELECT max(id) FROM assessment.spot_quizzes), 1));
SELECT setval(pg_get_serial_sequence('assessment.spot_quiz_questions', 'id'), greatest((SELECT max(id) FROM assessment.spot_quiz_questions), 1));
SELECT setval(pg_get_serial_sequence('assessment.standard_mcqs', 'id'), greatest((SELECT max(id) FROM assessment.standard_mcqs), 1));
SELECT setval(pg_get_serial_sequence('assessment.standard_mcq_questions', 'id'), greatest((SELECT max(id) FROM assessment.standard_mcq_questions), 1));
SELECT setval(pg_get_serial_sequence('classes.class_students', 'id'), greatest((SELECT max(id) FROM classes.class_students), 1));
