/*
 * The membership B5D fixtures for the new API's database: what the contract file of GET /reports/registrations/allocated/download (the people placed in a class) reads. tools/parity-php/membership-b5d-fixtures.sql holds the same
 * rows for the PHP parity stack. Loaded by tools/membership-contract.sh after the B5B fixtures (it uses their classes 9561 gents, 9562 ladies and 9563 closed from the B4B fixtures); resets every row it owns by token and explicit id.
 * Synthetic only: tokens 902101 to 902199, emails b5d.<token>@example.invalid (or exactly <token>@thestrongrope.com for the placeholder), registrations 952101 and up, enrolments 952121 and up. Nothing here is changed by a file.
 *
 *   STAFF   902101 coordinator (role 5) assigned the class 9561 only
 *   PLACED  902111 gents in 9561, registered for 9561 (two forms; entity text, interests, extra students of the class)  902112 gents in 9561, open registration (for no class)  902113 ladies in 9562, registered for 9562
 *           902114 gents only in the CLOSED class 9563 (hidden)  902115 gents whose enrolment was removed (hidden)  902116 gender Male in 9561, open registration (listed with the gents)
 *           902117 gents in 9561 with the placeholder email (hidden)  902118 no gender in 9561 (hidden)
 *   The class 9561 gets two extra students (the file counts them).
 */
INSERT INTO identity.users (token, email)
SELECT v.token, 'b5d.' || v.token || '@example.invalid' FROM generate_series(902101, 902199) AS v (token)
WHERE v.token IN (902101, 902111, 902112, 902113, 902114, 902115, 902116, 902117, 902118)
  AND NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);
UPDATE identity.users SET email = 'b5d.' || token || '@example.invalid' WHERE token BETWEEN 902101 AND 902199 AND email <> 'b5d.' || token || '@example.invalid';
UPDATE identity.users SET email = '902117@thestrongrope.com' WHERE token = 902117;
UPDATE identity.users SET createdon = TIMESTAMPTZ '2025-02-10 09:30:00+00' WHERE token BETWEEN 902101 AND 902199;

INSERT INTO membership.member_profiles (user_id, name, gender, mobile, age_range, city, state, country, zip)
SELECT u.id, 'B5D Member ' || u.token,
       CASE WHEN u.token = 902113 THEN '2' WHEN u.token = 902116 THEN 'Male' WHEN u.token = 902118 THEN NULL ELSE '1' END,
       '+91000021' || right(u.token::text, 4), CASE WHEN u.token = 902113 THEN '2' ELSE '3' END, 'Pune', 'MH', 'India', '411001'
FROM identity.users u WHERE u.token BETWEEN 902101 AND 902199
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile, age_range = excluded.age_range, city = excluded.city, state = excluded.state, country = excluded.country, zip = excluded.zip;

DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 902101 AND 902199);
INSERT INTO access.user_roles (user_id, roleid) SELECT id, 5 FROM identity.users WHERE token = 902101;
DELETE FROM access.class_access_rule_conditions WHERE rule_id = 952101;
DELETE FROM access.class_access_rules WHERE id = 952101;
INSERT INTO access.class_access_rules (id, token, gender, note, created_at) VALUES (952101, 902101, 1, 'B5D level 3', now());
INSERT INTO access.class_access_rule_conditions (rule_id, field, negate, level_id) VALUES (952101, 'level', false, 3);

DELETE FROM membership.class_registrations WHERE token BETWEEN 902101 AND 902199;
DELETE FROM classes.class_students WHERE token_no BETWEEN 902101 AND 902199;
UPDATE classes.classes SET extra_students = E'Ali Extra\nBob Extra' WHERE id = 9561;

INSERT INTO membership.class_registrations (id, token, for_classid, preferred_location, residence_location, work_location, birth_year, profession, islamic_study_years, class_level, class_number, interests, other_interests, status, created_at, modified_at) VALUES
  (952101, 902111, 9561, 'B5D Pune', 'B5D Home', 'B5D Office', 1990, 'R &amp; D', 5, 'Primary', 'C1', 'Teaching,Research', 'Tafsir ,Seerah', 'Accepted', TIMESTAMPTZ '2025-03-01 10:00:00+00', TIMESTAMPTZ '2025-03-02 11:15:00+00'),
  (952102, 902111, NULL, NULL, NULL, NULL, 1991, NULL, NULL, NULL, NULL, NULL, NULL, 'Accepted', TIMESTAMPTZ '2025-03-03 10:00:00+00', NULL),
  (952103, 902112, NULL, 'B5D open', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Debates', NULL, 'Accepted', TIMESTAMPTZ '2025-03-04 10:00:00+00', NULL),
  (952104, 902113, 9562, 'B5D ladies', NULL, NULL, 1985, NULL, 2, NULL, NULL, NULL, '0', 'Accepted', TIMESTAMPTZ '2025-03-05 10:00:00+00', NULL),
  (952105, 902114, 9563, 'B5D closed', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Accepted', TIMESTAMPTZ '2025-03-06 10:00:00+00', NULL),
  (952106, 902115, NULL, 'B5D left', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Accepted', TIMESTAMPTZ '2025-03-07 10:00:00+00', NULL),
  (952107, 902116, NULL, 'B5D male', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Accepted', TIMESTAMPTZ '2025-03-08 10:00:00+00', NULL),
  (952108, 902117, 9561, 'B5D placeholder', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Accepted', TIMESTAMPTZ '2025-03-09 10:00:00+00', NULL),
  (952109, 902118, 9561, 'B5D no gender', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Accepted', TIMESTAMPTZ '2025-03-10 10:00:00+00', NULL);

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (952121, 9561, 902111, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (952122, 9561, 902112, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (952123, 9562, 902113, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (952124, 9563, 902114, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (952125, 9561, 902115, DATE '2025-09-02', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'B5D left', 901101, 'I'),
  (952126, 9561, 902116, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (952127, 9561, 902117, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (952128, 9561, 902118, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A');
UPDATE classes.class_students SET created_at = joined_on + TIME '08:00' AT TIME ZONE 'UTC' WHERE id BETWEEN 952121 AND 952128;
SELECT setval(pg_get_serial_sequence('classes.class_students', 'id'), greatest((SELECT max(id) FROM classes.class_students), 959199));
