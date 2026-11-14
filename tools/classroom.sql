-- Star Academy "Classroom with Baba": private kid <-> parent channel. Isolated schema, no direct table access; only token-checked RPCs.
create schema if not exists kidchat;
revoke all on schema kidchat from public, anon, authenticated;

create table kidchat.families(
  id uuid primary key default gen_random_uuid(),
  kid_hash text not null unique,
  baba_hash text not null unique,
  kid_name text not null default '',
  created_at timestamptz not null default now()
);
create table kidchat.msgs(
  id bigserial primary key,
  family uuid not null references kidchat.families(id) on delete cascade,
  sender text not null check (sender in ('kid','baba')),
  kind text not null check (kind in ('nudge','voice','text','ask','answer')),
  body text not null default '' check (length(body) <= 600),
  audio text check (audio is null or length(audio) <= 1600000),
  mime text,
  dur int,
  seen boolean not null default false,
  created_at timestamptz not null default now()
);
create index on kidchat.msgs(family, id);
alter table kidchat.families enable row level security;
alter table kidchat.msgs enable row level security;
revoke all on all tables in schema kidchat from public, anon, authenticated;

create or replace function kidchat.h(t text) returns text language sql immutable set search_path='' as
$$ select encode(sha256(convert_to(coalesce(t,''),'UTF8')),'hex') $$;
create or replace function kidchat.tok() returns text language sql volatile set search_path='' as
$$ select replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','') $$;

create or replace function kidchat.who(p_token text, out fam uuid, out role text) language plpgsql stable set search_path='' as $$
begin
  if p_token is null or length(p_token) < 40 then raise exception 'bad token'; end if;
  select f.id, 'kid' into fam, role from kidchat.families f where f.kid_hash = kidchat.h(p_token);
  if fam is null then select f.id, 'baba' into fam, role from kidchat.families f where f.baba_hash = kidchat.h(p_token); end if;
  if fam is null then raise exception 'not paired'; end if;
end $$;

create or replace function public.kc_pair_create(p_kid_name text) returns jsonb language plpgsql security definer set search_path='' as $$
declare k text := kidchat.tok(); b text := kidchat.tok(); n int;
begin
  select count(*) into n from kidchat.families where created_at > now() - interval '1 hour';
  if n >= 30 then raise exception 'busy, try later'; end if;
  insert into kidchat.families(kid_hash, baba_hash, kid_name) values (kidchat.h(k), kidchat.h(b), left(coalesce(p_kid_name,''),30));
  return jsonb_build_object('kid', k, 'baba', b);
end $$;

create or replace function public.kc_rotate_baba(p_kid_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare w record; b text := kidchat.tok();
begin
  select * into w from kidchat.who(p_kid_token);
  if w.role <> 'kid' then raise exception 'only the tablet can do this'; end if;
  update kidchat.families set baba_hash = kidchat.h(b) where id = w.fam;
  return jsonb_build_object('baba', b);
end $$;

create or replace function public.kc_unpair(p_kid_token text) returns boolean language plpgsql security definer set search_path='' as $$
declare w record;
begin
  select * into w from kidchat.who(p_kid_token);
  if w.role <> 'kid' then raise exception 'only the tablet can do this'; end if;
  delete from kidchat.families where id = w.fam;
  return true;
end $$;

create or replace function public.kc_send(p_token text, p_kind text, p_body text default '', p_audio text default null, p_mime text default null, p_dur int default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare w record; n int; new_id bigint;
begin
  select * into w from kidchat.who(p_token);
  if w.role = 'kid' and p_kind not in ('nudge','voice','text','answer') then raise exception 'bad kind'; end if;
  if w.role = 'baba' and p_kind not in ('nudge','voice','text','ask') then raise exception 'bad kind'; end if;
  if p_kind = 'voice' and (p_audio is null or length(p_audio) < 100) then raise exception 'no audio'; end if;
  if p_kind <> 'voice' and p_audio is not null then raise exception 'audio only on voice'; end if;
  if p_mime is not null and p_mime !~ '^audio/[a-z0-9.;=, +-]{1,60}$' then raise exception 'bad mime'; end if;
  select count(*) into n from kidchat.msgs where family = w.fam and sender = w.role and created_at > now() - interval '10 minutes';
  if n >= 40 then raise exception 'slow down'; end if;
  insert into kidchat.msgs(family, sender, kind, body, audio, mime, dur)
    values (w.fam, w.role, p_kind, left(coalesce(p_body,''),600), p_audio, p_mime, least(greatest(coalesce(p_dur,0),0),120))
    returning id into new_id;
  -- short-lived voice: audio kept 14 days, messages kept 120 days
  update kidchat.msgs set audio = null where family = w.fam and audio is not null and created_at < now() - interval '14 days';
  delete from kidchat.msgs where family = w.fam and created_at < now() - interval '120 days';
  return jsonb_build_object('id', new_id);
end $$;

create or replace function public.kc_list(p_token text, p_after bigint default 0) returns jsonb language plpgsql security definer set search_path='' as $$
declare w record; r jsonb;
begin
  select * into w from kidchat.who(p_token);
  select coalesce(jsonb_agg(x order by x.id), '[]'::jsonb) into r from (
    select m.id, m.sender, m.kind, m.body, (m.audio is not null) as has_audio, m.mime, m.dur, m.seen, m.created_at
    from kidchat.msgs m where m.family = w.fam and m.id > coalesce(p_after,0)
    order by m.id desc limit 150) x;
  return jsonb_build_object('role', w.role, 'msgs', r,
    'kid_name', (select kid_name from kidchat.families where id = w.fam));
end $$;

create or replace function public.kc_audio(p_token text, p_id bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare w record; a text; mm text;
begin
  select * into w from kidchat.who(p_token);
  select audio, mime into a, mm from kidchat.msgs where id = p_id and family = w.fam;
  return jsonb_build_object('audio', a, 'mime', mm);
end $$;

create or replace function public.kc_seen(p_token text, p_upto bigint) returns int language plpgsql security definer set search_path='' as $$
declare w record; n int;
begin
  select * into w from kidchat.who(p_token);
  update kidchat.msgs set seen = true where family = w.fam and sender <> w.role and id <= p_upto and not seen;
  get diagnostics n = row_count;
  return n;
end $$;

revoke all on function public.kc_pair_create(text), public.kc_rotate_baba(text), public.kc_unpair(text),
  public.kc_send(text,text,text,text,text,int), public.kc_list(text,bigint), public.kc_audio(text,bigint), public.kc_seen(text,bigint) from public;
grant execute on function public.kc_pair_create(text), public.kc_rotate_baba(text), public.kc_unpair(text),
  public.kc_send(text,text,text,text,text,int), public.kc_list(text,bigint), public.kc_audio(text,bigint), public.kc_seen(text,bigint) to anon, authenticated;
revoke all on all functions in schema kidchat from public, anon, authenticated;
