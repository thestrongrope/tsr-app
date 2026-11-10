/*
 * The membership fixtures for the PHP parity stack's MariaDB (tools/parity-php/membership-fixtures.sh loads it): the same members
 * and rows as the db/synthetic/membership-fixtures.sql, so one Hurl contract sees one data set on both sides.
 * Synthetic only: tokens 900201 and up, emails on .invalid. Safe to run again: it RESETS every row it owns (a contract run
 * that changed a link or a registration is put back). 900207 is held by two users on purpose (users.token is not unique).
 * created_by and revoked_by are users.id, looked up by email, because ids differ between the two sides.
 */
INSERT INTO users (token, email, roleid, provider, createdon)
SELECT v.token, v.email, 0, 'firebase', NOW() FROM (
  SELECT 900201 AS token, 'gender.one@example.invalid' AS email UNION ALL
  SELECT 900202, 'gender.two@example.invalid' UNION ALL
  SELECT 900203, 'gender.male@example.invalid' UNION ALL
  SELECT 900204, 'gender.female@example.invalid' UNION ALL
  SELECT 900205, 'gender.empty@example.invalid' UNION ALL
  SELECT 900206, 'gender.null@example.invalid' UNION ALL
  SELECT 900207, 'shared.token.one@example.invalid' UNION ALL
  SELECT 900207, 'shared.token.two@example.invalid' UNION ALL
  SELECT 900211, 'parent.one@example.invalid' UNION ALL
  SELECT 900212, 'child.active@example.invalid' UNION ALL
  SELECT 900213, 'child.revoked@example.invalid' UNION ALL
  SELECT 900214, 'child.invited@example.invalid' UNION ALL
  SELECT 900215, 'child.expired@example.invalid' UNION ALL
  SELECT 900221, 'registrant.duplicates@example.invalid' UNION ALL
  SELECT 900222, 'registrant.single@example.invalid' UNION ALL
  SELECT 900223, 'registrant.update@example.invalid' UNION ALL
  SELECT 900231, 'accept.parent@example.invalid' UNION ALL
  SELECT 900241, 'accept.child@example.invalid' UNION ALL
  SELECT 900242, 'accept.child.removed@example.invalid' UNION ALL
  SELECT 900251, 'revoke.parent@example.invalid' UNION ALL
  SELECT 900252, 'revoke.child@example.invalid' UNION ALL
  SELECT 900261, 'prevoke.child@example.invalid' UNION ALL
  SELECT 900262, 'prevoke.parent@example.invalid' UNION ALL
  SELECT 900271, 'profile.entity@example.invalid' UNION ALL
  SELECT 900272, 'profile.noname@example.invalid' UNION ALL
  SELECT 900281, 'profile.patch@example.invalid') v
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.email = v.email);

UPDATE users u JOIN (
  SELECT 'gender.one@example.invalid' AS email, 'Synthetic Gender One' AS name, NULL AS picture, '1' AS gender, '+911234567801' AS mobile, 'Switzerland' AS country, 'Zürich' AS state, 'Zürich' AS city, '8001' AS zip, 1 AS language UNION ALL
  SELECT 'gender.two@example.invalid', 'Synthetic Gender Two', NULL, '2', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'gender.male@example.invalid', 'Synthetic Gender Male', NULL, 'Male', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'gender.female@example.invalid', 'Synthetic Gender Female', NULL, 'Female', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'gender.empty@example.invalid', 'Synthetic Gender Empty', NULL, '', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'gender.null@example.invalid', 'Synthetic Gender Null', NULL, NULL, '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'shared.token.one@example.invalid', 'Synthetic Shared One', NULL, '1', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'shared.token.two@example.invalid', 'Synthetic Shared Two', NULL, NULL, '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'parent.one@example.invalid', 'Synthetic Parent One', NULL, '1', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'child.active@example.invalid', 'Synthetic Child Active', NULL, '1', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'child.revoked@example.invalid', 'Synthetic Child Revoked', NULL, '2', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'child.invited@example.invalid', 'Synthetic Child Invited', NULL, '1', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'child.expired@example.invalid', 'Synthetic Child Expired', NULL, '2', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'registrant.duplicates@example.invalid', 'Synthetic Registrant Duplicates', NULL, '2', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'registrant.single@example.invalid', 'Synthetic Registrant Single', NULL, '1', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'registrant.update@example.invalid', 'Synthetic Registrant Update', NULL, '2', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'accept.parent@example.invalid', 'Synthetic Accept Parent', NULL, '1', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'accept.child@example.invalid', 'Synthetic Accept Child', NULL, '1', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'accept.child.removed@example.invalid', 'Synthetic Accept Child Removed', NULL, '2', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'revoke.parent@example.invalid', 'Synthetic Revoke Parent', NULL, '1', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'revoke.child@example.invalid', 'Synthetic Revoke Child', NULL, '1', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'prevoke.child@example.invalid', 'Synthetic Prevoke Child', NULL, '2', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'prevoke.parent@example.invalid', 'Synthetic Prevoke Parent', NULL, '1', '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'profile.entity@example.invalid', 'O&#039;Brien &amp; Sons', 'https://example.invalid/a.png?x=1&amp;y=2', '1', '+911234567802', 'Switzerland', 'Z&#252;rich', 'St&#039;s', '8001', 2 UNION ALL
  SELECT 'profile.noname@example.invalid', '', '', NULL, '', NULL, NULL, NULL, NULL, 0 UNION ALL
  SELECT 'profile.patch@example.invalid', 'Synthetic Profile Patch', NULL, '1', '', NULL, NULL, NULL, NULL, 0) p ON p.email = u.email
SET u.name = p.name, u.picture = p.picture, u.gender = p.gender, u.mobile = p.mobile, u.country = p.country, u.state = p.state, u.city = p.city,
    u.zip = p.zip, u.language = p.language, u.first_name = NULL, u.last_name = NULL, u.age_range = NULL, u.sendupdates = 'N', u.unsubscribe = 'N';

-- The one member with a first name (the invite page shows it).
UPDATE users SET first_name = 'Kidname' WHERE email = 'child.invited@example.invalid';

DELETE FROM user_guardians WHERE child_token BETWEEN 900201 AND 900299;
INSERT INTO user_guardians (parent_token, child_token, relationship, status, source, code, expires_at, created_by, created_at, activated_at, revoked_by, revoked_at)
SELECT v.parent_token, v.child_token, v.relationship, v.status, v.source, v.code, v.expires_at,
       (SELECT id FROM users WHERE email = v.created_by_email), '2026-01-10 09:00:00', v.activated_at,
       (SELECT id FROM users WHERE email = v.revoked_by_email), v.revoked_at
FROM (
  SELECT 900211 AS parent_token, 900212 AS child_token, 'father' AS relationship, 'active' AS status, 'token_entry' AS source, NULL AS code, NULL AS expires_at, 'parent.one@example.invalid' AS created_by_email, '2026-01-10 09:00:00' AS activated_at, NULL AS revoked_by_email, NULL AS revoked_at UNION ALL
  SELECT 900211, 900213, 'mother', 'revoked', 'token_entry', NULL, NULL, 'parent.one@example.invalid', '2026-01-10 09:00:00', 'parent.one@example.invalid', '2026-01-11 09:00:00' UNION ALL
  SELECT NULL, 900214, NULL, 'invited', 'link', 'a1b2c3d4e5f60718293a4b5c6d7e8f01', '2099-01-01 00:00:00', 'child.invited@example.invalid', NULL, NULL, NULL UNION ALL
  SELECT NULL, 900215, NULL, 'invited', 'link', '0f8e7d6c5b4a39281706f5e4d3c2b1a0', '2000-01-01 00:00:00', 'child.expired@example.invalid', NULL, NULL, NULL UNION ALL
  SELECT NULL, 900241, NULL, 'invited', 'link', 'c1c1c1c1c1c1c1c1c1c1c1c1c1c1c101', '2099-01-01 00:00:00', 'accept.child@example.invalid', NULL, NULL, NULL UNION ALL
  SELECT NULL, 900241, NULL, 'invited', 'link', 'c1c1c1c1c1c1c1c1c1c1c1c1c1c1c102', '2099-01-01 00:00:00', 'accept.child@example.invalid', NULL, NULL, NULL UNION ALL
  SELECT NULL, 900241, NULL, 'invited', 'link', 'c1c1c1c1c1c1c1c1c1c1c1c1c1c1c103', '2099-01-01 00:00:00', 'accept.parent@example.invalid', NULL, NULL, NULL UNION ALL
  SELECT 900231, 900242, 'father', 'revoked', 'token_entry', NULL, NULL, 'accept.child.removed@example.invalid', '2026-01-10 09:00:00', 'accept.child.removed@example.invalid', '2026-01-11 09:00:00' UNION ALL
  SELECT NULL, 900242, NULL, 'invited', 'link', 'c1c1c1c1c1c1c1c1c1c1c1c1c1c1c104', '2099-01-01 00:00:00', 'accept.child.removed@example.invalid', NULL, NULL, NULL UNION ALL
  SELECT NULL, 900207, NULL, 'invited', 'link', 'c1c1c1c1c1c1c1c1c1c1c1c1c1c1c105', '2099-01-01 00:00:00', 'gender.one@example.invalid', NULL, NULL, NULL UNION ALL
  SELECT 900251, 900252, 'mother', 'active', 'token_entry', NULL, NULL, 'revoke.parent@example.invalid', '2026-01-10 09:00:00', NULL, NULL UNION ALL
  SELECT 900262, 900261, 'guardian', 'active', 'token_entry', NULL, NULL, 'prevoke.parent@example.invalid', '2026-01-10 09:00:00', NULL, NULL) v;

DELETE FROM class_registrations WHERE token BETWEEN 900201 AND 900299;
INSERT INTO class_registrations (token, residence_location, work_location, preferred_location, birth_year, islamic_study_years, other_interests, education,
   field_of_study, occupation_type, years_experience, linkedin_url, status, status_reason, created_at)
VALUES
  (900221, 'Zurich', 'Basel', 'Zurich, Online', 1990, 5, 'Calligraphy', 'Graduate (Bachelor''s Degree)',
   '["Law","Science"]', 'Salaried Professional', '3-5 years', 'https://www.linkedin.com/in/synthetic-person', 'Pending', NULL, '2026-01-10 09:00:00'),
  (900221, NULL, NULL, 'Duplicate form', 1991, 1, NULL, NULL, NULL, NULL, NULL, NULL, 'Rejected', 'Synthetic duplicate', '2026-01-10 09:00:00'),
  (900222, 'Bern', NULL, 'Bern', 1985, 0, NULL, 'Not Applicable / Prefer not to say', '[]', NULL, NULL, NULL, 'Accepted', NULL, '2026-01-10 09:00:00'),
  (900223, 'Zurich', 'Basel', 'Zurich, Online', 1990, 5, 'Calligraphy', 'Graduate (Bachelor''s Degree)',
   '["Law","Science"]', 'Salaried Professional', '3-5 years', 'https://www.linkedin.com/in/synthetic-person', 'Pending', NULL, '2026-01-10 09:00:00'),
  (900223, NULL, NULL, 'Duplicate form', 1991, 1, NULL, NULL, NULL, NULL, NULL, NULL, 'Rejected', 'Synthetic duplicate', '2026-01-10 09:00:00');

DELETE FROM class_registrations_languages WHERE token BETWEEN 900201 AND 900299;
INSERT INTO class_registrations_languages (token, language, skill, proficiency) VALUES
  (900221, 'English', 'Read', 'Fluent'),
  (900221, 'English', 'Speak', 'Fluent'),
  (900221, 'Urdu', 'Read', 'Learning'),
  (900221, 'Arabic', 'Understand', 'Beginner'),
  (900223, 'English', 'Read', 'Fluent'),
  (900223, 'English', 'Speak', 'Fluent'),
  (900223, 'Urdu', 'Read', 'Learning'),
  (900223, 'Arabic', 'Understand', 'Beginner');

DELETE FROM student_interests WHERE token BETWEEN 900201 AND 900299;
INSERT INTO student_interests (token, interest_id) VALUES (900221, 11), (900221, 13), (900222, 9), (900223, 11), (900223, 13);
