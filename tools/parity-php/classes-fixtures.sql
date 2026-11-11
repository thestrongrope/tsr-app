/*
 * The classes fixtures for the PHP parity stack's MariaDB (tools/classes-contract.sh parity loads it): the same members and rows as
 * db/synthetic/classes-fixtures.sql (read that header), so one Hurl file sees one data set on both sides.
 * Synthetic only: tokens 900301 to 900399, emails on .invalid, class ids 9301 and up. Safe to run again: it resets every row it owns.
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, v.email, v.roleid, 'firebase', NOW(), v.name, v.gender, v.mobile FROM (
  SELECT 900301 AS token, 'cls.teacher.gents@example.invalid' AS email, 0 AS roleid, 'Cls Teacher Gents' AS name, '1' AS gender, '+910000003001' AS mobile UNION ALL
  SELECT 900302, 'cls.teacher.ladies@example.invalid', 0, 'Cls Teacher Ladies', '2', '+910000003002' UNION ALL
  SELECT 900311, 'cls.student.gents@example.invalid', 0, 'Cls Student Gents', '1', '+910000003011' UNION ALL
  SELECT 900312, 'cls.student.ladies@example.invalid', 0, 'Cls Student Ladies', '2', '+910000003012' UNION ALL
  SELECT 900313, 'cls.outsider@example.invalid', 0, 'Cls Outsider', '1', '' UNION ALL
  SELECT 900314, 'cls.nogender@example.invalid', 0, 'Cls No Gender', NULL, '' UNION ALL
  SELECT 900315, 'cls.admin@example.invalid', 1, 'Cls Admin', '1', '' UNION ALL
  SELECT 900316, 'cls.removed@example.invalid', 0, 'Cls Removed', '1', '' UNION ALL
  SELECT 900321, 'cls.parent@example.invalid', 0, 'Cls Parent', '1', '' UNION ALL
  SELECT 900322, 'cls.child.one@example.invalid', 0, 'Cls Child One', '1', '' UNION ALL
  SELECT 900323, 'cls.child.two@example.invalid', 0, 'Cls Child Two', '2', '' UNION ALL
  SELECT 900324, 'cls.child.three@example.invalid', 0, 'Cls Child Three', '1', '') v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.email = v.email);
UPDATE users SET roleid = 1 WHERE email = 'cls.admin@example.invalid';

DELETE FROM class_attendance WHERE session_id BETWEEN 939301 AND 939399;
DELETE FROM class_sessions WHERE class_id BETWEEN 9301 AND 9399;
DELETE FROM class_students WHERE class_id BETWEEN 9301 AND 9399;
DELETE FROM class_schedules WHERE class_id BETWEEN 9301 AND 9399;
DELETE FROM class_tags WHERE class_id BETWEEN 9301 AND 9399;
DELETE FROM classes WHERE id BETWEEN 9301 AND 9399;
DELETE FROM tags WHERE id BETWEEN 9301 AND 9399;
DELETE FROM syllabus WHERE id BETWEEN 9301 AND 9399;
DELETE FROM guides WHERE level_id IN (3, 4, 5) AND language_id = 1;

INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (9301, 'CLS-G-001', 1, 'clslnk9301', 'Cls Gents Class', 3, '2025-09-01', 900301, 1, 'Offline', 'Mumbai', 'India', 'Cls Hall', 'A', 900315),
  (9302, 'CLS-L-001', 2, 'clslnk9302', 'Cls Ladies Class', 5, '2025-09-08', 900302, 2, 'Online', 'Dubai', 'United Arab Emirates', NULL, 'A', 900315),
  (9303, 'CLS-G-002', 1, 'clslnk9303', 'Cls Closed Class', 4, '2024-09-01', 900301, 1, 'Offline', 'Mumbai', 'India', NULL, 'I', 900315);
INSERT INTO tags (id, name) VALUES (9301, 'cls-beginners'), (9302, 'cls-evening');
INSERT INTO class_tags (class_id, tag_id, created_by) VALUES (9301, 9301, 900315), (9301, 9302, 900315);
INSERT INTO class_schedules (id, class_id, day, hour, minute, timezone, created_by) VALUES
  (9301, 9301, 6, 18, 30, 'Asia/Kolkata', 900315), (9302, 9301, 2, 9, 15, 'Asia/Kolkata', 900315), (9303, 9302, 7, 10, 0, 'Asia/Dubai', 900315);
INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9301, 9301, 900311, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9302, 9301, 900322, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9303, 9301, 900316, '2025-09-01', 0, '2025-10-01 00:00:00', 'Cls removed', 900315, 'I'),
  (9304, 9302, 900312, '2025-09-08', 0, NULL, NULL, NULL, 'A'),
  (9305, 9302, 900323, '2025-09-08', 0, NULL, NULL, NULL, 'A'),
  (9306, 9303, 900311, '2024-09-01', 0, '2025-06-30 00:00:00', 'Cls closed', 900315, 'I');
INSERT INTO class_sessions (id, class_id, teacher, conducted_on, conducted, non_conduction_reason, conducted_by, duration, attendance) VALUES
  (939301, 9301, 900301, '2025-09-06', 1, NULL, 900301, 60, 2),
  (939302, 9301, 900301, '2025-09-13', 0, 'Cls teacher unwell', NULL, NULL, NULL),
  (939303, 9301, 900301, '2025-09-20', 1, NULL, 900301, 45, 1),
  (939304, 9302, 900302, '2025-09-14', 1, NULL, 900302, 50, 2);
INSERT INTO class_attendance (id, session_id, token, extra_student, present, recitation) VALUES
  (939301, 939301, 900311, 0, 1, 5), (939302, 939301, 900322, 0, 1, 3), (939303, 939303, 900311, 0, 0, 0), (939304, 939303, 900322, 0, 1, 2),
  (939305, 939304, 900312, 0, 1, 4), (939306, 939304, 900323, 0, 1, 1);

DELETE FROM user_guardians WHERE child_token BETWEEN 900321 AND 900329;
INSERT INTO user_guardians (parent_token, child_token, relationship, status, source, code, expires_at, created_by, created_at, activated_at, revoked_by, revoked_at)
SELECT 900321, v.child, 'father', v.status, 'token_entry', NULL, NULL, p.id, '2026-01-10 09:00:00', '2026-01-10 09:00:00',
       IF(v.status = 'revoked', p.id, NULL), IF(v.status = 'revoked', '2026-01-11 09:00:00', NULL)
FROM (SELECT 900322 AS child, 'active' AS status UNION ALL SELECT 900323, 'revoked' UNION ALL SELECT 900324, 'active') v
JOIN users p ON p.email = 'cls.parent@example.invalid';

INSERT INTO guides (level_id, language_id, guide, created_by) VALUES (3, 1, '<p>Cls Miqdad guide</p>', 900315), (5, 1, '   ', 900315);
INSERT INTO syllabus (id, level_id, subject_name, description, link_type, url, sort_order, is_active, created_by) VALUES
  (9301, 3, 'Cls syllabus b', NULL, 'external', 'https://example.invalid/syllabus/b', 2, 1, 900315),
  (9302, 3, 'Cls syllabus a', 'Invented description', 'pdf', 'https://example.invalid/syllabus/a.pdf', 1, 1, 900315),
  (9303, 3, 'Cls syllabus hidden', NULL, 'pdf', 'https://example.invalid/syllabus/h.pdf', 3, 0, 900315);

DELETE FROM spot_quiz_responses WHERE spot_quiz_id IN (9301, 9302);
DELETE FROM spot_quiz_questions WHERE spot_quiz_id IN (9301, 9302);
DELETE FROM spot_quizzes WHERE id IN (9301, 9302);
INSERT INTO spot_quizzes (id, code, language_id, level_id, name, class_id, restrict_to_class, published_at, published_by, created_by, created_at)
VALUES (9301, 'CLSQ9301', 1, 3, 'Cls quiz', 9301, 1, '2025-09-06 12:00:00', 900301, 900301, '2025-09-06 11:00:00');
INSERT INTO spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, answer)
VALUES (939301, 9301, FALSE, 'Cls question one', 'a', 'b', 1), (939302, 9301, FALSE, 'Cls question two', 'a', 'b', 2), (939303, 9301, FALSE, 'Cls question three', 'a', 'b', 1);
INSERT INTO spot_quiz_responses (id, spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct)
VALUES (939301, 9301, 939301, 900311, 'a', 'a', 1), (939302, 9301, 939302, 900311, 'a', 'b', 0), (939303, 9301, 939303, 900322, 'a', 'a', 1);
INSERT INTO spot_quizzes (id, code, language_id, level_id, name, class_id, restrict_to_class, published_at, published_by, created_by, created_at)
VALUES (9302, 'CLSQ9302', 1, 3, 'Cls quiz ladies', 9302, 1, '2025-09-06 12:00:00', 900302, 900302, '2025-09-06 11:00:00');
INSERT INTO spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, answer)
VALUES (939304, 9302, FALSE, 'Cls question four', 'a', 'b', 1), (939305, 9302, FALSE, 'Cls question five', 'a', 'b', 1), (939306, 9302, FALSE, 'Cls question six', 'a', 'b', 1);
INSERT INTO spot_quiz_responses (id, spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct)
VALUES (939304, 9302, 939304, 900312, 'a', 'a', 1), (939305, 9302, 939305, 900312, 'b', 'a', 0), (939306, 9302, 939306, 900312, 'b', 'a', 0);

-- The roster slice shows when a student joined (the day of the enrolment row's created_at) and the row's note: fixed here so the day does not move.
UPDATE class_students SET created_at = CONCAT(joined_on, ' 08:00:00') WHERE class_id BETWEEN 9301 AND 9399;
UPDATE class_students SET notes = 'Cls note &amp; more' WHERE id = 9301;
