# Phase 3a collation proof (2026-11-10)

Question: can ONE ICU collation that ignores case and accents carry what the geo operations need on the
dev stack's PostgreSQL, replacing MariaDB's `utf8mb4_unicode_520_ci`? Needs: (1) equality (postal code),
(2) prefix search with LIKE escaping (cities), (3) `ORDER BY` (countries, cities), (4) a usable index.

**Result: yes, all four. Use `create collation geo_ci_ai (provider = icu, locale = 'und-u-ks-level1', deterministic = false)`.**
Not proven, and not needed: `ILIKE`, regular expressions and `starts_with()` (refused, see 2).

## 0. What was checked first

- Image: `postgres:18` (the dev stack's db service), `PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2)`. ICU is there:
  `select count(*) from pg_collation where collprovider = 'i'` gives 871, and `icu_unicode_version()` is 16.0.
  The database itself uses `libc` `en_US.utf8`; the collation is per column, so that does not matter.
- PostgreSQL 18 documentation, read from postgresql.org/docs/18 (`collation.html` section 23.2.2.4, `functions-matching.html`):
  - "LIKE pattern matching supports nondeterministic collations" (new in 18; older versions refuse it).
  - "ILIKE ... does not support nondeterministic collations"; "SIMILAR TO and POSIX-style regular expressions do not support nondeterministic collations".
  - "B-tree cannot use deduplication with indexes that use a nondeterministic collation" (a size and speed cost, not a failure).
  - The docs' own examples use `und-u-ks-level2` (ignore case only) and `und-u-ks-level1-kc-true`. `und-u-ks-level1`
    is the primary strength: base letters only, so case AND accents are ignored.
- Everything below ran in a transaction that was rolled back (`BEGIN ... ROLLBACK`), in a scratch schema `proof`, on the
  dev database; nothing was left behind.

## 1 to 3. Behaviour (SQL A and Output A below)

Findings:

| Need | Result |
|---|---|
| Equality | `'zurich' = 'Zürich'` true, `'Zurich' = 'zürich'` true, `'ß' = 'ss'` true; under the default collation the first is false. Postal code `D02 XY45` finds the stored `d02 xy45`; `sw1a` finds `SW1A`. |
| Prefix search with escaping | `like 'zur%' escape '|'` finds `Zürich`, `Zurich West`, `Zürs`; `100|%%` finds only `100% Pure` (the `%` is literal); `a|_b%` finds only `a_b`, not `aXb`; `pipe||%` finds `Pipe|Town`; `kol%` finds `Köln` and `Koln`. This is exactly the PHP query shape (`escape '|'`, `|` escaped first). |
| ORDER BY | `Åland Islands` sorts between Afghanistan and Albania and `Côte d'Ivoire` between Costa Rica and Cuba, as MariaDB sorts them; the same list under `"C"` puts them at the end. |
| Differences from MariaDB (known) | A trailing space is NOT ignored (`'Zurich' = 'Zurich '` is false; MariaDB's PAD SPACE says true). The API trims input before every lookup and stores no trailing spaces, so this is not reachable. Level-equal names (`Köln`/`Koln`) have no defined order between them, on either engine; tests avoid such ties. |
| Not supported (as documented) | `ILIKE`, `~`, `starts_with()` raise "nondeterministic collations are not supported ..."; the slices use `LIKE` only. |

## 4. Index, at the real size (SQL B, Output B)

171,000 cities (30,000 of them in one country), 1,100,000 postal codes, 250 countries:

- Postal equality: `Index Scan using postal_pkey` on the composite primary key `(country_code, postal_code)`, 0.03 ms.
- Countries `ORDER BY name`: `Index Scan using idx_countries_name`, no sort node. Equality on the name column also uses the index.
- Cities prefix search: the index on `(country_code, name)` narrows to the country (`Bitmap Index Scan`), the `LIKE` is then a
  filter, and the sort is top-N: 12 ms for the largest country at 30,000 rows. A btree cannot answer a prefix range under a
  nondeterministic collation, so the search is a scan of one country's rows; at the real data size that is acceptable (the
  slice is limited to 10 rows and rate limited to 60 a minute per member). If that ever hurts, the options are a trigram index
  or a normalised search column; neither is needed now.

## SQL A (behaviour)

```sql
\set ON_ERROR_STOP on
\pset format aligned
begin;
create schema proof;
create collation proof.geo_ci_ai (provider = icu, locale = 'und-u-ks-level1', deterministic = false);

-- 1. what the collation considers equal
select 'zurich' = 'Zürich' collate proof.geo_ci_ai as accent_and_case_equal,
       'Zurich' = 'zürich' collate proof.geo_ci_ai as case_and_accent_equal,
       'Zurich' = 'Zurich ' collate proof.geo_ci_ai as trailing_space_equal,
       'e' = 'è' collate proof.geo_ci_ai as e_grave,
       'o' = 'ö' collate proof.geo_ci_ai as o_umlaut,
       'ss' = 'ß' collate proof.geo_ci_ai as sharp_s,
       'zurich' = 'Zürich' as default_collation_equal;

create table proof.countries (code char(2) primary key, name text collate proof.geo_ci_ai not null);
insert into proof.countries values ('AF','Afghanistan'),('AX','Åland Islands'),('AL','Albania'),('CO','Colombia'),('CR','Costa Rica'),('CI','Côte d''Ivoire'),('CU','Cuba'),('ZA','South Africa'),('ZM','Zambia');

-- 2. ORDER BY: accented names sort among plain ones
select code, name from proof.countries order by name;
select 'ordinal (C) order for contrast' as note, string_agg(name, ', ' order by name collate "C") from proof.countries;

create table proof.postal (country_code text not null, postal_code text collate proof.geo_ci_ai not null, city text, primary key (country_code, postal_code));
insert into proof.postal values ('CH','8001','Zurich'),('GB','SW1A','Westminster'),('PL','00-950','Warszawa'),('IE','d02 xy45','Dublin'),('CA','K1A','Ottawa');
-- 3. equality (postal code, case-insensitive)
select * from proof.postal where country_code = 'IE' and postal_code = 'D02 XY45';
select * from proof.postal where country_code = 'GB' and postal_code = 'sw1a';

create table proof.cities (geoname_id int primary key, country_code text not null, name text collate proof.geo_ci_ai not null, state text, population int not null default 0);
insert into proof.cities values
 (1,'CH','Zürich','ZH',400000),(2,'CH','Zurich West','ZH',1000),(3,'CH','Zug','ZG',30000),(4,'CH','Zürs','VO',100),
 (5,'XX','100% Pure','A',5),(6,'XX','100 Pure','A',4),(7,'XX','a_b','A',3),(8,'XX','aXb','A',2),(9,'XX','Pipe|Town','A',1),
 (10,'XX','Köln','NW',1000000),(11,'XX','Koln','NW',10),(12,'XX','Cologne','NW',5);

-- 4. prefix search with LIKE-style escaping, ESCAPE '|' as the PHP does
select name from proof.cities where country_code='CH' and name like 'zur%' escape '|' order by population desc, name limit 10;
select name from proof.cities where country_code='CH' and name like 'zür%' escape '|' order by population desc, name;
select name from proof.cities where country_code='XX' and name like '100|%%' escape '|' order by population desc, name;
select name from proof.cities where country_code='XX' and name like 'a|_b%' escape '|' order by population desc, name;
select name from proof.cities where country_code='XX' and name like 'pipe||%' escape '|' order by population desc, name;
select name from proof.cities where country_code='XX' and name like 'kol%' escape '|' order by population desc, name;
select name from proof.cities where country_code='XX' and name like 'koln%' escape '|' order by population desc, name;
-- the wildcard is literal when escaped: 'a|_b%' must NOT match 'aXb'
select count(*) as should_be_1 from proof.cities where country_code='XX' and name like 'a|_b%' escape '|';
-- what the docs say is NOT supported: ILIKE and regex
do $$ begin
  begin perform 1 from proof.cities where name ilike 'zur%'; raise notice 'ILIKE ok'; exception when others then raise notice 'ILIKE: %', sqlerrm; end;
  begin perform 1 from proof.cities where name ~ '^zur'; raise notice 'regex ok'; exception when others then raise notice 'regex: %', sqlerrm; end;
  begin perform 1 from proof.cities where starts_with(name, 'zur'); raise notice 'starts_with ok'; exception when others then raise notice 'starts_with: %', sqlerrm; end;
end $$;
rollback;
```

## Output A

```
Output format is aligned.
BEGIN
CREATE SCHEMA
CREATE COLLATION
 accent_and_case_equal | case_and_accent_equal | trailing_space_equal | e_grave | o_umlaut | sharp_s | default_collation_equal 
-----------------------+-----------------------+----------------------+---------+----------+---------+-------------------------
 t                     | t                     | f                    | t       | t        | t       | f
(1 row)

CREATE TABLE
INSERT 0 9
 code |     name      
------+---------------
 AF   | Afghanistan
 AX   | Åland Islands
 AL   | Albania
 CO   | Colombia
 CR   | Costa Rica
 CI   | Côte d'Ivoire
 CU   | Cuba
 ZA   | South Africa
 ZM   | Zambia
(9 rows)

              note              |                                              string_agg                                              
--------------------------------+------------------------------------------------------------------------------------------------------
 ordinal (C) order for contrast | Afghanistan, Albania, Colombia, Costa Rica, Cuba, Côte d'Ivoire, South Africa, Zambia, Åland Islands
(1 row)

CREATE TABLE
INSERT 0 5
 country_code | postal_code |  city  
--------------+-------------+--------
 IE           | d02 xy45    | Dublin
(1 row)

 country_code | postal_code |    city     
--------------+-------------+-------------
 GB           | SW1A        | Westminster
(1 row)

CREATE TABLE
INSERT 0 12
    name     
-------------
 Zürich
 Zurich West
 Zürs
(3 rows)

    name     
-------------
 Zürich
 Zurich West
 Zürs
(3 rows)

   name    
-----------
 100% Pure
(1 row)

 name 
------
 a_b
(1 row)

   name    
-----------
 Pipe|Town
(1 row)

 name 
------
 Köln
 Koln
(2 rows)

 name 
------
 Köln
 Koln
(2 rows)

 should_be_1 
-------------
           1
(1 row)

NOTICE:  ILIKE: nondeterministic collations are not supported for ILIKE
NOTICE:  regex: nondeterministic collations are not supported for regular expressions
NOTICE:  starts_with: nondeterministic collations are not supported for substring searches
DO
ROLLBACK
```

## SQL B (index at scale)

```sql
\set ON_ERROR_STOP on
begin;
create schema proof;
create collation proof.geo_ci_ai (provider = icu, locale = 'und-u-ks-level1', deterministic = false);

-- a correct escaped prefix for the query "pipe|": the PHP doubles the pipe, then adds the trailing %
create table proof.t (name text collate proof.geo_ci_ai);
insert into proof.t values ('Pipe|Town'), ('Pipe Town');
select name as pipe_escape_matches from proof.t where name like 'pipe||%' escape '|';

-- scale: 171,000 cities (30,000 in one country), 1,100,000 postal codes, 250 countries
create table proof.countries (code char(2) primary key, name text collate proof.geo_ci_ai not null);
insert into proof.countries select chr(65 + i / 26) || chr(65 + i % 26), 'Country ' || chr(65 + (i * 7) % 26) || i from generate_series(0, 249) i;
create index idx_countries_name on proof.countries (name);

create table proof.cities (geoname_id int primary key, country_code text not null, name text collate proof.geo_ci_ai not null, state text, population int not null default 0);
insert into proof.cities
select i, case when i <= 30000 then 'US' else chr(65 + (i % 249) / 26) || chr(65 + (i % 249) % 26) end,
       (array['Zürich','Zurich','Zug','Köln','Koln','Alpha','Beta'])[1 + i % 7] || ' ' || md5(i::text),
       'S', (random() * 100000)::int
from generate_series(1, 171000) i;
create index idx_cities_country_name on proof.cities (country_code, name);
analyze proof.cities;

create table proof.postal (country_code text not null, postal_code text collate proof.geo_ci_ai not null, city text, primary key (country_code, postal_code));
insert into proof.postal select case when i <= 200000 then 'US' else chr(65 + (i % 249) / 26) || chr(65 + (i % 249) % 26) end, 'p' || i, 'x' from generate_series(1, 1100000) i;
analyze proof.postal;

\echo === postal equality uses the primary-key index
explain (analyze, costs off, timing off) select city from proof.postal where country_code = 'US' and postal_code = 'P150000';
\echo === cities prefix search, US (30,000 rows), the PHP query shape
explain (analyze, costs off, timing on) select name, state from proof.cities where country_code = 'US' and name like 'zur%' escape '|' order by population desc, name limit 10;
\echo === countries ORDER BY name uses the name index
set enable_seqscan = off;
explain (analyze, costs off, timing off) select code, name from proof.countries order by name;
reset enable_seqscan;
\echo === equality on the name column uses an index
set enable_seqscan = off;
explain (analyze, costs off, timing off) select code from proof.countries where name = 'COUNTRY H7';
reset enable_seqscan;
\echo === a bare country filter on cities uses the (country_code, name) index
explain (analyze, costs off, timing off) select count(*) from proof.cities where country_code = 'CH';
rollback;
```

## Output B

```
BEGIN
CREATE SCHEMA
CREATE COLLATION
CREATE TABLE
INSERT 0 2
 pipe_escape_matches 
---------------------
 Pipe|Town
(1 row)

CREATE TABLE
INSERT 0 250
CREATE INDEX
CREATE TABLE
INSERT 0 171000
CREATE INDEX
ANALYZE
CREATE TABLE
INSERT 0 1100000
ANALYZE
=== postal equality uses the primary-key index
                                   QUERY PLAN                                    
---------------------------------------------------------------------------------
 Index Scan using postal_pkey on postal (actual rows=1.00 loops=1)
   Index Cond: ((country_code = 'US'::text) AND (postal_code = 'P150000'::text))
   Index Searches: 1
   Buffers: shared hit=4
 Planning:
   Buffers: shared hit=22
 Planning Time: 0.097 ms
 Execution Time: 0.030 ms
(8 rows)

=== cities prefix search, US (30,000 rows), the PHP query shape
                                                   QUERY PLAN                                                    
-----------------------------------------------------------------------------------------------------------------
 Limit (actual time=12.190..12.191 rows=10.00 loops=1)
   Buffers: shared hit=310 read=244
   ->  Sort (actual time=12.189..12.189 rows=10.00 loops=1)
         Sort Key: population DESC, name COLLATE geo_ci_ai
         Sort Method: top-N heapsort  Memory: 26kB
         Buffers: shared hit=310 read=244
         ->  Bitmap Heap Scan on cities (actual time=2.015..11.754 rows=8571.00 loops=1)
               Recheck Cond: (country_code = 'US'::text)
               Filter: (name ~~ 'zur%'::text)
               Rows Removed by Filter: 21429
               Heap Blocks: exact=310
               Buffers: shared hit=310 read=244
               ->  Bitmap Index Scan on idx_cities_country_name (actual time=1.985..1.985 rows=30000.00 loops=1)
                     Index Cond: (country_code = 'US'::text)
                     Index Searches: 1
                     Buffers: shared read=244
 Planning:
   Buffers: shared hit=33 read=1
 Planning Time: 0.127 ms
 Execution Time: 12.207 ms
(20 rows)

=== countries ORDER BY name uses the name index
SET
                                  QUERY PLAN                                   
-------------------------------------------------------------------------------
 Index Scan using idx_countries_name on countries (actual rows=250.00 loops=1)
   Index Searches: 1
   Buffers: shared hit=59 read=1
 Planning:
   Buffers: shared hit=15 read=1
 Planning Time: 0.062 ms
 Execution Time: 0.036 ms
(7 rows)

RESET
=== equality on the name column uses an index
SET
                                 QUERY PLAN                                  
-----------------------------------------------------------------------------
 Index Scan using idx_countries_name on countries (actual rows=0.00 loops=1)
   Index Cond: (name = 'COUNTRY H7'::text)
   Index Searches: 1
   Buffers: shared hit=1
 Planning Time: 0.012 ms
 Execution Time: 0.006 ms
(6 rows)

RESET
=== a bare country filter on cities uses the (country_code, name) index
                                      QUERY PLAN                                       
---------------------------------------------------------------------------------------
 Aggregate (actual rows=1.00 loops=1)
   Buffers: shared hit=567 read=7
   ->  Bitmap Heap Scan on cities (actual rows=566.00 loops=1)
         Recheck Cond: (country_code = 'CH'::text)
         Heap Blocks: exact=566
         Buffers: shared hit=567 read=7
         ->  Bitmap Index Scan on idx_cities_country_name (actual rows=566.00 loops=1)
               Index Cond: (country_code = 'CH'::text)
               Index Searches: 1
               Buffers: shared hit=1 read=7
 Planning:
   Buffers: shared hit=6
 Planning Time: 0.029 ms
 Execution Time: 0.621 ms
(14 rows)

ROLLBACK
```
