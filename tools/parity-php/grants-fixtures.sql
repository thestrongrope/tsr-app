/*
 * The grants lane fixtures for the PHP parity stack's MariaDB: the same rows as db/synthetic/grants-fixtures.sql (read the header there). Loaded by tools/contract-grants.sh parity
 * inside the parity lock; resets every row it owns. Synthetic only: tokens 925000 to 925999, classes 98500 to 98599, other ids 9750000 to 9759999.
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT t.token, CONCAT('gr.', t.token, '@example.invalid'), 0, 'firebase', NOW(), 'x', '1', ''
FROM (
  SELECT 925001 + seq AS token FROM seq_0_to_11
  UNION ALL SELECT 925021 + seq FROM seq_0_to_3
  UNION ALL SELECT 925031 + seq FROM seq_0_to_3
  UNION ALL SELECT 925041 + seq FROM seq_0_to_11
  UNION ALL SELECT 925060 + seq FROM seq_0_to_24) t
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = t.token);

UPDATE users SET email = CONCAT('gr.', token, '@example.invalid'),
  name = CASE token WHEN 925031 THEN 'Gsrch Percent 50% Off' WHEN 925032 THEN 'Gsrch Under_Score' WHEN 925033 THEN 'Gsrch Plain' WHEN 925034 THEN 'Gsrch NoPercent 50 Off'
    ELSE IF(token BETWEEN 925060 AND 925084, CONCAT('Gsrch Many ', LPAD(token - 925059, 2, '0')), CONCAT('Gr Member ', token)) END,
  gender = CASE WHEN token IN (925004, 925043, 925052) THEN '2' WHEN token = 925044 THEN NULL ELSE '1' END,
  mobile = CONCAT('+9100092', RIGHT(token, 4)),
  roleid = CASE token WHEN 925001 THEN 1 WHEN 925002 THEN 1 WHEN 925011 THEN 1 WHEN 925012 THEN 1 WHEN 925046 THEN 1 WHEN 925003 THEN 3 WHEN 925005 THEN 3 WHEN 925045 THEN 3 WHEN 925004 THEN 4
    WHEN 925006 THEN 5 WHEN 925042 THEN 5 WHEN 925050 THEN 5 WHEN 925051 THEN 5 WHEN 925052 THEN 5 WHEN 925007 THEN 7 WHEN 925009 THEN 6 WHEN 925047 THEN 6 ELSE 0 END
WHERE token BETWEEN 925000 AND 925999;

DELETE FROM class_access_rule_conditions WHERE rule_id IN (SELECT id FROM class_access_rules WHERE token BETWEEN 925000 AND 925999);
DELETE FROM class_access_rules WHERE token BETWEEN 925000 AND 925999;
DELETE FROM user_permissions WHERE user_id IN (SELECT id FROM users WHERE token BETWEEN 925000 AND 925999);

INSERT INTO user_permissions (id, user_id, permission, granted_by, reason, revoked_at, revoked_by, revoke_reason)
SELECT 9750001, u.id, 'standard-mcqs:update:all', s.id, 'Gr fixture grant', NULL, NULL, NULL FROM users u, users s WHERE u.token = 925010 AND s.token = 925001
UNION ALL SELECT 9750011, u.id, 'api-docs:read:all', s.id, 'Gr live grant', NULL, NULL, NULL FROM users u, users s WHERE u.token = 925022 AND s.token = 925001
UNION ALL SELECT 9750012, u.id, 'summary-report:read:all', s.id, 'Gr revoked grant', '2026-01-01 00:00:00', s.id, 'Gr fixture revoke' FROM users u, users s WHERE u.token = 925022 AND s.token = 925001
UNION ALL SELECT 9750013, u.id, 'standard-mcqs:update:all', s.id, 'Gr second live grant', NULL, NULL, NULL FROM users u, users s WHERE u.token = 925022 AND s.token = 925001;

DELETE FROM class_tags WHERE class_id BETWEEN 98500 AND 98599;
DELETE FROM classes WHERE id BETWEEN 98500 AND 98599;
DELETE FROM tags WHERE id BETWEEN 9750001 AND 9759999;
INSERT INTO classes (id, code, language_id, link, name, class_level_id, started_on, teacher, gender, format, city, country, location, status, created_by) VALUES
  (98501, 'GR-G-501', 7, 'grlnk98501', 'Gr Class One', 2, '2025-01-06', 925001, 1, 'Offline', 'GRville', 'Grland', 'Gr Hall', 'A', 925001),
  (98502, 'GR-G-502', 7, 'grlnk98502', 'Gr Class Two', 3, '2025-01-06', 925001, 1, 'Offline', 'GRville', 'Grland', 'Gr Hall', 'A', 925001),
  (98503, 'GR-G-503', 7, 'grlnk98503', 'Gr Class Three', 2, '2025-01-06', 925001, 1, 'Offline', 'GRother', 'Grland', 'Gr Hall', 'A', 925001),
  (98504, 'GR-G-504', 7, 'grlnk98504', 'Gr Class Closed', 2, '2025-01-06', 925001, 1, 'Offline', 'GRville', 'Grland', 'Gr Hall', 'I', 925001),
  (98505, 'GR-L-505', 7, 'grlnk98505', 'Gr Ladies One', 2, '2025-01-06', 925001, 2, 'Offline', 'GRville', 'Grland', 'Gr Hall', 'A', 925001),
  (98506, 'GR-L-506', 7, 'grlnk98506', 'Gr Ladies Two', 4, '2025-01-06', 925001, 2, 'Offline', 'GRlady', 'Grland', 'Gr Hall', 'A', 925001),
  (98507, 'GR-G-507', 7, 'grlnk98507', 'Gr Closed Only', 2, '2025-01-06', 925001, 1, 'Offline', 'GRclosed', 'Grclosedland', 'Gr Hall', 'I', 925001);
INSERT INTO tags (id, name) VALUES (9750001, 'gr-tag-a'), (9750002, 'gr-tag-b');
INSERT INTO class_tags (class_id, tag_id, created_by) VALUES (98501, 9750001, 925001), (98502, 9750001, 925001), (98505, 9750002, 925001);

INSERT INTO class_access_rules (id, token, gender, note, granted_by, reason, revoked_at, revoked_by, revoke_reason) VALUES
  (9750021, 925042, 1, 'Gents, GRville', (SELECT id FROM users WHERE token = 925001), 'Gr fixture', NULL, NULL, NULL),
  (9750022, 925042, 1, 'Gents, level 2, Grland', (SELECT id FROM users WHERE token = 925001), 'Gr fixture', NULL, NULL, NULL),
  (9750024, 925042, 1, 'Gents, GRother', (SELECT id FROM users WHERE token = 925001), 'Gr fixture', NOW(), (SELECT id FROM users WHERE token = 925001), 'Gr fixture revoke'),
  (9750031, 925050, 1, 'Gents, GRville', (SELECT id FROM users WHERE token = 925001), 'Gr fixture', NULL, NULL, NULL),
  (9750032, 925050, 2, 'Ladies, GRville', (SELECT id FROM users WHERE token = 925001), 'Gr fixture', NULL, NULL, NULL),
  (9750033, 925050, NULL, 'Any gender, GRville', (SELECT id FROM users WHERE token = 925001), 'Gr fixture', NULL, NULL, NULL),
  (9750034, 925050, 1, 'Gents, GRother', (SELECT id FROM users WHERE token = 925001), 'Gr fixture', NOW(), (SELECT id FROM users WHERE token = 925001), 'Gr fixture revoke'),
  (9750041, 925051, 2, 'Ladies, GRville', (SELECT id FROM users WHERE token = 925001), 'Gr fixture', NULL, NULL, NULL),
  (9750042, 925051, NULL, 'Any gender, GRville', (SELECT id FROM users WHERE token = 925001), 'Gr fixture', NULL, NULL, NULL),
  (9750043, 925052, 2, 'Ladies, GRville', (SELECT id FROM users WHERE token = 925001), 'Gr fixture', NULL, NULL, NULL);
INSERT INTO class_access_rule_conditions (rule_id, field, negate, value, level_id) VALUES
  (9750021, 'city', 0, 'GRville', NULL), (9750022, 'level', 0, NULL, 2), (9750022, 'country', 0, 'Grland', NULL), (9750024, 'city', 0, 'GRother', NULL),
  (9750031, 'city', 0, 'GRville', NULL), (9750032, 'city', 0, 'GRville', NULL), (9750033, 'city', 0, 'GRville', NULL), (9750034, 'city', 0, 'GRother', NULL),
  (9750041, 'city', 0, 'GRville', NULL), (9750042, 'city', 0, 'GRville', NULL), (9750043, 'city', 0, 'GRville', NULL);
