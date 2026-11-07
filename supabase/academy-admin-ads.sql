-- NEXORA FORGE ACADEMY: secure administrator role and advertisement management
-- Run in Supabase SQL Editor for project vfatmvmgtgpmnxqbgszm.
-- Admin membership is granted manually from SQL Editor only. Never add a public signup path for admins.

create table if not exists public.academy_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.academy_ads (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 2 and 120),
  body text not null check (char_length(body) between 2 and 1000),
  image_url text,
  target_url text,
  placement text not null default 'student' check (placement in ('home','student','both')),
  is_active boolean not null default false,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.is_academy_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.academy_admins
    where user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_academy_admin() from public;
grant execute on function public.is_academy_admin() to authenticated;

alter table public.academy_admins enable row level security;
alter table public.academy_ads enable row level security;

drop policy if exists "Admins can read admin roster" on public.academy_admins;
create policy "Admins can read admin roster" on public.academy_admins
for select to authenticated using (public.is_academy_admin());

drop policy if exists "Public can read active ads" on public.academy_ads;
create policy "Public can read active ads" on public.academy_ads
for select to anon, authenticated
using (
  is_active = true
  and (starts_at is null or starts_at <= now())
  and (ends_at is null or ends_at > now())
);

drop policy if exists "Admins manage ads" on public.academy_ads;
create policy "Admins manage ads" on public.academy_ads
for all to authenticated
using (public.is_academy_admin())
with check (public.is_academy_admin());

grant select on public.academy_ads to anon, authenticated;
grant insert, update, delete on public.academy_ads to authenticated;
grant select on public.academy_admins to authenticated;

-- IMPORTANT: After the account is registered and email-verified, replace the address below
-- with the exact email of the existing owner account, then run this statement separately.
-- Only the SQL project owner can grant this role; never expose this operation in the website.
-- insert into public.academy_admins (user_id)
-- select id from auth.users where lower(email) = lower('YOUR-EXISTING-ACCOUNT-EMAIL')
-- on conflict (user_id) do nothing;
