/*
 * The geo rows tsr-account's Patrol persona journey persona_member_location_test.dart reads, and nothing more: India and three of
 * its postal codes with the state and city GeoNames (CC BY 4.0) gives for them. Public place data, no member data.
 * Loaded by tools/patrol-lane.sh reset-personas into a Patrol lane's PostgreSQL, with search_path set to platform.
 * A file of its own, NOT part of geo-fixtures.sql: the platform contract (geo-countries.hurl) pins that file's exact country
 * list on both sides, and India would change it. Re-runnable: it replaces only its own rows.
 *   411001  the persona member's saved code (Pune), so State and City open locked
 *   110001  Delhi / New Delhi
 *   400001  Maharashtra / Mumbai
 * 999999 is deliberately absent: the journey expects "we do not have that postal code".
 */
DELETE FROM geo_postal_codes WHERE country_code = 'IN';
DELETE FROM geo_countries WHERE code = 'IN';

INSERT INTO geo_countries (code, name, has_postal_codes, postal_code_regex) VALUES
  ('IN', 'India', TRUE, '^(\d{6})$');

INSERT INTO geo_postal_codes (country_code, postal_code, city, state) VALUES
  ('IN', '411001', 'Pune', 'Maharashtra'),
  ('IN', '110001', 'New Delhi', 'Delhi'),
  ('IN', '400001', 'Mumbai', 'Maharashtra');
