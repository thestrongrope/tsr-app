/*
 * The classes bulk-add fixtures for the new API's database: what domains/classes/spec/tests/class-students-bulk*.hurl change. tools/parity-php/classes-bulk-fixtures.sql holds the same rows for the PHP
 * parity stack. Loaded by tools/classes-contract.sh after the other classes fixtures, before every run. Synthetic only: tokens 900701 to 900799, emails bk.<token>@example.invalid, mobiles +91000007xxxx, class ids
 * 9451 to 9469 (inside the write fixtures' reset range).
 *
 * A bulk add CREATES members (email <token>@thestrongrope.com); classes-bulk-cleanup.sql (loaded first) deletes them. It deletes a member whose address is its own token placeholder, whose token is 900000 or above, and
 * who is on the roster of a bulk fixture class (9451 to 9469). Their profile, class request and enrolments go with them. The synthetic-stack guard (tools/data-load/test/require-synthetic.sh) accepts such a member.
 *
 *   900701 to 900704, 900706 gents admins (role 3; each has its own rate-limit allowance of 10 bulk adds a minute)    900705 ladies admin (role 4)    900711 teacher of 9451 and 9453    900712 teacher of 9452
 *   900721 "Bulk Existing" gents, on the roster of 9451    900722 "Gents Freeman" gents    900723 "Ladies Freewoman" ladies    900724 "Nogender Person" no gender
 *   900725 "Short Number" gents, a seven digit mobile    900726 "Format Member" gents, mobile with a plus, spaces and a dash
 *   9451 gents (900721 enrolled), 9452 ladies, 9453 gents; both empty but 9451
 */

INSERT INTO identity.users (token, email)
SELECT v.token, 'bk.' || v.token || '@example.invalid' FROM (VALUES
  (900701), (900702), (900703), (900704), (900705), (900706), (900711), (900712), (900721), (900722), (900723), (900724), (900725), (900726)
) AS v (token)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

UPDATE identity.users u SET email = 'bk.' || u.token || '@example.invalid' WHERE u.token BETWEEN 900701 AND 900799 AND u.email <> 'bk.' || u.token || '@example.invalid';

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id, v.name, v.gender, v.mobile FROM (VALUES
  (900701, 'Bulk Admin A', '1', '+910000070701'), (900702, 'Bulk Admin B', '1', '+910000070702'), (900703, 'Bulk Admin C', '1', '+910000070703'),
  (900704, 'Bulk Admin D', '1', '+910000070704'), (900705, 'Bulk Admin E', '2', '+910000070705'), (900706, 'Bulk Admin F', '1', '+910000070706'),
  (900711, 'Bulk Teacher Gents', '1', '+910000070711'), (900712, 'Bulk Teacher Ladies', '2', '+910000070712'),
  (900721, 'Bulk Existing', '1', '+910000070721'), (900722, 'Gents Freeman', '1', '+910000070722'), (900723, 'Ladies Freewoman', '2', '+910000070723'),
  (900724, 'Nogender Person', NULL, '+910000070724'), (900725, 'Short Number', '1', '9007250'), (900726, 'Format Member', '1', '+91 00000-70726')
) AS v (token, name, gender, mobile)
JOIN identity.users u ON u.token = v.token
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 900701 AND 900706);
INSERT INTO access.user_roles (user_id, roleid)
SELECT u.id, CASE u.token WHEN 900705 THEN 4 ELSE 3 END FROM identity.users u WHERE u.token BETWEEN 900701 AND 900706;

DELETE FROM membership.class_registrations WHERE token BETWEEN 900701 AND 900799;
DELETE FROM classes.class_students WHERE class_id BETWEEN 9451 AND 9469;
DELETE FROM classes.classes WHERE id BETWEEN 9451 AND 9469;

INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (9451, 'BK-G-051', 1, 'bklnk9451', 'Bk Gents Class', 3, DATE '2025-09-01', 900711, 1, 'Offline', 'Mumbai', 'India', 'Bk Hall', 'A', 900331),
  (9452, 'BK-L-052', 1, 'bklnk9452', 'Bk Ladies Class', 3, DATE '2025-09-01', 900712, 2, 'Offline', 'Mumbai', 'India', 'Bk Hall', 'A', 900331),
  (9453, 'BK-G-053', 1, 'bklnk9453', 'Bk Second Gents Class', 3, DATE '2025-09-01', 900711, 1, 'Offline', 'Mumbai', 'India', 'Bk Hall', 'A', 900331);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9451, 9451, 900721, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A');
UPDATE classes.class_students SET created_at = joined_on + TIME '08:00' AT TIME ZONE 'UTC' WHERE class_id BETWEEN 9451 AND 9469;

SELECT setval(pg_get_serial_sequence('classes.class_students', 'id'), greatest((SELECT max(id) FROM classes.class_students), 9499));
SELECT setval(pg_get_serial_sequence('classes.classes', 'id'), greatest((SELECT max(id) FROM classes.classes), 1));
