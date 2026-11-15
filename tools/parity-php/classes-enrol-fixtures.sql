/*
 * The classes ENROLMENT fixtures for the PHP parity stack's MariaDB (batch B2b): members and classes that the enrolment write contract files change (remove, restore, add, transfer, join, place,
 * edit a student, bulk add). db/synthetic/classes-enrol-fixtures.sql holds the same rows for the new API's database (read that header). Loaded by tools/classes-contract.sh after the write fixtures, before every
 * run, and it resets every row it owns (by token and class id). Each file owns its class and members. Synthetic only: tokens 900501 to 900599, emails en.<token>@example.invalid, mobiles +91000005xxxx,
 * class ids 9411 to 9429 (inside the write fixtures' reset range, which deletes their rows first).
 *
 *   900501 gents admin (role 3)    900502 ladies admin (role 4)    900511 teacher of the gents classes    900512 teacher of the ladies class 9414
 *   9414  ladies class (read only for every file: gender mismatch, a destination of another gender)
 *   remove  class 9411: students 900521, 900522 active, 900523 removed
 *   restore class 9412: 900531 removed, 900532 active, 900533 moved away (removal reason "Transfer to class #9411")
 *   add     class 9413: 900541 free gents, 900542 free ladies, 900543 no gender, 900544 active, 900545 removed, 900546 free (gender text 'Male')
 *   transfer classes 9415 (source) and 9416 (destination), 9417 closed: 900551 in 9415, 900552 in 9415 and 9416, 900553 and 900554 in 9415, 900555 removed from 9415
 *   join    class 9418 (link WrJoin9418), 9419 closed (link wrjoin9419): 900561 free gents, 900562 free ladies, 900563 enrolled, 900564 removed by an admin, 900565 removed by themself, 900566 no gender
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, CONCAT('en.', v.token, '@example.invalid'), v.roleid, 'firebase', NOW(), CONCAT('En Member ', v.token), v.gender, CONCAT('+91000005', RIGHT(v.token, 4)) FROM (
  SELECT 900501 AS token, '1' AS gender, 3 AS roleid UNION ALL
  SELECT 900502, '2', 4 UNION ALL
  SELECT 900511, '1', 0 UNION ALL
  SELECT 900512, '2', 0 UNION ALL
  SELECT 900521, '1', 0 UNION ALL
  SELECT 900522, '1', 0 UNION ALL
  SELECT 900523, '1', 0 UNION ALL
  SELECT 900531, '1', 0 UNION ALL
  SELECT 900532, '1', 0 UNION ALL
  SELECT 900533, '1', 0 UNION ALL
  SELECT 900541, '1', 0 UNION ALL
  SELECT 900542, '2', 0 UNION ALL
  SELECT 900543, NULL, 0 UNION ALL
  SELECT 900544, '1', 0 UNION ALL
  SELECT 900545, '1', 0 UNION ALL
  SELECT 900546, 'Male', 0 UNION ALL
  SELECT 900551, '1', 0 UNION ALL
  SELECT 900552, '1', 0 UNION ALL
  SELECT 900553, '1', 0 UNION ALL
  SELECT 900554, '1', 0 UNION ALL
  SELECT 900555, '1', 0 UNION ALL
  SELECT 900561, '1', 0 UNION ALL
  SELECT 900562, '2', 0 UNION ALL
  SELECT 900563, '1', 0 UNION ALL
  SELECT 900564, '1', 0 UNION ALL
  SELECT 900565, '1', 0 UNION ALL
  SELECT 900566, NULL, 0 UNION ALL
  SELECT 900571, '1', 0 UNION ALL
  SELECT 900572, '2', 0 UNION ALL
  SELECT 900573, '1', 0 UNION ALL
  SELECT 900574, '1', 0 UNION ALL
  SELECT 900575, '1', 0 UNION ALL
  SELECT 900576, '1', 0) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users u JOIN (
  SELECT 900501 AS token, '1' AS gender, 3 AS roleid UNION ALL
  SELECT 900502, '2', 4 UNION ALL
  SELECT 900511, '1', 0 UNION ALL
  SELECT 900512, '2', 0 UNION ALL
  SELECT 900521, '1', 0 UNION ALL
  SELECT 900522, '1', 0 UNION ALL
  SELECT 900523, '1', 0 UNION ALL
  SELECT 900531, '1', 0 UNION ALL
  SELECT 900532, '1', 0 UNION ALL
  SELECT 900533, '1', 0 UNION ALL
  SELECT 900541, '1', 0 UNION ALL
  SELECT 900542, '2', 0 UNION ALL
  SELECT 900543, NULL, 0 UNION ALL
  SELECT 900544, '1', 0 UNION ALL
  SELECT 900545, '1', 0 UNION ALL
  SELECT 900546, 'Male', 0 UNION ALL
  SELECT 900551, '1', 0 UNION ALL
  SELECT 900552, '1', 0 UNION ALL
  SELECT 900553, '1', 0 UNION ALL
  SELECT 900554, '1', 0 UNION ALL
  SELECT 900555, '1', 0 UNION ALL
  SELECT 900561, '1', 0 UNION ALL
  SELECT 900562, '2', 0 UNION ALL
  SELECT 900563, '1', 0 UNION ALL
  SELECT 900564, '1', 0 UNION ALL
  SELECT 900565, '1', 0 UNION ALL
  SELECT 900566, NULL, 0 UNION ALL
  SELECT 900571, '1', 0 UNION ALL
  SELECT 900572, '2', 0 UNION ALL
  SELECT 900573, '1', 0 UNION ALL
  SELECT 900574, '1', 0 UNION ALL
  SELECT 900575, '1', 0 UNION ALL
  SELECT 900576, '1', 0) v ON v.token = u.token
SET u.email = CONCAT('en.', v.token, '@example.invalid'), u.name = CONCAT('En Member ', v.token), u.gender = v.gender, u.roleid = v.roleid, u.mobile = CONCAT('+91000005', RIGHT(v.token, 4));

DELETE FROM student_transfers WHERE token_no BETWEEN 900501 AND 900599 OR from_class_id BETWEEN 9401 AND 9499 OR to_class_id BETWEEN 9401 AND 9499;
DELETE FROM class_registrations WHERE token BETWEEN 900501 AND 900599;
DELETE FROM class_students WHERE class_id BETWEEN 9411 AND 9499;
DELETE FROM classes WHERE id BETWEEN 9411 AND 9499;

INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (9411, 'EN-G-011', 1, 'enlnk9411', 'En Remove Class', 3, '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9412, 'EN-G-012', 1, 'enlnk9412', 'En Restore Class', 3, '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9413, 'EN-G-013', 1, 'enlnk9413', 'En Add Class', 3, '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9414, 'EN-L-014', 1, 'enlnk9414', 'En Ladies Class', 3, '2025-09-01', 900512, 2, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9415, 'EN-G-015', 1, 'enlnk9415', 'En Transfer Source', 3, '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9416, 'EN-G-016', 1, 'enlnk9416', 'En Transfer Destination', 3, '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9417, 'EN-G-017', 1, 'enlnk9417', 'En Closed Class', 3, '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'I', 900331),
  (9418, 'EN-G-018', 1, 'WrJoin9418', 'En Join Class', 3, '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9420, 'EN-G-020', 1, 'enlnk9420', 'En Place Class', 3, '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9421, 'EN-G-021', 1, 'enlnk9421', 'En Placed Elsewhere Class', 3, '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'A', 900331),
  (9419, 'EN-G-019', 1, 'wrjoin9419', 'En Closed Join Class', 3, '2025-09-01', 900511, 1, 'Offline', 'Mumbai', 'India', 'En Hall', 'I', 900331);

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (9411, 9411, 900521, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9412, 9411, 900522, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9413, 9411, 900523, '2025-09-01', 0, '2025-10-01 00:00:00', 'En removed', 900331, 'I'),
  (9414, 9412, 900531, '2025-09-01', 0, '2025-10-01 00:00:00', 'En gone', 900331, 'I'),
  (9415, 9412, 900532, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9416, 9412, 900533, '2025-09-01', 0, '2025-10-01 00:00:00', 'Transfer to class #9411', 900331, 'I'),
  (9417, 9413, 900544, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9418, 9413, 900545, '2025-09-01', 0, '2025-10-01 00:00:00', 'En left', 900331, 'I'),
  (9419, 9415, 900551, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9420, 9415, 900552, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9421, 9416, 900552, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (9422, 9415, 900553, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9423, 9415, 900554, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9424, 9415, 900555, '2025-09-01', 0, '2025-10-01 00:00:00', 'En left', 900331, 'I'),
  (9425, 9418, 900563, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (9426, 9418, 900564, '2025-09-01', 0, '2025-10-01 00:00:00', 'En removed by admin', 900331, 'I'),
  (9427, 9418, 900565, '2025-09-01', 0, '2025-10-01 00:00:00', 'En left by themself', 900565, 'I'),
  (9428, 9421, 900574, '2025-09-01', 0, NULL, NULL, NULL, 'A');

INSERT INTO class_registrations (id, token, status, created_at) VALUES
  (9571, 900571, 'Pending', NOW()), (9572, 900572, 'Pending', NOW()), (9573, 900573, 'Rejected', NOW()), (9574, 900574, 'Pending', NOW()),
  (9575, 900575, 'Pending', NOW()), (9576, 900575, 'Pending', NOW()), (9577, 900576, 'Pending', NOW());
UPDATE class_students SET created_at = CONCAT(joined_on, ' 08:00:00') WHERE class_id BETWEEN 9411 AND 9499;
-- classes_before_create replaces the link of every inserted class with a random string; an UPDATE keeps ours (the join contract files use 9418 and 9419).
UPDATE classes SET link = CONCAT('enlnk', id) WHERE id BETWEEN 9411 AND 9499;
UPDATE classes SET link = 'WrJoin9418' WHERE id = 9418;
UPDATE classes SET link = 'wrjoin9419' WHERE id = 9419;
