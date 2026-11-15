/* Deletes the members a bulk add created in an earlier run: the same as db/synthetic/classes-bulk-cleanup.sql, for the PHP parity stack. Loaded by tools/classes-contract.sh before every other classes fixture. */
DROP TEMPORARY TABLE IF EXISTS bulk_created;
CREATE TEMPORARY TABLE bulk_created AS
SELECT u.token FROM users u
WHERE u.token >= 900000 AND u.email = CONCAT(u.token, '@thestrongrope.com')
  AND u.token IN (SELECT token_no FROM class_students WHERE class_id BETWEEN 9451 AND 9469);
DELETE FROM class_registrations WHERE token IN (SELECT token FROM bulk_created);
DELETE FROM class_students WHERE token_no IN (SELECT token FROM bulk_created);
DELETE FROM users WHERE token IN (SELECT token FROM bulk_created);
DROP TEMPORARY TABLE bulk_created;
