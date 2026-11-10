/*
 * Requested-by: Asif Shakir (site spike, 2026-11-10)
 * Reason: The public site is built from the API; content owns the articles it shows.
 *
 * EXPAND ONLY. Creates the articles table, owned by the content domain. Nothing else reads or
 * writes it. An article is public only once published_at is set and not in the future.
 *
 * VERIFY. Must return one row:
 *   SELECT table_name FROM information_schema.tables WHERE table_name = 'articles'
 *
 * TO UNDO. Roll forward only.
 */

CREATE TABLE IF NOT EXISTS `articles` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `slug` VARCHAR(120) NOT NULL,
  `title` VARCHAR(200) NOT NULL,
  `body` TEXT NOT NULL,
  `published_at` DATETIME DEFAULT NULL COMMENT 'UTC; NULL is a draft',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_articles_slug` (`slug`),
  KEY `idx_articles_published` (`published_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci;
