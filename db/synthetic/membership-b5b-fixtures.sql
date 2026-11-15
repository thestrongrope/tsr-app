/*
 * The membership B5b fixtures for the new API's database: what the contract file of GET /reports/registrations (the waiting list) and the student card read. tools/parity-php/membership-b5b-fixtures.sql holds the same
 * rows for the PHP parity stack. Loaded by tools/membership-contract.sh after the B4b fixtures (it names their classes 9561 to 9563); resets every row it owns by token and explicit id. Synthetic only: tokens 901801 to
 * 901899, emails b5b.<token>@example.invalid (or exactly <token>@thestrongrope.com for the placeholder form), registrations 951501 and up, enrolments 951521 and up. Nothing here is changed by a file.
 *
 *   STAFF   901801 super administrator (role 1)  901802 gents administrator (role 3)  901803 ladies administrator (role 4)  901804 plain member
 *   WAITING 901811 gents, two forms (Pending for 9561 then Accepted: the status shown is the greatest text, Pending)  901812 gents, Rejected then Pending (hidden)  901813 gents in the active class 9561 (hidden)
 *           901814 ladies for 9562  901815 gents, placeholder email (hidden)  901816 gents for the CLOSED class 9563 (listed, no requested class)  901817 gents whose enrolment was removed (listed)
 *           901818 gender Male (in neither list)  901819 gents for a class that is gone (listed, no requested class), entity text and empty mobile
 */
INSERT INTO identity.users (token, email)
SELECT v.token, 'b5b.' || v.token || '@example.invalid' FROM generate_series(901801, 901899) AS v (token)
WHERE v.token IN (901801, 901802, 901803, 901804, 901811, 901812, 901813, 901814, 901815, 901816, 901817, 901818, 901819)
  AND NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.token = v.token);
UPDATE identity.users SET email = 'b5b.' || token || '@example.invalid' WHERE token BETWEEN 901801 AND 901899 AND email <> 'b5b.' || token || '@example.invalid';
UPDATE identity.users SET email = '901815@thestrongrope.com' WHERE token = 901815;
UPDATE identity.users SET createdon = TIMESTAMPTZ '2025-01-15 10:00:00+00' WHERE token BETWEEN 901801 AND 901899;

INSERT INTO membership.member_profiles (user_id, name, gender, mobile, city, state, country, zip)
SELECT u.id, 'B5B Member ' || u.token,
       CASE WHEN u.token IN (901803, 901814) THEN '2' WHEN u.token = 901818 THEN 'Male' ELSE '1' END,
       '+91000018' || right(u.token::text, 4), 'Pune', 'MH', 'India', '411001'
FROM identity.users u WHERE u.token BETWEEN 901801 AND 901899
ON CONFLICT (user_id) DO UPDATE SET name = excluded.name, gender = excluded.gender, mobile = excluded.mobile, city = excluded.city, state = excluded.state, country = excluded.country, zip = excluded.zip;
UPDATE membership.member_profiles SET mobile = '' WHERE user_id IN (SELECT id FROM identity.users WHERE token = 901819);

DELETE FROM access.user_roles WHERE user_id IN (SELECT id FROM identity.users WHERE token BETWEEN 901801 AND 901899);
INSERT INTO access.user_roles (user_id, roleid) SELECT u.id, CASE u.token WHEN 901801 THEN 1 WHEN 901802 THEN 3 ELSE 4 END FROM identity.users u WHERE u.token IN (901801, 901802, 901803);

DELETE FROM membership.class_registrations WHERE token BETWEEN 901801 AND 901899;
DELETE FROM classes.class_students WHERE token_no BETWEEN 901801 AND 901899;

INSERT INTO membership.class_registrations (id, token, for_classid, preferred_location, residence_location, birth_year, profession, islamic_study_years, class_level, status, created_at) VALUES
  (951501, 901811, 9561, 'B5B Pune &amp; Co', 'B5B Home', 1990, 'Engineer', 5, 'Primary', 'Pending', TIMESTAMPTZ '2025-04-01 10:00:00+00'),
  (951502, 901811, NULL, NULL, NULL, 1991, NULL, NULL, NULL, 'Accepted', TIMESTAMPTZ '2025-04-03 10:00:00+00'),
  (951503, 901812, NULL, 'B5B rejected', NULL, NULL, NULL, NULL, NULL, 'Rejected', TIMESTAMPTZ '2025-04-02 10:00:00+00'),
  (951504, 901812, NULL, 'B5B pending', NULL, NULL, NULL, NULL, NULL, 'Pending', TIMESTAMPTZ '2025-04-04 10:00:00+00'),
  (951505, 901813, NULL, 'B5B enrolled', NULL, NULL, NULL, NULL, NULL, 'Pending', TIMESTAMPTZ '2025-04-05 10:00:00+00'),
  (951506, 901814, 9562, 'B5B ladies', NULL, 1985, NULL, 2, NULL, 'Pending', TIMESTAMPTZ '2025-04-06 10:00:00+00'),
  (951507, 901815, NULL, 'B5B placeholder', NULL, NULL, NULL, NULL, NULL, 'Pending', TIMESTAMPTZ '2025-04-07 10:00:00+00'),
  (951508, 901816, 9563, 'B5B closed class', NULL, NULL, NULL, NULL, NULL, 'Pending', TIMESTAMPTZ '2025-05-01 10:00:00+00'),
  (951509, 901817, NULL, 'B5B left', NULL, NULL, NULL, NULL, NULL, 'Pending', TIMESTAMPTZ '2025-04-02 12:00:00+00'),
  (951510, 901818, NULL, 'B5B male', NULL, NULL, NULL, NULL, NULL, 'Pending', TIMESTAMPTZ '2025-04-08 10:00:00+00'),
  (951511, 901819, 99999999, 'B5B gone class', NULL, NULL, 'Tom &amp; Jerry', NULL, NULL, 'Pending', TIMESTAMPTZ '2025-04-09 10:00:00+00');

INSERT INTO classes.class_students (id, class_id, token_no, joined_on, mcq_admin, removed_at, removed_reason, removed_by, status) VALUES
  (951521, 9561, 901813, DATE '2025-09-02', 0, NULL, NULL, NULL, 'A'),
  (951522, 9561, 901817, DATE '2025-09-02', 0, TIMESTAMPTZ '2025-10-01 00:00:00+00', 'B5B left', 901101, 'I');
UPDATE classes.class_students SET created_at = joined_on + TIME '08:00' AT TIME ZONE 'UTC' WHERE id IN (951521, 951522);
SELECT setval(pg_get_serial_sequence('classes.class_students', 'id'), greatest((SELECT max(id) FROM classes.class_students), 959199));
