/*
 * Deletes the members a bulk add created in an earlier run (see classes-bulk-fixtures.sql). Loaded by tools/classes-contract.sh BEFORE every other classes fixture, because the write and enrolment fixtures
 * delete the bulk classes' enrolments, which is how these members are found: an email that is the member's own token plus @thestrongrope.com, a token of 900000 or above, on the roster of a class 9451 to 9469.
 */
CREATE TEMP TABLE bulk_created AS
SELECT u.id AS user_id, u.token
FROM identity.users u
WHERE u.token >= 900000 AND u.email = u.token || '@thestrongrope.com'
  AND u.token IN (SELECT token_no FROM classes.class_students WHERE class_id BETWEEN 9451 AND 9469);
DELETE FROM membership.member_profiles WHERE user_id IN (SELECT user_id FROM bulk_created);
DELETE FROM membership.class_registrations WHERE token IN (SELECT token FROM bulk_created);
DELETE FROM classes.class_students WHERE token_no IN (SELECT token FROM bulk_created);
DELETE FROM identity.users WHERE id IN (SELECT user_id FROM bulk_created);
DROP TABLE bulk_created;
