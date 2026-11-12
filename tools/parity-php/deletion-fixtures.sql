/*
 * The "deletion" lane fixtures (account deletion: /me/deletion-request, /admin/deletion-requests, completion, the gate) for the PHP parity stack's MariaDB. db/synthetic/deletion-fixtures.sql holds the same rows
 * for the new API. Loaded by tools/contract-deletion.sh before every run, after it replaced __BASE__ (a number that changes every two seconds: the completion rate limit is per request id and lasts 60 seconds, so a rerun
 * must not reuse ids). Resets every row it owns. Synthetic only, the lane's id block (TSR_STACK 4): tokens 924000 to 924999, classes 98400 to 98499, other rows 9740000 to 9749999. Emails dl.<token>@example.invalid.
 *
 *   924001 admin (role 1)   924002 plain member (no permission for the admin routes)   924003 the member-flow member (raises and cancels in deletion-request.hurl)   924005 member with a live request 9740005 (the gate)
 *   924006 raise target   924007 member whose request 9740007 completed 5 hours ago (cancel answers 409)   924011 unconfirmed request 9740011   924012 held request 9740012 (zip and mobile shown)   924013 cancelled 9740013
 *   924014 demo member (dl.924014@demo.invalid), confirmed request 9740014   924021 hold target 9740021   924022 completed 9740022   924031 confirmation target 9740031   924032 cancelled 9740032
 *   guest user (token 0, dl.guest.924000@example.invalid)
 *   completion, ids __BASE__ + n: 0 request naming no member, confirmed   1 unconfirmed (924042)   2 completed (924043)   3 cancelled (924044)   4 demo member (924045), confirmed   5 token with no user row (924046), confirmed
 *     6 guest token 0, confirmed   7 member 924047 (php-only file: Firebase not configured on the parity stack)   8 member 924048 with a device, feedback and a queued message (new-API file: a real completion)
 */
DELETE FROM account_deletion_requests WHERE (id BETWEEN 9740000 AND 9749999) OR (token BETWEEN 924000 AND 924999);
DELETE FROM feedback WHERE user_id IN (SELECT id FROM users WHERE token BETWEEN 924000 AND 924999);
DELETE FROM user_devices WHERE token BETWEEN 924000 AND 924999;
DELETE FROM outbound_messages WHERE dedupe_key LIKE 'dl-%';
DELETE FROM class_registrations WHERE token BETWEEN 924000 AND 924999;
DELETE FROM users WHERE token BETWEEN 924000 AND 924999 OR email = 'dl.guest.924000@example.invalid';

INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile, zip) VALUES
  (924001, 'dl.924001@example.invalid', 1, 'firebase', NOW(), 'Dl Member 924001', '1', '+91000092401', NULL),
  (924002, 'dl.924002@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924002', '1', '+91000092402', NULL),
  (924003, 'dl.924003@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924003', '1', '+91000092403', NULL),
  (924005, 'dl.924005@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924005', '1', '+91000092405', NULL),
  (924006, 'dl.924006@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924006', '1', '+91000092406', NULL),
  (924007, 'dl.924007@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924007', '1', '+91000092407', NULL),
  (924011, 'dl.924011@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924011', '1', '+91000092411', '411011'),
  (924012, 'dl.924012@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924012', '1', '+91000092412', '411012'),
  (924013, 'dl.924013@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924013', '1', '+91000092413', NULL),
  (924014, 'dl.924014@demo.invalid', 0, 'firebase', NOW(), 'Dl Member 924014', '1', '+91000092414', NULL),
  (924021, 'dl.924021@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924021', '1', '+91000092421', '411021'),
  (924022, 'dl.924022@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924022', '1', '+91000092422', NULL),
  (924031, 'dl.924031@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924031', '1', '+91000092431', NULL),
  (924032, 'dl.924032@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924032', '1', '+91000092432', NULL),
  (924042, 'dl.924042@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924042', '1', '+91000092442', NULL),
  (924043, 'dl.924043@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924043', '1', '+91000092443', NULL),
  (924044, 'dl.924044@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924044', '1', '+91000092444', NULL),
  (924045, 'dl.924045@demo.invalid', 0, 'firebase', NOW(), 'Dl Member 924045', '1', '+91000092445', NULL),
  (924047, 'dl.924047@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924047', '1', '+91000092447', NULL),
  (924048, 'dl.924048@example.invalid', 0, 'firebase', NOW(), 'Dl Member 924048', '1', '+91000092448', '411048'),
  (0, 'dl.guest.924000@example.invalid', 0, 'firebase', NOW(), 'Dl Guest', NULL, '', NULL);
UPDATE users SET mobile = CONCAT('+91000', token) WHERE token BETWEEN 924001 AND 924999;

INSERT INTO account_deletion_requests (id, token, status, source, reason, contact_name, contact_email, operator_note, requested_at, confirmation_sent_at, completed_at, cancelled_at, handled_by) VALUES
  (9740005, 924005, 'pending', 'app', NULL, 'Dl Member 924005', 'dl.924005@example.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 1 DAY, NULL, NULL, NULL, NULL),
  (9740007, 924007, 'completed', 'app', NULL, 'Dl Member 924007', 'dl.924007@example.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 2 DAY, UTC_TIMESTAMP() - INTERVAL 6 HOUR, UTC_TIMESTAMP() - INTERVAL 5 HOUR, NULL, 924001),
  (9740011, 924011, 'pending', 'app', 'leaving soon', 'Dl Member 924011', 'dl.924011@example.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 1 DAY, NULL, NULL, NULL, NULL),
  (9740012, 924012, 'awaiting_prize_delivery', 'web', NULL, 'Dl Member 924012', 'dl.924012@example.invalid', 'Prize is on its way', UTC_TIMESTAMP() - INTERVAL 2 DAY, NULL, NULL, NULL, 924001),
  (9740013, 924013, 'cancelled', 'app', NULL, 'Dl Member 924013', 'dl.924013@example.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 3 DAY, NULL, NULL, UTC_TIMESTAMP() - INTERVAL 2 DAY, NULL),
  (9740014, 924014, 'pending', 'app', NULL, 'Dl Member 924014', 'dl.924014@demo.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 1 DAY, UTC_TIMESTAMP() - INTERVAL 1 HOUR, NULL, NULL, 924001),
  (9740021, 924021, 'pending', 'app', NULL, 'Dl Member 924021', 'dl.924021@example.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 1 DAY, NULL, NULL, NULL, NULL),
  (9740022, 924022, 'completed', 'app', NULL, 'Dl Member 924022', 'dl.924022@example.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 2 DAY, UTC_TIMESTAMP() - INTERVAL 6 HOUR, UTC_TIMESTAMP() - INTERVAL 5 HOUR, NULL, 924001),
  (9740031, 924031, 'pending', 'app', NULL, 'Dl Member 924031', 'dl.924031@example.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 1 DAY, NULL, NULL, NULL, NULL),
  (9740032, 924032, 'cancelled', 'app', NULL, 'Dl Member 924032', 'dl.924032@example.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 3 DAY, NULL, NULL, UTC_TIMESTAMP() - INTERVAL 2 DAY, NULL),
  (__BASE__ + 0, NULL, 'pending', 'web', NULL, 'Stranger', 'stranger.dl@example.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 1 DAY, UTC_TIMESTAMP() - INTERVAL 1 HOUR, NULL, NULL, NULL),
  (__BASE__ + 1, 924042, 'pending', 'app', NULL, 'Dl Member 924042', 'dl.924042@example.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 1 DAY, NULL, NULL, NULL, NULL),
  (__BASE__ + 2, 924043, 'completed', 'app', NULL, 'Dl Member 924043', 'dl.924043@example.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 2 DAY, UTC_TIMESTAMP() - INTERVAL 6 HOUR, UTC_TIMESTAMP() - INTERVAL 5 HOUR, NULL, 924001),
  (__BASE__ + 3, 924044, 'cancelled', 'app', NULL, 'Dl Member 924044', 'dl.924044@example.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 3 DAY, NULL, NULL, UTC_TIMESTAMP() - INTERVAL 2 DAY, NULL),
  (__BASE__ + 4, 924045, 'pending', 'app', NULL, 'Dl Member 924045', 'dl.924045@demo.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 1 DAY, UTC_TIMESTAMP() - INTERVAL 1 HOUR, NULL, NULL, NULL),
  (__BASE__ + 5, 924046, 'pending', 'app', NULL, 'Dl Gone 924046', 'dl.924046@example.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 1 DAY, UTC_TIMESTAMP() - INTERVAL 1 HOUR, NULL, NULL, NULL),
  (__BASE__ + 6, 0, 'pending', 'app', NULL, 'Dl Guest', 'dl.guest.924000@example.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 1 DAY, UTC_TIMESTAMP() - INTERVAL 1 HOUR, NULL, NULL, NULL),
  (__BASE__ + 7, 924047, 'pending', 'app', NULL, 'Dl Member 924047', 'dl.924047@example.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 1 DAY, UTC_TIMESTAMP() - INTERVAL 1 HOUR, NULL, NULL, NULL),
  (__BASE__ + 8, 924048, 'pending', 'app', NULL, 'Dl Member 924048', 'dl.924048@example.invalid', NULL, UTC_TIMESTAMP() - INTERVAL 1 DAY, UTC_TIMESTAMP() - INTERVAL 1 HOUR, NULL, NULL, NULL);

INSERT INTO user_devices (token, device_id) VALUES (924048, 'dl-device-924048');
INSERT INTO feedback (user_id, client_id, message) SELECT id, 'dl-client-924048', 'feedback of a fixture member' FROM users WHERE token = 924048;
INSERT INTO outbound_messages (channel, recipient, payload, dedupe_key) VALUES ('push', 'dl-device-924048', '[]', 'dl-push-924048'), ('whatsapp:gents', '+91000924048', '[]', 'dl-wa-924048');
