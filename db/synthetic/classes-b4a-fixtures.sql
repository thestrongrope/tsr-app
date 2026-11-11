/*
 * The classes B4a fixtures for the new API's database: what the 15 /admin contract files read and change (syllabus, transfers, member lookup and enrolment, deactivated classes, teachers).
 * tools/parity-php/classes-b4a-fixtures.sql holds the same rows for the PHP parity stack. Loaded last by tools/classes-contract.sh, before every run; resets every row it owns (by token, class id and
 * syllabus id), including what a run created. Synthetic only: tokens 900901 to 900999 and 901001 to 901099, emails b4.<token>@example.invalid, mobiles +91000009xxxx, classes 9511 to 9559,
 * syllabus 9501 to 9599, enrolment, transfer, audit and history rows 951101 and up (explicit ids: a sequence may already be past 9500).
 *
 *   900901 syllabus admin (role 1)  900902 admin for the transfer, deactivated and teacher reads (role 1)  900903 transfer-save admin  900904, 900905 member-lookup admins  900906 to 900909 enrolment admins
 *   900910 not an admin: named as the performer in the deactivation log
 *   syllabus  level 4: 9501 (sort 2), 9502 (sort NULL), 9503 inactive, 9504 deleted, 9506 (sort 1)    level 2: 9505 (PUT), 9507 (DELETE), 9508 (DELETE of a deleted item); POST adds to level 1 (levels 1 and 2 hold a seed item on the new API only)
 *   READ classes  9511 gents active (900931, 900932 active, 900933 removed, 900934 status I with no removal)  9512 gents closed (cohort 900941, 900942; 900943 left before; 900944 cohort but active in 9513)
 *                 9513 gents active  9514 ladies active (900951)  9515 closed with no audit row  9516 closed with two audit rows   transfers 951101 to 951103 (operator 900910)
 *   SAVE classes  9521 source (900961 to 900965 active, 900966 removed)  9522 destination (900962 in it)  9523 ladies  9524 closed  9525 closed source (cohort 900971, 900972)  9526 (900972 active)
 *   LOOKUP        900991 (9541, 9542 active; 9543 row not removed) 900992 ladies, bare  900993 text gender, accepted request, left 9541  900994 gender unknown  900995 token shared by two members
 *                 900996 pending request for a class that is gone    classes 9541, 9542 active, 9543 closed
 *   ENROL         class 9531 gents active (900981 in it, 900982 removed), 9532 ladies, 9533 closed; 900983 free gents, 900984 free gents, 900985 gender unknown
 *   TEACHERS      900921 (records, student of 9544, teaches 9511 and 9513)  900922 (record, no class as a student)  900923 ladies (record, student of 9514)  900924 record status I  900925 text gender
 *                 9544 gents active L2 (students 900921, 900924, 900925)
 *   TRAINING      901001 record, all off  901002 no record  901003 ladies, no record  901004 text gender  901005 record status I, bilal on  901006 record, salman and bilal on
 *   IMPORT        ladies 901011 teaches 9551 (level 3) and 9552 (level 2), 901012 teaches 9553 (level 1), 901013 has a record and teaches 9554
 */
INSERT INTO identity.users (token, email)
SELECT v.token, 'b4.' || v.token || '@example.invalid' FROM (VALUES
  (900901), (900902), (900903), (900904), (900905), (900906), (900907), (900908), (900909), (900910),
  (900921), (900922), (900923), (900924), (900925),
  (900931), (900932), (900933), (900934), (900941), (900942), (900943), (900944), (900951),
  (900961), (900962), (900963), (900964), (900965), (900966), (900971), (900972),
  (900981), (900982), (900983), (900984), (900985),
  (900991), (900992), (900993), (900994), (900995), (900996),
  (901001), (901002), (901003), (901004), (901005), (901006), (901011), (901012), (901013)
) AS v (token)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

UPDATE identity.users u SET email = 'b4.' || u.token || '@example.invalid'
WHERE (u.token BETWEEN 900901 AND 900999 OR u.token BETWEEN 901001 AND 901099) AND u.email <> 'b4.' || u.token || '@example.invalid' AND u.email NOT LIKE 'b4.%.dup@example.invalid';

-- 900995 is held by two members (an ambiguous token). The first row is the one above; the second is added here.
INSERT INTO identity.users (token, email)
SELECT 900995, 'b4.900995.dup@example.invalid' WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.email = 'b4.900995.dup@example.invalid');
UPDATE identity.users SET createdon = TIMESTAMPTZ '2025-01-15 10:00:00+00' WHERE token BETWEEN 900901 AND 900999 OR token BETWEEN 901001 AND 901099;

INSERT INTO membership.member_profiles (user_id, name, gender, mobile, city, country)
SELECT u.id, 'B4 Member ' || v.token,
       CASE WHEN v.token IN (900923, 900951, 900992, 901003, 901011, 901012, 901013) THEN '2' WHEN v.token = 900993 OR v.token IN (900925, 901004) THEN 'Male' WHEN v.token = 900994 THEN 'Other' WHEN v.token = 900985 THEN NULL ELSE '1' END,
       CASE WHEN v.token = 900992 THEN '' ELSE '+91000009' || right(v.token::text, 4) END,
       CASE WHEN v.token = 900991 THEN 'Pune' END,
       CASE WHEN v.token = 900991 THEN 'India' END
FROM (VALUES
  (900901), (900902), (900903), (900904), (900905), (900906), (900907), (900908), (900909), (900910),
  (900921), (900922), (900923), (900924), (900925),
  (900931), (900932), (900933), (900934), (900941), (900942), (900943), (900944), (900951),
  (900961), (900962), (900963), (900964), (900965), (900966), (900971), (900972),
  (900981), (900982), (900983), (900984), (900985),
  (900991), (900992), (900993), (900994), (900995), (900996),
  (901001), (901002), (901003), (901004), (901005), (901006), (901011), (901012), (901013)
) AS v (token)
JOIN identity.users u ON u.token = v.token AND u.email = 'b4.' || v.token || '@example.invalid'
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile, city = excluded.city, country = excluded.country;
UPDATE membership.member_profiles SET name = 'B4 Admin Deact' WHERE user_id IN (SELECT id FROM identity.users WHERE token = 900910);

DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 900901 AND 900909);
INSERT INTO access.user_roles (user_id, roleid)
SELECT u.id, 1 FROM identity.users u WHERE u.token BETWEEN 900901 AND 900909;

-- Everything the files created or changed is put back: syllabus items (the ones a POST made carry created_by 900901), transfers, requests, audit rows, training records, enrolments, classes.
DELETE FROM classes.syllabus WHERE id BETWEEN 9501 AND 9599 OR created_by = 900901;
DELETE FROM classes.student_transfers WHERE token_no BETWEEN 900901 AND 900999 OR from_class_id BETWEEN 9511 AND 9559 OR to_class_id BETWEEN 9511 AND 9559;
DELETE FROM membership.class_registrations WHERE token BETWEEN 900901 AND 900999;
DELETE FROM classes.class_audit_log WHERE class_id BETWEEN 9511 AND 9559;
DELETE FROM classes.teachers_history WHERE token BETWEEN 900901 AND 900999 OR token BETWEEN 901001 AND 901099;
DELETE FROM classes.teachers WHERE token BETWEEN 900901 AND 900999 OR token BETWEEN 901001 AND 901099;
DELETE FROM classes.class_students WHERE class_id BETWEEN 9511 AND 9559 OR token_no BETWEEN 900901 AND 900999 OR token_no BETWEEN 901001 AND 901099;
DELETE FROM classes.class_schedules WHERE class_id BETWEEN 9511 AND 9559;
DELETE FROM classes.classes WHERE id BETWEEN 9511 AND 9559;

INSERT INTO classes.syllabus (id, level_id, subject_name, description, link_type, url, sort_order, is_active, created_by, created_at, deleted_at, deleted_by) VALUES
  (9501,  4, 'B4 Syllabus Two', '', 'pdf', 'https://example.invalid/b4/two.pdf', 2, 1, 900901, TIMESTAMPTZ '2025-06-01 09:00:00+00', NULL, NULL),
  (9502,  4, 'B4 Syllabus Unsorted', 'B4 text', 'external', 'https://example.invalid/b4/unsorted', NULL, 1, 900901, TIMESTAMPTZ '2025-06-01 09:00:00+00', NULL, NULL),
  (9503,  4, 'B4 Syllabus Hidden', NULL, 'pdf', 'https://example.invalid/b4/hidden.pdf', 3, 0, 900901, TIMESTAMPTZ '2025-06-01 09:00:00+00', NULL, NULL),
  (9504,  4, 'B4 Syllabus Deleted', NULL, 'pdf', 'https://example.invalid/b4/deleted.pdf', 4, 1, 900901, TIMESTAMPTZ '2025-06-01 09:00:00+00', TIMESTAMPTZ '2025-06-02 09:00:00+00', 900901),
  (9505,  2, 'B4 Syllabus Put', 'B4 put text', 'pdf', 'https://example.invalid/b4/put.pdf', 1, 1, 900901, TIMESTAMPTZ '2025-06-01 09:00:00+00', NULL, NULL),
  (9506,  4, 'B4 Syllabus One', NULL, 'pdf', 'https://example.invalid/b4/one.pdf', 1, 1, 900901, TIMESTAMPTZ '2025-06-01 09:00:00+00', NULL, NULL),
  (9507,  2, 'B4 Syllabus Delete', NULL, 'pdf', 'https://example.invalid/b4/delete.pdf', 2, 1, 900901, TIMESTAMPTZ '2025-06-01 09:00:00+00', NULL, NULL),
  (9508,  2, 'B4 Syllabus Gone', NULL, 'pdf', 'https://example.invalid/b4/gone.pdf', 3, 1, 900901, TIMESTAMPTZ '2025-06-01 09:00:00+00', TIMESTAMPTZ '2025-06-02 09:00:00+00', 900901);

INSERT INTO classes.classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by, completed_on, comments, deleted_at, deleted_by) VALUES
  (9511, 'B4-G-11', 1, 'b4lnk9511', 'B4 Alpha Class', 3, DATE '2025-09-01', 900921, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9512, 'B4-G-12', 1, 'b4lnk9512', 'B4 Closed Class', 4, DATE '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'I', 900901, NULL, NULL, NULL, NULL),
  (9513, 'B4-G-13', 1, 'b4lnk9513', 'B4 Beta Class', 3, DATE '2025-09-01', 900921, 1, 'Offline', NULL, 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9514, 'B4-L-14', 1, 'b4lnk9514', 'B4 Ladies Class', 2, DATE '2025-09-01', 900923, 2, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9515, 'B4-G-15', 1, 'b4lnk9515', 'B4 Old Class', 3, DATE '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'I', 900901, DATE '2025-08-01', 'B4 old comment', TIMESTAMPTZ '2025-08-02 09:00:00+00', 900910),
  (9516, 'B4-G-16', 1, 'b4lnk9516', 'B4 Twice Class', 3, DATE '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'I', 900901, NULL, 'B4 sixteen comment', NULL, NULL),
  (9521, 'B4-G-21', 1, 'b4lnk9521', 'B4 Save Source', 3, DATE '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9522, 'B4-G-22', 1, 'b4lnk9522', 'B4 Save Destination', 3, DATE '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9523, 'B4-L-23', 1, 'b4lnk9523', 'B4 Save Ladies', 3, DATE '2025-09-01', 900923, 2, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9524, 'B4-G-24', 1, 'b4lnk9524', 'B4 Save Closed', 3, DATE '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'I', 900901, NULL, NULL, NULL, NULL),
  (9525, 'B4-G-25', 1, 'b4lnk9525', 'B4 Save Closed Source', 3, DATE '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'I', 900901, NULL, NULL, NULL, NULL),
  (9526, 'B4-G-26', 1, 'b4lnk9526', 'B4 Save Other', 3, DATE '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9531, 'B4-G-31', 1, 'b4lnk9531', 'B4 Enrol Class', 3, DATE '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9532, 'B4-L-32', 1, 'b4lnk9532', 'B4 Enrol Ladies', 3, DATE '2025-09-01', 900923, 2, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9533, 'B4-G-33', 1, 'b4lnk9533', 'B4 Enrol Closed', 3, DATE '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'I', 900901, NULL, NULL, NULL, NULL),
  (9541, 'B4-G-41', 1, 'b4lnk9541', 'B4 Lookup One', 3, DATE '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9542, 'B4-G-42', 1, 'b4lnk9542', 'B4 Lookup Two', 4, DATE '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9543, 'B4-G-43', 1, 'b4lnk9543', 'B4 Lookup Closed', 3, DATE '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'I', 900901, NULL, NULL, NULL, NULL),
  (9544, 'B4-G-44', 1, 'b4lnk9544', 'B4 Teachers Class', 2, DATE '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9551, 'B4-L-51', 1, 'b4lnk9551', 'B4 Import One', 3, DATE '2025-09-01', 901011, 2, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9552, 'B4-L-52', 1, 'b4lnk9552', 'B4 Import Two', 2, DATE '2025-09-01', 901011, 2, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9553, 'B4-L-53', 1, 'b4lnk9553', 'B4 Import Three', 1, DATE '2025-09-01', 901012, 2, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9554, 'B4-L-54', 1, 'b4lnk9554', 'B4 Import Four', 4, DATE '2025-09-01', 901013, 2, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (951101, 9511, 900931, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951102, 9511, 900932, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951103, 9511, 900933, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'B4 left', 900910, 'I'),
  (951104, 9511, 900934, DATE '2025-09-01', 0, NULL, NULL, NULL, 'I'),
  (951105, 9512, 900941, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-05 12:00:00+00', 'Class deactivated: B4 closing', 900910, 'I'),
  (951106, 9512, 900942, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-05 12:00:00+00', 'Class deactivated: B4 closing', 900910, 'I'),
  (951107, 9512, 900943, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-09-20 12:00:00+00', 'B4 left earlier', 900910, 'I'),
  (951108, 9512, 900944, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-05 12:00:00+00', 'Class deactivated: B4 closing', 900910, 'I'),
  (951109, 9513, 900944, DATE '2025-10-06', 0, NULL, NULL, NULL, 'A'),
  (951110, 9514, 900951, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951121, 9521, 900961, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951122, 9521, 900962, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951123, 9521, 900963, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951124, 9521, 900964, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951125, 9521, 900965, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951126, 9521, 900966, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'B4 left', 900910, 'I'),
  (951127, 9522, 900962, DATE '2025-09-05', 0, NULL, NULL, NULL, 'A'),
  (951128, 9525, 900971, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-05 12:00:00+00', 'Class deactivated: B4 save', 900910, 'I'),
  (951129, 9525, 900972, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-10-05 12:00:00+00', 'Class deactivated: B4 save', 900910, 'I'),
  (951130, 9526, 900972, DATE '2025-10-06', 0, NULL, NULL, NULL, 'A'),
  (951131, 9531, 900981, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951132, 9531, 900982, DATE '2025-09-01', 1, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'B4 left', 900910, 'I'),
  (951141, 9541, 900991, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951142, 9542, 900991, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951143, 9543, 900991, DATE '2025-09-03', 0, NULL, NULL, NULL, 'A'),
  (951144, 9541, 900993, DATE '2025-09-01', 0, TIMESTAMPTZ '2025-11-01 00:00:00+00', 'B4 left', 900910, 'I'),
  (951151, 9544, 900921, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951152, 9544, 900924, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951153, 9544, 900925, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951154, 9514, 900923, DATE '2025-09-01', 0, NULL, NULL, NULL, 'A');
UPDATE classes.class_students SET created_at = joined_on + TIME '08:00' AT TIME ZONE 'UTC' WHERE class_id BETWEEN 9511 AND 9559;

INSERT INTO classes.class_audit_log (id, class_id, action, details, performed_by, performed_at) VALUES
  (951101, 9512, 'deactivated', '{"type": "shutdown", "effective_date": "2025-10-05", "reason": "B4 closing"}', 900910, TIMESTAMPTZ '2025-10-05 12:00:00+00'),
  (951102, 9516, 'deactivated', '{"type": "shutdown", "effective_date": "2025-09-01", "reason": "B4 first"}', 900910, TIMESTAMPTZ '2025-09-01 10:00:00+00'),
  (951103, 9516, 'deactivated', '{"type": "completed", "effective_date": "2025-09-15"}', 900910, TIMESTAMPTZ '2025-09-15 10:00:00+00');

INSERT INTO classes.student_transfers (id, token_no, from_class_id, to_class_id, type, reason, transferred_by, transferred_at) VALUES
  (951101, 900931, 9511, 9513, 'transfer', 'B4 reason a', 900910, TIMESTAMPTZ '2025-10-01 10:00:00+00'),
  (951102, 900932, 9511, 9513, 'promotion', '', 900910, TIMESTAMPTZ '2025-10-02 10:00:00+00'),
  (951103, 900931, 9513, 9511, 'demotion', 'B4 100%_x', 900910, TIMESTAMPTZ '2025-10-03 10:00:00+00');

INSERT INTO membership.class_registrations (id, token, for_classid, status, created_at) VALUES
  (951101, 900991, 9541, 'Pending', TIMESTAMPTZ '2025-02-01 10:00:00+00'),
  (951102, 900993, 9541, 'Accepted', TIMESTAMPTZ '2025-02-01 10:00:00+00'),
  (951103, 900996, 9599, 'Pending', TIMESTAMPTZ '2025-02-01 10:00:00+00');

INSERT INTO classes.teachers (token, salman, abuzar, miqdad, ammar, bilal, comments, status, created_by) VALUES
  (900921, 0, 1, 1, 0, 0, 'B4 record', 'A', 900902),
  (900922, 0, 0, 1, 0, 0, 'B4 record', 'A', 900902),
  (900923, 1, 0, 0, 0, 0, 'B4 record', 'A', 900902),
  (900924, 1, 1, 0, 0, 0, 'B4 record', 'I', 900902),
  (900925, 1, 0, 0, 0, 0, 'B4 record', 'A', 900902),
  (901001, 0, 0, 0, 0, 0, 'B4 record', 'A', 900902),
  (901005, 0, 0, 0, 0, 1, 'B4 record', 'I', 900902),
  (901006, 1, 0, 0, 0, 1, 'B4 record', 'A', 900902),
  (901013, 0, 0, 1, 1, 1, 'B4 record', 'A', 900902);
INSERT INTO classes.teachers_history (id, token, salman, abuzar, miqdad, ammar, bilal, comments, status, created_by, created_at) VALUES
  (951101, 901006, 1, 0, 0, 0, 1, 'B4 history', 'A', 900902, TIMESTAMPTZ '2025-08-01 09:00:00+00');

SELECT setval(pg_get_serial_sequence('classes.syllabus', 'id'), greatest((SELECT max(id) FROM classes.syllabus), 9599));
SELECT setval(pg_get_serial_sequence('classes.class_students', 'id'), greatest((SELECT max(id) FROM classes.class_students), 9499));
SELECT setval(pg_get_serial_sequence('classes.student_transfers', 'id'), greatest((SELECT max(id) FROM classes.student_transfers), 1));
SELECT setval(pg_get_serial_sequence('classes.class_audit_log', 'id'), greatest((SELECT max(id) FROM classes.class_audit_log), 1));
SELECT setval(pg_get_serial_sequence('classes.teachers_history', 'id'), greatest((SELECT max(id) FROM classes.teachers_history), 1));
SELECT setval(pg_get_serial_sequence('membership.class_registrations', 'id'), greatest((SELECT max(id) FROM membership.class_registrations), 9599));
SELECT setval(pg_get_serial_sequence('classes.classes', 'id'), greatest((SELECT max(id) FROM classes.classes), 1));
