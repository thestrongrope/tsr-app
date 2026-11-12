/*
 * The calendar fixtures (the member calendar, its settings, a class's scheduled events) for the new API's database. tools/parity-php/calendar-fixtures.sql holds the same rows for the PHP parity stack.
 * Loaded by tools/contract-calendar.sh before every run; resets every row it owns, and ONLY those, by explicit lists of ids (never a token range: a bulk add elsewhere hands out the next free token).
 * Synthetic only: member tokens 928001 to 928099 (emails cal.<token>@example.invalid), classes 9701 to 9709, every other row 9280000 to 9289999.
 *
 *   928001 plain member, in no class   928002 super administrator
 *   class 9701 (teacher 928011): the guards; student 928023
 *   class 9702 (teacher 928012): READ ONLY. Events 9280421 (the teacher's), 9280422 (the super administrator's), 9280423 (deleted); slots 9280202 (live), 9280203 (deleted); student 928021
 *   class 9703 (teacher 928013): events are created here (none to start with)
 *   class 9704 (teacher 928014): events are edited here. 9280441 (the teacher's), 9280442 (the super administrator's), 9280443 (deleted)
 *   class 9705 (teacher 928015): events are deleted here. 9280451 (the teacher's), 9280452 (the super administrator's), 9280453 (deleted)
 *   class 9706 (teacher 928016): the settings sync. Events 9280461, 9280463, 9280464 (live), 9280462 (deleted); slot 9280206; student 928022
 *   class 9709 (teacher 928019): closed. Event 9280491, slot 9280209; student 928021
 *   928021 reads the calendar and never syncs: two settings are stored for them (9280421 muted with a 15 minute alert, 9280422 deleted for them). 928022 syncs settings (none to start with).
 */
INSERT INTO identity.users (token, email)
SELECT v.token, 'cal.' || v.token || '@example.invalid' FROM (VALUES
  (928001), (928002), (928011), (928012), (928013), (928014), (928015), (928016), (928019), (928021), (928022), (928023)
) AS v (token)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

UPDATE identity.users u SET email = 'cal.' || u.token || '@example.invalid'
WHERE u.token IN (928001, 928002, 928011, 928012, 928013, 928014, 928015, 928016, 928019, 928021, 928022, 928023) AND u.email <> 'cal.' || u.token || '@example.invalid';

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id, 'Cal Member ' || u.token, '1', '+91000028' || right(u.token::text, 4) FROM identity.users u
WHERE u.token IN (928001, 928002, 928011, 928012, 928013, 928014, 928015, 928016, 928019, 928021, 928022, 928023)
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token IN (928001, 928002, 928011, 928012, 928013, 928014, 928015, 928016, 928019, 928021, 928022, 928023));
INSERT INTO access.user_roles (user_id, roleid) SELECT id, 1 FROM identity.users WHERE token = 928002;

DELETE FROM notifications.member_event_settings WHERE user_id IN (SELECT id FROM identity.users WHERE token IN (928001, 928002, 928011, 928012, 928013, 928014, 928015, 928016, 928019, 928021, 928022, 928023));
DELETE FROM notifications.class_scheduled_events WHERE class_id IN (9701, 9702, 9703, 9704, 9705, 9706, 9709);
DELETE FROM classes.class_schedules WHERE class_id IN (9701, 9702, 9703, 9704, 9705, 9706, 9709);
DELETE FROM classes.class_students WHERE class_id IN (9701, 9702, 9703, 9704, 9705, 9706, 9709);
DELETE FROM classes.classes WHERE id IN (9701, 9702, 9703, 9704, 9705, 9706, 9709);

INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (9701, 'CAL-G-701', 9, 'callnk9701', 'Cal Class Guards', 3, DATE '2025-01-06', 928011, 1, 'Offline', 'Calville', 'India', 'Cal Hall', 'A', 928011),
  (9702, 'CAL-G-702', 9, 'callnk9702', 'Cal Class Read', 3, DATE '2025-01-06', 928012, 1, 'Offline', 'Calville', 'India', 'Cal Hall', 'A', 928012),
  (9703, 'CAL-G-703', 9, 'callnk9703', 'Cal Class Create', 3, DATE '2025-01-06', 928013, 1, 'Offline', 'Calville', 'India', 'Cal Hall', 'A', 928013),
  (9704, 'CAL-G-704', 9, 'callnk9704', 'Cal Class Edit', 3, DATE '2025-01-06', 928014, 1, 'Offline', 'Calville', 'India', 'Cal Hall', 'A', 928014),
  (9705, 'CAL-G-705', 9, 'callnk9705', 'Cal Class Delete', 3, DATE '2025-01-06', 928015, 1, 'Offline', 'Calville', 'India', 'Cal Hall', 'A', 928015),
  (9706, 'CAL-G-706', 9, 'callnk9706', 'Cal Class Settings', 3, DATE '2025-01-06', 928016, 1, 'Offline', 'Calville', 'India', 'Cal Hall', 'A', 928016),
  (9709, 'CAL-G-709', 9, 'callnk9709', 'Cal Class Closed', 3, DATE '2025-01-06', 928019, 1, 'Offline', 'Calville', 'India', 'Cal Hall', 'I', 928019);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9280301, 9701, 928023, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9280302, 9702, 928021, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9280303, 9709, 928021, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9280304, 9706, 928022, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A');

INSERT INTO classes.class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) VALUES
  (9280202, 9702, 2, 18, 5, 'Europe/London', 928012, NULL, NULL),
  (9280203, 9702, 3, 9, 0, 'Asia/Kolkata', 928012, TIMESTAMPTZ '2026-01-12 00:00:00+00', 928012),
  (9280206, 9706, 4, 7, 0, 'Asia/Kolkata', 928016, NULL, NULL),
  (9280209, 9709, 5, 8, 0, 'Asia/Kolkata', 928019, NULL, NULL);

INSERT INTO notifications.class_scheduled_events (id, class_id, created_by, created_by_user_id, message, description, action_link, weekdays, send_time, tz, status, created_at, updated_at, deleted_at)
SELECT v.id, v.class_id, v.created_by, u.id, v.message, v.description, v.action_link, v.weekdays, v.send_time, v.tz, v.status, TIMESTAMPTZ '2026-11-10 08:00:00+00', TIMESTAMPTZ '2026-11-10 08:00:00+00',
       CASE WHEN v.status = 'deleted' THEN TIMESTAMPTZ '2026-11-11 08:00:00+00' END
FROM (VALUES
  (9280421, 9702, 928012, 'Cal Read the lesson', 'Chapter two', '/classes/9702/syllabus', '1,3', TIME '18:30', 'Asia/Kolkata', 'active'),
  (9280422, 9702, 928002, 'Cal Super event', NULL, NULL, '5', TIME '07:05', 'Europe/London', 'active'),
  (9280423, 9702, 928012, 'Cal Deleted event', NULL, NULL, '2', TIME '09:00', 'Asia/Kolkata', 'deleted'),
  (9280441, 9704, 928014, 'Cal Edit me', 'Before', '/classes/9704/syllabus', '2,4', TIME '07:15', 'Europe/London', 'active'),
  (9280442, 9704, 928002, 'Cal Super event', NULL, NULL, '5', TIME '07:05', 'Europe/London', 'active'),
  (9280443, 9704, 928014, 'Cal Deleted event', NULL, NULL, '2', TIME '09:00', 'Asia/Kolkata', 'deleted'),
  (9280451, 9705, 928015, 'Cal Delete me', NULL, NULL, '2,4', TIME '07:15', 'Europe/London', 'active'),
  (9280452, 9705, 928002, 'Cal Super event', NULL, NULL, '5', TIME '07:05', 'Europe/London', 'active'),
  (9280453, 9705, 928015, 'Cal Deleted event', NULL, NULL, '2', TIME '09:00', 'Asia/Kolkata', 'deleted'),
  (9280461, 9706, 928016, 'Cal Settings one', NULL, NULL, '1', TIME '10:00', 'Asia/Kolkata', 'active'),
  (9280462, 9706, 928016, 'Cal Deleted event', NULL, NULL, '2', TIME '09:00', 'Asia/Kolkata', 'deleted'),
  (9280463, 9706, 928016, 'Cal Settings two', NULL, NULL, '2', TIME '11:00', 'Asia/Kolkata', 'active'),
  (9280464, 9706, 928016, 'Cal Settings three', NULL, NULL, '3', TIME '12:00', 'Asia/Kolkata', 'active'),
  (9280491, 9709, 928019, 'Cal Closed class event', NULL, NULL, '1', TIME '10:00', 'Asia/Kolkata', 'active')
) AS v (id, class_id, created_by, message, description, action_link, weekdays, send_time, tz, status)
JOIN identity.users u ON u.token = v.created_by;

INSERT INTO notifications.member_event_settings (user_id, class_id, event_key, offset_minutes, muted, deleted_for_me, client_updated_at, server_updated_at, device_key)
SELECT u.id, 9702, v.event_key, v.offset_minutes, v.muted, v.deleted_for_me, TIMESTAMPTZ '2026-11-10 08:00:00+00', TIMESTAMPTZ '2026-11-10 08:00:01.5+00', 'calfixturedevice01'
FROM (VALUES ('event:9280421', -15, 1, 0), ('event:9280422', NULL, 0, 1)) AS v (event_key, offset_minutes, muted, deleted_for_me)
JOIN identity.users u ON u.token = 928021;
