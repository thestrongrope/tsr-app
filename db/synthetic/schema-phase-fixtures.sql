/*
 * Synthetic rows for the tables of the schema phase (classes, assessment, notifications, and platform's and content's new tables),
 * so every table has at least one row and a small, coherent story: classes of each gender and status with levels, tags, teachers,
 * schedules, sessions, attendance and enrolments for the synthetic members of seed.sql; a spot quiz with questions, a submission and
 * responses; standard MCQs; devices, notifications, a scheduled notification of each kind and the notifier's rows.
 * Included by seed.sql. Every value is invented: member tokens are the 900000 range of seed.sql, emails (where any) end .invalid,
 * IPs are from the documentation range. Rows have fixed ids (9001 and up) and ON CONFLICT DO NOTHING, so running it again changes nothing.
 * Not a migration: production must never get these rows.
 *
 *   members used: 900001 (gents), 900002 (ladies), 900303 (gents class teacher), 900304 (ladies class teacher): not 9001xx (the access contract holds those to no class) and not 9003xx (the classes contract fixtures)
 *   genders: 1 Male, 2 Female. Languages: 1 English, 2 Urdu, 3 Hindi. Levels 1 to 5 (names are the programme's).
 *   classes: 9001 gents active, 9002 ladies active, 9003 gents inactive (status I), 9004 ladies active online
 */

INSERT INTO platform.genders (id, name) VALUES (1, 'Male'), (2, 'Female') ON CONFLICT DO NOTHING;

INSERT INTO platform.languages (id, name, sort_order) VALUES (1, 'English', 1), (2, 'Urdu', 2), (3, 'Hindi', 3) ON CONFLICT DO NOTHING;

INSERT INTO platform.admin_access_log (id, accessed_at, user_id, token, roleid, page, method, ip, user_agent, referer, session_id)
VALUES
  (9001, TIMESTAMPTZ '2026-01-10 08:00:00+00', NULL, 900003, 1, '/admin/classes.php', 'GET', '192.0.2.10', 'Synthetic Browser 1.0', NULL, 'synthetic-session-1'),
  (9002, TIMESTAMPTZ '2026-01-10 08:05:00+00', NULL, 900003, 1, '/admin/reports.php', 'POST', '192.0.2.10', 'Synthetic Browser 1.0', 'https://example.invalid/admin/classes.php', 'synthetic-session-1')
ON CONFLICT DO NOTHING;

INSERT INTO platform.outbound_messages (id, channel, recipient, payload, dedupe_key, status, attempts, next_attempt_at, created_by, created_at, sent_at, error)
VALUES
  (9001, 'push', 'synthetic-device-0001', '{"title":"Synthetic push","body":"Invented text"}', 'synthetic-push-1', 'queued', 0, NULL, NULL, TIMESTAMPTZ '2026-01-10 09:00:00+00', NULL, NULL),
  (9002, 'whatsapp:gents', '+910000000001', '{"text":"Invented reminder"}', 'synthetic-wa-1', 'sent', 1, NULL, 900303, TIMESTAMPTZ '2026-01-10 09:01:00+00', TIMESTAMPTZ '2026-01-10 09:01:30+00', NULL),
  (9003, 'whatsapp:ladies', '+910000000002', NULL, NULL, 'failed', 3, TIMESTAMPTZ '2026-01-11 09:00:00+00', NULL, TIMESTAMPTZ '2026-01-10 09:02:00+00', NULL, 'Synthetic delivery error')
ON CONFLICT DO NOTHING;

INSERT INTO content.holy_quran (id, surah, arabic, verses)
VALUES (1, 'Al-Fatiha', 'الفاتحة', 7), (2, 'Al-Baqarah', 'البقرة', 286), (3, 'Aal-Imran', 'آل عمران', 200)
ON CONFLICT DO NOTHING;

-- A cancelled web request raised by someone matching no member (token NULL): it never blocks a sign-in.
INSERT INTO identity.account_deletion_requests
  (token, status, source, reason, contact_name, contact_email, operator_note, requested_at, cancelled_at, confirmation_sent_at, handled_by)
SELECT NULL, 'cancelled', 'web', 'Synthetic reason', 'Synthetic Web Requester', 'web.requester@example.invalid', 'Synthetic note',
       TIMESTAMPTZ '2026-01-05 10:00:00+00', TIMESTAMPTZ '2026-01-06 10:00:00+00', TIMESTAMPTZ '2026-01-05 10:05:00+00', 900003
WHERE NOT EXISTS (SELECT 1 FROM identity.account_deletion_requests r WHERE r.contact_email = 'web.requester@example.invalid');

-- classes -----------------------------------------------------------------------------------------------------------------------------

INSERT INTO classes.class_levels (id, code, name, sort_order)
VALUES (1, 'SM', 'SALMAN', 1), (2, 'AG', 'ABUZAR', 2), (3, 'MK', 'MIQDAD', 3), (4, 'AY', 'AMMAR', 4), (5, 'B', 'BILAL', 5)
ON CONFLICT DO NOTHING;

INSERT INTO classes.tags (id, name) VALUES (9001, 'synthetic-beginners'), (9002, 'synthetic-online') ON CONFLICT DO NOTHING;

INSERT INTO classes.classes
  (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, address, city, country, lat, lng, location,
   extra_students, status, shutdown_on, completed_on, comments, created_by)
VALUES
  (9001, 'SYN-G-001', 1, 'synlnk0001', 'Synthetic Gents Class', 1, DATE '2025-09-01', 900303, 1, 'Offline', '1 Invented Street', 'Mumbai', 'India',
   19.07600000, 72.87770000, 'Synthetic Hall', NULL, 'A', NULL, NULL, NULL, 900003),
  (9002, 'SYN-L-001', 2, 'synlnk0002', 'Synthetic Ladies Class', 2, DATE '2025-09-08', 900304, 2, 'Offline', '2 Invented Road', 'Dubai', 'United Arab Emirates',
   25.20480000, 55.27080000, 'Synthetic Centre', 'Invented Guest One, Invented Guest Two', 'A', NULL, NULL, 'Invented comment', 900003),
  (9003, 'SYN-G-002', 1, 'synlnk0003', 'Synthetic Closed Gents Class', 3, DATE '2024-09-01', 900303, 1, 'Offline', NULL, 'Mumbai', 'India',
   NULL, NULL, NULL, NULL, 'I', DATE '2025-06-30', DATE '2025-06-30', 'Closed for the synthetic story', 900003),
  (9004, 'SYN-L-002', 3, 'synlnk0004', 'Synthetic Online Ladies Class', 3, DATE '2025-10-01', 900304, 2, 'Online', NULL, 'Karachi', 'Pakistan',
   NULL, NULL, NULL, NULL, 'A', NULL, NULL, NULL, 900003)
ON CONFLICT DO NOTHING;

INSERT INTO classes.class_tags (class_id, tag_id, created_by) VALUES (9001, 9001, 900003), (9004, 9002, 900003) ON CONFLICT DO NOTHING;

INSERT INTO classes.class_schedules (id, class_id, day, hour, minute, timezone, created_by)
VALUES (9001, 9001, 6, 18, 30, 'Asia/Kolkata', 900003), (9002, 9002, 7, 10, 0, 'Asia/Dubai', 900003), (9003, 9004, 3, 20, 15, 'Asia/Karachi', 900003)
ON CONFLICT DO NOTHING;

INSERT INTO classes.topics (id, name, is_vocational, sort_order, created_by)
VALUES (9001, 'Synthetic Aqaed', 0, 1, 900003), (9002, 'Synthetic Akhlaq', 0, 2, 900003), (9003, 'Synthetic Craft', 1, 3, 900003)
ON CONFLICT DO NOTHING;

INSERT INTO classes.class_schedule_topics (id, class_schedule_id, topic_id, sort_order, created_by)
VALUES (9001, 9001, 9001, 1, 900003), (9002, 9001, 9002, 2, 900003), (9003, 9002, 9003, 1, 900003)
ON CONFLICT DO NOTHING;

INSERT INTO classes.class_sessions
  (id, class_id, teacher, conducted_on, conducted, non_conduction_reason, conducted_by, duration, attendance, quran_recitation_surah,
   quran_recitation_verse, aqaed_conducted, aqaed_topic, akhlaq_conducted, akhlaq_topic, assignments, assignment_count, team_request, created_by)
VALUES
  (9001, 9001, 900303, DATE '2025-09-06', 1, NULL, 900303, 60, 1, 1, 7, 'Y', 'Synthetic belief topic', 'N', NULL, 'Invented assignment', 1, NULL, 900303),
  (9002, 9001, 900303, DATE '2025-09-13', 0, 'Synthetic: teacher unwell', NULL, NULL, NULL, NULL, NULL, 'N', NULL, 'N', NULL, NULL, 0, NULL, 900303),
  (9003, 9002, 900304, DATE '2025-09-14', 1, NULL, 900304, 45, 1, 2, 5, 'Y', 'Synthetic belief topic', 'Y', 'Synthetic manners topic', NULL, 0, 'Invented request', 900304),
  (9004, 9004, 900304, DATE '2025-10-08', 1, NULL, 900304, 50, 0, NULL, NULL, 'Y', 'Synthetic belief topic', 'N', NULL, NULL, 0, NULL, 900304)
ON CONFLICT DO NOTHING;

INSERT INTO classes.class_attendance (id, session_id, token, name, extra_student, present, recitation, pages_read, assignments_done, followup)
VALUES
  (9001, 9001, 900001, 'Synthetic Gents Member', 0, 1, 7, 2, 1, NULL),
  (9002, 9003, 900002, 'Synthetic Ladies Member', 0, 1, 5, 1, 0.5, 'Invented follow-up'),
  (9003, 9003, 0, 'Invented Guest One', 1, 0, 0, 0, 0, NULL)
ON CONFLICT DO NOTHING;

INSERT INTO classes.class_students
  (id, class_id, token_no, joined_on, data_admin, mcq_admin, assignment_admin, removed_at, removed_reason, removed_by, status, notes, added_by)
VALUES
  (9001, 9001, 900001, DATE '2025-09-01', 0, 1, 0, NULL, NULL, NULL, 'A', 'Invented class-specific note', 900303),
  (9002, 9002, 900002, DATE '2025-09-08', 1, 0, 1, NULL, NULL, NULL, 'A', NULL, 900304),
  (9003, 9003, 900001, DATE '2024-09-01', 0, 0, 0, TIMESTAMPTZ '2025-06-30 00:00:00+00', 'Synthetic: class closed', 900003, 'I', NULL, 900303)
ON CONFLICT DO NOTHING;

INSERT INTO classes.student_transfers (id, token_no, from_class_id, to_class_id, type, reason, transferred_by, transferred_at)
VALUES (9001, 900001, 9003, 9001, 'promotion', 'Synthetic promotion', 900003, TIMESTAMPTZ '2025-07-01 00:00:00+00')
ON CONFLICT DO NOTHING;

INSERT INTO classes.class_audit_log (id, class_id, action, details, performed_by, performed_at)
VALUES
  (9001, 9001, 'created', '{"name":"Synthetic Gents Class"}', 900003, TIMESTAMPTZ '2025-08-30 00:00:00+00'),
  (9002, 9003, 'deactivated', '{"reason":"Closed for the synthetic story"}', 900003, TIMESTAMPTZ '2025-06-30 00:00:00+00')
ON CONFLICT DO NOTHING;

INSERT INTO classes.teachers (token, salman, abuzar, miqdad, ammar, bilal, comments, status, created_by)
VALUES (900303, 0, 0, 1, 1, 1, 'Invented teacher note', 'A', 900003), (900304, 0, 0, 0, 1, 1, NULL, 'A', 900003)
ON CONFLICT DO NOTHING;

INSERT INTO classes.teachers_history (id, token, salman, abuzar, miqdad, ammar, bilal, comments, status, created_by)
VALUES (9001, 900303, 0, 0, 0, 1, 1, 'Before miqdad training', 'A', 900003)
ON CONFLICT DO NOTHING;

INSERT INTO classes.syllabus (id, level_id, subject_name, description, link_type, url, sort_order, is_active, created_by)
VALUES
  (9001, 1, 'Synthetic syllabus (pdf)', 'Invented description', 'pdf', 'https://example.invalid/syllabus/level-1.pdf', 1, 1, 900003),
  (9002, 2, 'Synthetic syllabus (web)', NULL, 'external', 'https://example.invalid/syllabus/level-2', 1, 1, 900003)
ON CONFLICT DO NOTHING;

INSERT INTO classes.guides (id, level_id, language_id, guide, created_by)
VALUES (9001, 1, 1, 'Invented guide text for level 1 in English.', 900003)
ON CONFLICT DO NOTHING;

-- assessment --------------------------------------------------------------------------------------------------------------------------

INSERT INTO assessment.standard_mcqs (id, code, language_id, level_id, topic, subject, lesson, name, sort_order, created_by)
VALUES
  (9001, 'SYN-MCQ-1', 1, 1, 'Synthetic topic', 'Synthetic subject', 'Synthetic lesson 1', 'Synthetic MCQ set 1', 1, 900003),
  (9002, 'SYN-MCQ-2', 1, 2, 'Synthetic topic', 'Synthetic subject', 'Synthetic lesson 2', 'Synthetic MCQ set 2', 2, 900003)
ON CONFLICT DO NOTHING;

INSERT INTO assessment.standard_mcq_questions
  (id, mcq_code, question, answer, option1, option2, option3, reason_option1, reason_option2, reason_option3, sort_order, created_by)
VALUES
  (9001, 'SYN-MCQ-1', 'Synthetic question one?', 'Synthetic right answer', 'Synthetic right answer', 'Synthetic wrong A', 'Synthetic wrong B', NULL, 'Because A is wrong', 'Because B is wrong', 1, 900003),
  (9002, 'SYN-MCQ-1', 'Synthetic question two?', 'Yes', 'Yes', 'No', NULL, NULL, NULL, NULL, 2, 900003),
  (9003, 'SYN-MCQ-2', 'Synthetic question three?', 'Blue', 'Blue', 'Red', 'Green', NULL, NULL, NULL, 1, 900003)
ON CONFLICT DO NOTHING;

INSERT INTO assessment.spot_quizzes
  (id, code, mcq_code, language_id, level_id, topic_id, subject_id, lesson_id, name, class_id, topic, session, restrict_to_class,
   published_at, published_by, created_by, created_at)
VALUES
  (9001, 'SYNQ0001', 'SYN-MCQ-1', 1, 1, 9001, NULL, NULL, 'Synthetic published quiz', 9001, 'Synthetic belief topic', 1, 1,
   TIMESTAMPTZ '2025-09-06 12:00:00+00', 900303, 900303, TIMESTAMPTZ '2025-09-06 11:00:00+00'),
  (9002, 'SYNQ0002', NULL, 1, 2, NULL, NULL, NULL, 'Synthetic draft quiz', 9002, NULL, NULL, 0,
   NULL, NULL, 900304, TIMESTAMPTZ '2025-09-14 11:00:00+00')
ON CONFLICT DO NOTHING;

INSERT INTO assessment.spot_quiz_questions
  (id, spot_quiz_id, is_arabic, question, option1, option2, option3, option4, option5, answer, option_display_order)
VALUES
  (9001, 9001, FALSE, 'Synthetic quiz question one?', 'Right', 'Wrong A', 'Wrong B', NULL, NULL, 1, '1,2,3'),
  (9002, 9001, FALSE, 'Synthetic quiz question two?', 'Wrong', 'Right', NULL, NULL, NULL, 2, NULL),
  (9003, 9001, TRUE, 'سؤال تجريبي', 'نعم', 'لا', NULL, NULL, NULL, 1, NULL)
ON CONFLICT DO NOTHING;

INSERT INTO assessment.spot_quiz_submissions (id, spot_quiz_id, token, created_at, modified_at)
VALUES (9001, 9001, 900001, TIMESTAMPTZ '2025-09-06 12:30:00+00', TIMESTAMPTZ '2025-09-06 12:35:00+00')
ON CONFLICT DO NOTHING;

INSERT INTO assessment.spot_quiz_responses (id, spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct)
VALUES
  (9001, 9001, 9001, 900001, 'Right', 'Right', 1),
  (9002, 9001, 9002, 900001, 'Wrong', 'Right', 0),
  (9003, 9001, 9003, 900001, NULL, 'نعم', NULL)
ON CONFLICT DO NOTHING;

INSERT INTO assessment.quiz_campaigns (id, name, year, registrations_start, registrations_end, quiz_start, quiz_disabled, quiz_end, outof, active)
VALUES (9001, 'Synthetic Grand Quiz', 2026, TIMESTAMPTZ '2026-01-01 00:00:00+00', TIMESTAMPTZ '2026-01-31 00:00:00+00',
        TIMESTAMPTZ '2026-02-10 00:00:00+00', NULL, TIMESTAMPTZ '2026-02-17 00:00:00+00', 100, 1)
ON CONFLICT DO NOTHING;

-- notifications -----------------------------------------------------------------------------------------------------------------------

INSERT INTO notifications.user_devices (id, token, device_id, registered_at, last_accessed_at)
VALUES (9001, 900001, 'synthetic-device-0001', TIMESTAMPTZ '2026-01-01 00:00:00+00', TIMESTAMPTZ '2026-01-10 00:00:00+00'),
       (9002, 900002, 'synthetic-device-0002', TIMESTAMPTZ '2026-01-02 00:00:00+00', TIMESTAMPTZ '2026-01-10 00:00:00+00')
ON CONFLICT DO NOTHING;

INSERT INTO notifications.notifications
  (notification_id, title, body, target_audience_criteria, sent_at, created_by, device_count, success_count, failure_count, priority, image_url, action_link)
VALUES
  (9001, 'Synthetic notice', 'Invented body text.', '{"class_id":9001}', TIMESTAMPTZ '2026-01-10 09:00:00+00', 900303, 1, 1, 0, 'NORMAL', NULL, NULL),
  (9002, 'Synthetic announcement', 'Another invented body.', '{"gender":"all"}', TIMESTAMPTZ '2026-01-11 09:00:00+00', 900003, 2, 1, 1, 'HIGH',
   'https://example.invalid/image.png', 'https://example.invalid/link')
ON CONFLICT DO NOTHING;

INSERT INTO notifications.user_notifications (id, notification_id, user_token, is_read, read_at, created_at)
VALUES (9001, 9001, 900001, 1, TIMESTAMPTZ '2026-01-10 10:00:00+00', TIMESTAMPTZ '2026-01-10 09:00:00+00'),
       (9002, 9002, 900001, 0, NULL, TIMESTAMPTZ '2026-01-11 09:00:00+00'),
       (9003, 9002, 900002, 0, NULL, TIMESTAMPTZ '2026-01-11 09:00:00+00')
ON CONFLICT DO NOTHING;

INSERT INTO notifications.notifier_reminders
  (id, name, type, gender, city, country, levels, lang, leeway_days, timezone, weekday, send_time, schedule_on, enabled, updated_by)
VALUES
  (9001, 'Synthetic gents reminder', 'cform_missing', 'gents', NULL, NULL, 'BILAL,AMMAR', 'english', 10, 'Asia/Kolkata', 1, TIME '09:00', 1, 1, 900003),
  (9002, 'Synthetic ladies reminder', 'cform_missing', 'ladies', 'Dubai', 'United Arab Emirates', 'BILAL', 'english', 7, 'Asia/Dubai', NULL, NULL, 0, 0, 900003)
ON CONFLICT DO NOTHING;

INSERT INTO notifications.notifier_runs
  (id, reminder_id, started_at, finished_at, from_date, to_date, status, sent_count, skipped_count, failed_count, dry_run, triggered_by, settings_snapshot, error_message)
VALUES
  (9001, 9001, TIMESTAMPTZ '2026-01-12 03:30:00+00', TIMESTAMPTZ '2026-01-12 03:31:00+00', DATE '2026-01-05', DATE '2026-01-11', 'completed', 1, 1, 0, 0, NULL,
   '{"leeway_days":10}', NULL),
  (9002, 9002, TIMESTAMPTZ '2026-01-12 04:00:00+00', TIMESTAMPTZ '2026-01-12 04:00:05+00', DATE '2026-01-05', DATE '2026-01-11', 'failed', 0, 0, 1, 1, 900003,
   NULL, 'Synthetic failure')
ON CONFLICT DO NOTHING;

INSERT INTO notifications.notifier_sent_messages
  (id, run_id, teacher_token, teacher_mobile, teacher_name, total_missing, message_excerpt, status, error, sent_at)
VALUES
  (9001, 9001, 900303, '+910000000001', 'Synthetic Teacher One', 3, 'Invented excerpt of the reminder', 'sent', NULL, TIMESTAMPTZ '2026-01-12 03:30:30+00'),
  (9002, 9001, NULL, '+910000000003', NULL, NULL, NULL, 'skipped', NULL, TIMESTAMPTZ '2026-01-12 03:30:40+00'),
  (9003, 9002, 900304, '+910000000002', 'Synthetic Teacher Two', 1, 'Invented excerpt', 'dry_run', NULL, TIMESTAMPTZ '2026-01-12 04:00:02+00')
ON CONFLICT DO NOTHING;

-- send_at and send_time are wall-clock values in tz, not UTC.
INSERT INTO notifications.class_scheduled_notifications
  (id, class_id, created_by, created_by_user_id, title, body, action_link, kind, send_at, weekdays, send_time, tz,
   class_schedule_id, offset_minutes, repeat_weekly, status, last_run_at, last_run_key)
VALUES
  (9001, 9001, 900303, 900303, 'Synthetic one-off', 'Invented body', NULL, 'ONCE', TIMESTAMP '2026-02-01 18:00:00', NULL, NULL, 'Asia/Kolkata',
   NULL, NULL, 0, 'done', TIMESTAMPTZ '2026-02-01 12:30:00+00', 'once-2026-02-01'),
  (9002, 9001, 900303, 900303, 'Synthetic weekly', 'Invented body', 'https://example.invalid/link', 'WEEKLY', NULL, '1,3', TIME '19:30', 'Asia/Kolkata',
   NULL, NULL, 0, 'active', NULL, NULL),
  (9003, 9002, 900304, 900304, 'Synthetic reminder before class', 'Invented body', NULL, 'REMINDER', NULL, NULL, NULL, 'Asia/Dubai',
   9002, -30, 1, 'active', NULL, NULL)
ON CONFLICT DO NOTHING;

INSERT INTO notifications.class_scheduled_notification_runs
  (id, scheduled_id, class_id, run_at, notification_id, student_count, device_count, success_count, failure_count, skipped_reason)
VALUES
  (9001, 9001, 9001, TIMESTAMPTZ '2026-02-01 12:30:00+00', 9001, 1, 1, 1, 0, NULL),
  (9002, 9002, 9001, TIMESTAMPTZ '2026-02-02 14:00:00+00', NULL, 0, 0, 0, 0, 'no devices')
ON CONFLICT DO NOTHING;
