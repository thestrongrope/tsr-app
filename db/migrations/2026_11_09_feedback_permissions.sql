/*
 * Requested-by: Asif Shakir (issues 882, 891)
 * Reason: Members send feedback, and super admins review it, so the catalog needs both permissions
 *
 * EXPAND ONLY. Adds feedback:create:self (held by every registered member in code, like
 * the other :self permissions) and feedback:review:all with its role 1 grant. Safe
 * against live code: code that does not know the names never reads them.
 *
 * VERIFY. Must return two rows:
 *   SELECT name FROM permissions WHERE name LIKE 'feedback:%'
 *
 * TO UNDO. Roll forward only.
 */

INSERT INTO `permissions` (`name`, `description`) VALUES
('feedback:create:self', 'Send feedback to the team'),
('feedback:review:all', 'Review member feedback and mark items handled');

INSERT INTO `role_permissions` (`roleid`, `permission`)
SELECT 1, 'feedback:review:all'
WHERE NOT EXISTS (
  SELECT 1 FROM `role_permissions` WHERE `roleid` = 1 AND `permission` = 'feedback:review:all'
);
