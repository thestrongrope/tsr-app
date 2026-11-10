/*
 * Synthetic members and articles for local development and the contract tests. Every value is
 * invented: tokens in the 900000 range, emails on the reserved .invalid domain. Never add a real member.
 * Loaded by the dev stack's "seed" service after the migrations (docker-compose.dev.yml). Not a
 * migration: production runs migrations and must never get these rows. Safe to run again.
 *
 *   900001  member, gents      (default TSR_AUTH_VALUE of the contract tests)
 *   900002  member, ladies
 *   900003  super admin (roleid 1)
 *   0       a guest: never a member, so it can never sign in
 *
 * Articles, one of each kind. Invented text.
 *   published  public (published_at in the past)
 *   draft      not public (published_at NULL)
 *   scheduled  not public yet (published_at in 2099)
 */

INSERT INTO identity.users (token, roleid, gender, email)
SELECT v.token, v.roleid, v.gender, v.email
FROM (VALUES
  (900001, 0, 1::smallint, 'member.gents@example.invalid'),
  (900002, 0, 2::smallint, 'member.ladies@example.invalid'),
  (900003, 1, 1::smallint, 'super.admin@example.invalid'),
  (0, 0, NULL::smallint, 'guest@example.invalid')
) AS v (token, roleid, gender, email)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);

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
