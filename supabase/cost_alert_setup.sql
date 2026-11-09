-- =====================================================================
-- COST CHANGE ALERT  -  Supabase setup (run ONCE in SQL Editor -> Run)
-- Everything uses the prefix ca_ so it never touches other tables.
-- =====================================================================
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.ca_users (
  id bigint generated always as identity primary key,
  name text not null,
  role text not null check (role in ('admin','staff')),
  pin_hash text not null,
  active boolean not null default true,
  failed_attempts int not null default 0,
  locked_until timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists ca_users_name_key on public.ca_users (lower(name));

create table if not exists public.ca_sessions (
  token uuid primary key default gen_random_uuid(),
  user_id bigint not null references public.ca_users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '60 days'
);
create index if not exists ca_sessions_user_idx on public.ca_sessions (user_id);

create table if not exists public.ca_changes (
  id bigint generated always as identity primary key,
  code text not null default '',
  name text not null,
  old_cost numeric(12,3),
  new_cost numeric(12,3) not null,
  supplier text not null default '',
  note text not null default '',
  changed_by text not null default '',
  changed_at timestamptz not null default now()
);
create index if not exists ca_changes_time_idx on public.ca_changes (changed_at desc);
create index if not exists ca_changes_code_idx on public.ca_changes (code);
create index if not exists ca_changes_name_idx on public.ca_changes (name);

create table if not exists public.ca_seen_log (
  change_id bigint not null references public.ca_changes(id) on delete cascade,
  user_id bigint not null references public.ca_users(id) on delete cascade,
  seen_at timestamptz not null default now(),
  primary key (change_id, user_id)
);
create index if not exists ca_seen_user_idx on public.ca_seen_log (user_id);

-- Tables are locked (RLS on, no policies): the website can only use the functions below.
alter table public.ca_users    enable row level security;
alter table public.ca_sessions enable row level security;
alter table public.ca_changes  enable row level security;
alter table public.ca_seen_log enable row level security;

-- ---------- internal helpers (not callable from the website) ----------
create or replace function public.ca_local(t timestamptz) returns text
language sql stable set search_path = public as $$
  select to_char(t at time zone 'Asia/Qatar', 'YYYY-MM-DD"T"HH24:MI:SS')
$$;

create or replace function public.ca_auth(p_token uuid, p_admin boolean default false)
returns public.ca_users language plpgsql stable security definer set search_path = public as $$
declare u public.ca_users;
begin
  select u2.* into u from public.ca_sessions s join public.ca_users u2 on u2.id = s.user_id
   where s.token = p_token and s.expires_at > now() and u2.active;
  if u.id is null then raise exception 'SESSION_EXPIRED'; end if;
  if p_admin and u.role <> 'admin' then raise exception 'Admin only'; end if;
  return u;
end $$;

-- ---------- login ----------
create or replace function public.ca_has_users() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.ca_users)
$$;

create or replace function public.ca_login(p_name text, p_pin text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare u public.ca_users; t uuid;
begin
  select * into u from public.ca_users where lower(name) = lower(trim(coalesce(p_name,''))) and active;
  if u.id is null then return json_build_object('error','Wrong name or password'); end if;
  if u.locked_until is not null and u.locked_until > now() then
    return json_build_object('error', 'Too many wrong tries. Try again in '
      || ceil(extract(epoch from u.locked_until - now())/60)::int || ' min');
  end if;
  if u.pin_hash <> crypt(coalesce(p_pin,''), u.pin_hash) then
    update public.ca_users set
      failed_attempts = case when failed_attempts + 1 >= 5 then 0 else failed_attempts + 1 end,
      locked_until    = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' else locked_until end
    where id = u.id;
    return json_build_object('error','Wrong name or password');
  end if;
  update public.ca_users set failed_attempts = 0, locked_until = null where id = u.id;
  delete from public.ca_sessions where expires_at < now();
  insert into public.ca_sessions(user_id) values (u.id) returning token into t;
  return json_build_object('token', t, 'name', u.name, 'role', u.role);
end $$;

-- First admin: works only while there are no logins yet.
create or replace function public.ca_setup(p_name text, p_pin text)
returns json language plpgsql security definer set search_path = public, extensions as $$
begin
  lock table public.ca_users in exclusive mode;
  if exists (select 1 from public.ca_users) then raise exception 'Setup is already done. Please log in.'; end if;
  if length(trim(coalesce(p_name,''))) = 0 then raise exception 'Name is required'; end if;
  if length(coalesce(p_pin,'')) < 6 then raise exception 'Admin password must be at least 6 characters'; end if;
  insert into public.ca_users(name, role, pin_hash) values (trim(p_name), 'admin', crypt(p_pin, gen_salt('bf')));
  return public.ca_login(p_name, p_pin);
end $$;

create or replace function public.ca_logout(p_token uuid) returns json
language plpgsql security definer set search_path = public as $$
begin
  delete from public.ca_sessions where token = p_token;
  return json_build_object('ok', true);
end $$;

-- ---------- feed (admin + staff) ----------
create or replace function public.ca_feed(p_token uuid, p_days int default 2)
returns json language plpgsql security definer set search_path = public as $$
declare u public.ca_users; d date := (now() at time zone 'Asia/Qatar')::date; since timestamptz;
begin
  u := public.ca_auth(p_token);
  since := ((d - (greatest(1, least(60, coalesce(p_days,2))) - 1))::timestamp) at time zone 'Asia/Qatar';
  return json_build_object(
    'today', to_char(d, 'YYYY-MM-DD'), 'me', u.name, 'role', u.role,
    'rows', coalesce((
      select json_agg(json_build_object(
        'id', c.id, 'code', c.code, 'name', c.name, 'old_cost', c.old_cost, 'new_cost', c.new_cost,
        'supplier', c.supplier, 'note', c.note, 'changed_by', c.changed_by,
        'changed_at', public.ca_local(c.changed_at),
        'me_seen', exists (select 1 from public.ca_seen_log l where l.change_id = c.id and l.user_id = u.id),
        'seen', coalesce((select json_agg(json_build_object('by', su.name, 'at', public.ca_local(l.seen_at)) order by l.seen_at)
                          from public.ca_seen_log l join public.ca_users su on su.id = l.user_id
                          where l.change_id = c.id), '[]'::json)
      ) order by c.id desc)
      from public.ca_changes c where c.changed_at >= since), '[]'::json));
end $$;

create or replace function public.ca_seen(p_token uuid, p_id bigint) returns json
language plpgsql security definer set search_path = public as $$
declare u public.ca_users;
begin
  u := public.ca_auth(p_token);
  insert into public.ca_seen_log(change_id, user_id) values (p_id, u.id) on conflict do nothing;
  return json_build_object('ok', true);
end $$;

-- ---------- admin: costs ----------
create or replace function public.ca_add(p_token uuid, p_code text, p_name text, p_old numeric, p_new numeric,
                                         p_supplier text default '', p_note text default '')
returns json language plpgsql security definer set search_path = public as $$
declare u public.ca_users; v_name text := upper(trim(coalesce(p_name,'')));
        v_code text := trim(coalesce(p_code,'')); v_old numeric := p_old; v_id bigint;
begin
  u := public.ca_auth(p_token, true);
  if v_name = '' then raise exception 'Product name is required'; end if;
  if p_new is null or p_new < 0 then raise exception 'Enter a valid new cost'; end if;
  if v_old is null then
    select new_cost into v_old from public.ca_changes
     where (v_code <> '' and code = v_code) or name = v_name order by id desc limit 1;
  end if;
  insert into public.ca_changes(code, name, old_cost, new_cost, supplier, note, changed_by)
  values (v_code, v_name, v_old, p_new, trim(coalesce(p_supplier,'')), trim(coalesce(p_note,'')), u.name)
  returning id into v_id;
  return json_build_object('ok', true, 'id', v_id);
end $$;

create or replace function public.ca_lookup(p_token uuid, p_q text) returns json
language plpgsql security definer set search_path = public as $$
declare r json; s text := trim(coalesce(p_q,''));
begin
  perform public.ca_auth(p_token, true);
  if s = '' then return '{}'::json; end if;
  select json_build_object('code', code, 'name', name, 'new_cost', new_cost) into r
    from public.ca_changes where code = s order by id desc limit 1;
  if r is null then
    select json_build_object('code', code, 'name', name, 'new_cost', new_cost) into r
      from public.ca_changes where name ilike '%' || s || '%' order by id desc limit 1;
  end if;
  return coalesce(r, '{}'::json);
end $$;

create or replace function public.ca_products(p_token uuid) returns json
language plpgsql security definer set search_path = public as $$
begin
  perform public.ca_auth(p_token, true);
  return coalesce((select json_agg(json_build_object('code', code, 'name', name, 'new_cost', new_cost) order by name)
                   from (select distinct on (name) code, name, new_cost from public.ca_changes order by name, id desc) x),
                  '[]'::json);
end $$;

create or replace function public.ca_delete(p_token uuid, p_id bigint) returns json
language plpgsql security definer set search_path = public as $$
begin
  perform public.ca_auth(p_token, true);
  delete from public.ca_changes where id = p_id;
  return json_build_object('ok', true);
end $$;

-- ---------- admin: logins ----------
create or replace function public.ca_users_list(p_token uuid) returns json
language plpgsql security definer set search_path = public as $$
begin
  perform public.ca_auth(p_token, true);
  return coalesce((select json_agg(json_build_object('id', id, 'name', name, 'role', role) order by role, name)
                   from public.ca_users where active), '[]'::json);
end $$;

create or replace function public.ca_user_save(p_token uuid, p_name text, p_pin text, p_role text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare me public.ca_users; ex public.ca_users; v_name text := trim(coalesce(p_name,''));
begin
  me := public.ca_auth(p_token, true);
  if v_name = '' then raise exception 'Name is required'; end if;
  if p_role not in ('admin','staff') then raise exception 'Role must be admin or staff'; end if;
  if coalesce(p_pin,'') <> '' and length(p_pin) < 4 then raise exception 'Password must be at least 4 characters'; end if;
  select * into ex from public.ca_users where lower(name) = lower(v_name);
  if ex.id is null then
    if coalesce(p_pin,'') = '' then raise exception 'Password is required for a new login'; end if;
    insert into public.ca_users(name, role, pin_hash) values (v_name, p_role, crypt(p_pin, gen_salt('bf')));
  else
    if ex.id = me.id and p_role <> 'admin' then raise exception 'You cannot remove your own admin role'; end if;
    update public.ca_users set role = p_role, active = true, failed_attempts = 0, locked_until = null,
           pin_hash = case when coalesce(p_pin,'') <> '' then crypt(p_pin, gen_salt('bf')) else pin_hash end
     where id = ex.id;
    if coalesce(p_pin,'') <> '' and ex.id <> me.id then delete from public.ca_sessions where user_id = ex.id; end if;
  end if;
  return json_build_object('ok', true);
end $$;

create or replace function public.ca_user_remove(p_token uuid, p_id bigint) returns json
language plpgsql security definer set search_path = public as $$
declare me public.ca_users;
begin
  me := public.ca_auth(p_token, true);
  if p_id = me.id then raise exception 'You cannot remove your own login'; end if;
  update public.ca_users set active = false where id = p_id;
  delete from public.ca_sessions where user_id = p_id;
  return json_build_object('ok', true);
end $$;

-- ---------- permissions ----------
revoke all on table public.ca_users, public.ca_sessions, public.ca_changes, public.ca_seen_log from anon, authenticated;
revoke execute on function public.ca_local(timestamptz) from public, anon, authenticated;
revoke execute on function public.ca_auth(uuid, boolean) from public, anon, authenticated;
grant execute on function
  public.ca_has_users(), public.ca_login(text, text), public.ca_setup(text, text), public.ca_logout(uuid),
  public.ca_feed(uuid, int), public.ca_seen(uuid, bigint),
  public.ca_add(uuid, text, text, numeric, numeric, text, text), public.ca_lookup(uuid, text),
  public.ca_products(uuid), public.ca_delete(uuid, bigint),
  public.ca_users_list(uuid), public.ca_user_save(uuid, text, text, text), public.ca_user_remove(uuid, bigint)
to anon, authenticated;
