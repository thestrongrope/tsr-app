/*
 * Requested-by: Asif Shakir (issues 882, 883, 884)
 * Reason: A member sends feedback from the app, and a reviewer reads it later (issue 891)
 *
 * EXPAND ONLY. Creates the feedback table. Safe against live code: nothing reads or
 * writes it until the release that carries POST /feedback. user_id and handled_by are
 * INT(11) to match users.id. client_id is the app's UUID, and the unique key makes a
 * replay whose reply was lost return the stored row, not a second one.
 *
 * VERIFY. Must return one row:
 *   SELECT table_name FROM information_schema.tables WHERE table_name = 'feedback'
 *
 * TO UNDO. Roll forward only.
 */

CREATE TABLE IF NOT EXISTS `feedback` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `user_id` INT(11) DEFAULT NULL,
  `client_id` CHAR(36) NOT NULL,
  `message` TEXT NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `handled_at` DATETIME DEFAULT NULL,
  `handled_by` INT(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_feedback_user_client` (`user_id`, `client_id`),
  KEY `idx_feedback_handled_created` (`handled_at`, `created_at`),
  CONSTRAINT `fk_feedback_handled_by` FOREIGN KEY (`handled_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_feedback_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci;
