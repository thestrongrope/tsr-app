/*
 * Requested-by: Asif Shakir (tsr-app sample)
 * Reason: The smallest slice of the production schema that the sample slices need
 *
 * SAMPLE BASELINE, NOT THE REAL ONE. Production's users table has many more columns. The real
 * schema-only baseline comes from tsr-account (open-source task C6) and replaces this file.
 * Column names and types match production for every column listed here.
 *
 * VERIFY. Must return four rows:
 *   SELECT table_name FROM information_schema.tables
 *    WHERE table_name IN ('users', 'permissions', 'role_permissions', 'user_permissions')
 *
 * TO UNDO. Roll forward only.
 */

CREATE TABLE IF NOT EXISTS `users` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `token` INT(11) NOT NULL DEFAULT 0,
  `roleid` INT(11) NOT NULL DEFAULT 0,
  `gender` TINYINT(4) DEFAULT NULL,
  `email` VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_users_token` (`token`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci;

CREATE TABLE IF NOT EXISTS `permissions` (
  `name` VARCHAR(100) NOT NULL,
  `description` VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci;

CREATE TABLE IF NOT EXISTS `role_permissions` (
  `roleid` INT(11) NOT NULL,
  `permission` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`roleid`, `permission`),
  CONSTRAINT `fk_role_permissions_permission` FOREIGN KEY (`permission`) REFERENCES `permissions` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci;

CREATE TABLE IF NOT EXISTS `user_permissions` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `user_id` INT(11) NOT NULL,
  `permission` VARCHAR(100) NOT NULL,
  `granted_by` INT(11) DEFAULT NULL,
  `granted_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `revoked_at` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_user_permissions_user` (`user_id`, `permission`),
  CONSTRAINT `fk_user_permissions_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_user_permissions_permission` FOREIGN KEY (`permission`) REFERENCES `permissions` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci;
