/*
 * The classes B4a fixtures for the PHP parity stack's MariaDB: the same rows as db/synthetic/classes-b4a-fixtures.sql (read that header for the legend). Loaded last by tools/classes-contract.sh, before every
 * run; resets every row it owns (by token, class id and syllabus id), including what a run created.
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile, city, country)
SELECT v.token, CONCAT('b4.', v.token, '@example.invalid'), 0, 'firebase', '2025-01-15 10:00:00', CONCAT('B4 Member ', v.token),
       CASE WHEN v.token IN (900923, 900951, 900992, 901003, 901011, 901012, 901013) THEN '2' WHEN v.token IN (900993, 900925, 901004) THEN 'Male' WHEN v.token = 900994 THEN 'Other' WHEN v.token = 900985 THEN NULL ELSE '1' END,
       CASE WHEN v.token = 900992 THEN '' ELSE CONCAT('+91000009', RIGHT(v.token, 4)) END,
       CASE WHEN v.token = 900991 THEN 'Pune' END, CASE WHEN v.token = 900991 THEN 'India' END
FROM (SELECT 900901 AS token UNION ALL SELECT 900902 UNION ALL SELECT 900903 UNION ALL SELECT 900904 UNION ALL SELECT 900905 UNION ALL SELECT 900906 UNION ALL SELECT 900907 UNION ALL SELECT 900908 UNION ALL SELECT 900909 UNION ALL SELECT 900910 UNION ALL SELECT 900921 UNION ALL SELECT 900922 UNION ALL SELECT 900923 UNION ALL SELECT 900924 UNION ALL SELECT 900925 UNION ALL SELECT 900931 UNION ALL SELECT 900932 UNION ALL SELECT 900933 UNION ALL SELECT 900934 UNION ALL SELECT 900941 UNION ALL SELECT 900942 UNION ALL SELECT 900943 UNION ALL SELECT 900944 UNION ALL SELECT 900951 UNION ALL SELECT 900961 UNION ALL SELECT 900962 UNION ALL SELECT 900963 UNION ALL SELECT 900964 UNION ALL SELECT 900965 UNION ALL SELECT 900966 UNION ALL SELECT 900971 UNION ALL SELECT 900972 UNION ALL SELECT 900981 UNION ALL SELECT 900982 UNION ALL SELECT 900983 UNION ALL SELECT 900984 UNION ALL SELECT 900985 UNION ALL SELECT 900991 UNION ALL SELECT 900992 UNION ALL SELECT 900993 UNION ALL SELECT 900994 UNION ALL SELECT 900995 UNION ALL SELECT 900996 UNION ALL SELECT 901001 UNION ALL SELECT 901002 UNION ALL SELECT 901003 UNION ALL SELECT 901004 UNION ALL SELECT 901005 UNION ALL SELECT 901006 UNION ALL SELECT 901011 UNION ALL SELECT 901012 UNION ALL SELECT 901013) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users SET email = CONCAT('b4.', token, '@example.invalid'), name = CONCAT('B4 Member ', token), roleid = 0, createdon = '2025-01-15 10:00:00',
  gender = CASE WHEN token IN (900923, 900951, 900992, 901003, 901011, 901012, 901013) THEN '2' WHEN token IN (900993, 900925, 901004) THEN 'Male' WHEN token = 900994 THEN 'Other' WHEN token = 900985 THEN NULL ELSE '1' END,
  mobile = CASE WHEN token = 900992 THEN '' ELSE CONCAT('+91000009', RIGHT(token, 4)) END,
  city = CASE WHEN token = 900991 THEN 'Pune' END, country = CASE WHEN token = 900991 THEN 'India' END
WHERE (token BETWEEN 900901 AND 900999 OR token BETWEEN 901001 AND 901099) AND email NOT LIKE 'b4.%.dup@example.invalid';
UPDATE users SET name = 'B4 Admin Deact' WHERE token = 900910;
UPDATE users SET roleid = 1 WHERE token BETWEEN 900901 AND 900909;

-- 900995 is held by two members (an ambiguous token).
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT 900995, 'b4.900995.dup@example.invalid', 0, 'firebase', '2025-01-15 10:00:00', 'B4 Member 900995', '1', '+910000099950'
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.email = 'b4.900995.dup@example.invalid');

DELETE FROM syllabus WHERE id BETWEEN 9501 AND 9599 OR created_by = 900901;
DELETE FROM student_transfers WHERE token_no BETWEEN 900901 AND 900999 OR from_class_id BETWEEN 9511 AND 9559 OR to_class_id BETWEEN 9511 AND 9559;
DELETE FROM class_registrations WHERE token BETWEEN 900901 AND 900999;
DELETE FROM class_audit_log WHERE class_id BETWEEN 9511 AND 9559;
DELETE FROM teachers_history WHERE token BETWEEN 900901 AND 900999 OR token BETWEEN 901001 AND 901099;
DELETE FROM teachers WHERE token BETWEEN 900901 AND 900999 OR token BETWEEN 901001 AND 901099;
DELETE FROM class_students WHERE class_id BETWEEN 9511 AND 9559 OR token_no BETWEEN 900901 AND 900999 OR token_no BETWEEN 901001 AND 901099;
DELETE FROM class_schedules WHERE class_id BETWEEN 9511 AND 9559;
DELETE FROM classes WHERE id BETWEEN 9511 AND 9559;

INSERT INTO syllabus (id, level_id, subject_name, description, link_type, url, sort_order, is_active, created_by, created_at, deleted_at, deleted_by) VALUES
  (9501,  4, 'B4 Syllabus Two', '', 'pdf', 'https://example.invalid/b4/two.pdf', 2, 1, 900901, '2025-06-01 09:00:00', NULL, NULL),
  (9502,  4, 'B4 Syllabus Unsorted', 'B4 text', 'external', 'https://example.invalid/b4/unsorted', NULL, 1, 900901, '2025-06-01 09:00:00', NULL, NULL),
  (9503,  4, 'B4 Syllabus Hidden', NULL, 'pdf', 'https://example.invalid/b4/hidden.pdf', 3, 0, 900901, '2025-06-01 09:00:00', NULL, NULL),
  (9504,  4, 'B4 Syllabus Deleted', NULL, 'pdf', 'https://example.invalid/b4/deleted.pdf', 4, 1, 900901, '2025-06-01 09:00:00', '2025-06-02 09:00:00', 900901),
  (9505,  2, 'B4 Syllabus Put', 'B4 put text', 'pdf', 'https://example.invalid/b4/put.pdf', 1, 1, 900901, '2025-06-01 09:00:00', NULL, NULL),
  (9506,  4, 'B4 Syllabus One', NULL, 'pdf', 'https://example.invalid/b4/one.pdf', 1, 1, 900901, '2025-06-01 09:00:00', NULL, NULL),
  (9507,  2, 'B4 Syllabus Delete', NULL, 'pdf', 'https://example.invalid/b4/delete.pdf', 2, 1, 900901, '2025-06-01 09:00:00', NULL, NULL),
  (9508,  2, 'B4 Syllabus Gone', NULL, 'pdf', 'https://example.invalid/b4/gone.pdf', 3, 1, 900901, '2025-06-01 09:00:00', '2025-06-02 09:00:00', 900901);

INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by, completed_on, comments, deleted_at, deleted_by) VALUES
  (9511, 'B4-G-11', 1, 'b4lnk9511', 'B4 Alpha Class', 3, '2025-09-01', 900921, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9512, 'B4-G-12', 1, 'b4lnk9512', 'B4 Closed Class', 4, '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'I', 900901, NULL, NULL, NULL, NULL),
  (9513, 'B4-G-13', 1, 'b4lnk9513', 'B4 Beta Class', 3, '2025-09-01', 900921, 1, 'Offline', NULL, 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9514, 'B4-L-14', 1, 'b4lnk9514', 'B4 Ladies Class', 2, '2025-09-01', 900923, 2, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9515, 'B4-G-15', 1, 'b4lnk9515', 'B4 Old Class', 3, '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'I', 900901, '2025-08-01', 'B4 old comment', '2025-08-02 09:00:00', 900910),
  (9516, 'B4-G-16', 1, 'b4lnk9516', 'B4 Twice Class', 3, '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'I', 900901, NULL, 'B4 sixteen comment', NULL, NULL),
  (9521, 'B4-G-21', 1, 'b4lnk9521', 'B4 Save Source', 3, '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9522, 'B4-G-22', 1, 'b4lnk9522', 'B4 Save Destination', 3, '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9523, 'B4-L-23', 1, 'b4lnk9523', 'B4 Save Ladies', 3, '2025-09-01', 900923, 2, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9524, 'B4-G-24', 1, 'b4lnk9524', 'B4 Save Closed', 3, '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'I', 900901, NULL, NULL, NULL, NULL),
  (9525, 'B4-G-25', 1, 'b4lnk9525', 'B4 Save Closed Source', 3, '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'I', 900901, NULL, NULL, NULL, NULL),
  (9526, 'B4-G-26', 1, 'b4lnk9526', 'B4 Save Other', 3, '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9531, 'B4-G-31', 1, 'b4lnk9531', 'B4 Enrol Class', 3, '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9532, 'B4-L-32', 1, 'b4lnk9532', 'B4 Enrol Ladies', 3, '2025-09-01', 900923, 2, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9533, 'B4-G-33', 1, 'b4lnk9533', 'B4 Enrol Closed', 3, '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'I', 900901, NULL, NULL, NULL, NULL),
  (9541, 'B4-G-41', 1, 'b4lnk9541', 'B4 Lookup One', 3, '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9542, 'B4-G-42', 1, 'b4lnk9542', 'B4 Lookup Two', 4, '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9543, 'B4-G-43', 1, 'b4lnk9543', 'B4 Lookup Closed', 3, '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'I', 900901, NULL, NULL, NULL, NULL),
  (9544, 'B4-G-44', 1, 'b4lnk9544', 'B4 Teachers Class', 2, '2025-09-01', 900922, 1, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9551, 'B4-L-51', 1, 'b4lnk9551', 'B4 Import One', 3, '2025-09-01', 901011, 2, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9552, 'B4-L-52', 1, 'b4lnk9552', 'B4 Import Two', 2, '2025-09-01', 901011, 2, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9553, 'B4-L-53', 1, 'b4lnk9553', 'B4 Import Three', 1, '2025-09-01', 901012, 2, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL),
  (9554, 'B4-L-54', 1, 'b4lnk9554', 'B4 Import Four', 4, '2025-09-01', 901013, 2, 'Offline', 'Pune', 'India', 'B4 Hall', 'A', 900901, NULL, NULL, NULL, NULL);

INSERT INTO class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (951101, 9511, 900931, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951102, 9511, 900932, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951103, 9511, 900933, '2025-09-01', 0, '2025-10-01 00:00:00', 'B4 left', 900910, 'I'),
  (951104, 9511, 900934, '2025-09-01', 0, NULL, NULL, NULL, 'I'),
  (951105, 9512, 900941, '2025-09-01', 0, '2025-10-05 12:00:00', 'Class deactivated: B4 closing', 900910, 'I'),
  (951106, 9512, 900942, '2025-09-01', 0, '2025-10-05 12:00:00', 'Class deactivated: B4 closing', 900910, 'I'),
  (951107, 9512, 900943, '2025-09-01', 0, '2025-09-20 12:00:00', 'B4 left earlier', 900910, 'I'),
  (951108, 9512, 900944, '2025-09-01', 0, '2025-10-05 12:00:00', 'Class deactivated: B4 closing', 900910, 'I'),
  (951109, 9513, 900944, '2025-10-06', 0, NULL, NULL, NULL, 'A'),
  (951110, 9514, 900951, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951121, 9521, 900961, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951122, 9521, 900962, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951123, 9521, 900963, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951124, 9521, 900964, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951125, 9521, 900965, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951126, 9521, 900966, '2025-09-01', 0, '2025-10-01 00:00:00', 'B4 left', 900910, 'I'),
  (951127, 9522, 900962, '2025-09-05', 0, NULL, NULL, NULL, 'A'),
  (951128, 9525, 900971, '2025-09-01', 0, '2025-10-05 12:00:00', 'Class deactivated: B4 save', 900910, 'I'),
  (951129, 9525, 900972, '2025-09-01', 0, '2025-10-05 12:00:00', 'Class deactivated: B4 save', 900910, 'I'),
  (951130, 9526, 900972, '2025-10-06', 0, NULL, NULL, NULL, 'A'),
  (951131, 9531, 900981, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951132, 9531, 900982, '2025-09-01', 1, '2025-10-01 00:00:00', 'B4 left', 900910, 'I'),
  (951141, 9541, 900991, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951142, 9542, 900991, '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951143, 9543, 900991, '2025-09-03', 0, NULL, NULL, NULL, 'A'),
  (951144, 9541, 900993, '2025-09-01', 0, '2025-11-01 00:00:00', 'B4 left', 900910, 'I'),
  (951151, 9544, 900921, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951152, 9544, 900924, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951153, 9544, 900925, '2025-09-01', 0, NULL, NULL, NULL, 'A'),
  (951154, 9514, 900923, '2025-09-01', 0, NULL, NULL, NULL, 'A');
UPDATE class_students SET created_at = CONCAT(joined_on, ' 08:00:00') WHERE class_id BETWEEN 9511 AND 9559;

INSERT INTO class_audit_log (id, class_id, action, details, performed_by, performed_at) VALUES
  (951101, 9512, 'deactivated', '{"type": "shutdown", "effective_date": "2025-10-05", "reason": "B4 closing"}', 900910, '2025-10-05 12:00:00'),
  (951102, 9516, 'deactivated', '{"type": "shutdown", "effective_date": "2025-09-01", "reason": "B4 first"}', 900910, '2025-09-01 10:00:00'),
  (951103, 9516, 'deactivated', '{"type": "completed", "effective_date": "2025-09-15"}', 900910, '2025-09-15 10:00:00');

INSERT INTO student_transfers (id, token_no, from_class_id, to_class_id, type, reason, transferred_by, transferred_at) VALUES
  (951101, 900931, 9511, 9513, 'transfer', 'B4 reason a', 900910, '2025-10-01 10:00:00'),
  (951102, 900932, 9511, 9513, 'promotion', '', 900910, '2025-10-02 10:00:00'),
  (951103, 900931, 9513, 9511, 'demotion', 'B4 100%_x', 900910, '2025-10-03 10:00:00');

INSERT INTO class_registrations (id, token, for_classid, status, created_at) VALUES
  (951101, 900991, 9541, 'Pending', '2025-02-01 10:00:00'),
  (951102, 900993, 9541, 'Accepted', '2025-02-01 10:00:00'),
  (951103, 900996, 9599, 'Pending', '2025-02-01 10:00:00');

INSERT INTO teachers (token, salman, abuzar, miqdad, ammar, bilal, comments, status, created_by) VALUES
  (900921, 0, 1, 1, 0, 0, 'B4 record', 'A', 900902),
  (900922, 0, 0, 1, 0, 0, 'B4 record', 'A', 900902),
  (900923, 1, 0, 0, 0, 0, 'B4 record', 'A', 900902),
  (900924, 1, 1, 0, 0, 0, 'B4 record', 'I', 900902),
  (900925, 1, 0, 0, 0, 0, 'B4 record', 'A', 900902),
  (901001, 0, 0, 0, 0, 0, 'B4 record', 'A', 900902),
  (901005, 0, 0, 0, 0, 1, 'B4 record', 'I', 900902),
  (901006, 1, 0, 0, 0, 1, 'B4 record', 'A', 900902),
  (901013, 0, 0, 1, 1, 1, 'B4 record', 'A', 900902);
INSERT INTO teachers_history (id, token, salman, abuzar, miqdad, ammar, bilal, comments, status, created_by, created_at) VALUES
  (951101, 901006, 1, 0, 0, 0, 1, 'B4 history', 'A', 900902, '2025-08-01 09:00:00');

-- classes_before_create replaces the link of every inserted class with a random string; an UPDATE keeps ours.
UPDATE classes SET link = CONCAT('b4lnk', id) WHERE id BETWEEN 9511 AND 9559;
