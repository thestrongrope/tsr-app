-- The members the Hurl contract files sign in as, for the S2 scratch source (tools/parity-php/s2-source.sh), so a database
-- FILLED BY THE LOAD can answer them. These are the same rows that tools/identity-contract.sh, tools/access-contract.sh and
-- tools/platform-contract.sh create in the PHP parity database (copied: keep them in step), plus
-- tools/parity-php/membership-fixtures.sql, which s2-source.sh applies as it is. Synthetic only: tokens 900001 and up, .invalid emails.
INSERT INTO users (token, email, roleid, provider, createdon)
SELECT v.token, v.email, 0, 'firebase', NOW() FROM (
  SELECT 900001 AS token, 'member.gents@example.invalid' AS email UNION ALL
  SELECT 0, 'guest@example.invalid' UNION ALL
  SELECT 900011, 'deletion.pending@example.invalid' UNION ALL
  SELECT 900012, 'unverified.target@example.invalid' UNION ALL
  SELECT 900013, 'link.target@example.invalid') v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.email = v.email);
INSERT INTO account_deletion_requests (token, status, source, contact_email, requested_at)
SELECT 900011, 'pending', 'app', 'deletion.pending@example.invalid', UTC_TIMESTAMP() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM account_deletion_requests WHERE token = 900011);
INSERT INTO account_deletion_requests (token, status, source, contact_email, requested_at, completed_at)
SELECT NULL, 'completed', 'app', 'deleted.recently@example.invalid', UTC_TIMESTAMP(), UTC_TIMESTAMP() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM account_deletion_requests WHERE status = 'completed' AND contact_email = 'deleted.recently@example.invalid');
UPDATE account_deletion_requests SET completed_at = UTC_TIMESTAMP()
WHERE status = 'completed' AND contact_email = 'deleted.recently@example.invalid';

INSERT INTO users (token, email, roleid, provider, createdon)
SELECT v.token, v.email, 0, 'firebase', NOW() FROM (
  SELECT 900101 AS token, 'perm.member@example.invalid' AS email UNION ALL
  SELECT 900102, 'perm.superadmin@example.invalid' UNION ALL
  SELECT 900103, 'perm.gentsadmin@example.invalid' UNION ALL
  SELECT 900104, 'perm.ladiesadmin@example.invalid' UNION ALL
  SELECT 900105, 'perm.coordinator@example.invalid' UNION ALL
  SELECT 900106, 'perm.finance@example.invalid' UNION ALL
  SELECT 900107, 'perm.teacherrole@example.invalid' UNION ALL
  SELECT 900108, 'perm.granted@example.invalid' UNION ALL
  SELECT 0, 'guest@example.invalid') v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.email = v.email);
UPDATE users SET roleid = CASE token WHEN 900102 THEN 1 WHEN 900103 THEN 3 WHEN 900104 THEN 4
  WHEN 900105 THEN 5 WHEN 900106 THEN 7 WHEN 900107 THEN 6 ELSE 0 END
WHERE token BETWEEN 900101 AND 900108;
INSERT INTO user_permissions (user_id, permission, reason, revoked_at)
SELECT u.id, v.permission, 'synthetic fixture', v.revoked_at FROM (
  SELECT 'standard-mcqs:update:all' AS permission, NULL AS revoked_at UNION ALL
  SELECT 'api-docs:read:all', NULL UNION ALL
  SELECT 'summary-report:read:all', '2026-01-01 00:00:00') v
JOIN users u ON u.token = 900108
WHERE NOT EXISTS (SELECT 1 FROM user_permissions g WHERE g.user_id = u.id AND g.permission = v.permission);

INSERT INTO users (token, email, roleid, provider, createdon)
SELECT 900002, 'member.ladies@example.invalid', 0, 'firebase', NOW() FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.email = 'member.ladies@example.invalid');
