/*
 * The calendar fixtures for the PHP parity stack's MariaDB: the same rows as db/synthetic/calendar-fixtures.sql (read the header there).
 * Loaded by tools/contract-calendar.sh before every run; resets every row it owns, and ONLY those, by explicit lists of ids (never a token range: a bulk add elsewhere hands out the next free token).
 * Synthetic only: member tokens 928001 to 928099, classes 9701 to 9709, every other row 9280000 to 9289999. The two 2026_11_10 migrations (class_scheduled_events, member_event_settings) are
 * already applied to the parity database.
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, CONCAT('cal.', v.token, '@example.invalid'), 0, 'firebase', NOW(), CONCAT('Cal Member ', v.token), '1', CONCAT('+91000028', RIGHT(v.token, 4)) FROM (
  SELECT 928001 AS token UNION ALL SELECT 928002 UNION ALL SELECT 928011 UNION ALL SELECT 928012 UNION ALL SELECT 928013 UNION ALL SELECT 928014 UNION ALL SELECT 928015 UNION ALL SELECT 928016
  UNION ALL SELECT 928019 UNION ALL SELECT 928021 UNION ALL SELECT 928022 UNION ALL SELECT 928023) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users SET email = CONCAT('cal.', token, '@example.invalid'), name = CONCAT('Cal Member ', token), gender = '1',
  roleid = CASE token WHEN 928002 THEN 1 ELSE 0 END, mobile = CONCAT('+91000028', RIGHT(token, 4))
WHERE token IN (928001, 928002, 928011, 928012, 928013, 928014, 928015, 928016, 928019, 928021, 928022, 928023);

DELETE FROM member_event_settings WHERE user_id IN (SELECT id FROM users WHERE token IN (928001, 928002, 928011, 928012, 928013, 928014, 928015, 928016, 928019, 928021, 928022, 928023));
DELETE FROM class_scheduled_events WHERE class_id IN (9701, 9702, 9703, 9704, 9705, 9706, 9709);
DELETE FROM class_schedules WHERE class_id IN (9701, 9702, 9703, 9704, 9705, 9706, 9709);
DELETE FROM class_students WHERE class_id IN (9701, 9702, 9703, 9704, 9705, 9706, 9709);
DELETE FROM classes WHERE id IN (9701, 9702, 9703, 9704, 9705, 9706, 9709);

INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (9701, 'CAL-G-701', 9, 'callnk9701', 'Cal Class Guards', 3, '2025-01-06', 928011, 1, 'Offline', 'Calville', 'India', 'Cal Hall', 'A', 928011),
  (9702, 'CAL-G-702', 9, 'callnk9702', 'Cal Class Read', 3, '2025-01-06', 928012, 1, 'Offline', 'Calville', 'India', 'Cal Hall', 'A', 928012),
  (9703, 'CAL-G-703', 9, 'callnk9703', 'Cal Class Create', 3, '2025-01-06', 928013, 1, 'Offline', 'Calville', 'India', 'Cal Hall', 'A', 928013),
  (9704, 'CAL-G-704', 9, 'callnk9704', 'Cal Class Edit', 3, '2025-01-06', 928014, 1, 'Offline', 'Calville', 'India', 'Cal Hall', 'A', 928014),
  (9705, 'CAL-G-705', 9, 'callnk9705', 'Cal Class Delete', 3, '2025-01-06', 928015, 1, 'Offline', 'Calville', 'India', 'Cal Hall', 'A', 928015),
  (9706, 'CAL-G-706', 9, 'callnk9706', 'Cal Class Settings', 3, '2025-01-06', 928016, 1, 'Offline', 'Calville', 'India', 'Cal Hall', 'A', 928016),
  (9709, 'CAL-G-709', 9, 'callnk9709', 'Cal Class Closed', 3, '2025-01-06', 928019, 1, 'Offline', 'Calville', 'India', 'Cal Hall', 'I', 928019);

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9280301, 9701, 928023, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9280302, 9702, 928021, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9280303, 9709, 928021, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9280304, 9706, 928022, '2025-01-06', 0, NULL, NULL, NULL, 'A');

INSERT INTO class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) VALUES
  (9280202, 9702, 2, 18, 5, 'Europe/London', 928012, NULL, NULL),
  (9280203, 9702, 3, 9, 0, 'Asia/Kolkata', 928012, '2026-01-12 00:00:00', 928012),
  (9280206, 9706, 4, 7, 0, 'Asia/Kolkata', 928016, NULL, NULL),
  (9280209, 9709, 5, 8, 0, 'Asia/Kolkata', 928019, NULL, NULL);

INSERT INTO class_scheduled_events (id, class_id, created_by, created_by_user_id, message, description, action_link, weekdays, send_time, tz, status, created_at, updated_at, deleted_at)
SELECT v.id, v.class_id, v.created_by, u.id, v.message, v.description, v.action_link, v.weekdays, v.send_time, v.tz, v.status, '2026-11-10 08:00:00', '2026-11-10 08:00:00',
       IF(v.status = 'deleted', '2026-11-11 08:00:00', NULL)
FROM (
  SELECT 9280421 AS id, 9702 AS class_id, 928012 AS created_by, 'Cal Read the lesson' AS message, 'Chapter two' AS description, '/classes/9702/syllabus' AS action_link, '1,3' AS weekdays, '18:30:00' AS send_time, 'Asia/Kolkata' AS tz, 'active' AS status
  UNION ALL SELECT 9280422, 9702, 928002, 'Cal Super event', NULL, NULL, '5', '07:05:00', 'Europe/London', 'active'
  UNION ALL SELECT 9280423, 9702, 928012, 'Cal Deleted event', NULL, NULL, '2', '09:00:00', 'Asia/Kolkata', 'deleted'
  UNION ALL SELECT 9280441, 9704, 928014, 'Cal Edit me', 'Before', '/classes/9704/syllabus', '2,4', '07:15:00', 'Europe/London', 'active'
  UNION ALL SELECT 9280442, 9704, 928002, 'Cal Super event', NULL, NULL, '5', '07:05:00', 'Europe/London', 'active'
  UNION ALL SELECT 9280443, 9704, 928014, 'Cal Deleted event', NULL, NULL, '2', '09:00:00', 'Asia/Kolkata', 'deleted'
  UNION ALL SELECT 9280451, 9705, 928015, 'Cal Delete me', NULL, NULL, '2,4', '07:15:00', 'Europe/London', 'active'
  UNION ALL SELECT 9280452, 9705, 928002, 'Cal Super event', NULL, NULL, '5', '07:05:00', 'Europe/London', 'active'
  UNION ALL SELECT 9280453, 9705, 928015, 'Cal Deleted event', NULL, NULL, '2', '09:00:00', 'Asia/Kolkata', 'deleted'
  UNION ALL SELECT 9280461, 9706, 928016, 'Cal Settings one', NULL, NULL, '1', '10:00:00', 'Asia/Kolkata', 'active'
  UNION ALL SELECT 9280462, 9706, 928016, 'Cal Deleted event', NULL, NULL, '2', '09:00:00', 'Asia/Kolkata', 'deleted'
  UNION ALL SELECT 9280463, 9706, 928016, 'Cal Settings two', NULL, NULL, '2', '11:00:00', 'Asia/Kolkata', 'active'
  UNION ALL SELECT 9280464, 9706, 928016, 'Cal Settings three', NULL, NULL, '3', '12:00:00', 'Asia/Kolkata', 'active'
  UNION ALL SELECT 9280491, 9709, 928019, 'Cal Closed class event', NULL, NULL, '1', '10:00:00', 'Asia/Kolkata', 'active'
) v
JOIN users u ON u.token = v.created_by;

INSERT INTO member_event_settings (user_id, class_id, event_key, offset_minutes, muted, deleted_for_me, client_updated_at, server_updated_at, device_key)
SELECT u.id, 9702, v.event_key, v.offset_minutes, v.muted, v.deleted_for_me, '2026-11-10 08:00:00.000', '2026-11-10 08:00:01.500', 'calfixturedevice01'
FROM (SELECT 'event:9280421' AS event_key, -15 AS offset_minutes, 1 AS muted, 0 AS deleted_for_me UNION ALL SELECT 'event:9280422', NULL, 0, 1) v
JOIN users u ON u.token = 928021;
