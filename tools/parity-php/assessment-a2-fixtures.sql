/*
 * The assessment A2 fixtures (a teacher or class admin manages a class's quizzes) for the PHP parity stack's MariaDB: the same rows as db/synthetic/assessment-a2-fixtures.sql (read the header there).
 * Loaded by tools/assessment-contract.sh after the A1 fixtures, before every run; resets every row it owns. Synthetic only: tokens 902501 to 902513, emails qm.<token>@example.invalid,
 * classes 9631 to 9637 (language 7, level 3; the standard A2S-5 is language 8), enrolments 963301 and up, quizzes 963401 to 963499 (code A2Q<id>), questions 963501 and up, responses 963601 and up, standard MCQs 963701 and up (codes A2S-*).
 * Quizzes a run CREATES (the create and copy files, when built) get ids from the sequence, above these ranges, and are NOT deleted here (a classes fixture may later hand a class id of this range to a created class): the reset deletes the fixture classes 9631 to 9637 and everything of theirs.
 *
 *   902501 teacher of 9631, 9632, 9634   902502 class admin (mcq_admin) of 9631   902503 plain student of 9631   902504 teacher of 9633, 9635, 9636   902505 class admin of 9631 who was REMOVED (status I, removed_at)
 *   902506 class admin of 9633 and plain stranger of 9631   902507 super admin (role 1)   902508 gents admin (role 3)   902509 coordinator (role 5) assigned 9631, 9632, 9633, 9637 (gents classes of city A2ville)
 *   902510 ladies admin (role 4, gender 2)   902511 nobody (no class)   902512 a class admin of 9632 (not 9631)   902513 class admin of 9631 whose enrolment status is I but never removed (removed_at null): PHP's predicate (mcq_admin = 1 and removed_at null, active class) still makes them a manager
 *   9631 (gents, active, A2ville): 963401 draft 3 questions   963402 published 2 questions answered by 902503   963403 deactivated   963404 edit target   963405 edit-refusal target   963406 deactivate target
 *        963407 deactivate-toggle target (published)   963408 a copy of the standard MCQ A2S-1 (mcq_code), 963409 a deactivated copy of A2S-2   963410 no questions   963411 topic with a % and _ in it
 *   9632 (gents, active, A2ville; 902503 is a student here too): 963421 one quiz   963422 published and answered by 902503 (edit-impact target)   963423 edit-wipe target   963424 edit-quirks target   963425 edit-types target (new-API file)   9633 (gents, A2ville, teacher 902504): 963431 a quiz   9634 (gents, CLOSED, A2ville): 963441 a quiz   9635 (gents, A2other, 902504)   9636 (ladies, A2ville, 902504)   9637 (gents, A2ville, level 1: no standard MCQ fits, teacher 902501)
 *   standard MCQs (level 3, language 7): A2S-1 (2 questions, copied once into 9631), A2S-2 (1 question, copied twice into 9631), A2S-3 (1 question, never copied), A2S-4 (another level: not shown), A2S-5 (language 8: not shown)
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, CONCAT('qm.', v.token, '@example.invalid'), 0, 'firebase', NOW(), CONCAT('Qm Member ', v.token), IF(v.token = 902510, '2', '1'), CONCAT('+91000025', RIGHT(v.token, 4)) FROM (
  SELECT 902501 AS token UNION ALL SELECT 902502 UNION ALL SELECT 902503 UNION ALL SELECT 902504 UNION ALL SELECT 902505 UNION ALL SELECT 902506 UNION ALL SELECT 902507 UNION ALL SELECT 902508
  UNION ALL SELECT 902509 UNION ALL SELECT 902510 UNION ALL SELECT 902511 UNION ALL SELECT 902512 UNION ALL SELECT 902513) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users SET email = CONCAT('qm.', token, '@example.invalid'), name = CONCAT('Qm Member ', token), gender = IF(token = 902510, '2', '1'), mobile = CONCAT('+91000025', RIGHT(token, 4)),
  roleid = CASE token WHEN 902507 THEN 1 WHEN 902508 THEN 3 WHEN 902509 THEN 5 WHEN 902510 THEN 4 ELSE 0 END
WHERE token BETWEEN 902501 AND 902513;

DELETE FROM class_access WHERE token = 902509;
DELETE FROM spot_quiz_responses WHERE spot_quiz_id IN (SELECT id FROM spot_quizzes WHERE class_id BETWEEN 9631 AND 9637);
DELETE FROM spot_quiz_questions WHERE spot_quiz_id IN (SELECT id FROM spot_quizzes WHERE class_id BETWEEN 9631 AND 9637);
DELETE FROM spot_quizzes WHERE class_id BETWEEN 9631 AND 9637;
DELETE FROM standard_mcq_questions WHERE mcq_code LIKE 'A2S-%';
DELETE FROM standard_mcqs WHERE code LIKE 'A2S-%';
DELETE FROM class_students WHERE class_id BETWEEN 9631 AND 9637;
DELETE FROM classes WHERE id BETWEEN 9631 AND 9637;

INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (9631, 'A2-G-631', 7, 'a2lnk9631', 'A2 Class Main', 3, '2025-01-06', 902501, 1, 'Offline', 'A2ville', 'India', 'A2 Hall', 'A', 900315),
  (9632, 'A2-G-632', 7, 'a2lnk9632', 'A2 Class Second', 3, '2025-01-06', 902501, 1, 'Offline', 'A2ville', 'India', 'A2 Hall', 'A', 900315),
  (9633, 'A2-G-633', 7, 'a2lnk9633', 'A2 Class Other', 3, '2025-01-06', 902504, 1, 'Offline', 'A2ville', 'India', 'A2 Hall', 'A', 900315),
  (9634, 'A2-G-634', 7, 'a2lnk9634', 'A2 Class Closed', 3, '2025-01-06', 902501, 1, 'Offline', 'A2ville', 'India', 'A2 Hall', 'I', 900315),
  (9635, 'A2-G-635', 7, 'a2lnk9635', 'A2 Class Elsewhere', 3, '2025-01-06', 902504, 1, 'Offline', 'A2other', 'India', 'A2 Hall', 'A', 900315),
  (9636, 'A2-L-636', 7, 'a2lnk9636', 'A2 Ladies Class', 3, '2025-01-06', 902504, 2, 'Offline', 'A2ville', 'India', 'A2 Hall', 'A', 900315),
  (9637, 'A2-G-637', 7, 'a2lnk9637', 'A2 Class No Standards', 1, '2025-01-06', 902501, 1, 'Offline', 'A2ville', 'India', 'A2 Hall', 'A', 900315);

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (963301, 9631, 902502, '2025-01-06', 1, NULL, NULL, NULL, 'A'),
  (963302, 9631, 902503, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (963303, 9631, 902505, '2025-01-06', 1, '2026-01-12 00:00:00', 'A2 left', 900315, 'I'),
  (963304, 9633, 902506, '2025-01-06', 1, NULL, NULL, NULL, 'A'),
  (963305, 9632, 902512, '2025-01-06', 1, NULL, NULL, NULL, 'A'),
  (963306, 9632, 902503, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (963390, 9631, 902513, '2025-01-06', 1, NULL, NULL, NULL, 'I');

INSERT INTO standard_mcqs (id, code, language_id, level_id, topic, subject, lesson, name, sort_order, created_by, deleted_at) VALUES
  (963701, 'A2S-1', 7, 3, 'A2 Topic Beta', 'A2 Subject Two', 'A2 lesson 1', 'A2 standard one', 1, 900315, NULL),
  (963702, 'A2S-2', 7, 3, 'A2 Topic Beta', 'A2 Subject One', 'A2 lesson 2', 'A2 standard two', 2, 900315, NULL),
  (963703, 'A2S-3', 7, 3, 'A2 Topic Alpha', 'A2 Subject One', 'A2 lesson 3', 'A2 standard three', 3, 900315, NULL),
  (963704, 'A2S-4', 7, 2, 'A2 Topic Alpha', 'A2 Subject One', 'A2 lesson 4', 'A2 standard other level', 4, 900315, NULL),
  (963705, 'A2S-5', 8, 3, 'A2 Topic Alpha', 'A2 Subject One', 'A2 lesson 5', 'A2 standard other language', 5, 900315, NULL);

INSERT INTO standard_mcq_questions (id, mcq_code, question, answer, option1, option2, option3, sort_order, created_by) VALUES
  (963711, 'A2S-1', 'S1 q1', 'Right1', 'Wrong1a', 'Wrong1b', NULL, 1, 900315),
  (963712, 'A2S-1', 'S1 q2', 'Right2', 'Wrong2a', NULL, NULL, 2, 900315),
  (963713, 'A2S-2', 'S2 q1', 'Right3', 'Wrong3a', 'Wrong3b', 'Wrong3c', 1, 900315),
  (963714, 'A2S-3', 'S3 q1', 'Right4', 'Wrong4a', NULL, NULL, 1, 900315),
  (963715, 'A2S-4', 'S4 q1', 'Right5', 'Wrong5a', NULL, NULL, 1, 900315),
  (963716, 'A2S-5', 'S5 q1', 'Right6', 'Wrong6a', NULL, NULL, 1, 900315);

INSERT INTO spot_quizzes (id, code, mcq_code, name, topic, published_at, published_by, deactivated_at, created_by, class_id, language_id, level_id, restrict_to_class, created_at) VALUES
  (963401, 'A2Q963401', NULL, 'A2 Quiz Draft', 'A2 topic one', NULL, NULL, NULL, 902501, 9631, 9, 3, 1, '2026-01-01 09:00:00'),
  (963402, 'A2Q963402', NULL, 'A2 Quiz Published', 'A2 topic two', '2026-01-10 10:00:00', 902501, NULL, 902501, 9631, 9, 3, 0, '2026-01-02 09:00:00'),
  (963403, 'A2Q963403', NULL, 'A2 Quiz Deactivated', 'A2 topic two', '2026-01-11 10:00:00', 902501, '2026-01-15 10:00:00', 902501, 9631, 9, 3, 1, '2026-01-03 09:00:00'),
  (963404, 'A2Q963404', NULL, 'A2 Quiz Edit', 'A2 topic edit', NULL, NULL, NULL, 902501, 9631, 9, 3, 1, '2026-01-04 09:00:00'),
  (963405, 'A2Q963405', NULL, 'A2 Quiz Edit Refused', 'A2 topic edit', NULL, NULL, NULL, 902501, 9631, 9, 3, 1, '2026-01-05 09:00:00'),
  (963406, 'A2Q963406', NULL, 'A2 Quiz Deactivate', 'A2 topic deact', '2026-01-12 10:00:00', 902501, NULL, 902501, 9631, 9, 3, 1, '2026-01-06 09:00:00'),
  (963407, 'A2Q963407', NULL, 'A2 Quiz Toggle', 'A2 topic deact', '2026-01-12 10:00:00', 902501, NULL, 902501, 9631, 9, 3, 1, '2026-01-07 09:00:00'),
  (963408, 'A2Q963408', 'A2S-1', 'A2 Subject Two - A2 lesson 1 - A2 standard one', 'A2 Topic Beta', NULL, NULL, NULL, 902501, 9631, 9, 3, 1, '2026-01-08 09:00:00'),
  (963409, 'A2Q963409', 'A2S-2', 'A2 Subject One - A2 lesson 2 - A2 standard two', 'A2 Topic Beta', NULL, NULL, '2026-01-20 10:00:00', 902501, 9631, 9, 3, 1, '2026-01-09 09:00:00'),
  (963410, 'A2Q963410', 'A2S-2', 'A2 Subject One - A2 lesson 2 - A2 standard two', 'A2 Topic Beta', NULL, NULL, NULL, 902501, 9631, 9, 3, 1, '2026-01-09 10:00:00'),
  (963411, 'A2Q963411', NULL, 'A2 Quiz No Questions', 'A2 100% sure_', NULL, NULL, NULL, 902501, 9631, 9, 3, 1, '2026-01-10 09:00:00'),
  (963412, 'A2Q963412', NULL, 'A2 Quiz Blank Topic', '   ', NULL, NULL, NULL, 902501, 9631, 9, 3, 1, '2026-01-10 10:00:00'),
  (963421, 'A2Q963421', NULL, 'A2 Second Class Quiz', 'A2 topic second', NULL, NULL, NULL, 902501, 9632, 9, 3, 1, '2026-01-01 09:00:00'),
  (963422, 'A2Q963422', NULL, 'A2 Edit Published Answered', 'A2 topic second', '2026-01-10 10:00:00', 902501, NULL, 902501, 9632, 9, 3, 1, '2026-01-02 09:00:00'),
  (963423, 'A2Q963423', NULL, 'A2 Edit Wipe', 'A2 topic second', NULL, NULL, NULL, 902501, 9632, 9, 3, 1, '2026-01-03 09:00:00'),
  (963425, 'A2Q963425', NULL, 'A2 Edit Types', 'A2 topic second', NULL, NULL, NULL, 902501, 9632, 9, 3, 1, '2026-01-05 09:00:00'),
  (963424, 'A2Q963424', NULL, 'A2 Edit Quirks', 'A2 topic second', NULL, NULL, NULL, 902501, 9632, 9, 3, 0, '2026-01-04 09:00:00'),
  (963431, 'A2Q963431', NULL, 'A2 Other Class Quiz', 'A2 topic other', NULL, NULL, NULL, 902504, 9633, 9, 3, 1, '2026-01-01 09:00:00'),
  (963441, 'A2Q963441', NULL, 'A2 Closed Class Quiz', 'A2 topic closed', NULL, NULL, NULL, 902501, 9634, 9, 3, 1, '2026-01-01 09:00:00');

INSERT INTO spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, option3, option4, option5, answer, option_display_order) VALUES
  (963501, 963401, 0, 'A2 draft q1', 'Right a', 'Wrong b', 'Wrong c', 'Wrong d', 'Wrong e', 1, NULL),
  (963502, 963401, 1, 'ما هو؟', 'نعم', 'لا', NULL, NULL, NULL, 1, NULL),
  (963503, 963401, 0, 'A2 draft q3', 'Right', 'Wrong', '', NULL, NULL, 1, NULL),
  (963504, 963402, 0, 'A2 pub q1', 'Right a', 'Wrong b', NULL, NULL, NULL, 1, '2,1'),
  (963505, 963402, 0, 'A2 pub q2', 'Right x', 'Wrong y', 'Wrong z', NULL, NULL, 1, '3,1,2'),
  (963506, 963403, 0, 'A2 deact q1', 'a', 'b', NULL, NULL, NULL, 1, NULL),
  (963507, 963404, 0, 'A2 edit q1', 'a', 'b', NULL, NULL, NULL, 1, NULL),
  (963508, 963404, 0, 'A2 edit q2', 'a', 'b', NULL, NULL, NULL, 1, NULL),
  (963509, 963405, 0, 'A2 refuse q1', 'a', 'b', NULL, NULL, NULL, 1, NULL),
  (963510, 963406, 0, 'A2 deact target q1', 'a', 'b', NULL, NULL, NULL, 1, NULL),
  (963511, 963407, 0, 'A2 toggle q1', 'a', 'b', NULL, NULL, NULL, 1, NULL),
  (963512, 963408, 0, 'S1 q1', 'Right1', 'Wrong1a', 'Wrong1b', NULL, NULL, 1, NULL),
  (963513, 963408, 0, 'S1 q2', 'Right2', 'Wrong2a', NULL, NULL, NULL, 1, NULL),
  (963514, 963421, 0, 'A2 second q1', 'a', 'b', NULL, NULL, NULL, 1, NULL),
  (963515, 963422, 0, 'A2 ans q1', 'Right a', 'Wrong b', NULL, NULL, NULL, 1, '2,1'),
  (963516, 963422, 0, 'A2 ans q2', 'Right x', 'Wrong y', NULL, NULL, NULL, 1, '2,1'),
  (963517, 963423, 0, 'A2 wipe q1', 'a', 'b', NULL, NULL, NULL, 1, NULL),
  (963519, 963425, 0, 'A2 types q1', 'a', 'b', NULL, NULL, NULL, 1, NULL),
  (963518, 963424, 0, 'A2 quirks q1', 'a', 'b', NULL, NULL, NULL, 1, NULL);

INSERT INTO spot_quiz_responses (id, spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct, created_at) VALUES
  (963601, 963402, 963504, 902503, 'Right a', 'Right a', 1, '2026-02-01 09:00:01'),
  (963602, 963402, 963505, 902503, 'Wrong y', 'Right x', 0, '2026-02-01 09:00:02'),
  (963603, 963422, 963515, 902503, 'Right a', 'Right a', 1, '2026-02-01 09:00:01'),
  (963604, 963422, 963516, 902503, 'Right x', 'Right x', 1, '2026-02-01 09:00:02');

INSERT INTO class_access (class_id, token) VALUES (9631, 902509), (9632, 902509), (9633, 902509), (9637, 902509);

-- The trigger on spot_quizzes ignores a supplied code on insert; an UPDATE keeps ours.
UPDATE spot_quizzes SET code = CONCAT('A2Q', id) WHERE id BETWEEN 963401 AND 963499;
-- classes_before_create replaces the link of every inserted class with a random string; an UPDATE keeps ours.
UPDATE classes SET link = CONCAT('a2lnk', id) WHERE id BETWEEN 9631 AND 9637;
