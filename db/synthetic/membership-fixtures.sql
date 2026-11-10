/*
 * The membership fixtures for the new API's database: the members, guardian links and class registrations the membership contract
 * files (domains/membership/spec/tests) use. tools/parity-php/membership-fixtures.sql holds the same rows for the PHP parity stack's
 * MariaDB, so one set of Hurl files sees one data set on both sides. Synthetic only: tokens 900201 to 900299, emails on .invalid.
 * Safe to run again: it RESETS every row it owns (a contract run that changed a link, a profile or a registration is put back).
 * Keyed by email, never by token: 900207 is held by two users on purpose (users.token is not unique). created_by and revoked_by are
 * looked up by email because user ids differ between the two sides. Dates are far past or far future so no clock can matter.
 *
 *   900201 to 900206  one member per gender form: '1', '2', 'Male', 'Female', '' and NULL
 *   900207 (twice)    two users sharing one token: gender '1' and NULL
 *   900211            parent.one: an active link (father) to 900212 and a revoked one (mother) to 900213; read only for the contract
 *   900212 to 900215  children: 900212 and 900213 above, 900214 a live invite (expires 2099), 900215 an expired invite (2000)
 *   900221 / 900222   registrations: 900221 two (first Pending, second Rejected) with 4 language skills and 2 interests; 900222 one Accepted;
 *                     900223 a copy of 900221 that registration-save.hurl changes (Hurl runs files in parallel, so no two files share a changed member)
 *   900231            accept.parent: accepts the invites of 900241 (five invites: three live codes c101 to c103) and 900242 (c104, with a revoked link
 *                     the child ended himself), and 900207 (c105, a child whose token is shared)
 *   900251 / 900252   revoke.parent and its active link to revoke.child
 *   900261 / 900262   prevoke.child and its active parent prevoke.parent
 *   900271 / 900272   profile.entity (entity-encoded name, city, picture) and profile.noname (empty name)
 *   900281            profile.patch: the member the PATCH contract changes
 */
INSERT INTO identity.users (token, email)
SELECT v.token, v.email
FROM (VALUES
  (900201, 'gender.one@example.invalid'),
  (900202, 'gender.two@example.invalid'),
  (900203, 'gender.male@example.invalid'),
  (900204, 'gender.female@example.invalid'),
  (900205, 'gender.empty@example.invalid'),
  (900206, 'gender.null@example.invalid'),
  (900207, 'shared.token.one@example.invalid'),
  (900207, 'shared.token.two@example.invalid'),
  (900211, 'parent.one@example.invalid'),
  (900212, 'child.active@example.invalid'),
  (900213, 'child.revoked@example.invalid'),
  (900214, 'child.invited@example.invalid'),
  (900215, 'child.expired@example.invalid'),
  (900221, 'registrant.duplicates@example.invalid'),
  (900222, 'registrant.single@example.invalid'),
  (900223, 'registrant.update@example.invalid'),
  (900231, 'accept.parent@example.invalid'),
  (900241, 'accept.child@example.invalid'),
  (900242, 'accept.child.removed@example.invalid'),
  (900251, 'revoke.parent@example.invalid'),
  (900252, 'revoke.child@example.invalid'),
  (900261, 'prevoke.child@example.invalid'),
  (900262, 'prevoke.parent@example.invalid'),
  (900271, 'profile.entity@example.invalid'),
  (900272, 'profile.noname@example.invalid'),
  (900281, 'profile.patch@example.invalid')
) AS v (token, email)
WHERE NOT EXISTS (SELECT 1 FROM identity.users u WHERE u.email = v.email);

INSERT INTO membership.member_profiles (user_id, name, picture, gender, mobile, country, state, city, zip, language)
SELECT u.id, v.name, v.picture, v.gender, v.mobile, v.country, v.state, v.city, v.zip, v.language
FROM (VALUES
  ('gender.one@example.invalid', 'Synthetic Gender One', NULL, '1', '+911234567801', 'Switzerland', 'Zürich', 'Zürich', '8001', 1),
  ('gender.two@example.invalid', 'Synthetic Gender Two', NULL, '2', '', NULL, NULL, NULL, NULL, 0),
  ('gender.male@example.invalid', 'Synthetic Gender Male', NULL, 'Male', '', NULL, NULL, NULL, NULL, 0),
  ('gender.female@example.invalid', 'Synthetic Gender Female', NULL, 'Female', '', NULL, NULL, NULL, NULL, 0),
  ('gender.empty@example.invalid', 'Synthetic Gender Empty', NULL, '', '', NULL, NULL, NULL, NULL, 0),
  ('gender.null@example.invalid', 'Synthetic Gender Null', NULL, NULL, '', NULL, NULL, NULL, NULL, 0),
  ('shared.token.one@example.invalid', 'Synthetic Shared One', NULL, '1', '', NULL, NULL, NULL, NULL, 0),
  ('shared.token.two@example.invalid', 'Synthetic Shared Two', NULL, NULL, '', NULL, NULL, NULL, NULL, 0),
  ('parent.one@example.invalid', 'Synthetic Parent One', NULL, '1', '', NULL, NULL, NULL, NULL, 0),
  ('child.active@example.invalid', 'Synthetic Child Active', NULL, '1', '', NULL, NULL, NULL, NULL, 0),
  ('child.revoked@example.invalid', 'Synthetic Child Revoked', NULL, '2', '', NULL, NULL, NULL, NULL, 0),
  ('child.invited@example.invalid', 'Synthetic Child Invited', NULL, '1', '', NULL, NULL, NULL, NULL, 0),
  ('child.expired@example.invalid', 'Synthetic Child Expired', NULL, '2', '', NULL, NULL, NULL, NULL, 0),
  ('registrant.duplicates@example.invalid', 'Synthetic Registrant Duplicates', NULL, '2', '', NULL, NULL, NULL, NULL, 0),
  ('registrant.single@example.invalid', 'Synthetic Registrant Single', NULL, '1', '', NULL, NULL, NULL, NULL, 0),
  ('registrant.update@example.invalid', 'Synthetic Registrant Update', NULL, '2', '', NULL, NULL, NULL, NULL, 0),
  ('accept.parent@example.invalid', 'Synthetic Accept Parent', NULL, '1', '', NULL, NULL, NULL, NULL, 0),
  ('accept.child@example.invalid', 'Synthetic Accept Child', NULL, '1', '', NULL, NULL, NULL, NULL, 0),
  ('accept.child.removed@example.invalid', 'Synthetic Accept Child Removed', NULL, '2', '', NULL, NULL, NULL, NULL, 0),
  ('revoke.parent@example.invalid', 'Synthetic Revoke Parent', NULL, '1', '', NULL, NULL, NULL, NULL, 0),
  ('revoke.child@example.invalid', 'Synthetic Revoke Child', NULL, '1', '', NULL, NULL, NULL, NULL, 0),
  ('prevoke.child@example.invalid', 'Synthetic Prevoke Child', NULL, '2', '', NULL, NULL, NULL, NULL, 0),
  ('prevoke.parent@example.invalid', 'Synthetic Prevoke Parent', NULL, '1', '', NULL, NULL, NULL, NULL, 0),
  ('profile.entity@example.invalid', 'O&#039;Brien &amp; Sons', 'https://example.invalid/a.png?x=1&amp;y=2', '1', '+911234567802', 'Switzerland', 'Z&#252;rich', 'St&#039;s', '8001', 2),
  ('profile.noname@example.invalid', '', '', NULL, '', NULL, NULL, NULL, NULL, 0),
  ('profile.patch@example.invalid', 'Synthetic Profile Patch', NULL, '1', '', NULL, NULL, NULL, NULL, 0)
) AS v (email, name, picture, gender, mobile, country, state, city, zip, language)
JOIN identity.users u ON u.email = v.email
ON CONFLICT (user_id) DO UPDATE SET
  name = excluded.name, picture = excluded.picture, gender = excluded.gender, mobile = excluded.mobile, country = excluded.country,
  state = excluded.state, city = excluded.city, zip = excluded.zip, language = excluded.language,
  first_name = NULL, last_name = NULL, age_range = NULL, sendupdates = 'N', unsubscribe = 'N';

-- The one member with a first name (the invite page shows it).
UPDATE membership.member_profiles SET first_name = 'Kidname'
WHERE user_id IN (SELECT id FROM identity.users WHERE email = 'child.invited@example.invalid');

DELETE FROM membership.user_guardians WHERE child_token BETWEEN 900201 AND 900299;
INSERT INTO membership.user_guardians
  (parent_token, child_token, relationship, status, source, code, expires_at, created_by, created_at, activated_at, revoked_by, revoked_at)
SELECT v.parent_token, v.child_token, v.relationship, v.status, v.source, v.code, v.expires_at,
       (SELECT id FROM identity.users WHERE email = v.created_by_email),
       TIMESTAMPTZ '2026-01-10 09:00:00+00', v.activated_at,
       (SELECT id FROM identity.users WHERE email = v.revoked_by_email), v.revoked_at
FROM (VALUES
  (900211, 900212, 'father', 'active', 'token_entry', NULL, NULL::timestamptz,
   'parent.one@example.invalid', TIMESTAMPTZ '2026-01-10 09:00:00+00', NULL, NULL::timestamptz),
  (900211, 900213, 'mother', 'revoked', 'token_entry', NULL, NULL::timestamptz,
   'parent.one@example.invalid', TIMESTAMPTZ '2026-01-10 09:00:00+00', 'parent.one@example.invalid', TIMESTAMPTZ '2026-01-11 09:00:00+00'),
  (NULL, 900214, NULL, 'invited', 'link', 'a1b2c3d4e5f60718293a4b5c6d7e8f01', TIMESTAMPTZ '2099-01-01 00:00:00+00',
   'child.invited@example.invalid', NULL, NULL, NULL::timestamptz),
  (NULL, 900215, NULL, 'invited', 'link', '0f8e7d6c5b4a39281706f5e4d3c2b1a0', TIMESTAMPTZ '2000-01-01 00:00:00+00',
   'child.expired@example.invalid', NULL, NULL, NULL::timestamptz),
  (NULL, 900241, NULL, 'invited', 'link', 'c1c1c1c1c1c1c1c1c1c1c1c1c1c1c101', TIMESTAMPTZ '2099-01-01 00:00:00+00',
   'accept.child@example.invalid', NULL, NULL, NULL::timestamptz),
  (NULL, 900241, NULL, 'invited', 'link', 'c1c1c1c1c1c1c1c1c1c1c1c1c1c1c102', TIMESTAMPTZ '2099-01-01 00:00:00+00',
   'accept.child@example.invalid', NULL, NULL, NULL::timestamptz),
  (NULL, 900241, NULL, 'invited', 'link', 'c1c1c1c1c1c1c1c1c1c1c1c1c1c1c103', TIMESTAMPTZ '2099-01-01 00:00:00+00',
   'accept.parent@example.invalid', NULL, NULL, NULL::timestamptz),
  (900231, 900242, 'father', 'revoked', 'token_entry', NULL, NULL::timestamptz,
   'accept.child.removed@example.invalid', TIMESTAMPTZ '2026-01-10 09:00:00+00', 'accept.child.removed@example.invalid', TIMESTAMPTZ '2026-01-11 09:00:00+00'),
  (NULL, 900242, NULL, 'invited', 'link', 'c1c1c1c1c1c1c1c1c1c1c1c1c1c1c104', TIMESTAMPTZ '2099-01-01 00:00:00+00',
   'accept.child.removed@example.invalid', NULL, NULL, NULL::timestamptz),
  (NULL, 900207, NULL, 'invited', 'link', 'c1c1c1c1c1c1c1c1c1c1c1c1c1c1c105', TIMESTAMPTZ '2099-01-01 00:00:00+00',
   'gender.one@example.invalid', NULL, NULL, NULL::timestamptz),
  (900251, 900252, 'mother', 'active', 'token_entry', NULL, NULL::timestamptz,
   'revoke.parent@example.invalid', TIMESTAMPTZ '2026-01-10 09:00:00+00', NULL, NULL::timestamptz),
  (900262, 900261, 'guardian', 'active', 'token_entry', NULL, NULL::timestamptz,
   'prevoke.parent@example.invalid', TIMESTAMPTZ '2026-01-10 09:00:00+00', NULL, NULL::timestamptz)
) AS v (parent_token, child_token, relationship, status, source, code, expires_at, created_by_email, activated_at, revoked_by_email, revoked_at);

-- Two registrations for 900221 (PHP's table holds duplicates per token; its fetch() takes the first, the Pending one).
DELETE FROM membership.class_registrations WHERE token BETWEEN 900201 AND 900299;
INSERT INTO membership.class_registrations
  (token, residence_location, work_location, preferred_location, birth_year, islamic_study_years, other_interests, education,
   field_of_study, occupation_type, years_experience, linkedin_url, status, status_reason, created_at)
SELECT v.token, v.residence_location, v.work_location, v.preferred_location, v.birth_year, v.islamic_study_years, v.other_interests,
       v.education, v.field_of_study::jsonb, v.occupation_type, v.years_experience, v.linkedin_url, v.status, v.status_reason,
       TIMESTAMPTZ '2026-01-10 09:00:00+00'
FROM (VALUES
  (900221, 'Zurich', 'Basel', 'Zurich, Online', 1990, 5, 'Calligraphy', 'Graduate (Bachelor''s Degree)',
   '["Law","Science"]', 'Salaried Professional', '3-5 years', 'https://www.linkedin.com/in/synthetic-person', 'Pending', NULL),
  (900221, NULL, NULL, 'Duplicate form', 1991, 1, NULL, NULL, NULL, NULL, NULL, NULL, 'Rejected', 'Synthetic duplicate'),
  (900222, 'Bern', NULL, 'Bern', 1985, 0, NULL, 'Not Applicable / Prefer not to say', '[]', NULL, NULL, NULL, 'Accepted', NULL),
  (900223, 'Zurich', 'Basel', 'Zurich, Online', 1990, 5, 'Calligraphy', 'Graduate (Bachelor''s Degree)',
   '["Law","Science"]', 'Salaried Professional', '3-5 years', 'https://www.linkedin.com/in/synthetic-person', 'Pending', NULL),
  (900223, NULL, NULL, 'Duplicate form', 1991, 1, NULL, NULL, NULL, NULL, NULL, NULL, 'Rejected', 'Synthetic duplicate')
) AS v (token, residence_location, work_location, preferred_location, birth_year, islamic_study_years, other_interests, education,
        field_of_study, occupation_type, years_experience, linkedin_url, status, status_reason);

DELETE FROM membership.class_registrations_languages WHERE token BETWEEN 900201 AND 900299;
INSERT INTO membership.class_registrations_languages (token, language, skill, proficiency) VALUES
  (900221, 'English', 'Read', 'Fluent'),
  (900221, 'English', 'Speak', 'Fluent'),
  (900221, 'Urdu', 'Read', 'Learning'),
  (900221, 'Arabic', 'Understand', 'Beginner'),
  (900223, 'English', 'Read', 'Fluent'),
  (900223, 'English', 'Speak', 'Fluent'),
  (900223, 'Urdu', 'Read', 'Learning'),
  (900223, 'Arabic', 'Understand', 'Beginner');

DELETE FROM membership.student_interests WHERE token BETWEEN 900201 AND 900299;
INSERT INTO membership.student_interests (token, interest_id) VALUES (900221, 11), (900221, 13), (900222, 9), (900223, 11), (900223, 13);
