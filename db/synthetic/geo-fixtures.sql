/*
 * Synthetic geo rows: countries, postal codes and cities, all invented or trivially public (a handful of
 * country and city names; no member data). ONE file, two databases: written in the SQL that both
 * PostgreSQL (the dev stack: db/synthetic/seed.sql includes it with search_path set to platform) and MariaDB
 * (the PHP parity stack: tools/platform-contract.sh parity pipes it in) accept, so the two sides hold exactly
 * these rows and the one Hurl contract (domains/platform/spec/tests/geo-*.hurl) runs against both.
 * No backslashes: MariaDB treats them as escapes in strings.
 * It REPLACES the three tables' content: synthetic dev and parity databases only, never production.
 *
 * What the rows are for (the cases are in the Hurl files):
 *   countries  accented and plain names sort together ("Aland" between Afghanistan and Albania; "Cote d'Ivoire" among C);
 *              has_postal_codes true and false
 *   postal     a plain code, a code with a space (full form stored, outward form stored, only the outward form stored),
 *              a lone "0", city or state NULL, city and state '' (stays ''), a code stored with a space (IE)
 *   cities     the same prefix at different populations; accented and plain names; a population tie (name breaks it);
 *              "%", "_" and "|" inside a name; "&amp;" and "&#039;" entities; state NULL and ''; the same name in
 *              three states; twelve names for the limit of 10
 */
DELETE FROM geo_cities;
DELETE FROM geo_postal_codes;
DELETE FROM geo_countries;

INSERT INTO geo_countries (code, name, has_postal_codes, postal_code_regex) VALUES
  ('AF', 'Afghanistan', FALSE, NULL),
  ('AX', 'Åland Islands', TRUE, NULL),
  ('AL', 'Albania', TRUE, NULL),
  ('CO', 'Colombia', FALSE, NULL),
  ('CI', 'Côte d''Ivoire', FALSE, NULL),
  ('CU', 'Cuba', FALSE, NULL),
  ('CH', 'Switzerland', TRUE, NULL),
  ('GB', 'United Kingdom', TRUE, '^[A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}$');

INSERT INTO geo_postal_codes (country_code, postal_code, city, state) VALUES
  ('CH', '8001', 'Zürich', 'Zürich'),
  ('CH', '0', 'Never looked up', 'Nowhere'),
  ('GB', 'SW1A', 'Westminster', 'England'),
  ('GB', 'EC1A 1BB', 'City of London', 'England'),
  ('GB', 'EC1A', 'Clerkenwell', 'England'),
  ('CA', 'M5V', 'Toronto', 'Ontario'),
  ('AL', '1001', 'Tirana', NULL),
  ('AL', '1002', NULL, 'Tirana County'),
  ('AL', '1003', '', ''),
  ('IE', 'D02 XY45', 'Dublin', 'Leinster');

INSERT INTO geo_cities (geoname_id, country_code, name, state, population) VALUES
  (1, 'CH', 'Zürich', 'Zürich', 400000),
  (2, 'CH', 'Zurich West', 'Zürich', 1000),
  (3, 'CH', 'Zug', 'Zug', 30000),
  (4, 'CH', 'Zürs', 'Vorarlberg', 100),
  (5, 'CH', 'Zell', 'Zürich', 500),
  (6, 'CH', 'Zeller', 'Zürich', 500),
  (10, 'DE', 'Köln', 'Nordrhein-Westfalen', 1000000),
  (11, 'DE', 'Kolbermoor', 'Bayern', 18000),
  (12, 'DE', 'Kassel', 'Hessen', 200000),
  (20, 'ZZ', '100% Pure', 'Alpha', 50),
  (21, 'ZZ', '100 Pure', 'Alpha', 40),
  (22, 'ZZ', 'a_b', 'Beta', 30),
  (23, 'ZZ', 'aXb', 'Beta', 20),
  (24, 'ZZ', 'Pipe|Town', 'Gamma', 10),
  (25, 'ZZ', 'Ben &amp; Jerry''s', 'Delta', 60),
  (26, 'ZZ', 'Rock &#039;n Roll', '', 70),
  (27, 'ZZ', 'Ottawa-Gatineau', NULL, 5),
  (30, 'US', 'Springfield', 'Illinois', 114000),
  (31, 'US', 'Springfield', 'Missouri', 169000),
  (32, 'US', 'Springfield', 'Massachusetts', 153000),
  (41, 'LM', 'Limit 01', 'State', 999),
  (42, 'LM', 'Limit 02', 'State', 998),
  (43, 'LM', 'Limit 03', 'State', 997),
  (44, 'LM', 'Limit 04', 'State', 996),
  (45, 'LM', 'Limit 05', 'State', 995),
  (46, 'LM', 'Limit 06', 'State', 994),
  (47, 'LM', 'Limit 07', 'State', 993),
  (48, 'LM', 'Limit 08', 'State', 992),
  (49, 'LM', 'Limit 09', 'State', 991),
  (50, 'LM', 'Limit 10', 'State', 990),
  (51, 'LM', 'Limit 11', 'State', 989),
  (52, 'LM', 'Limit 12', 'State', 988);
