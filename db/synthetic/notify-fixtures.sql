/*
 * The notify lane fixtures (devices, the member inbox, announcements, class notifications) for the new API's database. tools/parity-php/notify-fixtures.sql holds the same rows for the PHP parity stack.
 * Loaded by tools/contract-notify.sh before every run; resets every row it owns. Synthetic only: member tokens 926001 to 926999 (emails nf.<token>@example.invalid; 926005 is the demo member nf.926005@demo.invalid),
 * classes 98601 to 98606, every other row 9760000 and up. Nothing here may be pushed anywhere: device ids are plain strings that start n6-.
 *
 *   926001 plain member, no device (403 cases)   926011 registers and removes devices   926012 takes over a device   926013 holds the device n6-held-1
 *   926021 reads the inbox (3 rows: 9760101 unread, 9760102 read, 9760103 unread)   926022 owns row 9760104   926023 marks rows 9760111 and 9760112   926024 owns row 9760113   926025 read-all (9760121, 9760122)   926026 owns row 9760123
 *   926101 super administrator   926102 gents administrator   926111 sender of the history rows
 *   class 98601 (teacher 926031): student 926041 with the device n6-stu-41, 926042 removed (device n6-stu-42), 926043 inactive (device n6-stu-43), 926044 no device   class 98602 (teacher 926032): student 926045 without a device
 *   class 98603 (teacher 926033): closed   class 98604 (teacher 926034): the other teacher   class 98605 (teacher 926035) and 98606 (teacher 926036): scheduled notifications (slots 9760201 to 9760204)
 *   notifications 9760001 to 9760004 sent 2099-12-31 (they head the history): ALL_USERS, GENDER, CLASS_LEVEL, TEACHERS
 */
INSERT INTO identity.users (token, email)
SELECT v.token, 'nf.' || v.token || CASE WHEN v.token = 926005 THEN '@demo.invalid' ELSE '@example.invalid' END FROM (VALUES
  (926001), (926005), (926011), (926012), (926013), (926021), (926022), (926023), (926024), (926025), (926026), (926101), (926102), (926111),
  (926031), (926032), (926033), (926034), (926035), (926036), (926041), (926042), (926043), (926044), (926045)
) AS v (token)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

UPDATE identity.users u SET email = 'nf.' || u.token || CASE WHEN u.token = 926005 THEN '@demo.invalid' ELSE '@example.invalid' END
WHERE u.token BETWEEN 926001 AND 926999 AND u.email <> 'nf.' || u.token || CASE WHEN u.token = 926005 THEN '@demo.invalid' ELSE '@example.invalid' END;

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id, 'Nf Member ' || u.token, '1', '+91000026' || right(u.token::text, 4) FROM identity.users u WHERE u.token BETWEEN 926001 AND 926999
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

UPDATE membership.member_profiles SET name = 'Nf Sender' WHERE user_id = (SELECT id FROM identity.users WHERE token = 926111);

DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 926001 AND 926999);
INSERT INTO access.user_roles (user_id, roleid) SELECT id, 1 FROM identity.users WHERE token = 926101;
INSERT INTO access.user_roles (user_id, roleid) SELECT id, 3 FROM identity.users WHERE token = 926102;

DELETE FROM notifications.class_scheduled_notification_runs WHERE scheduled_id IN (SELECT id FROM notifications.class_scheduled_notifications WHERE class_id BETWEEN 98601 AND 98699);
DELETE FROM notifications.class_scheduled_notifications WHERE class_id BETWEEN 98601 AND 98699;
DELETE FROM notifications.user_notifications WHERE user_token BETWEEN 926001 AND 926999 OR notification_id BETWEEN 9760001 AND 9769999 OR notification_id IN (SELECT notification_id FROM notifications.notifications WHERE created_by BETWEEN 926001 AND 926999);
DELETE FROM notifications.notifications WHERE notification_id BETWEEN 9760001 AND 9769999 OR created_by BETWEEN 926001 AND 926999;
DELETE FROM notifications.user_devices WHERE token BETWEEN 926001 AND 926999 OR device_id LIKE 'n6-%';
DELETE FROM classes.class_schedules WHERE class_id BETWEEN 98601 AND 98699;
DELETE FROM classes.class_students WHERE class_id BETWEEN 98601 AND 98699;
DELETE FROM classes.classes WHERE id BETWEEN 98601 AND 98699;

INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (98601, 'NF-G-601', 9, 'nflnk98601', 'Nf Class Live', 3, DATE '2025-01-06', 926031, 1, 'Offline', 'Nfville', 'India', 'Nf Hall', 'A', 926031),
  (98602, 'NF-G-602', 9, 'nflnk98602', 'Nf Class No Devices', 3, DATE '2025-01-06', 926032, 1, 'Offline', 'Nfville', 'India', 'Nf Hall', 'A', 926032),
  (98603, 'NF-G-603', 9, 'nflnk98603', 'Nf Class Closed', 3, DATE '2025-01-06', 926033, 1, 'Offline', 'Nfville', 'India', 'Nf Hall', 'I', 926033),
  (98604, 'NF-G-604', 9, 'nflnk98604', 'Nf Class Other', 3, DATE '2025-01-06', 926034, 1, 'Offline', 'Nfville', 'India', 'Nf Hall', 'A', 926034),
  (98605, 'NF-G-605', 9, 'nflnk98605', 'Nf Class Scheduled', 3, DATE '2025-01-06', 926035, 1, 'Offline', 'Nfville', 'India', 'Nf Hall', 'A', 926035),
  (98606, 'NF-G-606', 9, 'nflnk98606', 'Nf Class Scheduled Two', 3, DATE '2025-01-06', 926036, 1, 'Offline', 'Nfville', 'India', 'Nf Hall', 'A', 926036);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9760301, 98601, 926041, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9760302, 98601, 926042, DATE '2025-01-06', 0, TIMESTAMPTZ '2026-01-12 00:00:00+00', 'Nf left', 926031, 'I'),
  (9760303, 98601, 926043, DATE '2025-01-06', 0, NULL, NULL, NULL, 'I'),
  (9760304, 98601, 926044, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9760305, 98602, 926045, DATE '2025-01-06', 0, NULL, NULL, NULL, 'A');

INSERT INTO classes.class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) VALUES
  (9760201, 98601, 1, 10, 0, 'Asia/Kolkata', 926031, NULL, NULL),
  (9760202, 98605, 2, 18, 30, 'Asia/Kolkata', 926035, NULL, NULL),
  (9760203, 98605, 3, 9, 0, 'Asia/Kolkata', 926035, TIMESTAMPTZ '2026-01-12 00:00:00+00', 926035),
  (9760204, 98606, 4, 7, 15, 'Asia/Kolkata', 926036, NULL, NULL);

INSERT INTO notifications.user_devices (token, device_id) VALUES
  (926013, 'n6-held-1'), (926041, 'n6-stu-41'), (926042, 'n6-stu-42'), (926043, 'n6-stu-43'), (926005, 'n6-demo-5');

INSERT INTO notifications.notifications (notification_id, title, body, target_audience_criteria, sent_at, created_by, device_count, success_count, failure_count, action_link) VALUES
  (9760001, 'Nf History All', 'Nf body one', '{"type":"ALL_USERS","value":null}', TIMESTAMPTZ '2099-12-31 23:00:04+00', 926111, 4, 3, 1, NULL),
  (9760002, 'Nf History Gender', 'Nf body two', '{"type":"GENDER","value":["male"]}', TIMESTAMPTZ '2099-12-31 23:00:03+00', 926111, 2, 2, 0, '/classes/12/syllabus'),
  (9760003, 'Nf History Level', 'Nf body three', '{"type":"CLASS_LEVEL","value":[3]}', TIMESTAMPTZ '2099-12-31 23:00:02+00', 926111, 1, 1, 0, 'https://example.invalid/nf'),
  (9760004, 'Nf History Teachers', 'Nf body four', '{"type":"TEACHERS","value":[98601]}', TIMESTAMPTZ '2099-12-31 23:00:01+00', 926111, 0, 0, 0, NULL);

INSERT INTO notifications.user_notifications (id, notification_id, user_token, is_read, read_at, created_at) VALUES
  (9760101, 9760001, 926021, 0, NULL, TIMESTAMPTZ '2099-12-31 23:00:04+00'),
  (9760102, 9760002, 926021, 1, TIMESTAMPTZ '2099-12-31 23:30:00+00', TIMESTAMPTZ '2099-12-31 23:00:03+00'),
  (9760103, 9760003, 926021, 0, NULL, TIMESTAMPTZ '2099-12-31 23:00:02+00'),
  (9760104, 9760001, 926022, 0, NULL, TIMESTAMPTZ '2099-12-31 23:00:04+00'),
  (9760111, 9760001, 926023, 0, NULL, TIMESTAMPTZ '2099-12-31 23:00:04+00'),
  (9760112, 9760002, 926023, 0, NULL, TIMESTAMPTZ '2099-12-31 23:00:03+00'),
  (9760113, 9760001, 926024, 0, NULL, TIMESTAMPTZ '2099-12-31 23:00:04+00'),
  (9760121, 9760001, 926025, 0, NULL, TIMESTAMPTZ '2099-12-31 23:00:04+00'),
  (9760122, 9760002, 926025, 0, NULL, TIMESTAMPTZ '2099-12-31 23:00:03+00'),
  (9760123, 9760001, 926026, 0, NULL, TIMESTAMPTZ '2099-12-31 23:00:04+00');
