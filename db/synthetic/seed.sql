/*
 * Synthetic members for local development and the contract tests. Every value is invented:
 * tokens in the 900000 range, emails on the reserved .invalid domain. Never add a real member.
 * Loaded once by the dev database container after the migrations (docker-compose.dev.yml).
 *
 *   900001  member, gents      (default TSR_AUTH_VALUE of the contract tests)
 *   900002  member, ladies
 *   900003  super admin (roleid 1)
 *   0       a guest: never a member, so it can never sign in
 */

INSERT INTO `users` (`token`, `roleid`, `gender`, `email`) VALUES
(900001, 0, 1, 'member.gents@example.invalid'),
(900002, 0, 2, 'member.ladies@example.invalid'),
(900003, 1, 1, 'super.admin@example.invalid'),
(0, 0, NULL, 'guest@example.invalid');

/*
 * Synthetic articles for the content domain and the site spike: one of each kind. Invented text.
 *   published  public (published_at in the past)
 *   draft      not public (published_at NULL)
 *   scheduled  not public yet (published_at in 2099)
 */

INSERT INTO `articles` (`slug`, `title`, `body`, `published_at`) VALUES
('synthetic-published-article', 'Synthetic published article', 'Invented text for local development. It has two paragraphs.\n\nThis is the second paragraph, with <angle brackets> that the site must escape.', '2026-01-15 09:00:00'),
('synthetic-draft-article', 'Synthetic draft article', 'Invented draft text. It must never appear on the site.', NULL),
('synthetic-scheduled-article', 'Synthetic scheduled article', 'Invented text scheduled for 2099. It must not appear yet.', '2099-01-01 00:00:00');
