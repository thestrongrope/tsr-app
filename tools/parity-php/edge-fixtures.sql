/*
 * The edge lane fixtures (WhatsApp proxy, access log, search guards, holy-quran) for the PHP parity stack's MariaDB: the same rows as db/synthetic/edge-fixtures.sql.
 * Loaded by tools/contract-edge.sh inside the parity lock, before every run; resets every row it owns. Synthetic only: tokens 927002 to 927012 and 927100, 927101 (emails edge.<token>@example.invalid).
 *   927002 gents admin (role 3)   927003 plain member (gender 1)   927004, 927005, 927006, 927007, 927008 super admins (role 1), each used by ONE Hurl file (the link limits are per member)
 *   927009 member with no gender (role 1)   927012 super admin for the search file   927100 the subject of the access-log rows (never signs in)   927101 a log row whose user row is absent
 * Access log rows (subject 927100, times relative to the load): alpha 1 hour ago (role 1, GET), alpha 2 days ago (role 3, POST), =beta 3 days ago (role 9), gamma 4 days ago (no role, no address),
 * old 40 days ago (outside the 30 day window, role 0); 927101: alpha 1 day ago (no user row). Rows the contract files cause (relink and logout write one each) are deleted here by token.
 */
DELETE FROM admin_access_log WHERE token BETWEEN 927000 AND 927999;

INSERT INTO users (token, email, roleid, provider, createdon, name, gender, mobile)
SELECT v.token, CONCAT('edge.', v.token, '@example.invalid'), 0, 'firebase', NOW(), CONCAT('Edge Member ', v.token), IF(v.token = 927009, NULL, '1'), CONCAT('+91000092', RIGHT(v.token, 4)) FROM (
  SELECT 927002 AS token UNION ALL SELECT 927003 UNION ALL SELECT 927004 UNION ALL SELECT 927005 UNION ALL SELECT 927006 UNION ALL SELECT 927007 UNION ALL SELECT 927008
  UNION ALL SELECT 927009 UNION ALL SELECT 927012 UNION ALL SELECT 927100) v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.token = v.token);

-- Only this fixture's own members: a member another run created in this token range (a bulk add hands out the next token, which lands here) is left alone,
-- or its mobile number stays behind under a fixture name and the bulk contract file finds it.
UPDATE users SET email = CONCAT('edge.', token, '@example.invalid'), name = CONCAT('Edge Member ', token), gender = IF(token = 927009, NULL, '1'),
  roleid = CASE WHEN token = 927002 THEN 3 WHEN token IN (927004, 927005, 927006, 927007, 927008, 927009, 927012) THEN 1 ELSE 0 END
WHERE token IN (927002, 927003, 927004, 927005, 927006, 927007, 927008, 927009, 927012, 927100);

INSERT INTO admin_access_log (accessed_at, user_id, token, roleid, page, method, ip, user_agent, referer)
SELECT NOW() - INTERVAL 1 HOUR, u.id, 927100, 1, '/edge/alpha', 'GET', '192.0.2.1', 'Edge UA', 'https://example.invalid/r' FROM users u WHERE u.token = 927100 LIMIT 1;
INSERT INTO admin_access_log (accessed_at, user_id, token, roleid, page, method, ip, user_agent, referer)
SELECT NOW() - INTERVAL 2 DAY, u.id, 927100, 3, '/edge/alpha', 'POST', '192.0.2.2', 'Edge UA', NULL FROM users u WHERE u.token = 927100 LIMIT 1;
INSERT INTO admin_access_log (accessed_at, user_id, token, roleid, page, method, ip, user_agent, referer)
SELECT NOW() - INTERVAL 3 DAY, u.id, 927100, 9, '/edge/=beta', 'GET', '192.0.2.3', '=cmd|calc', '@ref' FROM users u WHERE u.token = 927100 LIMIT 1;
INSERT INTO admin_access_log (accessed_at, user_id, token, roleid, page, method, ip, user_agent, referer)
SELECT NOW() - INTERVAL 4 DAY, u.id, 927100, NULL, '/edge/gamma', 'GET', NULL, NULL, NULL FROM users u WHERE u.token = 927100 LIMIT 1;
INSERT INTO admin_access_log (accessed_at, user_id, token, roleid, page, method, ip, user_agent, referer)
SELECT NOW() - INTERVAL 40 DAY, u.id, 927100, 0, '/edge/old', 'GET', '192.0.2.4', 'Edge UA', NULL FROM users u WHERE u.token = 927100 LIMIT 1;
INSERT INTO admin_access_log (accessed_at, user_id, token, roleid, page, method, ip, user_agent, referer)
VALUES (NOW() - INTERVAL 1 DAY, NULL, 927101, 1, '/edge/alpha', 'GET', '192.0.2.5', 'Edge UA', NULL);
