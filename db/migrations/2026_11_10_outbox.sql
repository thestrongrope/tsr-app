/*
 * Requested-by: Asif Shakir (target architecture, Stage 1)
 * Reason: Domain events are written in the same transaction as the change, then relayed to Redis Streams
 *
 * EXPAND ONLY. Creates the outbox table. Owned by the platform, not by any one domain. Nothing
 * reads it until the relay (hosts/scheduler) exists; rows simply accumulate until then.
 * Payloads carry ids, never message text or other member content.
 *
 * VERIFY. Must return one row:
 *   SELECT table_name FROM information_schema.tables WHERE table_name = 'outbox'
 *
 * TO UNDO. Roll forward only.
 */

CREATE TABLE IF NOT EXISTS `outbox` (
  `id` CHAR(36) NOT NULL,
  `event_type` VARCHAR(100) NOT NULL,
  `payload` JSON NOT NULL,
  `created_at` DATETIME NOT NULL,
  `published_at` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_outbox_unpublished` (`published_at`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci;
