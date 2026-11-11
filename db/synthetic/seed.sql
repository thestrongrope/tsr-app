/*
 * Synthetic members and articles for local development and the contract tests. Every value is
 * invented: tokens in the 900000 range, emails on the reserved .invalid domain. Never add a real member.
 * Loaded by the dev stack's "seed" service after the migrations (docker-compose.dev.yml). Not a
 * migration: production runs migrations and must never get these rows. Safe to run again.
 *
 *   900001  member, gents      (the member tools/dev-auth/mint-token.sh signs in)
 *   900002  member, ladies
 *   900003  super admin (roleid 1)
 *   0       a guest: never a member, so it can never sign in
 *   900011  member with a pending account deletion        (contract: link-account.hurl)
 *   900012  member whose email an unverified sign-in must not claim
 *   900013  member with no Firebase id yet, claimed by a verified email
 *   9001xx  one member per role, for the access contract (domains/access/spec/tests): 900101 member (role 0),
 *           900102 super admin (1), 900103 gents admin (3), 900104 ladies admin (4), 900105 class coordinator (5),
 *           900106 finance (7), 900107 class teacher (6), 900108 role 0 with named grants (two live, one revoked)
 *   (no row) deleted.recently: a deletion completed just now; tools/identity-contract.sh refreshes its time
 *   9002xx  membership fixtures (every gender form, a shared token, guardian links in each status, duplicate registrations): see the
 *           db/synthetic/membership-fixtures.sql (included below; it RESETS the rows it owns every time it runs);
 *           tools/parity-php/membership-fixtures.sql holds the same rows for the PHP parity stack
 *
 * Articles, one of each kind. Invented text.
 *   published  public (published_at in the past)
 *   draft      not public (published_at NULL)
 *   scheduled  not public yet (published_at in 2099)
 */

INSERT INTO identity.users (token, email)
SELECT v.token, v.email
FROM (VALUES
  (900001, 'member.gents@example.invalid'),
  (900002, 'member.ladies@example.invalid'),
  (900003, 'super.admin@example.invalid'),
  (0, 'guest@example.invalid')
) AS v (token, email)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

-- The profile (gender, name) lives in membership; identity.users holds none of it. 900001 to 900003 keep the genders they had.
INSERT INTO membership.member_profiles (user_id, name, gender)
SELECT u.id, v.name, v.gender
FROM (VALUES
  ('member.gents@example.invalid', 'Synthetic Gents Member', '1'),
  ('member.ladies@example.invalid', 'Synthetic Ladies Member', '2'),
  ('super.admin@example.invalid', 'Synthetic Super Admin', '1')
) AS v (email, name, gender)
JOIN identity.users u ON u.email = v.email
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO identity.users (token, email)
SELECT v.token, v.email
FROM (VALUES
  (900011, 'deletion.pending@example.invalid'),
  (900012, 'unverified.target@example.invalid'),
  (900013, 'link.target@example.invalid')
) AS v (token, email)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

-- Roles live in access (identity.users has no role column). A member (role 0) has no row.
INSERT INTO access.user_roles (user_id, roleid)
SELECT u.id, v.roleid
FROM (VALUES (900003, 1)) AS v (token, roleid)
JOIN identity.users u ON u.token = v.token
WHERE NOT EXISTS (SELECT 1 FROM access.user_roles r WHERE r.user_id = u.id);

-- The access contract's fixtures: the same emails and tokens exist on the PHP parity stack (tools/access-contract.sh).
INSERT INTO identity.users (token, email)
SELECT v.token, v.email
FROM (VALUES
  (900101, 'perm.member@example.invalid'),
  (900102, 'perm.superadmin@example.invalid'),
  (900103, 'perm.gentsadmin@example.invalid'),
  (900104, 'perm.ladiesadmin@example.invalid'),
  (900105, 'perm.coordinator@example.invalid'),
  (900106, 'perm.finance@example.invalid'),
  (900107, 'perm.teacherrole@example.invalid'),
  (900108, 'perm.granted@example.invalid')
) AS v (token, email)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

INSERT INTO access.user_roles (user_id, roleid)
SELECT u.id, v.roleid
FROM (VALUES (900102, 1), (900103, 3), (900104, 4), (900105, 5), (900106, 7), (900107, 6)) AS v (token, roleid)
JOIN identity.users u ON u.token = v.token
WHERE NOT EXISTS (SELECT 1 FROM access.user_roles r WHERE r.user_id = u.id);

INSERT INTO access.user_permissions (user_id, permission, reason, revoked_at)
SELECT u.id, v.permission, 'synthetic fixture', v.revoked_at
FROM (VALUES
  ('standard-mcqs:update:all', NULL::timestamptz),
  ('api-docs:read:all', NULL::timestamptz),
  ('summary-report:read:all', TIMESTAMPTZ '2026-01-01 00:00:00+00')
) AS v (permission, revoked_at)
JOIN identity.users u ON u.token = 900108
WHERE NOT EXISTS (SELECT 1 FROM access.user_permissions g WHERE g.user_id = u.id AND g.permission = v.permission);

INSERT INTO identity.account_deletion_requests (token, status, contact_email, requested_at)
SELECT 900011, 'pending', 'deletion.pending@example.invalid', now()
WHERE NOT EXISTS (SELECT 1 FROM identity.account_deletion_requests r WHERE r.token = 900011);

INSERT INTO identity.account_deletion_requests (token, status, contact_email, requested_at, completed_at)
SELECT NULL, 'completed', 'deleted.recently@example.invalid', now(), now()
WHERE NOT EXISTS (SELECT 1 FROM identity.account_deletion_requests r WHERE r.status = 'completed' AND r.contact_email = 'deleted.recently@example.invalid');

-- E'' strings: \n is a newline here, as it was in MariaDB's plain strings.
INSERT INTO content.articles (slug, title, body, published_at)
SELECT v.slug, v.title, v.body, v.published_at
FROM (VALUES
  ('synthetic-published-article', 'Synthetic published article',
   E'Invented text for local development. It has two paragraphs.\n\nThis is the second paragraph, with <angle brackets> that the site must escape.',
   TIMESTAMPTZ '2026-01-15 09:00:00+00'),
  ('synthetic-draft-article', 'Synthetic draft article',
   'Invented draft text. It must never appear on the site.',
   NULL::timestamptz),
  ('synthetic-scheduled-article', 'Synthetic scheduled article',
   'Invented text scheduled for 2099. It must not appear yet.',
   TIMESTAMPTZ '2099-01-01 00:00:00+00')
) AS v (slug, title, body, published_at)
WHERE NOT EXISTS (SELECT 1 FROM content.articles a WHERE a.slug = v.slug);

-- Membership fixtures (phase 3b): members, guardian links and registrations for the membership contract files. They RESET the rows
-- they own each time (tools/membership-contract.sh does it before a run), so a contract that changed a row is put back.
\ir membership-fixtures.sql

-- Geo rows (countries, postal codes, cities): one file shared with the PHP parity stack's MariaDB, so both sides
-- hold identical rows (tools/platform-contract.sh). It replaces the three geo tables' content, in schema platform.
SET search_path = platform, public;
\ir geo-fixtures.sql
RESET search_path;

-- The schema phase's tables (classes, assessment, notifications and the new platform, content and identity rows): one small coherent set
-- for the members above. Idempotent (fixed ids, ON CONFLICT DO NOTHING).
\ir schema-phase-fixtures.sql
