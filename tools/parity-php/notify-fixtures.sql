/*
 * The notify lane fixtures for the PHP parity stack's MariaDB: the same rows as db/synthetic/notify-fixtures.sql (read the header there).
 * Loaded by tools/contract-notify.sh before every run; resets every row it owns. Synthetic only: member tokens 926001 to 926999, classes 98601 to 98606, every other row 9760000 and up. Nothing here can be pushed:
 * the parity PHP has no Google credential (docs/specs/initial-build/test-notify-notes.md), and every device id starts n6-.
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, CONCAT('nf.', v.token, IF(v.token = 926005, '@demo.invalid', '@example.invalid')), 0, 'firebase', NOW(), CONCAT('Nf Member ', v.token), '1', CONCAT('+91000026', RIGHT(v.token, 4)) FROM (
  SELECT 926001 AS token UNION ALL SELECT 926005 UNION ALL SELECT 926011 UNION ALL SELECT 926012 UNION ALL SELECT 926013 UNION ALL SELECT 926021 UNION ALL SELECT 926022 UNION ALL SELECT 926023
  UNION ALL SELECT 926024 UNION ALL SELECT 926025 UNION ALL SELECT 926026 UNION ALL SELECT 926101 UNION ALL SELECT 926102 UNION ALL SELECT 926111 UNION ALL SELECT 926031 UNION ALL SELECT 926032
  UNION ALL SELECT 926033 UNION ALL SELECT 926034 UNION ALL SELECT 926035 UNION ALL SELECT 926036 UNION ALL SELECT 926041 UNION ALL SELECT 926042 UNION ALL SELECT 926043 UNION ALL SELECT 926044
  UNION ALL SELECT 926045) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users SET email = CONCAT('nf.', token, IF(token = 926005, '@demo.invalid', '@example.invalid')), name = IF(token = 926111, 'Nf Sender', CONCAT('Nf Member ', token)), gender = '1',
  roleid = CASE token WHEN 926101 THEN 1 WHEN 926102 THEN 3 ELSE 0 END, mobile = CONCAT('+91000026', RIGHT(token, 4))
WHERE token BETWEEN 926001 AND 926999;

DELETE FROM user_notifications WHERE user_token BETWEEN 926001 AND 926999 OR notification_id BETWEEN 9760001 AND 9769999 OR notification_id IN (SELECT notification_id FROM notifications WHERE created_by BETWEEN 926001 AND 926999);
DELETE FROM notifications WHERE notification_id BETWEEN 9760001 AND 9769999 OR created_by BETWEEN 926001 AND 926999;
DELETE FROM user_devices WHERE token BETWEEN 926001 AND 926999 OR device_id LIKE 'n6-%';
DELETE FROM class_schedules WHERE class_id BETWEEN 98601 AND 98699;
DELETE FROM class_students WHERE class_id BETWEEN 98601 AND 98699;
DELETE FROM classes WHERE id BETWEEN 98601 AND 98699;

INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (98601, 'NF-G-601', 9, 'nflnk98601', 'Nf Class Live', 3, '2025-01-06', 926031, 1, 'Offline', 'Nfville', 'India', 'Nf Hall', 'A', 926031),
  (98602, 'NF-G-602', 9, 'nflnk98602', 'Nf Class No Devices', 3, '2025-01-06', 926032, 1, 'Offline', 'Nfville', 'India', 'Nf Hall', 'A', 926032),
  (98603, 'NF-G-603', 9, 'nflnk98603', 'Nf Class Closed', 3, '2025-01-06', 926033, 1, 'Offline', 'Nfville', 'India', 'Nf Hall', 'I', 926033),
  (98604, 'NF-G-604', 9, 'nflnk98604', 'Nf Class Other', 3, '2025-01-06', 926034, 1, 'Offline', 'Nfville', 'India', 'Nf Hall', 'A', 926034),
  (98605, 'NF-G-605', 9, 'nflnk98605', 'Nf Class Scheduled', 3, '2025-01-06', 926035, 1, 'Offline', 'Nfville', 'India', 'Nf Hall', 'A', 926035),
  (98606, 'NF-G-606', 9, 'nflnk98606', 'Nf Class Scheduled Two', 3, '2025-01-06', 926036, 1, 'Offline', 'Nfville', 'India', 'Nf Hall', 'A', 926036);

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9760301, 98601, 926041, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9760302, 98601, 926042, '2025-01-06', 0, '2026-01-12 00:00:00', 'Nf left', 926031, 'I'),
  (9760303, 98601, 926043, '2025-01-06', 0, NULL, NULL, NULL, 'I'),
  (9760304, 98601, 926044, '2025-01-06', 0, NULL, NULL, NULL, 'A'),
  (9760305, 98602, 926045, '2025-01-06', 0, NULL, NULL, NULL, 'A');

INSERT INTO class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) VALUES
  (9760201, 98601, 1, 10, 0, 'Asia/Kolkata', 926031, NULL, NULL),
  (9760202, 98605, 2, 18, 30, 'Asia/Kolkata', 926035, NULL, NULL),
  (9760203, 98605, 3, 9, 0, 'Asia/Kolkata', 926035, '2026-01-12 00:00:00', 926035),
  (9760204, 98606, 4, 7, 15, 'Asia/Kolkata', 926036, NULL, NULL);

INSERT INTO user_devices (token, device_id) VALUES
  (926013, 'n6-held-1'), (926041, 'n6-stu-41'), (926042, 'n6-stu-42'), (926043, 'n6-stu-43'), (926005, 'n6-demo-5');

INSERT INTO notifications (notification_id, title, body, target_audience_criteria, sent_at, created_by, device_count, success_count, failure_count, action_link) VALUES
  (9760001, 'Nf History All', 'Nf body one', '{"type":"ALL_USERS","value":null}', '2099-12-31 23:00:04', 926111, 4, 3, 1, NULL),
  (9760002, 'Nf History Gender', 'Nf body two', '{"type":"GENDER","value":["male"]}', '2099-12-31 23:00:03', 926111, 2, 2, 0, '/classes/12/syllabus'),
  (9760003, 'Nf History Level', 'Nf body three', '{"type":"CLASS_LEVEL","value":[3]}', '2099-12-31 23:00:02', 926111, 1, 1, 0, 'https://example.invalid/nf'),
  (9760004, 'Nf History Teachers', 'Nf body four', '{"type":"TEACHERS","value":[98601]}', '2099-12-31 23:00:01', 926111, 0, 0, 0, NULL);

INSERT INTO user_notifications (id, notification_id, user_token, is_read, read_at, created_at) VALUES
  (9760101, 9760001, 926021, 0, NULL, '2099-12-31 23:00:04'),
  (9760102, 9760002, 926021, 1, '2099-12-31 23:30:00', '2099-12-31 23:00:03'),
  (9760103, 9760003, 926021, 0, NULL, '2099-12-31 23:00:02'),
  (9760104, 9760001, 926022, 0, NULL, '2099-12-31 23:00:04'),
  (9760111, 9760001, 926023, 0, NULL, '2099-12-31 23:00:04'),
  (9760112, 9760002, 926023, 0, NULL, '2099-12-31 23:00:03'),
  (9760113, 9760001, 926024, 0, NULL, '2099-12-31 23:00:04'),
  (9760121, 9760001, 926025, 0, NULL, '2099-12-31 23:00:04'),
  (9760122, 9760002, 926025, 0, NULL, '2099-12-31 23:00:03'),
  (9760123, 9760001, 926026, 0, NULL, '2099-12-31 23:00:04');
