-- Data load engine (S2). Run once per session before a domain file; objects live in schema "staging", dropped at the end.
-- Reports hold COUNTS and constraint, column and SQLSTATE names only. No value from a row is ever recorded or raised.
-- Settings come in as custom GUCs set by load.sh: staging.source_tz (zone of MariaDB datetime columns).
create schema if not exists staging;

create table if not exists staging.source_columns (
    table_name  text not null,
    column_name text not null,
    data_type   text not null,
    primary key (table_name, column_name)
);

create table if not exists staging.source_counts (
    table_name  text primary key,
    source_rows bigint not null
);

-- One row per run: the zone the datetime columns were read in, and the domains that failed and are not yet retried.
create table if not exists staging.run_info (
    source_tz      text not null,
    failed_domains text not null default ''
);

create table if not exists staging.report (
    seq           serial primary key,
    domain        text   not null,
    source_table  text   not null,
    target_table  text   not null,
    mode          text   not null,
    source_rows   bigint not null,
    filtered_rows bigint not null,
    loaded_rows   bigint not null,
    rejected_rows bigint not null,
    skipped_rows  bigint not null default 0
);

create table if not exists staging.report_detail (
    seq          serial primary key,
    target_table text   not null,
    kind         text   not null,
    reason       text   not null,
    row_count    bigint not null
);

create or replace function staging.add_detail(p_target text, p_kind text, p_reason text, p_count bigint)
returns void language sql as $$
    insert into staging.report_detail (target_table, kind, reason, row_count)
    select p_target, p_kind, p_reason, p_count where p_count > 0;
$$;

-- Loads staging.<p_src> (all text) into <p_dst>, converting by the TARGET column type.
--   p_map   target column -> source column, where the names differ ('{"user_id":"id"}')
--   p_trunc target column -> maximum length, for the cuts already decided ('{"name":200}'): counted, never silent
--   p_where SQL condition on alias s; rows failing it are "filtered", not loaded (by design, not rejected)
--   p_mode  'load' (target must be empty) or 'merge' (migration-seeded reference table: rows already there are kept,
--           not overwritten; counted as skipped, and the ones that differ from the source are counted too)
-- A row the target refuses is rejected and counted under its reason (SQLSTATE, constraint, column); the load goes on.
create or replace function staging.load_table(
    p_domain text, p_src text, p_dst text,
    p_map jsonb default '{}', p_trunc jsonb default '{}', p_where text default null, p_mode text default 'load')
returns void language plpgsql as $fn$
declare
    v_rel        regclass := to_regclass(p_dst);
    v_tz         text := current_setting('staging.source_tz');
    v_where      text := '(' || coalesce(p_where, 'true') || ')';
    v_tail       text := '';
    v_cols       text := '';
    v_exprs      text := '';
    v_pk         text[];
    v_col        record;
    v_src        text;
    v_expr       text;
    v_srctype    text;
    v_ref        text;
    v_zero       constant text := '^[0-9]{4}-(00|[0-9]{2}-00)';
    v_n          bigint;
    v_source     bigint;
    v_filtered   bigint;
    v_loaded     bigint := 0;
    v_skipped    bigint := 0;
    v_rejected   bigint;
    v_sql        text;
    v_rn         bigint;
    v_reasons    jsonb := '{}';
    v_reason     text;
    v_state      text;
    v_constraint text;
    v_column     text;
    v_json       boolean;
    v_idcol      text;
    v_next       bigint;
begin
    if v_rel is null then raise exception 'target table % does not exist (migrate first)', p_dst; end if;
    if to_regclass(format('staging.%I', p_src)) is null then raise exception 'staging table % does not exist', p_src; end if;
    if p_mode not in ('load', 'merge') then raise exception 'unknown mode %', p_mode; end if;

    for v_col in
        select a.attname, a.attnotnull, a.atthasdef or a.attidentity <> '' as has_default, t.typname,
               format_type(a.atttypid, a.atttypmod) as full_type,
               exists (select 1 from pg_constraint c
                        where c.conrelid = v_rel and c.contype = 'c'
                          and pg_get_constraintdef(c.oid) like '%IS JSON%'
                          and pg_get_constraintdef(c.oid) like '%' || quote_ident(a.attname) || '%') as json_check
          from pg_attribute a join pg_type t on t.oid = a.atttypid
         where a.attrelid = v_rel and a.attnum > 0 and not a.attisdropped and a.attgenerated = ''
         order by a.attnum
    loop
        v_src := coalesce(p_map ->> v_col.attname, v_col.attname);
        select data_type into v_srctype from staging.source_columns where table_name = p_src and column_name = v_src;
        if v_srctype is null then
            if v_col.attnotnull and not v_col.has_default then
                raise exception 'source table % has no column for required target column %.%', p_src, p_dst, v_col.attname;
            end if;
            perform staging.add_detail(p_dst, 'target_column_not_in_source', v_col.attname, 1);
            continue;
        end if;

        v_ref := format('s.%I', v_src);
        v_json := v_col.typname = 'jsonb' or v_col.json_check;
        if v_json then
            v_expr := format('case when %1$s is json then %1$s::%2$s end', v_ref, v_col.full_type);
            execute format('select count(*) from staging.%I s where %s is not null and %s is not json', p_src, v_ref, v_ref) into v_n;
            perform staging.add_detail(p_dst, case when v_col.attnotnull then 'invalid_json_in_required_column'
                                                   else 'invalid_json_set_null' end, v_col.attname, v_n);
        elsif v_col.typname in ('timestamptz', 'timestamp', 'date') then
            -- MariaDB timestamp columns were exported in UTC; datetime columns are read in the source zone.
            v_expr := case v_col.typname
                when 'timestamptz' then format('(%s::timestamp at time zone %L)', v_ref, case when v_srctype = 'timestamp' then 'UTC' else v_tz end)
                else format('%s::%s', v_ref, v_col.full_type) end;
            v_expr := format('case when %s ~ %L then null else %s end', v_ref, v_zero, v_expr);
            execute format('select count(*) from staging.%I s where %s ~ %L', p_src, v_ref, v_zero) into v_n;
            perform staging.add_detail(p_dst, case when v_col.attnotnull then 'zero_date_in_required_column'
                                                   else 'zero_date_set_null' end, v_col.attname, v_n);
        elsif v_col.typname = 'bool' then
            v_expr := format('(%s <> ''0'')', v_ref);
        elsif v_col.typname in ('int2', 'int4', 'int8', 'float4', 'float8', 'numeric', 'time') then
            v_expr := format('%s::%s', v_ref, v_col.full_type);
        elsif p_trunc ? v_col.attname then
            v_expr := format('left(%s, %s)::%s', v_ref, p_trunc ->> v_col.attname, v_col.full_type);
            execute format('select count(*) from staging.%I s where char_length(%s) > %s', p_src, v_ref, p_trunc ->> v_col.attname) into v_n;
            perform staging.add_detail(p_dst, 'truncated_to_' || (p_trunc ->> v_col.attname), v_col.attname, v_n);
        else
            v_expr := format('%s::%s', v_ref, v_col.full_type);
        end if;

        v_cols := v_cols || case when v_cols = '' then '' else ', ' end || quote_ident(v_col.attname);
        v_exprs := v_exprs || case when v_exprs = '' then '' else ', ' end || v_expr;
    end loop;
    if v_cols = '' then raise exception 'no column of % has a source column', p_dst; end if;

    execute format('select count(*) from staging.%I', p_src) into v_source;
    execute format('select count(*) from staging.%I s where not coalesce(%s, false)', p_src, v_where) into v_filtered;

    v_sql := format('insert into %s (%s) overriding system value select %s from staging.%I s where %s',
                    v_rel, v_cols, v_exprs, p_src, v_where);
    if p_mode = 'merge' then
        v_tail := ' on conflict do nothing';
    end if;

    begin
        execute v_sql || v_tail;
        get diagnostics v_loaded = row_count;
    exception when others then
        get stacked diagnostics v_state = returned_sqlstate;
        if v_state like '57%' then raise; end if;
        -- The set insert failed: redo it one row at a time, each in its own subtransaction.
        v_loaded := 0;
        for v_rn in execute format('select s._rn from staging.%I s where %s order by s._rn', p_src, v_where) loop
            begin
                execute v_sql || format(' and s._rn = %s', v_rn) || v_tail;
                get diagnostics v_n = row_count;
                v_loaded := v_loaded + v_n;
            exception when others then
                get stacked diagnostics v_state = returned_sqlstate, v_constraint = constraint_name, v_column = column_name;
                if v_state like '57%' then raise; end if;
                v_reason := v_state || coalesce(' constraint ' || nullif(v_constraint, ''), '') || coalesce(' column ' || nullif(v_column, ''), '');
                v_reasons := jsonb_set(v_reasons, array[v_reason], to_jsonb(coalesce((v_reasons ->> v_reason)::bigint, 0) + 1));
            end;
        end loop;
    end;

    for v_reason in select jsonb_object_keys(v_reasons) loop
        perform staging.add_detail(p_dst, 'rejected', v_reason, (v_reasons ->> v_reason)::bigint);
    end loop;

    if p_mode = 'merge' then
        -- Rows the target refused are rejected (counted per reason above). What is left over is the seed rows the
        -- migration already holds: skipped. The ones whose values differ from the source are reported.
        select coalesce(sum(value::bigint), 0) into v_rejected from jsonb_each_text(v_reasons);
        v_skipped := v_source - v_filtered - v_loaded - v_rejected;
        select array_agg(quote_ident(a.attname)) into v_pk
          from pg_index i join pg_attribute a on a.attrelid = i.indrelid and a.attnum = any (i.indkey)
         where i.indrelid = v_rel and i.indisprimary;
        if v_pk is null then raise exception 'merge mode needs a primary key on %', p_dst; end if;
        -- Per column: rows whose seed value differs from the source value (the seed row is kept either way).
        for v_idcol in select a.attname from pg_attribute a
                        where a.attrelid = v_rel and a.attnum > 0 and not a.attisdropped and a.attgenerated = ''
                          and quote_ident(a.attname) = any (string_to_array(v_cols, ', '))
                          and quote_ident(a.attname) <> all (v_pk) order by a.attnum loop
            execute format(
                'select count(*) from (select %s from staging.%I s where %s) c(%s) join %s t using (%s) where t.%I is distinct from c.%I',
                v_exprs, p_src, v_where, v_cols, v_rel, array_to_string(v_pk, ', '), v_idcol, v_idcol) into v_n;
            perform staging.add_detail(p_dst, 'seed_value_differs_kept_target', v_idcol, v_n);
        end loop;
    else
        v_rejected := v_source - v_filtered - v_loaded;
    end if;
    if v_filtered > 0 then perform staging.add_detail(p_dst, 'filtered_by_design', coalesce(p_where, ''), v_filtered); end if;

    -- Identity columns continue after the highest loaded id.
    for v_idcol in select a.attname from pg_attribute a where a.attrelid = v_rel and a.attidentity <> '' and not a.attisdropped loop
        execute format('select coalesce(max(%I), 0) + 1 from %s', v_idcol, v_rel) into v_next;
        perform setval(pg_get_serial_sequence(p_dst, v_idcol), v_next, false);
    end loop;

    insert into staging.report (domain, source_table, target_table, mode, source_rows, filtered_rows, loaded_rows, rejected_rows, skipped_rows)
    values (p_domain, p_src, p_dst, p_mode, v_source, v_filtered, v_loaded, v_rejected, v_skipped);
end
$fn$;

-- Counts rows of <p_child>.<p_col> that name nothing in <p_parent>.<p_pcol>. NULL is not an orphan; 0 is looked up like any value.
create or replace function staging.count_orphans(p_child text, p_col text, p_parent text, p_pcol text)
returns void language plpgsql as $$
declare v_n bigint;
begin
    execute format('select count(*) from %s c where c.%I is not null and not exists (select 1 from %s p where p.%I = c.%I)',
                   p_child, p_col, p_parent, p_pcol, p_col) into v_n;
    insert into staging.report_detail (target_table, kind, reason, row_count)
    values (p_child, 'orphan', format('%s -> %s.%s', p_col, p_parent, p_pcol), v_n);
end
$$;
