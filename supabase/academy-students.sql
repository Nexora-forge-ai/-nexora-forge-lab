-- NEXORA FORGE ACADEMY: student accounts and private learning data
-- Run this entire script in Supabase Dashboard > SQL Editor > New query.
-- Safe to run alongside the existing main-site tables; it creates academy-specific tables only.

create table if not exists public.student_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  completed_lessons text[] not null default '{}',
  updated_at timestamptz not null default now()
);

create table if not exists public.student_quiz_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  score integer not null check (score >= 0),
  total integer not null check (total > 0 and score <= total),
  created_at timestamptz not null default now()
);

alter table public.student_progress enable row level security;
alter table public.student_quiz_attempts enable row level security;

drop policy if exists "Students read own progress" on public.student_progress;
create policy "Students read own progress"
on public.student_progress for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Students insert own progress" on public.student_progress;
create policy "Students insert own progress"
on public.student_progress for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Students update own progress" on public.student_progress;
create policy "Students update own progress"
on public.student_progress for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Students read own quiz attempts" on public.student_quiz_attempts;
create policy "Students read own quiz attempts"
on public.student_quiz_attempts for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Students insert own quiz attempts" on public.student_quiz_attempts;
create policy "Students insert own quiz attempts"
on public.student_quiz_attempts for insert
to authenticated
with check (auth.uid() = user_id);

grant select, insert, update on public.student_progress to authenticated;
grant select, insert on public.student_quiz_attempts to authenticated;
grant usage, select on sequence public.student_quiz_attempts_id_seq to authenticated;
