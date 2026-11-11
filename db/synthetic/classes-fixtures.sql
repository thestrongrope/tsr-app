/*
 * The classes fixtures for the new API's database: members, three classes, enrolments, sessions, attendance, guardian links, guides and a syllabus
 * for the classes contract files (domains/classes/spec/tests). tools/parity-php/classes-fixtures.sql holds the same rows for the PHP parity
 * stack's MariaDB, so one Hurl file sees one data set on both sides. Synthetic only: tokens 900301 to 900399, emails on .invalid, class ids 9301 and up.
 * Safe to run again: it resets every row it owns. The classes slices only read, so no file changes these rows.
 *
 *   900301 / 900302  teachers of the gents class 9301 (and closed 9303) / the ladies class 9302
 *   900311 / 900312  students: 900311 in 9301 (and removed from the closed 9303), 900312 in 9302
 *   900313 outsider (gents, no class) · 900314 no gender · 900315 super admin (role 1) · 900316 removed from 9301
 *   900321 parent: active links to 900322 (enrolled in 9301) and 900324 (enrolled nowhere), a revoked link to 900323 (enrolled in 9302)
 *
 * It also aligns two things of the schema phase's seed with PHP's reference data (production's): the class levels (1 Salman .. 5 Bilal) and
 * the seed classes' teachers (900303, 900304: not the access contract's 9001xx members, which that contract keeps free of any class, and not this file's 9003xx).
 */
UPDATE classes.class_levels SET code = v.code, name = v.name
FROM (VALUES (1, 'SM', 'SALMAN'), (2, 'AG', 'ABUZAR'), (3, 'MK', 'MIQDAD'), (4, 'AY', 'AMMAR'), (5, 'B', 'BILAL')) AS v (id, code, name)
WHERE classes.class_levels.id = v.id;
UPDATE classes.classes SET teacher = 900303 WHERE id IN (9001, 9003);
UPDATE classes.classes SET teacher = 900304 WHERE id IN (9002, 9004);

INSERT INTO identity.users (token, email)
SELECT v.token, v.email FROM (VALUES
  (900301, 'cls.teacher.gents@example.invalid'), (900302, 'cls.teacher.ladies@example.invalid'),
  (900311, 'cls.student.gents@example.invalid'), (900312, 'cls.student.ladies@example.invalid'),
  (900313, 'cls.outsider@example.invalid'), (900314, 'cls.nogender@example.invalid'), (900315, 'cls.admin@example.invalid'),
  (900316, 'cls.removed@example.invalid'), (900321, 'cls.parent@example.invalid'), (900322, 'cls.child.one@example.invalid'),
  (900323, 'cls.child.two@example.invalid'), (900324, 'cls.child.three@example.invalid')
) AS v (token, email)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.email = v.email);

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id, v.name, v.gender, v.mobile FROM (VALUES
  ('cls.teacher.gents@example.invalid', 'Cls Teacher Gents', '1', '+910000003001'),
  ('cls.teacher.ladies@example.invalid', 'Cls Teacher Ladies', '2', '+910000003002'),
  ('cls.student.gents@example.invalid', 'Cls Student Gents', '1', '+910000003011'),
  ('cls.student.ladies@example.invalid', 'Cls Student Ladies', '2', '+910000003012'),
  ('cls.outsider@example.invalid', 'Cls Outsider', '1', ''),
  ('cls.nogender@example.invalid', 'Cls No Gender', NULL, ''),
  ('cls.admin@example.invalid', 'Cls Admin', '1', ''),
  ('cls.removed@example.invalid', 'Cls Removed', '1', ''),
  ('cls.parent@example.invalid', 'Cls Parent', '1', ''),
  ('cls.child.one@example.invalid', 'Cls Child One', '1', ''),
  ('cls.child.two@example.invalid', 'Cls Child Two', '2', ''),
  ('cls.child.three@example.invalid', 'Cls Child Three', '1', '')
) AS v (email, name, gender, mobile)
JOIN identity.users u ON u.email = v.email
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

INSERT INTO access.user_roles (user_id, roleid)
SELECT u.id, 1 FROM identity.users u WHERE u.email = 'cls.admin@example.invalid'
  AND NOT EXISTS (SELECT 1 FROM access.user_roles r WHERE r.user_id = u.id);

DELETE FROM classes.class_attendance WHERE session_id BETWEEN 939301 AND 939399;
DELETE FROM classes.class_sessions WHERE class_id BETWEEN 9301 AND 9399;
DELETE FROM classes.class_students WHERE class_id BETWEEN 9301 AND 9399;
DELETE FROM classes.class_schedules WHERE class_id BETWEEN 9301 AND 9399;
DELETE FROM classes.class_tags WHERE class_id BETWEEN 9301 AND 9399;
DELETE FROM classes.classes WHERE id BETWEEN 9301 AND 9399;
DELETE FROM classes.tags WHERE id BETWEEN 9301 AND 9399;
DELETE FROM classes.syllabus WHERE id BETWEEN 9301 AND 9399;
DELETE FROM classes.guides WHERE level_id IN (3, 4, 5) AND language_id = 1;

INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by)
VALUES
  (9301, 'CLS-G-001', 1, 'clslnk9301', 'Cls Gents Class', 3, DATE '2025-09-01', 900301, 1, 'Offline', 'Mumbai', 'India', 'Cls Hall', 'A', 900315),
  (9302, 'CLS-L-001', 2, 'clslnk9302', 'Cls Ladies Class', 5, DATE '2025-09-08', 900302, 2, 'Online', 'Dubai', 'United Arab Emirates', NULL, 'A', 900315),
  (9303, 'CLS-G-002', 1, 'clslnk9303', 'Cls Closed Class', 4, DATE '2024-09-01', 900301, 1, 'Offline', 'Mumbai', 'India', NULL, 'I', 900315);
INSERT INTO classes.tags (id, name) VALUES (9301, 'cls-beginners'), (9302, 'cls-evening');
INSERT INTO classes.class_tags (class_id, tag_id, created_by) VALUES (9301, 9301, 900315), (9301, 9302, 900315);
INSERT INTO classes.class_schedules (id, class_id, day, hour, minute, timezone, created_by)
VALUES (9301, 9301, 6, 18, 30, 'Asia/Kolkata', 900315), (9302, 9301, 2, 9, 15, 'Asia/Kolkata', 900315), (9303, 9302, 7, 10, 0, 'Asia/Dubai', 900315);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status)
VALUES
  (9301, 9301, 900311, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9302, 9301, 900322, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9303, 9301, 900316, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'Cls removed', 900315, 'I'),
  (9304, 9302, 900312, DATE '2025-09-08', 0, NULL, NULL, NULL, 'A'),
  (9305, 9302, 900323, DATE '2025-09-08', 0, NULL, NULL, NULL, 'A'),
  (9306, 9303, 900311, DATE '2024-09-01', 0, TIMESTAMPTZ '2025-06-30 00:00:00+00', 'Cls closed', 900315, 'I');

INSERT INTO classes.class_sessions (id, class_id, teacher, conducted_on, conducted, non_conduction_reason, conducted_by, duration, attendance)
VALUES
  (939301, 9301, 900301, DATE '2025-09-06', 1, NULL, 900301, 60, 2),
  (939302, 9301, 900301, DATE '2025-09-13', 0, 'Cls teacher unwell', NULL, NULL, NULL),
  (939303, 9301, 900301, DATE '2025-09-20', 1, NULL, 900301, 45, 1),
  (939304, 9302, 900302, DATE '2025-09-14', 1, NULL, 900302, 50, 2);
INSERT INTO classes.class_attendance (id, session_id, token, extra_student, present, recitation)
VALUES
  (939301, 939301, 900311, 0, 1, 5), (939302, 939301, 900322, 0, 1, 3), (939303, 939303, 900311, 0, 0, 0), (939304, 939303, 900322, 0, 1, 2),
  (939305, 939304, 900312, 0, 1, 4), (939306, 939304, 900323, 0, 1, 1);

DELETE FROM membership.user_guardians WHERE child_token BETWEEN 900321 AND 900329;
INSERT INTO membership.user_guardians
  (parent_token, child_token, relationship, status, source, code, expires_at, created_by, created_at, activated_at, revoked_by, revoked_at)
SELECT 900321, v.child, 'father', v.status, 'token_entry', NULL, NULL, p.id, TIMESTAMPTZ '2026-01-10 09:00:00+00',
       TIMESTAMPTZ '2026-01-10 09:00:00+00', CASE WHEN v.status = 'revoked' THEN p.id END,
       CASE WHEN v.status = 'revoked' THEN TIMESTAMPTZ '2026-01-11 09:00:00+00' END
FROM (VALUES (900322, 'active'), (900323, 'revoked'), (900324, 'active')) AS v (child, status)
JOIN identity.users p ON p.email = 'cls.parent@example.invalid';

INSERT INTO classes.guides (level_id, language_id, guide, created_by)
VALUES (3, 1, '<p>Cls Miqdad guide</p>', 900315), (5, 1, '   ', 900315);
INSERT INTO classes.syllabus (id, level_id, subject_name, description, link_type, url, sort_order, is_active, created_by)
VALUES
  (9301, 3, 'Cls syllabus b', NULL, 'external', 'https://example.invalid/syllabus/b', 2, 1, 900315),
  (9302, 3, 'Cls syllabus a', 'Invented description', 'pdf', 'https://example.invalid/syllabus/a.pdf', 1, 1, 900315),
  (9303, 3, 'Cls syllabus hidden', NULL, 'pdf', 'https://example.invalid/syllabus/h.pdf', 3, 0, 900315);

-- One quiz of class 9301 with three questions; the student 900311 answered two, one right (the performance figure is 50.0 of one quiz).
DELETE FROM assessment.spot_quiz_responses WHERE spot_quiz_id IN (9301, 9302);
DELETE FROM assessment.spot_quiz_questions WHERE spot_quiz_id IN (9301, 9302);
DELETE FROM assessment.spot_quizzes WHERE id IN (9301, 9302);
INSERT INTO assessment.spot_quizzes (id, code, language_id, level_id, name, class_id, restrict_to_class, published_at, published_by, created_by, created_at)
VALUES (9301, 'CLSQ9301', 1, 3, 'Cls quiz', 9301, 1, TIMESTAMPTZ '2025-09-06 12:00:00+00', 900301, 900301, TIMESTAMPTZ '2025-09-06 11:00:00+00');
INSERT INTO assessment.spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, answer)
VALUES (939301, 9301, FALSE, 'Cls question one', 'a', 'b', 1), (939302, 9301, FALSE, 'Cls question two', 'a', 'b', 2), (939303, 9301, FALSE, 'Cls question three', 'a', 'b', 1);
INSERT INTO assessment.spot_quiz_responses (id, spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct)
VALUES (939301, 9301, 939301, 900311, 'a', 'a', 1), (939302, 9301, 939302, 900311, 'a', 'b', 0), (939303, 9301, 939303, 900322, 'a', 'a', 1);
-- A second quiz, of the ladies class 9302: the ladies student 900312 answered three, one right (33.33, a figure that is not 50 or 100).
INSERT INTO assessment.spot_quizzes (id, code, language_id, level_id, name, class_id, restrict_to_class, published_at, published_by, created_by, created_at)
VALUES (9302, 'CLSQ9302', 1, 3, 'Cls quiz ladies', 9302, 1, TIMESTAMPTZ '2025-09-06 12:00:00+00', 900302, 900302, TIMESTAMPTZ '2025-09-06 11:00:00+00');
INSERT INTO assessment.spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, answer)
VALUES (939304, 9302, FALSE, 'Cls question four', 'a', 'b', 1), (939305, 9302, FALSE, 'Cls question five', 'a', 'b', 1), (939306, 9302, FALSE, 'Cls question six', 'a', 'b', 1);
INSERT INTO assessment.spot_quiz_responses (id, spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct)
VALUES (939304, 9302, 939304, 900312, 'a', 'a', 1), (939305, 9302, 939305, 900312, 'b', 'a', 0), (939306, 9302, 939306, 900312, 'b', 'a', 0);

-- The roster slice shows when a student joined (the day of the enrolment row's created_at) and the row's note: fixed here so the day does not move.
UPDATE classes.class_students SET created_at = joined_on + TIME '08:00' AT TIME ZONE 'UTC' WHERE class_id BETWEEN 9301 AND 9399;
UPDATE classes.class_students SET notes = 'Cls note &amp; more' WHERE id = 9301;
