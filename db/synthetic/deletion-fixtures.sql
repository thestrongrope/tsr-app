/*
 * The "deletion" lane fixtures for the new API's database; tools/parity-php/deletion-fixtures.sql holds the same rows for PHP (read the header there for who is who). Loaded by tools/contract-deletion.sh before
 * every run, after it replaced __BASE__ (changes every two seconds: the completion rate limit is per request id and lasts a minute). Resets every row it owns. Synthetic only; id block of TSR_STACK 4:
 * tokens 924000 to 924999, other rows 9740000 to 9749999.
 */
DELETE FROM identity.account_deletion_requests WHERE (id BETWEEN 9740000 AND 9749999) OR (token BETWEEN 924000 AND 924999);
DELETE FROM platform.feedback WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 924000 AND 924999);
DELETE FROM notifications.user_devices WHERE token BETWEEN 924000 AND 924999;
DELETE FROM platform.outbound_messages WHERE dedupe_key LIKE 'dl-%';
DELETE FROM membership.class_registrations WHERE token BETWEEN 924000 AND 924999;
DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 924000 AND 924999);
DELETE FROM membership.member_profiles WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 924000 AND 924999 OR email = 'dl.guest.924000@example.invalid');
DELETE FROM identity.users WHERE token BETWEEN 924000 AND 924999 OR email = 'dl.guest.924000@example.invalid';

INSERT INTO identity.users (token, email, provider, createdon)
SELECT v.token, v.email, 'firebase', now() FROM (VALUES
  (924001, 'dl.924001@example.invalid'), (924002, 'dl.924002@example.invalid'), (924003, 'dl.924003@example.invalid'), (924005, 'dl.924005@example.invalid'), (924006, 'dl.924006@example.invalid'),
  (924007, 'dl.924007@example.invalid'), (924011, 'dl.924011@example.invalid'), (924012, 'dl.924012@example.invalid'), (924013, 'dl.924013@example.invalid'), (924014, 'dl.924014@demo.invalid'),
  (924021, 'dl.924021@example.invalid'), (924022, 'dl.924022@example.invalid'), (924031, 'dl.924031@example.invalid'), (924032, 'dl.924032@example.invalid'), (924042, 'dl.924042@example.invalid'),
  (924043, 'dl.924043@example.invalid'), (924044, 'dl.924044@example.invalid'), (924045, 'dl.924045@demo.invalid'), (924047, 'dl.924047@example.invalid'), (924048, 'dl.924048@example.invalid'),
  (0, 'dl.guest.924000@example.invalid')
) AS v (token, email);

INSERT INTO membership.member_profiles (user_id, name, gender, mobile, zip)
SELECT u.id, CASE WHEN u.token = 0 THEN 'Dl Guest' ELSE 'Dl Member ' || u.token END, CASE WHEN u.token = 0 THEN NULL ELSE '1' END,
       CASE WHEN u.token = 0 THEN '' ELSE '+91000' || u.token END,
       CASE u.token WHEN 924011 THEN '411011' WHEN 924012 THEN '411012' WHEN 924021 THEN '411021' WHEN 924048 THEN '411048' END
FROM identity.users u WHERE u.token BETWEEN 924000 AND 924999 OR u.email = 'dl.guest.924000@example.invalid';

INSERT INTO access.user_roles (user_id, roleid) SELECT id, 1 FROM identity.users WHERE token = 924001;

INSERT INTO identity.account_deletion_requests (id, token, status, source, reason, contact_name, contact_email, operator_note, requested_at, confirmation_sent_at, completed_at, cancelled_at, handled_by) VALUES
  (9740005, 924005, 'pending', 'app', NULL, 'Dl Member 924005', 'dl.924005@example.invalid', NULL, now() - interval '1 day', NULL, NULL, NULL, NULL),
  (9740007, 924007, 'completed', 'app', NULL, 'Dl Member 924007', 'dl.924007@example.invalid', NULL, now() - interval '2 day', now() - interval '6 hour', now() - interval '5 hour', NULL, 924001),
  (9740011, 924011, 'pending', 'app', 'leaving soon', 'Dl Member 924011', 'dl.924011@example.invalid', NULL, now() - interval '1 day', NULL, NULL, NULL, NULL),
  (9740012, 924012, 'awaiting_prize_delivery', 'web', NULL, 'Dl Member 924012', 'dl.924012@example.invalid', 'Prize is on its way', now() - interval '2 day', NULL, NULL, NULL, 924001),
  (9740013, 924013, 'cancelled', 'app', NULL, 'Dl Member 924013', 'dl.924013@example.invalid', NULL, now() - interval '3 day', NULL, NULL, now() - interval '2 day', NULL),
  (9740014, 924014, 'pending', 'app', NULL, 'Dl Member 924014', 'dl.924014@demo.invalid', NULL, now() - interval '1 day', now() - interval '1 hour', NULL, NULL, 924001),
  (9740021, 924021, 'pending', 'app', NULL, 'Dl Member 924021', 'dl.924021@example.invalid', NULL, now() - interval '1 day', NULL, NULL, NULL, NULL),
  (9740022, 924022, 'completed', 'app', NULL, 'Dl Member 924022', 'dl.924022@example.invalid', NULL, now() - interval '2 day', now() - interval '6 hour', now() - interval '5 hour', NULL, 924001),
  (9740031, 924031, 'pending', 'app', NULL, 'Dl Member 924031', 'dl.924031@example.invalid', NULL, now() - interval '1 day', NULL, NULL, NULL, NULL),
  (9740032, 924032, 'cancelled', 'app', NULL, 'Dl Member 924032', 'dl.924032@example.invalid', NULL, now() - interval '3 day', NULL, NULL, now() - interval '2 day', NULL),
  (__BASE__ + 0, NULL, 'pending', 'web', NULL, 'Stranger', 'stranger.dl@example.invalid', NULL, now() - interval '1 day', now() - interval '1 hour', NULL, NULL, NULL),
  (__BASE__ + 1, 924042, 'pending', 'app', NULL, 'Dl Member 924042', 'dl.924042@example.invalid', NULL, now() - interval '1 day', NULL, NULL, NULL, NULL),
  (__BASE__ + 2, 924043, 'completed', 'app', NULL, 'Dl Member 924043', 'dl.924043@example.invalid', NULL, now() - interval '2 day', now() - interval '6 hour', now() - interval '5 hour', NULL, 924001),
  (__BASE__ + 3, 924044, 'cancelled', 'app', NULL, 'Dl Member 924044', 'dl.924044@example.invalid', NULL, now() - interval '3 day', NULL, NULL, now() - interval '2 day', NULL),
  (__BASE__ + 4, 924045, 'pending', 'app', NULL, 'Dl Member 924045', 'dl.924045@demo.invalid', NULL, now() - interval '1 day', now() - interval '1 hour', NULL, NULL, NULL),
  (__BASE__ + 5, 924046, 'pending', 'app', NULL, 'Dl Gone 924046', 'dl.924046@example.invalid', NULL, now() - interval '1 day', now() - interval '1 hour', NULL, NULL, NULL),
  (__BASE__ + 6, 0, 'pending', 'app', NULL, 'Dl Guest', 'dl.guest.924000@example.invalid', NULL, now() - interval '1 day', now() - interval '1 hour', NULL, NULL, NULL),
  (__BASE__ + 7, 924047, 'pending', 'app', NULL, 'Dl Member 924047', 'dl.924047@example.invalid', NULL, now() - interval '1 day', now() - interval '1 hour', NULL, NULL, NULL),
  (__BASE__ + 8, 924048, 'pending', 'app', NULL, 'Dl Member 924048', 'dl.924048@example.invalid', NULL, now() - interval '1 day', now() - interval '1 hour', NULL, NULL, NULL);

INSERT INTO notifications.user_devices (token, device_id) VALUES (924048, 'dl-device-924048');
INSERT INTO platform.feedback (user_id, client_id, message) SELECT id, 'dl-client-924048', 'feedback of a fixture member' FROM identity.users WHERE token = 924048;
INSERT INTO platform.outbound_messages (channel, recipient, payload, dedupe_key) VALUES ('push', 'dl-device-924048', '[]', 'dl-push-924048'), ('whatsapp:gents', '+91000924048', '[]', 'dl-wa-924048');
