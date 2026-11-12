/*
 * The quizwrites fixtures (test lane 2) for the PHP parity stack's MariaDB: the same rows as db/synthetic/quizwrites-fixtures.sql (read the header there for who is who).
 * Loaded by tools/contract-quizwrites.sh (inside the parity lock) before every run; resets every row it owns: everything of the classes 98200 to 98299 (quizzes a run created included) and the notifications of tokens 922000 to 922999.
 * Synthetic only: tokens 922001 to 922021, emails qw.<token>@example.invalid (922011 is 922011@thestrongrope.com), classes 98201 to 98205, ids 97<2>xxxx.
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, IF(v.token = 922011, '922011@thestrongrope.com', CONCAT('qw.', v.token, '@example.invalid')), 0, 'firebase', NOW(), IF(v.token IN (922020, 922021), 'Qw Twin', CONCAT('Qw Member ', v.token)), IF(v.token = 922009, '2', '1'), CONCAT('+91000092', RIGHT(v.token, 4)) FROM (
  SELECT 922001 AS token UNION ALL SELECT 922002 UNION ALL SELECT 922003 UNION ALL SELECT 922004 UNION ALL SELECT 922005 UNION ALL SELECT 922006 UNION ALL SELECT 922007 UNION ALL SELECT 922008
  UNION ALL SELECT 922009 UNION ALL SELECT 922010 UNION ALL SELECT 922011 UNION ALL SELECT 922012 UNION ALL SELECT 922013 UNION ALL SELECT 922014 UNION ALL SELECT 922015 UNION ALL SELECT 922016
  UNION ALL SELECT 922017 UNION ALL SELECT 922018 UNION ALL SELECT 922019 UNION ALL SELECT 922020 UNION ALL SELECT 922021) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users SET email = IF(token = 922011, '922011@thestrongrope.com', CONCAT('qw.', token, '@example.invalid')), name = IF(token IN (922020, 922021), 'Qw Twin', CONCAT('Qw Member ', token)),
  gender = IF(token = 922009, '2', '1'), mobile = CONCAT('+91000092', RIGHT(token, 4)),
  roleid = CASE token WHEN 922007 THEN 1 WHEN 922008 THEN 3 WHEN 922009 THEN 4 ELSE 0 END
WHERE token BETWEEN 922001 AND 922021;

DELETE FROM notifications WHERE created_by BETWEEN 922000 AND 922999;
DELETE FROM outbound_messages WHERE created_by BETWEEN 922000 AND 922999;
DELETE FROM spot_quiz_submissions WHERE spot_quiz_id IN (SELECT id FROM spot_quizzes WHERE class_id BETWEEN 98200 AND 98299);
DELETE FROM spot_quiz_responses WHERE spot_quiz_id IN (SELECT id FROM spot_quizzes WHERE class_id BETWEEN 98200 AND 98299);
DELETE FROM spot_quiz_questions WHERE spot_quiz_id IN (SELECT id FROM spot_quizzes WHERE class_id BETWEEN 98200 AND 98299);
DELETE FROM spot_quizzes WHERE class_id BETWEEN 98200 AND 98299;
DELETE FROM standard_mcq_questions WHERE mcq_code LIKE 'QW-S%';
DELETE FROM standard_mcqs WHERE code LIKE 'QW-S%';
DELETE FROM class_students WHERE class_id BETWEEN 98200 AND 98299;
DELETE FROM classes WHERE id BETWEEN 98200 AND 98299;

INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (98201, 'QW-G-201', 7, 'qwlnk98201', 'Qw Class Main', 3, '2025-01-06', 922001, 1, 'Offline', 'Qwville', 'India', 'Qw Hall', 'A', 900315),
  (98202, 'QW-G-202', 7, 'qwlnk98202', 'Qw Class Second', 3, '2025-01-06', 922001, 1, 'Offline', 'Qwville', 'India', 'Qw Hall', 'A', 900315),
  (98203, 'QW-G-203', 7, 'qwlnk98203', 'Qw Class Other', 3, '2025-01-06', 922004, 1, 'Offline', 'Qwville', 'India', 'Qw Hall', 'A', 900315),
  (98204, 'QW-G-204', 7, 'qwlnk98204', 'Qw Class Closed', 3, '2025-01-06', 922001, 1, 'Offline', 'Qwville', 'India', 'Qw Hall', 'I', 900315),
  (98205, 'QW-L-205', 7, 'qwlnk98205', 'Qw Ladies Class', 3, '2025-01-06', 922004, 2, 'Offline', 'Qwville', 'India', 'Qw Hall', 'A', 900315);

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9720301, 98201, 922002, '2025-01-06', 1, NULL, NULL, NULL, 'A'),
  (9720302, 98201, 922003, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9720303, 98201, 922005, '2025-01-06', 1, '2026-01-12 00:00:00', 'Qw left', 900315, 'I'),
  (9720304, 98201, 922011, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9720305, 98201, 922012, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9720306, 98201, 922013, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9720307, 98201, 922014, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9720308, 98201, 922015, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9720309, 98201, 922016, '2025-01-06', 0, '2026-01-12 00:00:00', 'Qw left', 900315, 'I'),
  (9720310, 98202, 922018, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9720311, 98202, 922019, '2025-01-06', 0, '2026-01-12 00:00:00', 'Qw left', 900315, 'I'),
  (9720312, 98203, 922006, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9720313, 98203, 922017, '2025-01-06', 1, NULL, NULL, NULL, 'A');

INSERT INTO standard_mcqs (id, code, language_id, level_id, topic, subject, lesson, name, sort_order, created_by, deleted_at) VALUES
  (9720101, 'QW-S1', 99, 99, 'Qw Topic Beta', 'Qw Subject Two', 'Qw lesson 1', 'Qw standard one', 1, 900315, NULL),
  (9720102, 'QW-S2', 99, 99, 'Qw Topic Alpha', 'Qw Subject One', 'Qw lesson 2', 'Qw standard two', 2, 900315, NULL);

INSERT INTO standard_mcq_questions (id, mcq_code, question, answer, option1, option2, option3, sort_order, created_by) VALUES
  (9720111, 'QW-S1', 'S1 q1', 'Right1', 'Wrong1a', 'Wrong1b', NULL, 1, 900315),
  (9720112, 'QW-S1', 'S1 q2', 'Right2', 'Wrong2a', NULL, NULL, 2, 900315),
  (9720113, 'QW-S2', 'S2 q1', 'Right3', 'Wrong3a', 'Wrong3b', 'Wrong3c', 1, 900315);

INSERT INTO spot_quizzes (id, code, mcq_code, name, topic, published_at, published_by, deactivated_at, created_by, class_id, language_id, level_id, restrict_to_class, created_at) VALUES
  (9720001, 'QWQ9720001', NULL, 'Qw Scores', 'Qw topic scores', '2026-01-10 10:00:00', 922001, NULL, 922001, 98201, 9, 3, 1, '2026-01-01 09:00:00'),
  (9720002, 'QWQ9720002', NULL, 'Qw Offline Read', 'Qw topic offline', '2026-01-10 10:00:00', 922001, NULL, 922001, 98201, 9, 3, 1, '2026-01-02 09:00:00'),
  (9720003, 'QWQ9720003', NULL, 'Qw Offline Save', 'Qw topic offline', '2026-01-10 10:00:00', 922001, NULL, 922001, 98201, 9, 3, 1, '2026-01-03 09:00:00'),
  (9720004, 'QWQ9720004', NULL, 'Qw Offline Phone', 'Qw topic offline', '2026-01-10 10:00:00', 922001, NULL, 922001, 98201, 9, 3, 1, '2026-01-04 09:00:00'),
  (9720005, 'QWQ9720005', NULL, 'Qw Sheet <b>"x"</b>', 'Qw topic sheet', NULL, NULL, NULL, 922001, 98201, 9, 3, 1, '2026-01-05 09:00:00'),
  (9720006, 'QWQ9720006', NULL, 'Qw Sheet Empty', 'Qw topic sheet', NULL, NULL, NULL, 922001, 98201, 9, 3, 1, '2026-01-06 09:00:00'),
  (9720007, 'QWQ9720007', NULL, 'Qw Publish A', 'Qw topic publish', NULL, NULL, NULL, 922001, 98201, 9, 3, 1, '2026-01-07 09:00:00'),
  (9720008, 'QWQ9720008', NULL, 'Qw Publish B', NULL, NULL, NULL, NULL, 922001, 98202, 9, 3, 1, '2026-01-08 09:00:00'),
  (9720009, 'QWQ9720009', 'QW-S1', 'Qw Copy Source', 'Qw copy topic', NULL, NULL, NULL, 922001, 98201, 9, 3, 0, '2026-01-09 09:00:00'),
  (9720010, 'QWQ9720010', NULL, 'Qw Dup Source', 'QW DUP TOPIC', NULL, NULL, NULL, 922001, 98202, 9, 3, 1, '2026-01-09 10:00:00'),
  (9720011, 'QWQ9720011', NULL, 'Qw Dup Source', 'Qw dup topic', NULL, NULL, NULL, 922001, 98201, 9, 3, 1, '2026-01-09 11:00:00'),
  (9720012, 'QWQ9720012', NULL, 'Qw Closed Class Quiz', 'Qw topic closed', NULL, NULL, NULL, 922001, 98204, 9, 3, 1, '2026-01-01 09:00:00'),
  (9720013, 'QWQ9720013', NULL, 'Qw Ladies Quiz', 'Qw topic ladies', NULL, NULL, NULL, 922004, 98205, 9, 3, 1, '2026-01-01 09:00:00');

INSERT INTO spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, option3, option4, option5, answer, option_display_order) VALUES
  (9720501, 9720001, 0, 'Qw score q1', 'Right a', 'Wrong b', NULL, NULL, NULL, 1, NULL),
  (9720502, 9720001, 0, 'Qw score q2', 'Right x', 'Wrong y', NULL, NULL, NULL, 1, NULL),
  (9720503, 9720001, 0, 'Qw score q3', 'Right m', 'Wrong n', NULL, NULL, NULL, 1, NULL),
  (9720504, 9720002, 0, 'Qw offline q1', 'Right a', 'Wrong b', 'Wrong c', 'Wrong d', NULL, 1, NULL),
  (9720505, 9720002, 0, 'Qw offline q2', 'Right x', 'Wrong y', 'Wrong z', NULL, NULL, 1, '3,1,2'),
  (9720506, 9720002, 0, 'Qw offline q3', 'Right m', '', 'Wrong n', NULL, 'Wrong five', 1, NULL),
  (9720507, 9720003, 0, 'Qw save q1', 'Right a', 'Wrong b', NULL, NULL, NULL, 1, NULL),
  (9720508, 9720003, 0, 'Qw save q2', 'Right x', 'Wrong y', NULL, NULL, NULL, 1, NULL),
  (9720509, 9720003, 0, 'Qw save q3', 'Right m', 'Wrong n', NULL, NULL, NULL, 1, NULL),
  (9720510, 9720004, 0, 'Qw phone q1', 'Right a', 'Wrong b', NULL, NULL, NULL, 1, NULL),
  (9720511, 9720004, 0, 'Qw phone q2', 'Right x', 'Wrong y', NULL, NULL, NULL, 1, NULL),
  (9720512, 9720005, 0, 'Qw <script>alert("1")</script> & ''quote''', 'Right <i>a</i>', 'Wrong "b"', 'Wrong & c', 'ما هو الجواب؟', NULL, 1, NULL),
  (9720513, 9720005, 1, 'ما هو؟', 'نعم', 'لا', NULL, NULL, NULL, 1, NULL),
  (9720514, 9720007, 0, 'Qw publish q1', 'Right a', 'Wrong b', 'Wrong c', NULL, NULL, 1, NULL),
  (9720515, 9720007, 0, 'Qw publish q2', 'Right x', 'Wrong y', NULL, NULL, NULL, 1, NULL),
  (9720516, 9720009, 1, 'Qw copy q1', 'Right a', 'Wrong b', 'Wrong c', 'Wrong d', 'Wrong e', 1, '2,1'),
  (9720517, 9720009, 0, 'Qw copy q2', 'Right x', 'Wrong y', NULL, NULL, NULL, 1, NULL),
  (9720518, 9720011, 0, 'Qw dup q1', 'Right a', 'Wrong b', NULL, NULL, NULL, 1, NULL),
  (9720519, 9720008, 0, 'Qw publish b q1', 'Right a', 'Wrong b', NULL, NULL, NULL, 1, NULL);

INSERT INTO spot_quiz_submissions (id, spot_quiz_id, token, created_at, modified_at) VALUES
  (9720401, 9720002, 922015, '2026-02-01 09:00:00', '2026-02-01 09:00:00'),
  (9720402, 9720003, 922015, '2026-02-01 09:00:00', '2026-02-01 09:00:00');

INSERT INTO spot_quiz_responses (id, spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct, created_at) VALUES
  (9720601, 9720001, 9720501, 922003, 'Right a', 'Right a', 1, '2026-02-01 09:00:01'),
  (9720602, 9720001, 9720502, 922003, 'Wrong y', 'Right x', 0, '2026-02-01 09:00:02'),
  (9720603, 9720001, 9720503, 922003, 'Right m', 'Right m', 1, '2026-02-01 09:00:03'),
  (9720604, 9720001, 9720501, 922012, 'Right a', 'Right a', 1, '2026-02-02 09:00:01'),
  (9720605, 9720001, 9720502, 922012, 'Right x', 'Right x', 1, '2026-02-02 09:00:02'),
  (9720606, 9720001, 9720503, 922012, 'Right m', 'Right m', 1, '2026-02-02 09:00:03'),
  (9720607, 9720001, 9720501, 922020, 'Right a', 'Right a', 1, '2026-02-03 09:00:01'),
  (9720608, 9720001, 9720502, 922020, 'Right x', 'Right x', 1, '2026-02-03 09:00:02'),
  (9720609, 9720001, 9720501, 922021, 'Wrong b', 'Right a', 0, '2026-02-03 09:00:03'),
  (9720610, 9720001, 9720501, 922099, 'Right a', 'Right a', 1, '2026-02-04 09:00:01'),
  (9720611, 9720002, 9720504, 922012, 'Right a', 'Right a', 1, '2026-02-01 09:00:01'),
  (9720612, 9720003, 9720507, 922015, 'Right a', 'Right a', 1, '2026-02-01 09:00:01'),
  (9720613, 9720003, 9720508, 922015, NULL, 'Right x', 0, '2026-02-01 09:00:01'),
  (9720614, 9720003, 9720509, 922015, NULL, 'Right m', 0, '2026-02-01 09:00:01'),
  (9720615, 9720004, 9720510, 922012, 'Right a', 'Right a', 1, '2026-02-01 09:00:01'),
  (9720616, 9720004, 9720511, 922012, 'Wrong y', 'Right x', 0, '2026-02-01 09:00:02');

-- The trigger on spot_quizzes ignores a supplied code on insert; an UPDATE keeps ours.
UPDATE spot_quizzes SET code = CONCAT('QWQ', id) WHERE id BETWEEN 9720001 AND 9720013;
-- classes_before_create replaces the link of every inserted class with a random string; an UPDATE keeps ours.
UPDATE classes SET link = CONCAT('qwlnk', id) WHERE id BETWEEN 98201 AND 98205;
