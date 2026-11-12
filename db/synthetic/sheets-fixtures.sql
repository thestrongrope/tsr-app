/*
 * The lane-sheets fixtures (standard MCQ update and the quiz competition admin) for the new API's database; tools/parity-php/sheets-fixtures.sql holds the same rows for PHP.
 * Loaded by tools/contract-sheets.sh before every run, idempotent. Synthetic only: tokens 923001 to 923008, emails sh.<token>@example.invalid, mobiles +910000923nnn.
 * No role holds quiz:admin or quiz:reset (a super admin holds standard-mcqs:update), so the quiz members hold NAMED GRANTS:
 *   923001 plain member (no role, no grant)   923002 super admin (role 1: standard-mcqs:update, no quiz permission)   923003 gents admin (role 3)
 *   923004 grant standard-mcqs:update only   923005 grant quiz:admin only   923006 grants quiz:admin and quiz:reset   923007 grant quiz:reset only (no quiz:admin)
 *   923008 REVOKED grants of quiz:admin and standard-mcqs:update
 */
INSERT INTO identity.users (token, email)
SELECT v.token, 'sh.' || v.token || '@example.invalid' FROM (VALUES (923001), (923002), (923003), (923004), (923005), (923006), (923007), (923008)) AS v (token)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

UPDATE identity.users SET email = 'sh.' || token || '@example.invalid' WHERE token BETWEEN 923001 AND 923008;

INSERT INTO membership.member_profiles (user_id, name, gender, mobile)
SELECT u.id, 'Sh Member ' || u.token, '1', '+910000' || u.token FROM identity.users u WHERE u.token BETWEEN 923001 AND 923008
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile;

DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 923001 AND 923008);
INSERT INTO access.user_roles (user_id, roleid) SELECT id, 1 FROM identity.users WHERE token = 923002;
INSERT INTO access.user_roles (user_id, roleid) SELECT id, 3 FROM identity.users WHERE token = 923003;

DELETE FROM access.user_permissions WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 923001 AND 923008);
INSERT INTO access.user_permissions (user_id, permission, reason, revoked_at)
SELECT u.id, v.permission, 'synthetic fixture', v.revoked_at FROM (VALUES
  (923004, 'standard-mcqs:update:all', NULL::timestamptz),
  (923005, 'quiz:admin:all', NULL),
  (923006, 'quiz:admin:all', NULL),
  (923006, 'quiz:reset:all', NULL),
  (923007, 'quiz:reset:all', NULL),
  (923008, 'quiz:admin:all', '2026-01-01 00:00:00+00'),
  (923008, 'standard-mcqs:update:all', '2026-01-01 00:00:00+00')
) AS v (token, permission, revoked_at) JOIN identity.users u ON u.token = v.token;
