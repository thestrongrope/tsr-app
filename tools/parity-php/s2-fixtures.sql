-- S2 fixtures for the scratch copy of the synthetic PHP database (tools/parity-php/s2-source.sh).
-- INVENTED data only: tokens 960001 and up, emails on .invalid, ids 960001 and up. Never real members.
-- Purpose: give every table the data load ports at least one row, and one row per MariaDB type class
-- that the load must convert (see tools/data-load/test/assert.sql, which names these ids).
SET SESSION sql_mode = '';
SET SESSION time_zone = '+00:00';

-- Users: emoji and accents; a 2001 character picture (the load cuts it to 2000 and counts it); NULL versus empty;
-- a zero date in a nullable column; a datetime; a role other than 0.
INSERT INTO users (id, token, email, roleid, name, first_name, last_name, provider, picture, createdon, lastlogin, gender, mobile, country, city, sendupdates, unsubscribe, firebase_uid, version, platform)
VALUES
 (960001, 960001, 's2-one@fixture.invalid', 4, CONCAT('Zo', CHAR(0xC3AB USING utf8mb4), ' ', CHAR(0xF09F9880 USING utf8mb4), ' name'), 'Zo', '', 'google', REPEAT('p', 2001), '2026-01-15 10:20:30', '2026-03-04 05:06:07', 'Female', '', 'India', 'Mumbai', 'Y', 'N', 's2-fixture-uid-1', '1.2.3', 'android'),
 (960002, 960002, 's2-two@fixture.invalid', 0, 'Plain Name', NULL, NULL, 'google', NULL, '0000-00-00 00:00:00', NULL, 'Male', '+910000000002', 'India', 'Pune', 'N', 'N', 's2-fixture-uid-2', NULL, NULL);

-- Tags and syllabus were empty in the generated data.
INSERT INTO tags (id, name, created_at, created_by) VALUES (960001, CONCAT('tag ', CHAR(0xF09F8C99 USING utf8mb4)), '2026-02-01 08:00:00', 960001);
INSERT INTO syllabus (id, level_id, subject_name, description, link_type, url, sort_order, is_active, created_at, created_by, modified_at, deleted_at)
VALUES
 (960001, (SELECT MIN(id) FROM class_levels), 'Fiqh', CONCAT('line one', CHAR(10), 'line two with', CHAR(9), 'a tab', CHAR(13), CHAR(10), 'back\\slash, "quotes", it''s, and \\N as text'), 'external', 'https://example.invalid/s2', 1, 1, '2026-02-02 09:00:00', 960001, '2026-02-03 10:00:00', '0000-00-00 00:00:00'),
 (960002, (SELECT MIN(id) FROM class_levels), 'Empty description', '', 'pdf', 'https://example.invalid/s2/2', NULL, 0, '2026-02-02 09:00:00', NULL, NULL, '2026-04-01 00:00:00');

-- SET column with a value that holds spaces, a slash and a parenthesis; an enum.
INSERT INTO class_registrations (id, token, class_level, interests, status, created_at)
VALUES (960001, 960001, 'Primary', 'Teaching,Writing (articles / scripts),Devops / Infra', 'Pending', '2026-02-10 11:00:00');

-- JSON longtext: valid with a non-ASCII value, and NULL.
INSERT INTO class_audit_log (id, class_id, action, details, performed_by, performed_at)
VALUES (960001, (SELECT MIN(id) FROM classes), 'updated', CONCAT('{"note":"', CHAR(0xF09F9880 USING utf8mb4), '","n":[1,2,3]}'), 960001, '2026-02-11 12:00:00'),
       (960002, (SELECT MIN(id) FROM classes), 'created', NULL, 960001, '2026-02-11 12:30:00');

-- A timestamp column (UTC) and a datetime column with explicit values.
INSERT INTO user_devices (id, token, device_id, last_accessed_at, registered_at)
VALUES (960001, 960001, 's2-device-one', '2026-02-03 04:05:06', '2026-01-02 03:04:05');

-- The two tables added by migration 2026_11_08 (empty in the generated data). send_at and send_time are wall clock in tz.
INSERT INTO class_scheduled_notifications (id, class_id, created_by, created_by_user_id, title, body, action_link, kind, send_at, weekdays, send_time, tz, class_schedule_id, offset_minutes, repeat_weekly, status, last_run_at, last_run_key, created_at, updated_at)
VALUES
 (960001, (SELECT MIN(id) FROM classes), 960001, 960001, CONCAT('Once ', CHAR(0xF09F9880 USING utf8mb4)), CONCAT('first line', CHAR(10), 'second line'), NULL, 'ONCE', '2026-12-01 09:30:00', NULL, NULL, 'Asia/Kolkata', NULL, NULL, 0, 'active', NULL, NULL, '2026-11-01 08:00:00', '2026-11-01 08:00:00'),
 (960002, (SELECT MIN(id) FROM classes), 960001, 960001, 'Weekly', 'body', 'https://example.invalid/a', 'WEEKLY', NULL, 'MON,WED', '18:45:00', 'Asia/Kolkata', NULL, NULL, 1, 'done', '2026-11-04 13:15:00', 'k1', '2026-11-01 08:00:00', '2026-11-05 08:00:00');
INSERT INTO class_scheduled_notification_runs (id, scheduled_id, class_id, run_at, notification_id, student_count, device_count, success_count, failure_count, skipped_reason)
VALUES (960001, 960002, (SELECT MIN(id) FROM classes), '2026-11-04 13:15:00', NULL, 10, 8, 7, 1, NULL),
       (960002, 960002, (SELECT MIN(id) FROM classes), '2026-11-11 13:15:00', NULL, 0, 0, 0, 0, '');

-- The calendar's two tables, added by the migrations of 2026_11_10 (empty in the generated data). send_time is wall clock in tz;
-- the settings' two times are datetime(3).
INSERT INTO class_scheduled_events (id, class_id, created_by, created_by_user_id, message, description, action_link, weekdays, send_time, tz, status, created_at, updated_at, deleted_at)
VALUES
 (960001, (SELECT MIN(id) FROM classes), 960001, 960001, 'Bring your notebook', CONCAT('line one', CHAR(10), 'line two'), NULL, 'TUE,THU', '07:15:00', 'Asia/Kolkata', 'active', '2026-11-12 08:00:00', '2026-11-12 08:00:00', NULL),
 (960002, (SELECT MIN(id) FROM classes), 960001, 960001, 'Old event', NULL, 'https://example.invalid/e', 'SUN', '20:00:00', 'Europe/London', 'deleted', '2026-11-12 08:00:00', '2026-11-13 09:30:00', '2026-11-13 09:30:00');
INSERT INTO member_event_settings (id, user_id, class_id, event_key, offset_minutes, muted, deleted_for_me, client_updated_at, server_updated_at, device_key)
VALUES
 (960001, 960001, (SELECT MIN(id) FROM classes), 'event:960001', NULL, 1, 0, '2026-11-14 10:11:12.345', '2026-11-14 10:11:13.000', 's2-device-one'),
 (960002, 960001, (SELECT MIN(id) FROM classes), 'schedule:1', 15, 0, 1, '2026-11-15 01:02:03.004', '2026-11-15 01:02:03.500', 's2-device-one');

-- Orphans, on purpose: a student of a class that does not exist, a device of a member that does not exist,
-- an attendance row of a session that does not exist. The load reports them; it never fails on them.
INSERT INTO class_students (id, class_id, token_no, joined_on, created_at, status) VALUES (960001, 987654, 960001, '2026-02-01', '2026-02-01 08:00:00', 'A');
INSERT INTO user_devices (id, token, device_id) VALUES (960002, 960098, 's2-device-orphan');
