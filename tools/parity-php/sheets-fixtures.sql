/*
 * The lane-sheets fixtures for the PHP parity stack's MariaDB: the same members and grants as db/synthetic/sheets-fixtures.sql (read the header there).
 * Loaded by tools/contract-sheets.sh before every run, idempotent. Tokens 923001 to 923008, emails sh.<token>@example.invalid.
 */
INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, CONCAT('sh.', v.token, '@example.invalid'), 0, 'firebase', NOW(), CONCAT('Sh Member ', v.token), '1', CONCAT('+910000', v.token) FROM (
  SELECT 923001 AS token UNION ALL SELECT 923002 UNION ALL SELECT 923003 UNION ALL SELECT 923004
  UNION ALL SELECT 923005 UNION ALL SELECT 923006 UNION ALL SELECT 923007 UNION ALL SELECT 923008) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

UPDATE users SET email = CONCAT('sh.', token, '@example.invalid'), name = CONCAT('Sh Member ', token), gender = '1', mobile = CONCAT('+910000', token),
  roleid = CASE token WHEN 923002 THEN 1 WHEN 923003 THEN 3 ELSE 0 END
WHERE token BETWEEN 923001 AND 923008;

DELETE FROM user_permissions WHERE user_id IN (SELECT id FROM users WHERE token BETWEEN 923001 AND 923008);
INSERT INTO user_permissions (user_id, permission, reason, revoked_at)
SELECT u.id, v.permission, 'synthetic fixture', v.revoked_at FROM (
  SELECT 923004 AS token, 'standard-mcqs:update:all' AS permission, NULL AS revoked_at
  UNION ALL SELECT 923005, 'quiz:admin:all', NULL
  UNION ALL SELECT 923006, 'quiz:admin:all', NULL
  UNION ALL SELECT 923006, 'quiz:reset:all', NULL
  UNION ALL SELECT 923007, 'quiz:reset:all', NULL
  UNION ALL SELECT 923008, 'quiz:admin:all', '2026-01-01 00:00:00'
  UNION ALL SELECT 923008, 'standard-mcqs:update:all', '2026-01-01 00:00:00') v
JOIN users u ON u.token = v.token;
