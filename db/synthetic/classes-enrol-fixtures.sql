/*
 * The classes ENROLMENT fixtures for the new API's database (batch B2b): members and classes that the enrolment write contract files change (remove, restore, add, transfer, join, place,
 * edit a student, bulk add). tools/parity-php/classes-enrol-fixtures.sql holds the same rows for the PHP parity stack. Loaded by tools/classes-contract.sh after the write fixtures, before every
 * run, and it resets every row it owns (by token and class id). Each file owns its class and members. Synthetic only: tokens 900501 to 900599, emails en.<token>@example.invalid, mobiles +91000005xxxx,
 * class ids 9411 to 9429 (inside the write fixtures' reset range, which deletes their rows first).
 *
 *   900501 gents admin (role 3)    900502 ladies admin (role 4)    900511 teacher of the gents classes    900512 teacher of the ladies class 9414
 *   9414  ladies class (read only for every file: gender mismatch, a destination of another gender)
 *   remove  class 9411: students 900521, 900522 active, 900523 removed
 *   restore class 9412: 900531 removed, 900532 active, 900533 moved away (removal reason "Transfer to class #9411")
 *   add     class 9413: 900541 free gents, 900542 free ladies, 900543 no gender, 900544 active, 900545 removed, 900546 free (gender text 'Male')
 *   transfer classes 9415 (source) and 9416 (destination), 9417 closed: 900551 in 9415, 900552 in 9415 and 9416, 900553 and 900554 in 9415, 900555 removed from 9415
 *   place   classes 9420 (to place into) and 9421 (900574 is enrolled): registrations 9571 (900571 gents), 9572 (900572 ladies), 9573 (900573 rejected), 9574 (900574, already enrolled), 9575 and 9576 (900575, two rows: 9576 is the one that counts),
 *           9577 (900576 gents). The placeholder-email rule (@thestrongrope.com) has no fixture: the synthetic-stack guard refuses any member whose email does not end in .invalid.
 *   join    class 9418 (link WrJoin9418), 9419 closed (link wrjoin9419): 900561 free gents, 900562 free ladies, 900563 enrolled, 900564 removed by an admin, 900565 removed by themself, 900566 no gender
 */
INSERT INTO identity.users (token, email)
SELECT v.token, 'en.' || v.token || '@example.invalid' FROM (VALUES
  (900501), (900502), (900511), (900512), (900521), (900522), (900523), (900531), (900532), (900533),
  (900541), (900542), (900543), (900544), (900545), (900546),
  (900551), (900552), (900553), (900554), (900555), (900561), (900562), (900563), (900564), (900565), (900566),
  (900571), (900572), (900573), (900574), (900575), (900576)
) AS v (token)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

UPDATE identity.users u SET email = 'en.' || u.token || '@example.invalid' WHERE u.token BETWEEN 900501 AND 900599 AND u.email <> 'en.' || u.token || '@example.invalid';

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id, 'En Member ' || v.token, v.gender, '+91000005' || right(v.token::text, 4) FROM (VALUES
  (900501, '1'), (900502, '2'), (900511, '1'), (900512, '2'), (900521, '1'), (900522, '1'), (900523, '1'), (900531, '1'), (900532, '1'), (900533, '1'),
  (900541, '1'), (900542, '2'), (900543, NULL), (900544, '1'), (900545, '1'), (900546, 'Male'),
  (900551, '1'), (900552, '1'), (900553, '1'), (900554, '1'), (900555, '1'), (900561, '1'), (900562, '2'), (900563, '1'), (900564, '1'), (900565, '1'), (900566, NULL),
  (900571, '1'), (900572, '2'), (900573, '1'), (900574, '1'), (900575, '1'), (900576, '1')
) AS v (token, gender)
JOIN identity.users u ON u.token = v.token
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token IN (900501, 900502));
INSERT INTO access.user_roles (user_id, roleid)
SELECT u.id, CASE u.token WHEN 900501 THEN 3 ELSE 4 END FROM identity.users u WHERE u.token IN (900501, 900502);

DELETE FROM classes.student_transfers WHERE token_no BETWEEN 900501 AND 900599 OR from_class_id BETWEEN 9401 AND 9499 OR to_class_id BETWEEN 9401 AND 9499;
DELETE FROM membership.class_registrations WHERE token BETWEEN 900501 AND 900599;
DELETE FROM classes.class_students WHERE class_id BETWEEN 9411 AND 9499;
DELETE FROM classes.classes WHERE id BETWEEN 9411 AND 9499;

INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (9411, 'EN-G-011', 1, 'enlnk9411', 'En Remove Class', 3, DATE '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9412, 'EN-G-012', 1, 'enlnk9412', 'En Restore Class', 3, DATE '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9413, 'EN-G-013', 1, 'enlnk9413', 'En Add Class', 3, DATE '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9414, 'EN-L-014', 1, 'enlnk9414', 'En Ladies Class', 3, DATE '2025-09-01', 900512, 2, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9415, 'EN-G-015', 1, 'enlnk9415', 'En Transfer Source', 3, DATE '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9416, 'EN-G-016', 1, 'enlnk9416', 'En Transfer Destination', 3, DATE '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9417, 'EN-G-017', 1, 'enlnk9417', 'En Closed Class', 3, DATE '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'I', 900331),
  (9418, 'EN-G-018', 1, 'WrJoin9418', 'En Join Class', 3, DATE '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9420, 'EN-G-020', 1, 'enlnk9420', 'En Place Class', 3, DATE '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9421, 'EN-G-021', 1, 'enlnk9421', 'En Placed Elsewhere Class', 3, DATE '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9419, 'EN-G-019', 1, 'wrjoin9419', 'En Closed Join Class', 3, DATE '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'I', 900331);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9411, 9411, 900521, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9412, 9411, 900522, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9413, 9411, 900523, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'En removed', 900331, 'I'),
  (9414, 9412, 900531, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'En gone', 900331, 'I'),
  (9415, 9412, 900532, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9416, 9412, 900533, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'Transfer to class #9411', 900331, 'I'),
  (9417, 9413, 900544, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9418, 9413, 900545, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'En left', 900331, 'I'),
  (9419, 9415, 900551, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9420, 9415, 900552, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9421, 9416, 900552, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (9422, 9415, 900553, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9423, 9415, 900554, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9424, 9415, 900555, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'En left', 900331, 'I'),
  (9425, 9418, 900563, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9426, 9418, 900564, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'En removed by admin', 900331, 'I'),
  (9427, 9418, 900565, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'En left by themself', 900565, 'I'),
  (9428, 9421, 900574, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A');

INSERT INTO membership.class_registrations (id, token, status, created_at) VALUES
  (9571, 900571, 'Pending', now()), (9572, 900572, 'Pending', now()), (9573, 900573, 'Rejected', now()), (9574, 900574, 'Pending', now()),
  (9575, 900575, 'Pending', now()), (9576, 900575, 'Pending', now()), (9577, 900576, 'Pending', now());
UPDATE classes.class_students SET created_at = joined_on + TIME '08:00' AT TIME ZONE 'UTC' WHERE class_id BETWEEN 9411 AND 9499;

-- New rows get ids above the fixtures' own (a sequence does not follow explicit ids).
SELECT setval(pg_get_serial_sequence('classes.class_students', 'id'), greatest((SELECT max(id) FROM classes.class_students), 9499));
SELECT setval(pg_get_serial_sequence('classes.student_transfers', 'id'), greatest((SELECT coalesce(max(id), 1) FROM classes.student_transfers), 1));
SELECT setval(pg_get_serial_sequence('membership.class_registrations', 'id'), greatest((SELECT max(id) FROM membership.class_registrations), 9599));
SELECT setval(pg_get_serial_sequence('classes.classes', 'id'), greatest((SELECT max(id) FROM classes.classes), 1));
