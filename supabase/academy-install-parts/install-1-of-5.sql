-- NEXORA FORGE ACADEMY INSTALL — COMBINED PART 1/5
-- Contains original parts 01-04. Run once, then wait for success.

begin;
-- NEXORA FORGE ACADEMY INSTALL — PART 1/21
-- Run this file in order. Each part commits independently.

begin;
-- NEXORA FORGE ACADEMY — ONE-TIME COMPLETE INSTALL
-- Target project: nutgcqhcgytjglyuvmla
-- Run only once on a fresh Supabase project. Do not rerun on an already installed database.
-- Never put the service_role key in browser code.

begin;

create extension if not exists pgcrypto;

-- 1) Shared updated_at trigger
create or replace function public.academy_set_updated_at()
returns trigger language plpgsql set search_path = public
as $$ begin new.updated_at = now(); return new; end; $$;

-- 2) Accounts and roles
create table if not exists public.academy_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.academy_user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('student','admin','super_admin')),
  created_at timestamptz not null default now(),
  primary key (user_id, role)
);

create or replace function public.academy_is_admin()
returns boolean language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.academy_user_roles r
    where r.user_id = (select auth.uid()) and r.role in ('admin','super_admin')
  );
$$;

create or replace function public.academy_is_super_admin()
returns boolean language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.academy_user_roles r
    where r.user_id = (select auth.uid()) and r.role = 'super_admin'
  );
$$;

revoke all on function public.academy_is_admin() from public;
revoke all on function public.academy_is_super_admin() from public;
grant execute on function public.academy_is_admin() to anon, authenticated;
grant execute on function public.academy_is_super_admin() to authenticated;

create or replace function public.academy_handle_new_user()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.academy_profiles(user_id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name',''))
  on conflict (user_id) do nothing;

  insert into public.academy_user_roles(user_id, role)
  values (new.id, 'student')
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists academy_on_auth_user_created on auth.users;
create trigger academy_on_auth_user_created
after insert on auth.users
for each row execute procedure public.academy_handle_new_user();

-- 3) Learning catalog
create table if not exists public.academy_languages (
  id text primary key,
  name text not null,
  slug text not null unique,
  description text not null default '',
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.academy_levels (
  id text primary key,
  name text not null,
  slug text not null unique,
  sort_order integer not null unique,
  description text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.academy_courses (
  id text primary key,
  language_id text not null references public.academy_languages(id) on update cascade,
  level_id text not null references public.academy_levels(id) on update cascade,
  title text not null,
  slug text not null unique,
  description text not null default '',
  cover_path text,
  status text not null default 'draft' check (status in ('draft','published','archived')),
  sort_order integer not null default 0,
  estimated_hours numeric(6,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique(language_id, level_id)
);

create table if not exists public.academy_lessons (
  id text primary key,
  course_id text not null references public.academy_courses(id) on delete restrict on update cascade,
  title text not null,
  slug text,
  summary text not null default '',
  content_html text not null default '',
  starter_code text not null default '',
  exercise text not null default '',
  video_url text,
  status text not null default 'draft' check (status in ('draft','published','archived')),
  sort_order integer not null default 0,
  estimated_minutes integer check (estimated_minutes is null or estimated_minutes > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique(course_id, slug)
);

create table if not exists public.academy_lesson_attachments (
  id uuid primary key default gen_random_uuid(),
  lesson_id text not null references public.academy_lessons(id) on delete cascade,
  file_path text not null,
  file_name text not null,
  mime_type text,
  file_size_bytes bigint check (file_size_bytes is null or file_size_bytes >= 0),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

-- 4) Student progress
create table if not exists public.academy_lesson_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_id text not null references public.academy_lessons(id) on delete cascade,
  status text not null default 'completed' check (status in ('started','completed')),
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key(user_id, lesson_id)
);

-- 5) Quiz engine. Correct answers are deliberately stored separately.
create table if not exists public.academy_quizzes (
  id uuid primary key default gen_random_uuid(),
  course_id text references public.academy_courses(id) on delete cascade,
  lesson_id text references public.academy_lessons(id) on delete cascade,
  title text not null,
  description text not null default '',
  pass_percent integer not null default 60 check (pass_percent between 0 and 100),
  time_limit_seconds integer check (time_limit_seconds is null or time_limit_seconds > 0),
  status text not null default 'draft' check (status in ('draft','published','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (course_id is not null or lesson_id is not null)
);

create table if not exists public.academy_quiz_questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.academy_quizzes(id) on delete cascade,
  question_text text not null,
  explanation text not null default '',
  points numeric(8,2) not null default 1 check (points > 0),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.academy_quiz_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.academy_quiz_questions(id) on delete cascade,
  option_text text not null,
  sort_order integer not null default 0
);

create table if not exists public.academy_quiz_correct_answers (
  question_id uuid primary key references public.academy_quiz_questions(id) on delete cascade,
  option_id uuid not null references public.academy_quiz_options(id) on delete cascade
);

create table if not exists public.academy_quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.academy_quizzes(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  score numeric(8,2) not null default 0,
  max_score numeric(8,2) not null default 0,
  percent integer not null default 0 check (percent between 0 and 100),
  passed boolean not null default false,
  submitted_at timestamptz not null default now()
);

create table if not exists public.academy_quiz_answers (
  attempt_id uuid not null references public.academy_quiz_attempts(id) on delete cascade,
  question_id uuid not null references public.academy_quiz_questions(id) on delete cascade,
  selected_option_id uuid references public.academy_quiz_options(id) on delete set null,
  is_correct boolean not null default false,
  awarded_points numeric(8,2) not null default 0,
  primary key(attempt_id, question_id)
);

-- 6) Ads, public settings, audit trail
create table if not exists public.academy_ads (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 2 and 120),
  body text not null default '' check (char_length(body) <= 2000),
  image_path text,
  target_url text,
  placement text not null default 'home' check (placement in ('home','student','both')),
  status text not null default 'draft' check (status in ('draft','active','paused','archived')),
  starts_at timestamptz,
  ends_at timestamptz,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create table if not exists public.academy_site_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  is_public boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

create table if not exists public.academy_activity_logs (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- 7) Indexes
create index if not exists academy_courses_catalog_idx on public.academy_courses(status, language_id, level_id, sort_order);
create index if not exists academy_lessons_course_idx on public.academy_lessons(course_id, status, sort_order);
create index if not exists academy_progress_user_idx on public.academy_lesson_progress(user_id, status);
create index if not exists academy_quizzes_course_idx on public.academy_quizzes(course_id, status);
create index if not exists academy_questions_quiz_idx on public.academy_quiz_questions(quiz_id, sort_order);
create index if not exists academy_options_question_idx on public.academy_quiz_options(question_id, sort_order);
create index if not exists academy_attempts_user_idx on public.academy_quiz_attempts(user_id, submitted_at desc);
create index if not exists academy_ads_active_idx on public.academy_ads(status, starts_at, ends_at, sort_order);

-- 8) updated_at triggers
do $$
declare t text;
begin
  foreach t in array array['academy_profiles','academy_languages','academy_courses','academy_lessons','academy_lesson_progress','academy_quizzes','academy_ads'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_updated_at', t);
    execute format('create trigger %I before update on public.%I for each row execute function public.academy_set_updated_at()', t || '_updated_at', t);
  end loop;
end $$;

-- 9) RLS
alter table public.academy_profiles enable row level security;
alter table public.academy_user_roles enable row level security;
alter table public.academy_languages enable row level security;
alter table public.academy_levels enable row level security;
alter table public.academy_courses enable row level security;
alter table public.academy_lessons enable row level security;
alter table public.academy_lesson_attachments enable row level security;
alter table public.academy_lesson_progress enable row level security;
alter table public.academy_quizzes enable row level security;
alter table public.academy_quiz_questions enable row level security;
alter table public.academy_quiz_options enable row level security;
alter table public.academy_quiz_correct_answers enable row level security;
alter table public.academy_quiz_attempts enable row level security;
alter table public.academy_quiz_answers enable row level security;
alter table public.academy_ads enable row level security;
alter table public.academy_site_settings enable row level security;
alter table public.academy_activity_logs enable row level security;

-- Remove only policies owned by this baseline before recreating them.
do $$
declare p record;
begin
  for p in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname='public' and tablename like 'academy\_%' escape '\'
  loop
    execute format('drop policy if exists %I on %I.%I', p.policyname, p.schemaname, p.tablename);
  end loop;
end $$;

create policy "profile_read_self_or_admin" on public.academy_profiles
for select to authenticated using (user_id = (select auth.uid()) or public.academy_is_admin());
create policy "profile_update_self_or_admin" on public.academy_profiles
for update to authenticated using (user_id = (select auth.uid()) or public.academy_is_admin())
with check (user_id = (select auth.uid()) or public.academy_is_admin());

create policy "roles_read_self_or_admin" on public.academy_user_roles
for select to authenticated using (user_id = (select auth.uid()) or public.academy_is_admin());
-- No client-side role writes. Admin role grants are performed by a protected server operation.

create policy "languages_read_active" on public.academy_languages
for select to anon, authenticated using (is_active or public.academy_is_admin());
create policy "languages_admin_all" on public.academy_languages
for all to authenticated using (public.academy_is_admin()) with check (public.academy_is_admin());

create policy "levels_read_all" on public.academy_levels
for select to anon, authenticated using (true);
create policy "levels_admin_all" on public.academy_levels
for all to authenticated using (public.academy_is_admin()) with check (public.academy_is_admin());

create policy "courses_read_published" on public.academy_courses
for select to anon, authenticated using (status='published' or public.academy_is_admin());
create policy "courses_admin_all" on public.academy_courses
for all to authenticated using (public.academy_is_admin()) with check (public.academy_is_admin());

create policy "lessons_read_published" on public.academy_lessons
for select to anon, authenticated using (
  status='published' and exists (
    select 1 from public.academy_courses c
    where c.id=course_id and c.status='published'
  )
  or public.academy_is_admin()
);
create policy "lessons_admin_all" on public.academy_lessons
for all to authenticated using (public.academy_is_admin()) with check (public.academy_is_admin());

create policy "attachments_read_published" on public.academy_lesson_attachments
for select to anon, authenticated using (
  exists (
    select 1 from public.academy_lessons l
    join public.academy_courses c on c.id=l.course_id
    where l.id=lesson_id and l.status='published' and c.status='published'
  ) or public.academy_is_admin()
);
create policy "attachments_admin_all" on public.academy_lesson_attachments
for all to authenticated using (public.academy_is_admin()) with check (public.academy_is_admin());

create policy "progress_read_self_or_admin" on public.academy_lesson_progress
for select to authenticated using (user_id=(select auth.uid()) or public.academy_is_admin());
create policy "progress_insert_self" on public.academy_lesson_progress
for insert to authenticated with check (
  user_id=(select auth.uid()) and exists (
    select 1 from public.academy_lessons l
    join public.academy_courses c on c.id=l.course_id
    where l.id=lesson_id and l.status='published' and c.status='published'
  )
);
create policy "progress_update_self" on public.academy_lesson_progress
for update to authenticated using (user_id=(select auth.uid()))
with check (
  user_id=(select auth.uid()) and exists (
    select 1 from public.academy_lessons l
    join public.academy_courses c on c.id=l.course_id
    where l.id=lesson_id and l.status='published' and c.status='published'
  )
);
create policy "progress_admin_all" on public.academy_lesson_progress
for all to authenticated using (public.academy_is_admin()) with check (public.academy_is_admin());

create policy "quizzes_read_published" on public.academy_quizzes
for select to anon, authenticated using (status='published' or public.academy_is_admin());
create policy "quizzes_admin_all" on public.academy_quizzes
for all to authenticated using (public.academy_is_admin()) with check (public.academy_is_admin());

create policy "questions_read_published" on public.academy_quiz_questions
for select to anon, authenticated using (
  exists (select 1 from public.academy_quizzes q where q.id=quiz_id and q.status='published')
  or public.academy_is_admin()
);
create policy "questions_admin_all" on public.academy_quiz_questions
for all to authenticated using (public.academy_is_admin()) with check (public.academy_is_admin());

create policy "options_read_published" on public.academy_quiz_options
for select to anon, authenticated using (
  exists (
    select 1 from public.academy_quiz_questions q
    join public.academy_quizzes z on z.id=q.quiz_id
    where q.id=question_id and z.status='published'
  ) or public.academy_is_admin()
);
create policy "options_admin_all" on public.academy_quiz_options
for all to authenticated using (public.academy_is_admin()) with check (public.academy_is_admin());

create policy "correct_answers_admin_only" on public.academy_quiz_correct_answers
for all to authenticated using (public.academy_is_admin()) with check (public.academy_is_admin());

create policy "attempts_read_self_or_admin" on public.academy_quiz_attempts
for select to authenticated using (user_id=(select auth.uid()) or public.academy_is_admin());
create policy "attempts_admin_all" on public.academy_quiz_attempts
for all to authenticated using (public.academy_is_admin()) with check (public.academy_is_admin());

create policy "answers_read_self_or_admin" on public.academy_quiz_answers
for select to authenticated using (
  exists (select 1 from public.academy_quiz_attempts a where a.id=attempt_id and a.user_id=(select auth.uid()))
  or public.academy_is_admin()
);
create policy "answers_admin_all" on public.academy_quiz_answers
for all to authenticated using (public.academy_is_admin()) with check (public.academy_is_admin());

create policy "ads_read_active" on public.academy_ads
for select to anon, authenticated using (
  status='active' and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>now())
  or public.academy_is_admin()
);
create policy "ads_admin_all" on public.academy_ads
for all to authenticated using (public.academy_is_admin()) with check (public.academy_is_admin());

create policy "settings_read_public" on public.academy_site_settings
for select to anon, authenticated using (is_public or public.academy_is_admin());
create policy "settings_admin_all" on public.academy_site_settings
for all to authenticated using (public.academy_is_admin()) with check (public.academy_is_admin());

create policy "activity_logs_admin_read" on public.academy_activity_logs
for select to authenticated using (public.academy_is_admin());
create policy "activity_logs_admin_insert" on public.academy_activity_logs
for insert to authenticated with check (actor_user_id=(select auth.uid()) and public.academy_is_admin());

-- 10) Grants
grant usage on schema public to anon, authenticated;
grant select on public.academy_languages, public.academy_levels, public.academy_courses, public.academy_lessons,
  public.academy_lesson_attachments, public.academy_quizzes, public.academy_quiz_questions,
  public.academy_quiz_options, public.academy_ads, public.academy_site_settings to anon, authenticated;
grant select, update on public.academy_profiles to authenticated;
grant select on public.academy_user_roles to authenticated;
grant insert, select, update on public.academy_lesson_progress to authenticated;
grant select on public.academy_quiz_attempts, public.academy_quiz_answers to authenticated;
-- Catalog records are archived, not hard-deleted, so student history remains intact.
grant select, insert, update on public.academy_languages, public.academy_levels, public.academy_courses,
  public.academy_lessons to authenticated;
grant select, insert, update, delete on public.academy_lesson_attachments, public.academy_quizzes,
  public.academy_quiz_questions, public.academy_quiz_options, public.academy_quiz_correct_answers,
  public.academy_ads, public.academy_site_settings to authenticated;
grant select, insert on public.academy_activity_logs to authenticated;

-- 11) Secure quiz submission: answer keys never need to be exposed to the browser.
create or replace function public.academy_submit_quiz(p_quiz_id uuid, p_answers jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_attempt uuid := gen_random_uuid();
  v_max numeric(8,2) := 0;
  v_score numeric(8,2) := 0;
  v_percent integer := 0;
  v_pass integer := 0;
  q record;
  v_selected uuid;
  v_correct uuid;
  v_awarded numeric(8,2);
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if jsonb_typeof(p_answers) <> 'array' then raise exception 'Answers must be an array'; end if;
  if not exists (select 1 from public.academy_quizzes where id=p_quiz_id and status='published') then
    raise exception 'Quiz is not available';
  end if;

  select pass_percent into v_pass from public.academy_quizzes where id=p_quiz_id;
  for q in select id, points from public.academy_quiz_questions where quiz_id=p_quiz_id loop
    v_max := v_max + q.points;
    v_selected := null;
    select (item->>'option_id')::uuid into v_selected
    from jsonb_array_elements(p_answers) as a(item)
    where item->>'question_id'=q.id::text
    limit 1;
    select option_id into v_correct from public.academy_quiz_correct_answers where question_id=q.id;
    v_awarded := case when v_selected is not null and v_selected=v_correct then q.points else 0 end;
    v_score := v_score + v_awarded;
  end loop;

  if v_max <= 0 then raise exception 'Quiz has no questions'; end if;
  v_percent := round((v_score / v_max) * 100)::integer;

  insert into public.academy_quiz_attempts(id,quiz_id,user_id,score,max_score,percent,passed)
  values(v_attempt,p_quiz_id,v_user,v_score,v_max,v_percent,v_percent>=v_pass);

  for q in select id from public.academy_quiz_questions where quiz_id=p_quiz_id loop
    v_selected := null;
    select (item->>'option_id')::uuid into v_selected
    from jsonb_array_elements(p_answers) as a(item)
    where item->>'question_id'=q.id::text
    limit 1;
    select option_id into v_correct from public.academy_quiz_correct_answers where question_id=q.id;
    insert into public.academy_quiz_answers(attempt_id,question_id,selected_option_id,is_correct,awarded_points)
    values(v_attempt,q.id,v_selected,(v_selected is not null and v_selected=v_correct),
      case when v_selected is not null and v_selected=v_correct
      then (select points from public.academy_quiz_questions where id=q.id) else 0 end);
  end loop;

  return jsonb_build_object('attempt_id',v_attempt,'score',v_score,'max_score',v_max,'percent',v_percent,'passed',v_percent>=v_pass);
end;
$$;

revoke all on function public.academy_submit_quiz(uuid,jsonb) from public, anon;
grant execute on function public.academy_submit_quiz(uuid,jsonb) to authenticated;

-- 12) Storage: public lesson media, uploads/deletes restricted to admins.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('academy-media','academy-media',true,52428800,
  array['image/jpeg','image/png','image/webp','image/gif','video/mp4','application/pdf','text/plain','application/zip'])
on conflict (id) do update set public=true, file_size_limit=excluded.file_size_limit, allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "academy_media_public_read" on storage.objects;
create policy "academy_media_public_read" on storage.objects
for select to anon, authenticated using (bucket_id='academy-media');
drop policy if exists "academy_media_admin_insert" on storage.objects;
create policy "academy_media_admin_insert" on storage.objects
for insert to authenticated with check (bucket_id='academy-media' and public.academy_is_admin());
drop policy if exists "academy_media_admin_update" on storage.objects;
create policy "academy_media_admin_update" on storage.objects
for update to authenticated using (bucket_id='academy-media' and public.academy_is_admin())
with check (bucket_id='academy-media' and public.academy_is_admin());
drop policy if exists "academy_media_admin_delete" on storage.objects;
create policy "academy_media_admin_delete" on storage.objects
for delete to authenticated using (bucket_id='academy-media' and public.academy_is_admin());
 
-- Student profile photos: public read, each authenticated user manages only their own folder.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('academy-avatars','academy-avatars',false,2097152,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "academy_avatars_public_read" on storage.objects;
drop policy if exists "academy_avatars_owner_read" on storage.objects;
create policy "academy_avatars_owner_read" on storage.objects
for select to authenticated using (
 bucket_id='academy-avatars' and
 ((storage.foldername(name))[1]=(select auth.uid())::text or public.academy_is_admin())
);
drop policy if exists "academy_avatars_owner_insert" on storage.objects;
create policy "academy_avatars_owner_insert" on storage.objects
for insert to authenticated with check (bucket_id='academy-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "academy_avatars_owner_update" on storage.objects;
create policy "academy_avatars_owner_update" on storage.objects
for update to authenticated using (bucket_id='academy-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text)
with check (bucket_id='academy-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "academy_avatars_owner_delete" on storage.objects;
create policy "academy_avatars_owner_delete" on storage.objects
for delete to authenticated using (bucket_id='academy-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);


-- 13) Initial catalog: 3 languages, 3 levels, 9 independent courses.
insert into public.academy_languages(id,name,slug,description,sort_order) values
('html','HTML','html','ساختار و معنای صفحات وب',1),
('css','CSS','css','طراحی و چیدمان صفحات وب',2),
('javascript','JavaScript','javascript','برنامه‌نویسی و تعامل در وب',3)
on conflict (id) do nothing;

insert into public.academy_levels(id,name,slug,sort_order,description) values
('beginner','مقدماتی','beginner',1,'شروع از پایه و یادگیری مفاهیم اصلی'),
('intermediate','متوسط','intermediate',2,'کار با مفاهیم کاربردی و ساخت پروژه'),
('advanced','پیشرفته','advanced',3,'معماری، بهینه‌سازی و پروژه‌های کامل')
on conflict (id) do nothing;

insert into public.academy_courses(id,language_id,level_id,title,slug,description,status,sort_order) values
('html','html','beginner','HTML مقدماتی','html-beginner','ساختار صفحات وب را از پایه یاد بگیر.','published',1),
('html-intermediate','html','intermediate','HTML متوسط','html-intermediate','فرم‌ها، عناصر معنایی، جدول‌ها و دسترس‌پذیری.','draft',2),
('html-advanced','html','advanced','HTML پیشرفته','html-advanced','استانداردها، دسترس‌پذیری و ساختار حرفه‌ای پروژه‌ها.','draft',3),
('css','css','beginner','CSS مقدماتی','css-beginner','رنگ، فاصله، تایپوگرافی و چیدمان را یاد بگیر.','published',1),
('css-intermediate','css','intermediate','CSS متوسط','css-intermediate','Flexbox، Grid، Responsive و انیمیشن.','draft',2),
('css-advanced','css','advanced','CSS پیشرفته','css-advanced','معماری CSS، طراحی سیستم و بهینه‌سازی.','draft',3),
('js','javascript','beginner','JavaScript مقدماتی','javascript-beginner','مبانی برنامه‌نویسی و تعامل با صفحه وب.','published',1),
('js-intermediate','javascript','intermediate','JavaScript متوسط','javascript-intermediate','DOM، آرایه‌ها، اشیا و مدیریت رویدادها.','draft',2),
('js-advanced','javascript','advanced','JavaScript پیشرفته','javascript-advanced','Async، API، امنیت و پروژه‌های واقعی.','draft',3)
on conflict (id) do nothing;

-- NEXORA FORGE ACADEMY INSTALL — PART 2/21
-- Run this file in order. Each part commits independently.

begin;


-- 14) Import the existing 58 beginner lessons without overwriting future edits.
with seed as (
  select $academy_seed$[{"id":"html:0","course_id":"html","title":"HTML چیست؟","content_html":"<p>HTML مخفف HyperText Markup Language است. با آن ساختار محتوای یک صفحه وب را مشخص می‌کنیم؛ مثلاً عنوان، پاراگراف، تصویر و لینک.</p><ul><li>HTML زبان نشانه‌گذاری است، نه زبان برنامه‌نویسی.</li><li>مرورگر تگ‌ها را می‌خواند و محتوا را نمایش می‌دهد.</li></ul>","starter_code":"<h1>سلام دنیا</h1>\n<p>این اولین صفحه من است.</p>","exercise":"یک صفحه ساده بساز که عنوان «آکادمی من» و یک پاراگراف معرفی داشته باشد.","sort_order":0},{"id":"html:1","course_id":"html","title":"ساختار استاندارد صفحه","content_html":"<p>هر سند HTML با اعلام نوع سند شروع می‌شود. عنصر html ریشه صفحه است، head اطلاعات صفحه را نگه می‌دارد و body محتوای قابل مشاهده را.</p>","starter_code":"<!doctype html>\n<html lang=\"fa\">\n<head>\n  <meta charset=\"UTF-8\">\n  <title>صفحه من</title>\n</head>\n<body>\n  <h1>سلام!</h1>\n</body>\n</html>","exercise":"یک سند کامل HTML با lang فارسی، charset، عنوان صفحه و بخش body بساز.","sort_order":1},{"id":"html:2","course_id":"html","title":"عنوان‌ها و پاراگراف‌ها","content_html":"<p>برای عنوان‌ها از h1 تا h6 استفاده می‌شود. تگ p برای پاراگراف است. عنوان‌ها باید ترتیب منطقی داشته باشند و فقط برای بزرگ کردن متن استفاده نشوند.</p>","starter_code":"<h1>عنوان اصلی</h1>\n<h2>عنوان بخش</h2>\n<p>این یک پاراگراف است.</p>","exercise":"برای یک مقاله، یک عنوان اصلی، دو عنوان فرعی و سه پاراگراف ایجاد کن.","sort_order":2},{"id":"html:3","course_id":"html","title":"لینک‌ها","content_html":"<p>تگ a برای ساخت لینک است. آدرس مقصد را در ویژگی href قرار می‌دهیم. برای باز کردن لینک در زبانه جدید از target استفاده می‌شود و بهتر است rel نیز تنظیم شود.</p>","starter_code":"<a href=\"https://example.com\">بازدید از سایت</a>\n<a href=\"https://example.com\" target=\"_blank\" rel=\"noopener\">در زبانه جدید</a>","exercise":"یک لینک به سایت دلخواه و یک لینک که در زبانه جدید باز شود بساز.","sort_order":3},{"id":"html:4","course_id":"html","title":"تصاویر و متن جایگزین","content_html":"<p>تگ img تصویر را نمایش می‌دهد. ویژگی src مسیر تصویر و alt توضیح متنی تصویر است. متن alt برای دسترس‌پذیری و زمانی که تصویر بارگذاری نشود اهمیت دارد.</p>","starter_code":"<img src=\"photo.jpg\" alt=\"نمایی از طبیعت\" width=\"300\">","exercise":"یک تصویر اضافه کن و برای آن alt توصیفی و عرض ۲۵۰ پیکسل تعیین کن.","sort_order":4},{"id":"html:5","course_id":"html","title":"فهرست‌ها","content_html":"<p>برای فهرست بدون ترتیب از ul و برای فهرست شماره‌دار از ol استفاده کن. هر مورد فهرست داخل li قرار می‌گیرد.</p>","starter_code":"<ul>\n  <li>HTML</li>\n  <li>CSS</li>\n</ul>\n<ol>\n  <li>یادگیری</li>\n  <li>تمرین</li>\n</ol>","exercise":"فهرست شماره‌دار سه مرحله‌ای و فهرست بدون ترتیب سه مهارت بساز.","sort_order":5},{"id":"html:6","course_id":"html","title":"عناصر معنایی HTML","content_html":"<p>عناصر معنایی نامی دارند که نقش محتوا را روشن می‌کند. header برای سربرگ، nav برای ناوبری، main برای محتوای اصلی، section برای بخش و footer برای پابرگ مناسب است.</p><p>از این عناصر به‌جای استفاده بی‌دلیل از div استفاده کن تا ساختار صفحه برای مرورگرها و ابزارهای کمکی قابل فهم‌تر باشد.</p>","starter_code":"<header>سربرگ سایت</header>\n<nav><a href='#home'>خانه</a></nav>\n<main>\n  <section><h2>درباره ما</h2><p>متن بخش</p></section>\n</main>\n<footer>پابرگ</footer>","exercise":"صفحه‌ای با header، nav، main، section و footer بساز.","sort_order":6},{"id":"html:7","course_id":"html","title":"ساخت فرم","content_html":"<p>فرم‌ها اطلاعات را از کاربر می‌گیرند. عنصر form محدوده فرم را می‌سازد و label عنوان هر ورودی را مشخص می‌کند. ویژگی for در label باید با id ورودی برابر باشد.</p>","starter_code":"<form>\n  <label for='fullname'>نام:</label>\n  <input id='fullname' name='fullname'>\n  <button type='submit'>ارسال</button>\n</form>","exercise":"فرمی با ورودی نام و دکمه ارسال بساز و label مرتبط اضافه کن.","sort_order":7},{"id":"html:8","course_id":"html","title":"انواع ورودی‌ها","content_html":"<p>ویژگی type نوع ورودی را مشخص می‌کند. email برای ایمیل، password برای رمز، number برای عدد، date برای تاریخ و checkbox برای انتخاب روشن/خاموش کاربرد دارند.</p><p>برای هر ورودی یک label قابل کلیک فراهم کن و در صورت نیاز از required استفاده کن.</p>","starter_code":"<label for='email'>ایمیل</label>\n<input id='email' type='email' required>\n<label for='age'>سن</label>\n<input id='age' type='number' min='1' max='120'>\n<label><input type='checkbox'> قوانین را می‌پذیرم</label>","exercise":"ورودی ایمیل، رمز عبور، تاریخ و checkbox ایجاد کن.","sort_order":8},{"id":"html:9","course_id":"html","title":"دکمه‌ها و ارسال فرم","content_html":"<p>دکمه داخل فرم به‌طور پیش‌فرض ممکن است فرم را ارسال کند. type='submit' برای ارسال و type='button' برای عملیاتی که نباید فرم را ارسال کند استفاده می‌شود.</p>","starter_code":"<form action='/register' method='post'>\n  <input name='username' required>\n  <button type='submit'>ثبت‌نام</button>\n  <button type='button' onclick='alert('سلام')'>نمایش پیام</button>\n</form>","exercise":"فرمی بساز که دکمه ارسال و دکمه عادی با عملکرد متفاوت داشته باشد.","sort_order":9},{"id":"html:10","course_id":"html","title":"جدول‌ها","content_html":"<p>برای داده‌های جدولی از table استفاده کن. tr ردیف، th عنوان ستون و td خانه داده است. caption عنوان جدول را می‌دهد و thead و tbody بخش‌های جدول را جدا می‌کنند.</p>","starter_code":"<table>\n  <caption>نمره‌ها</caption>\n  <thead><tr><th>نام</th><th>نمره</th></tr></thead>\n  <tbody><tr><td>سارا</td><td>۱۸</td></tr></tbody>\n</table>","exercise":"جدولی با سه ستون نام، درس و نمره و حداقل دو ردیف داده بساز.","sort_order":10},{"id":"html:11","course_id":"html","title":"صدا و ویدیو","content_html":"<p>عناصر audio و video برای پخش رسانه هستند. ویژگی controls کنترل‌های پخش را نمایش می‌دهد. می‌توان چند source با قالب‌های متفاوت تعریف کرد تا مرورگر گزینه سازگار را انتخاب کند.</p>","starter_code":"<video controls width='320'>\n  <source src='movie.mp4' type='video/mp4'>\n  مرورگر شما از ویدیو پشتیبانی نمی‌کند.\n</video>\n<audio controls src='sound.mp3'></audio>","exercise":"یک عنصر video با controls و متن جایگزین در صورت پشتیبانی‌نشدن اضافه کن.","sort_order":11},{"id":"html:12","course_id":"html","title":"ویژگی‌های عمومی و data","content_html":"<p>ویژگی‌هایی مانند id و class روی عناصر مختلف قابل استفاده‌اند. id باید در صفحه یکتا باشد؛ class برای گروهی از عناصر مناسب است. ویژگی‌های data-* برای نگهداری داده‌های سفارشی در HTML هستند.</p>","starter_code":"<article id='lesson-1' class='card' data-level='beginner'>\n  <h2>درس اول</h2>\n  <p>شروع یادگیری</p>\n</article>","exercise":"برای یک کارت id، class و data-level تعریف کن.","sort_order":12},{"id":"html:13","course_id":"html","title":"div و span","content_html":"<p>div یک ظرف بلوکی عمومی و span یک ظرف درون‌خطی عمومی است. وقتی عنصر معنایی مناسب وجود ندارد، از آن‌ها برای گروه‌بندی و استایل‌دهی استفاده کن؛ نه اینکه همه صفحه را با div بسازی.</p>","starter_code":"<div class='profile'>\n  <h2>مشخصات</h2>\n  <p>نام: <span class='highlight'>علی</span></p>\n</div>","exercise":"با div دو بخش بساز و با span یک کلمه را درون پاراگراف مشخص کن.","sort_order":13},{"id":"html:14","course_id":"html","title":"دسترس‌پذیری و HTML درست","content_html":"<p>برای دسترس‌پذیری، تصویر معنادار باید alt مناسب داشته باشد، فرم‌ها label داشته باشند، ترتیب عنوان‌ها منطقی باشد و لینک‌ها متن توصیفی داشته باشند. از عنصر درست برای کار درست استفاده کن.</p>","starter_code":"<img src='team.jpg' alt='اعضای تیم در جلسه کاری'>\n<h1>آموزش وب</h1>\n<h2>درس‌های رایگان</h2>\n<a href='/courses'>مشاهده دوره‌های آموزشی</a>","exercise":"برای تصویر alt، برای ورودی label و برای دکمه متن واضح قرار بده.","sort_order":14},{"id":"css:0","course_id":"css","title":"CSS چیست؟","content_html":"<p>CSS مخفف Cascading Style Sheets است و ظاهر عناصر HTML را کنترل می‌کند؛ مانند رنگ، اندازه، فاصله و چیدمان.</p><p>قانون CSS از انتخابگر و مجموعه‌ای از ویژگی‌ها و مقدارها تشکیل می‌شود.</p>","starter_code":"h1 {\n  color: crimson;\n  font-size: 32px;\n}","exercise":"رنگ عنوان را قرمز و اندازه آن را ۳۲ پیکسل کن.","sort_order":0},{"id":"css:1","course_id":"css","title":"سه روش افزودن CSS","content_html":"<p>CSS را می‌توان در ویژگی style، داخل تگ style یا در فایل جداگانه با پسوند css نوشت. برای پروژه‌های واقعی، فایل جداگانه معمولاً نگهداری را ساده‌تر می‌کند.</p>","starter_code":"<!-- در فایل HTML -->\n<link rel=\"stylesheet\" href=\"style.css\">\n\n/* در فایل style.css */\nbody { font-family: Arial; }","exercise":"یک فایل style.css بساز و آن را به فایل HTML وصل کن.","sort_order":1},{"id":"css:2","course_id":"css","title":"انتخابگرها","content_html":"<p>انتخابگر مشخص می‌کند کدام عنصر استایل بگیرد. نام تگ، کلاس با نقطه و شناسه با # انتخابگرهای رایج هستند.</p>","starter_code":"p { color: #444; }\n.card { padding: 16px; }\n#main-title { color: red; }","exercise":"با انتخابگر تگ، کلاس و شناسه سه عنصر متفاوت را استایل بده.","sort_order":2},{"id":"css:3","course_id":"css","title":"رنگ و پس‌زمینه","content_html":"<p>رنگ را می‌توان با نام، کد HEX یا تابع rgb مشخص کرد. ویژگی background-color رنگ پس‌زمینه را تعیین می‌کند.</p>","starter_code":"body { background-color: #101018; }\nh1 { color: #ff303b; }\n.note { color: rgb(180,180,190); }","exercise":"برای صفحه پس‌زمینه تیره و برای متن رنگ روشن انتخاب کن.","sort_order":3},{"id":"css:4","course_id":"css","title":"مدل جعبه‌ای","content_html":"<p>هر عنصر در CSS مانند یک جعبه است: محتوا، padding، border و margin. استفاده از box-sizing: border-box محاسبه اندازه‌ها را قابل پیش‌بینی‌تر می‌کند.</p>","starter_code":"* { box-sizing: border-box; }\n.card {\n  padding: 20px;\n  border: 1px solid #ccc;\n  margin: 12px;\n}","exercise":"یک کارت با padding، border و margin بساز و box-sizing را تنظیم کن.","sort_order":4},{"id":"css:5","course_id":"css","title":"Flexbox و واکنش‌گرایی","content_html":"<p>Flexbox برای چیدمان یک‌بعدی کاربرد دارد. با media query می‌توان ظاهر صفحه را برای نمایشگرهای کوچک تغییر داد.</p>","starter_code":".row { display: flex; gap: 12px; }\n@media (max-width: 600px) {\n  .row { flex-direction: column; }\n}","exercise":"سه کارت را با Flexbox کنار هم بچین و در عرض کمتر از ۶۰۰ پیکسل ستونی کن.","sort_order":5},{"id":"css:6","course_id":"css","title":"آبشار و وراثت CSS","content_html":"<p>وقتی چند قانون روی یک عنصر اثر می‌گذارند، آبشار CSS با توجه به اهمیت، اختصاصیت و ترتیب قوانین تصمیم می‌گیرد کدام مقدار اعمال شود. بعضی ویژگی‌ها مانند color به فرزندان به ارث می‌رسند.</p>","starter_code":"body { color: #333; }\n.card { color: #b21e35; }\n.card p { color: inherit; }","exercise":"رنگ متن body را تعیین کن و رنگ یک عنصر فرزند را جداگانه تغییر بده.","sort_order":6},{"id":"css:7","course_id":"css","title":"اختصاصیت انتخابگرها","content_html":"<p>انتخابگر id معمولاً از class اختصاصی‌تر است و class از انتخابگر نام تگ اختصاصی‌تر. برای جلوگیری از پیچیدگی، تا حد ممکن از کلاس‌های قابل استفاده مجدد استفاده کن و به !important وابسته نشو.</p>","starter_code":"p { color: gray; }\n.note { color: crimson; }\n#intro { color: navy; }","exercise":"برای یک عنصر قانون تگ، کلاس و شناسه بنویس و نتیجه را مقایسه کن.","sort_order":7},{"id":"css:8","course_id":"css","title":"واحدهای اندازه‌گیری","content_html":"<p>px واحد ثابت، درصد نسبی به اندازه والد، em وابسته به اندازه فونت عنصر والد و rem وابسته به اندازه فونت ریشه است. برای اندازه‌های قابل تطبیق معمولاً rem و درصد انتخاب‌های مناسبی‌اند.</p>","starter_code":"html { font-size: 16px; }\nh1 { font-size: 2rem; }\n.container { width: 90%; max-width: 1100px; }\n.card { padding: 1em; }","exercise":"یک کارت با rem برای فونت و درصد برای عرض بساز.","sort_order":8},{"id":"css:9","course_id":"css","title":"فونت و خوانایی متن","content_html":"<p>با font-family نوع قلم، font-size اندازه، font-weight ضخامت و line-height فاصله خطوط را کنترل می‌کنی. برای متن فارسی، قلم مناسب و فاصله خطوط کافی خوانایی را بهتر می‌کند.</p>","starter_code":"body { font-family: Tahoma, Arial, sans-serif; }\np { font-size: 16px; line-height: 1.9; }\nh1 { font-weight: 800; }","exercise":"برای متن فارسی فونت مناسب، line-height و اندازه خوانا تنظیم کن.","sort_order":9},{"id":"css:10","course_id":"css","title":"display و جریان عناصر","content_html":"<p>display رفتار چیدمان عنصر را تعیین می‌کند. block تمام عرض در دسترس را می‌گیرد، inline در جریان متن قرار می‌گیرد، inline-block امکان تعیین ابعاد را می‌دهد و none عنصر را از چیدمان حذف می‌کند.</p>","starter_code":".badge { display: inline-block; padding: 6px 10px; }\n.hidden { display: none; }\n.card { display: block; }","exercise":"دو عنصر را با inline-block کنار هم قرار بده و تفاوت block را بررسی کن.","sort_order":10},{"id":"css:11","course_id":"css","title":"موقعیت‌دهی عناصر","content_html":"<p>position با مقادیر static، relative، absolute، fixed و sticky موقعیت عنصر را کنترل می‌کند. absolute نسبت به نزدیک‌ترین والد موقعیت‌دار محاسبه می‌شود؛ sticky هنگام پیمایش می‌تواند به لبه صفحه بچسبد.</p>","starter_code":".parent { position: relative; }\n.label { position: absolute; top: 8px; right: 8px; }\nheader { position: sticky; top: 0; }","exercise":"یک نشان کوچک را در گوشه بالای کارت با position قرار بده.","sort_order":11},{"id":"css:12","course_id":"css","title":"CSS Grid","content_html":"<p>Grid برای چیدمان دوبعدی ردیف و ستون مناسب است. با grid-template-columns ستون‌ها و با gap فاصله خانه‌ها را تعیین می‌کنی. repeat و minmax ساخت شبکه‌های منعطف را آسان می‌کنند.</p>","starter_code":".grid {\n  display: grid;\n  grid-template-columns: repeat(3, minmax(0, 1fr));\n  gap: 16px;\n}\n@media (max-width: 650px) {\n  .grid { grid-template-columns: 1fr; }\n}","exercise":"یک شبکه سه‌ستونه بساز و فاصله بین کارت‌ها را تنظیم کن.","sort_order":12},{"id":"css:13","course_id":"css","title":"شبه‌کلاس‌ها","content_html":"<p>شبه‌کلاس‌ها وضعیت عنصر را هدف می‌گیرند. :hover هنگام قرار گرفتن نشانگر، :focus هنگام دریافت تمرکز و :first-child برای اولین فرزند کاربرد دارند. برای کاربران صفحه‌کلید، حالت focus را حذف نکن.</p>","starter_code":"a:hover { color: crimson; }\ninput:focus { outline: 2px solid crimson; }\nli:first-child { font-weight: bold; }","exercise":"برای لینک حالت hover و برای ورودی حالت focus تعریف کن.","sort_order":13},{"id":"css:14","course_id":"css","title":"شبه‌عنصرها","content_html":"<p>شبه‌عنصرهایی مانند ::before و ::after بخشی مجازی برای نمایش تزئینات ایجاد می‌کنند. برای محتوای مهم و ضروری به آن‌ها تکیه نکن؛ چون هدف اصلی‌شان ارائه ظاهری است.</p>","starter_code":".title::after {\n  content: '';\n  display: block;\n  width: 50px;\n  height: 3px;\n  background: crimson;\n}","exercise":"با ::before یک نشان تزئینی پیش از عنوان ایجاد کن.","sort_order":14},{"id":"css:15","course_id":"css","title":"رنگ، شفافیت و سایه","content_html":"<p>برای رنگ می‌توان از HEX، rgb و hsl استفاده کرد. opacity شفافیت کل عنصر و box-shadow سایه جعبه را کنترل می‌کند. برای متن، کنتراست کافی با پس‌زمینه ضروری است.</p>","starter_code":".card {\n  color: #222;\n  background: rgba(255,255,255,.95);\n  box-shadow: 0 8px 24px rgba(0,0,0,.15);\n}","exercise":"برای کارت پس‌زمینه نیمه‌شفاف و سایه ملایم بساز.","sort_order":15},{"id":"css:16","course_id":"css","title":"انتقال و تبدیل","content_html":"<p>transition تغییر ویژگی را نرم می‌کند و transform عنصر را جابه‌جا، چرخان یا بزرگ و کوچک می‌کند. فقط ویژگی‌هایی را متحرک کن که تجربه کاربر را بهتر می‌کنند.</p>","starter_code":".button { transition: transform .2s, background .2s; }\n.button:hover { transform: translateY(-2px); }","exercise":"با hover کارت را کمی بزرگ کن و تغییر را با transition نرم کن.","sort_order":16},{"id":"css:17","course_id":"css","title":"متغیرهای CSS","content_html":"<p>متغیرهای سفارشی با دو خط تیره تعریف می‌شوند و با var خوانده می‌شوند. آن‌ها برای رنگ‌های برند، فاصله‌ها و تنظیمات مشترک بسیار مفیدند.</p>","starter_code":":root {\n  --brand: #e32636;\n  --space: 16px;\n}\n.button { background: var(--brand); padding: var(--space); }","exercise":"رنگ اصلی را در :root تعریف کن و در دو عنصر استفاده کن.","sort_order":17},{"id":"js:0","course_id":"js","title":"JavaScript چیست؟","content_html":"<p>JavaScript زبان برنامه‌نویسی است که می‌تواند به صفحه وب رفتار اضافه کند؛ مثل واکنش به کلیک، محاسبه و تغییر محتوا.</p>","starter_code":"console.log('سلام از JavaScript!');","exercise":"با console.log یک پیام خوش‌آمدگویی در کنسول نمایش بده.","sort_order":0},{"id":"js:1","course_id":"js","title":"متغیرها","content_html":"<p>برای نگهداری داده از let و const استفاده می‌کنیم. مقدار const دوباره به متغیر نسبت داده نمی‌شود؛ let برای مقداری است که ممکن است تغییر کند.</p>","starter_code":"const academy = 'NEXORA';\nlet lessons = 6;\nlessons = 7;\nconsole.log(academy, lessons);","exercise":"نام آکادمی را با const و تعداد درس‌ها را با let ذخیره و چاپ کن.","sort_order":1},{"id":"js:2","course_id":"js","title":"نوع داده‌ها","content_html":"<p>رشته، عدد، مقدار بولی، آرایه و شیء از انواع داده رایج هستند. typeof نوع بسیاری از مقدارها را نشان می‌دهد.</p>","starter_code":"const name = 'Ali';\nconst age = 18;\nconst active = true;\nconsole.log(typeof name);\nconsole.log(typeof age);","exercise":"یک رشته، عدد، مقدار بولی، آرایه و شیء بساز و نوع داده‌ها را بررسی کن.","sort_order":2},{"id":"js:3","course_id":"js","title":"شرط‌ها","content_html":"<p>با if و else می‌توان بر اساس درست یا نادرست بودن یک شرط مسیرهای متفاوتی اجرا کرد. برای مقایسه مقدار و نوع، معمولاً از === استفاده کن.</p>","starter_code":"const score = 75;\nif (score >= 50) {\n  console.log('قبول شدی');\n} else {\n  console.log('بیشتر تمرین کن');\n}","exercise":"بر اساس نمره، پیام قبولی یا نیاز به تمرین نمایش بده.","sort_order":3},{"id":"js:4","course_id":"js","title":"تابع‌ها","content_html":"<p>تابع مجموعه‌ای از دستورهاست که می‌توان آن را دوباره اجرا کرد. تابع می‌تواند ورودی بگیرد و با return نتیجه برگرداند.</p>","starter_code":"function greet(name) {\n  return 'سلام ' + name;\n}\nconsole.log(greet('دوست من'));","exercise":"تابعی بنویس که نام را بگیرد و پیام خوش‌آمدگویی برگرداند.","sort_order":4},{"id":"js:5","course_id":"js","title":"رویداد کلیک","content_html":"<p>رویدادها به ما اجازه می‌دهند به کار کاربر واکنش نشان دهیم. در این مثال با کلیک روی دکمه، متن صفحه تغییر می‌کند.</p>","starter_code":"<button id=\"helloBtn\">کلیک کن</button>\n<p id=\"message\"></p>\n<script>\ndocument.querySelector('#helloBtn').addEventListener('click', () => {\n document.querySelector('#message').textContent = 'آفرین!';\n});\n<\\/script>","exercise":"با کلیک روی دکمه، متن یک پاراگراف را تغییر بده.","sort_order":5},{"id":"js:6","course_id":"js","title":"عملگرهای ریاضی و مقایسه","content_html":"<p>عملگرهای +، -، * و / محاسبه می‌کنند. عملگرهای ===، !==، بزرگ‌تر و کوچک‌تر برای مقایسه‌اند. برای مقایسه مقدار و نوع، از مقایسه سخت‌گیرانه استفاده کن.</p>","starter_code":"const price = 120;\nconst count = 3;\nconsole.log(price * count);\nconsole.log(count >= 2);\nconsole.log(5 === '5'); // false","exercise":"دو عدد را با عملگرهای +، * و === مقایسه و نتیجه را چاپ کن.","sort_order":6},{"id":"js:7","course_id":"js","title":"عملگرهای منطقی","content_html":"<p>عملگر && وقتی هر دو شرط درست باشند نتیجه درست می‌دهد؛ || وقتی دست‌کم یکی درست باشد و ! مقدار منطقی را برعکس می‌کند.</p>","starter_code":"const age = 20;\nconst hasTicket = true;\nconsole.log(age >= 18 && hasTicket);\nconsole.log(!hasTicket);","exercise":"شرطی بنویس که فقط در صورت درست بودن دو شرط پیام دسترسی بدهد.","sort_order":7},{"id":"js:8","course_id":"js","title":"حلقه for","content_html":"<p>حلقه for برای تکرار تعداد مشخصی از دفعات مناسب است. بخش آغاز، شرط ادامه و تغییر شمارنده در سرآیند حلقه نوشته می‌شوند.</p>","starter_code":"for (let i = 1; i <= 5; i++) {\n  console.log('شماره ' + i);\n}","exercise":"اعداد ۱ تا ۱۰ را با حلقه for در کنسول چاپ کن.","sort_order":8},{"id":"js:9","course_id":"js","title":"حلقه while و کنترل تکرار","content_html":"<p>while تا زمانی اجرا می‌شود که شرط درست باشد. مراقب باش شرط در نهایت نادرست شود؛ وگرنه حلقه بی‌نهایت ایجاد می‌شود. break حلقه را متوقف و continue به تکرار بعدی می‌رود.</p>","starter_code":"let number = 1;\nwhile (number <= 5) {\n  console.log(number);\n  number++;\n}","exercise":"با while تا رسیدن شمارنده به ۵ ادامه بده و سپس متوقف شو.","sort_order":9},{"id":"js:10","course_id":"js","title":"آرایه‌ها","content_html":"<p>آرایه چند مقدار را در یک متغیر نگه می‌دارد. اندیس آرایه از صفر شروع می‌شود؛ length تعداد عناصر را می‌دهد و می‌توان با اندیس به یک عضو دسترسی داشت.</p>","starter_code":"const skills = ['HTML', 'CSS', 'JavaScript'];\nconsole.log(skills[0]);\nconsole.log(skills.length);","exercise":"آرایه‌ای از سه نام درس بساز و عضو اول و آخر را چاپ کن.","sort_order":10},{"id":"js:11","course_id":"js","title":"افزودن و حذف از آرایه","content_html":"<p>push عضو را به انتها اضافه و pop عضو آخر را حذف می‌کند. unshift به ابتدا اضافه و shift عضو اول را حذف می‌کند. این روش‌ها آرایه اصلی را تغییر می‌دهند.</p>","starter_code":"const tasks = ['مطالعه'];\ntasks.push('تمرین');\ntasks.pop();\nconsole.log(tasks);","exercise":"یک درس به انتهای آرایه اضافه و سپس آخرین عضو را حذف کن.","sort_order":11},{"id":"js:12","course_id":"js","title":"پیمایش آرایه با forEach","content_html":"<p>forEach یک تابع را برای هر عضو آرایه اجرا می‌کند. این روش برای انجام کاری روی هر عضو مناسب است و آرایه جدید برنمی‌گرداند.</p>","starter_code":"const names = ['سارا', 'علی', 'مینا'];\nnames.forEach(name => {\n  console.log('سلام ' + name);\n});","exercise":"نام هر عضو آرایه را با forEach در کنسول چاپ کن.","sort_order":12},{"id":"js:13","course_id":"js","title":"متد map و filter","content_html":"<p>map از هر عضو آرایه مقداری می‌سازد و آرایه جدید برمی‌گرداند. filter فقط عضوهایی را نگه می‌دارد که شرط را بگذرانند؛ هر دو آرایه اصلی را دست‌نخورده می‌گذارند.</p>","starter_code":"const numbers = [1, 2, 3, 4];\nconst doubled = numbers.map(n => n * 2);\nconst even = numbers.filter(n => n % 2 === 0);\nconsole.log(doubled, even);","exercise":"از آرایه نمره‌ها با map نمره‌ها را دو برابر و با filter نمره‌های بالای ۵۰ را جدا کن.","sort_order":13},{"id":"js:14","course_id":"js","title":"شیءها","content_html":"<p>شیء داده‌ها را به شکل ویژگی و مقدار نگه می‌دارد. به ویژگی‌ها با نقطه یا براکت دسترسی پیدا می‌کنی. برای داده‌های مرتبط، شیء ساختار روشنی ایجاد می‌کند.</p>","starter_code":"const student = {\n  name: 'مریم',\n  age: 19,\n  active: true\n};\nconsole.log(student.name);\nstudent.age = 20;","exercise":"شیئی برای دانش‌آموز با name، age و course بساز و مقدارها را بخوان.","sort_order":14},{"id":"js:15","course_id":"js","title":"توابع پیکانی و پارامتر پیش‌فرض","content_html":"<p>تابع پیکانی شکل کوتاه‌تری برای تعریف تابع است. می‌توان برای پارامتر مقدار پیش‌فرض گذاشت تا اگر ورودی ارسال نشد از آن استفاده شود.</p>","starter_code":"const greet = (name = 'دوست') => {\n  return 'سلام ' + name;\n};\nconsole.log(greet());\nconsole.log(greet('سارا'));","exercise":"تابع پیکانی بساز که اگر نامی داده نشد، مقدار پیش‌فرض استفاده کند.","sort_order":15},{"id":"js:16","course_id":"js","title":"انتخاب عناصر صفحه با DOM","content_html":"<p>DOM نمای درختی صفحه است. با querySelector اولین عنصر مطابق انتخابگر و با querySelectorAll همه موارد مطابق را پیدا می‌کنی. سپس می‌توان متن یا ویژگی‌های آن‌ها را تغییر داد.</p>","starter_code":"const heading = document.querySelector('h1');\nif (heading) {\n  heading.textContent = 'عنوان تازه';\n}","exercise":"با querySelector عنوان صفحه را پیدا کن و متنش را تغییر بده.","sort_order":16},{"id":"js:17","course_id":"js","title":"رویدادها و event","content_html":"<p>با addEventListener به رویدادهایی مثل click و input گوش می‌دهیم. شیء event اطلاعات رویداد را دارد و currentTarget عنصری را نشان می‌دهد که شنونده روی آن نصب شده است.</p>","starter_code":"const button = document.querySelector('button');\nbutton.addEventListener('click', event => {\n  event.currentTarget.textContent = 'کلیک شد';\n});","exercise":"رویداد کلیک را ثبت کن و نوع رویداد را از شیء event بخوان.","sort_order":17},{"id":"js:18","course_id":"js","title":"کار با فرم و ورودی کاربر","content_html":"<p>برای دریافت مقدار ورودی از value استفاده کن. رویداد submit فرم را می‌توان کنترل کرد و با preventDefault از بارگذاری دوباره صفحه جلوگیری کرد. داده کاربر را قبل از استفاده بررسی کن.</p>","starter_code":"const form = document.querySelector('form');\nform.addEventListener('submit', event => {\n  event.preventDefault();\n  const name = document.querySelector('#name').value.trim();\n  console.log(name);\n});","exercise":"با submit مقدار ورودی را بخوان و از بارگذاری دوباره صفحه جلوگیری کن.","sort_order":18},{"id":"js:19","course_id":"js","title":"اعتبارسنجی ساده فرم","content_html":"<p>اعتبارسنجی یعنی بررسی اینکه داده ورودی قابل قبول است. برای ایمیل و فیلدهای ضروری می‌توان از ویژگی‌های HTML مثل required و type استفاده کرد و در JavaScript پیام دقیق‌تری نمایش داد.</p>","starter_code":"const username = 'Nexora';\nif (username.trim().length < 3) {\n  console.log('نام باید حداقل ۳ حرف باشد');\n} else {\n  console.log('نام معتبر است');\n}","exercise":"بررسی کن ورودی خالی نباشد و ایمیل شامل @ باشد.","sort_order":19},{"id":"js:20","course_id":"js","title":"ذخیره‌سازی در localStorage","content_html":"<p>localStorage داده متنی را در مرورگر همان دستگاه نگه می‌دارد و پس از بستن صفحه باقی می‌ماند. این داده به‌صورت خودکار بین دستگاه‌ها همگام نمی‌شود و برای رمز عبور یا اطلاعات حساس مناسب نیست.</p>","starter_code":"localStorage.setItem('theme', 'dark');\nconst theme = localStorage.getItem('theme');\nconsole.log(theme);\n// localStorage.removeItem('theme');","exercise":"نام کاربر را ذخیره کن و در بارگذاری بعدی بخوان.","sort_order":20},{"id":"js:21","course_id":"js","title":"JSON و تبدیل داده","content_html":"<p>JSON قالبی متنی برای تبادل داده است. JSON.stringify شیء را به متن تبدیل می‌کند و JSON.parse متن معتبر JSON را به داده JavaScript تبدیل می‌کند.</p>","starter_code":"const user = { name: 'Ali', level: 1 };\nconst text = JSON.stringify(user);\nconst copy = JSON.parse(text);\nconsole.log(copy.name);","exercise":"یک شیء را با JSON.stringify به متن و با JSON.parse به شیء تبدیل کن.","sort_order":21},{"id":"js:22","course_id":"js","title":"مدیریت خطا با try و catch","content_html":"<p>گاهی اجرای یک دستور با خطا روبه‌رو می‌شود. try کد پرخطر را در بر می‌گیرد و catch خطا را دریافت می‌کند تا برنامه بتواند واکنش کنترل‌شده نشان دهد.</p>","starter_code":"try {\n  const data = JSON.parse('{bad json}');\n  console.log(data);\n} catch (error) {\n  console.log('داده معتبر نیست');\n}","exercise":"تبدیل یک متن نامعتبر JSON را در try/catch قرار بده و پیام خطا را نمایش بده.","sort_order":22},{"id":"js:23","course_id":"js","title":"تاریخ و زمان","content_html":"<p>شیء Date برای کار با تاریخ و زمان استفاده می‌شود. getFullYear سال و getMonth ماه را از صفر تا یازده برمی‌گرداند؛ برای نمایش ماه انسانی معمولاً یک واحد اضافه می‌کنیم.</p>","starter_code":"const now = new Date();\nconsole.log(now.getFullYear());\nconsole.log(now.getMonth() + 1);\nconsole.log(now.toLocaleDateString('fa-IR'));","exercise":"تاریخ و ساعت فعلی را با شیء Date نمایش بده.","sort_order":23},{"id":"js:24","course_id":"js","title":"پروژه کوچک: شمارنده","content_html":"<p>در این تمرین یک شمارنده می‌سازیم. متغیر count وضعیت را نگه می‌دارد و هر کلیک مقدار را یک واحد افزایش می‌دهد. در پروژه واقعی، HTML دکمه و خروجی باید در صفحه وجود داشته باشند.</p>","starter_code":"let count = 0;\nconst button = document.querySelector('#plus');\nconst output = document.querySelector('#count');\nbutton.addEventListener('click', () => {\n  count++;\n  output.textContent = count;\n});","exercise":"شمارنده‌ای با دکمه‌های افزایش، کاهش و صفرکردن بساز.","sort_order":24}]$academy_seed$::jsonb as payload
),
rows as (
  select * from jsonb_to_recordset((select payload from seed)) as x(
    id text, course_id text, title text, content_html text,
    starter_code text, exercise text, sort_order integer
  )
)
insert into public.academy_lessons(id,course_id,title,content_html,starter_code,exercise,sort_order,status)
select id,course_id,title,content_html,starter_code,exercise,sort_order,'published'
from rows
on conflict (id) do nothing;

-- Public defaults. These contain no secrets.
insert into public.academy_site_settings(key,value,is_public) values
('brand',jsonb_build_object('name','NEXORA FORGE ACADEMY','slogan','BUILD THE FUTURE','direction','rtl','language','fa'),true),
('registration',jsonb_build_object('enabled',true,'guest_access',true,'email_confirmation',true),true),
('catalog',jsonb_build_object('show_draft_courses',false),true)
on conflict (key) do nothing;


-- Super-admin controlled role management; no browser-side role table writes.
create or replace function public.academy_set_user_role(
  p_user_id uuid,
  p_role text,
  p_enabled boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.academy_is_super_admin() then
    raise exception 'Super-admin permission required';
  end if;
  if p_role not in ('student','admin','super_admin') then
    raise exception 'Invalid role';
  end if;
  if p_user_id = auth.uid() and p_role = 'super_admin' and not p_enabled then
    raise exception 'Cannot remove your own super-admin role';
  end if;

  if p_enabled then
    insert into public.academy_user_roles(user_id,role)
    values(p_user_id,p_role)
    on conflict do nothing;
  else
    delete from public.academy_user_roles
    where user_id=p_user_id and role=p_role;
  end if;

  insert into public.academy_activity_logs(actor_user_id,action,entity_type,entity_id,details)
  values(auth.uid(),case when p_enabled then 'role_granted' else 'role_revoked' end,
    'user',p_user_id::text,jsonb_build_object('role',p_role));
end;
$$;
revoke all on function public.academy_set_user_role(uuid,text,boolean) from public, anon;
grant execute on function public.academy_set_user_role(uuid,text,boolean) to authenticated;

create or replace function public.academy_admin_student_overview()
returns table (
  user_id uuid,
  email text,
  display_name text,
  created_at timestamptz,
  completed_lessons bigint,
  quiz_attempts bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select p.user_id, u.email, p.display_name, u.created_at,
    (select count(*) from public.academy_lesson_progress lp
      where lp.user_id=p.user_id and lp.status='completed'),
    (select count(*) from public.academy_quiz_attempts qa where qa.user_id=p.user_id)
  from public.academy_profiles p
  join auth.users u on u.id=p.user_id
  where public.academy_is_admin()
  order by u.created_at desc;
$$;
revoke all on function public.academy_admin_student_overview() from public, anon;
grant execute on function public.academy_admin_student_overview() to authenticated;

-- NEXORA FORGE ACADEMY: 324-lesson curriculum (36 per course)
-- Archives old published lessons without deleting records or student history.
-- Safe to rerun: stable course and lesson IDs are upserted.

update public.academy_lessons l set status='archived',archived_at=coalesce(l.archived_at,now()),updated_at=now() where l.status='published' and l.course_id in (select c.id from public.academy_courses c where c.language_id in ('html','css','javascript') and c.level_id in ('beginner','intermediate','advanced'));
insert into public.academy_courses(id,language_id,level_id,title,slug,description,status,sort_order,estimated_hours)
select x.id,x.language_id,x.level_id,x.title,x.slug,x.description,x.status,x.sort_order,x.estimated_hours
from jsonb_to_recordset($courses$[{"id":"html","language_id":"html","level_id":"beginner","title":"HTML مقدماتی","slug":"html-course","description":"ساختار صفحات وب را از پایه یاد بگیر.","status":"published","sort_order":1,"estimated_hours":18},{"id":"html-intermediate","language_id":"html","level_id":"intermediate","title":"HTML متوسط","slug":"html-intermediate-course","description":"فرم‌های کامل، ساختار معنایی، رسانه و دسترس‌پذیری.","status":"published","sort_order":2,"estimated_hours":22},{"id":"html-advanced","language_id":"html","level_id":"advanced","title":"HTML پیشرفته","slug":"html-advanced-course","description":"استانداردهای مدرن، دسترس‌پذیری عمیق و معماری صفحات.","status":"published","sort_order":3,"estimated_hours":26},{"id":"css","language_id":"css","level_id":"beginner","title":"CSS مقدماتی","slug":"css-course","description":"رنگ، تایپوگرافی، مدل جعبه‌ای و چیدمان پایه.","status":"published","sort_order":1,"estimated_hours":18},{"id":"css-intermediate","language_id":"css","level_id":"intermediate","title":"CSS متوسط","slug":"css-intermediate-course","description":"Flexbox و Grid، واکنش‌گرایی، فرم و حرکت.","status":"published","sort_order":2,"estimated_hours":22},{"id":"css-advanced","language_id":"css","level_id":"advanced","title":"CSS پیشرفته","slug":"css-advanced-course","description":"معماری CSS، طراحی سیستم و بهینه‌سازی رابط.","status":"published","sort_order":3,"estimated_hours":26},{"id":"javascript","language_id":"javascript","level_id":"beginner","title":"JavaScript مقدماتی","slug":"javascript-course","description":"مبانی زبان، داده، شرط، حلقه، تابع و DOM.","status":"published","sort_order":1,"estimated_hours":18},{"id":"javascript-intermediate","language_id":"javascript","level_id":"intermediate","title":"JavaScript متوسط","slug":"javascript-intermediate-course","description":"DOM، رویداد، آرایه، فرم و ماژول.","status":"published","sort_order":2,"estimated_hours":22},{"id":"javascript-advanced","language_id":"javascript","level_id":"advanced","title":"JavaScript پیشرفته","slug":"javascript-advanced-course","description":"ناهمگامی، API، معماری، امنیت و تست.","status":"published","sort_order":3,"estimated_hours":26}]$courses$::jsonb)
as x(id text,language_id text,level_id text,title text,slug text,description text,status text,sort_order integer,estimated_hours numeric)
on conflict(language_id,level_id) do update set title=excluded.title,slug=excluded.slug,description=excluded.description,status='published',sort_order=excluded.sort_order,estimated_hours=excluded.estimated_hours,updated_at=now();

-- NEXORA FORGE ACADEMY INSTALL — PART 3/21
-- Curriculum lessons 1-18 of 324

begin;
-- Curriculum batch 1/18; lessons 1-18
insert into public.academy_lessons(id,course_id,title,slug,summary,content_html,starter_code,exercise,status,sort_order,estimated_minutes)
select x.id,c.id,x.title,x.slug,x.summary,x.content_html,x.starter_code,x.exercise,x.status,x.sort_order,x.estimated_minutes
from jsonb_to_recordset($lessons$[{"id":"curriculum-324-html-01","course_id":"html","title":"HTML چیست و مرورگر چگونه آن را می‌خواند","slug":"html-beginner-01","summary":"در این درس HTML چیست و مرورگر چگونه آن را می‌خواند را به‌صورت عملی یاد می‌گیری. HTML زبان نشانه‌گذاری برای توصیف ساختار و معنای محتوای صفحه است؛ زبان برنامه‌نویسی برای محاسبه و تصمیم‌گیری نیست. مرورگر تگ‌ها را تحلیل می‌کند و از آن‌ها درختی از عناصر می‌سازد.","content_html":"<h3>هدف درس</h3><p>HTML زبان نشانه‌گذاری برای توصیف ساختار و معنای محتوای صفحه است؛ زبان برنامه‌نویسی برای محاسبه و تصمیم‌گیری نیست. مرورگر تگ‌ها را تحلیل می‌کند و از آن‌ها درختی از عناصر می‌سازد.</p><h3>نمونه و بررسی</h3><p>این دو عنصر را در مرورگر باز کن و بررسی کن که مرورگر چگونه عنوان و بند متن را به دو گره جدا در ساختار صفحه تبدیل می‌کند.</p><pre><code>&lt;h1&gt;آکادمی NEXORA FORGE&lt;/h1&gt;\n&lt;p&gt;اینجا یاد می‌گیریم وب‌سایت چگونه ساخته می‌شود.&lt;/p&gt;</code></pre><h3>تمرین</h3><p>یک صفحه معرفی شخصی با یک عنوان اصلی و دو پاراگراف بساز. در توضیح خود بنویس HTML چه چیزی را مشخص می‌کند و چه کاری را به CSS می‌سپارد.</p><h3>نکته مهم</h3><p>اشتباه رایج: تصور اینکه HTML به‌تنهایی ظاهر نهایی و رفتار تعاملی را کنترل می‌کند.</p><h3>معیار موفقیت</h3><p>عنوان اصلی و پاراگراف‌ها به‌صورت عنصرهای جدا در DOM دیده شوند و بتوانی نقش HTML را از CSS توضیح بدهی.</p>","starter_code":"<h1>آکادمی NEXORA FORGE</h1>\n<p>اینجا یاد می‌گیریم وب‌سایت چگونه ساخته می‌شود.</p>","exercise":"یک صفحه معرفی شخصی با یک عنوان اصلی و دو پاراگراف بساز. در توضیح خود بنویس HTML چه چیزی را مشخص می‌کند و چه کاری را به CSS می‌سپارد.","status":"published","sort_order":1,"estimated_minutes":20},{"id":"curriculum-324-html-02","course_id":"html","title":"ساخت اولین فایل HTML","slug":"html-beginner-02","summary":"در این درس ساخت اولین فایل HTML را به‌صورت عملی یاد می‌گیری. یک فایل متنی با پسوند .html بساز و آن را با مرورگر باز کن. مرورگر فایل را تفسیر می‌کند؛ لازم نیست برای یک صفحه ساده سرور نصب کنی.","content_html":"<h3>هدف درس</h3><p>یک فایل متنی با پسوند .html بساز و آن را با مرورگر باز کن. مرورگر فایل را تفسیر می‌کند؛ لازم نیست برای یک صفحه ساده سرور نصب کنی.</p><h3>نمونه و بررسی</h3><p>فایل را دقیقاً با نام index.html ذخیره کن؛ سپس عنوان تب و متن داخل بدنه را جداگانه تغییر بده تا تفاوت head و body روشن شود.</p><pre><code>&lt;!doctype html&gt;\n&lt;html lang=\"fa\" dir=\"rtl\"&gt;\n  &lt;head&gt;&lt;meta charset=\"UTF-8\"&gt;&lt;title&gt;اولین صفحه&lt;/title&gt;&lt;/head&gt;\n  &lt;body&gt;&lt;h1&gt;سلام وب!&lt;/h1&gt;&lt;/body&gt;\n&lt;/html&gt;</code></pre><h3>تمرین</h3><p>فایلی به نام index.html بساز، کد را وارد کن، ذخیره کن و با مرورگر بازش کن. عنوان تب مرورگر را هم تغییر بده.</p><h3>نکته مهم</h3><p>اگر تغییرات دیده نمی‌شوند، فایل را ذخیره و صفحه را تازه‌سازی کن.</p><h3>معیار موفقیت</h3><p>فایل بدون تغییر پسوند ذخیره شود، در مرورگر باز شود و تغییر title در تب قابل مشاهده باشد.</p>","starter_code":"<!doctype html>\n<html lang=\"fa\" dir=\"rtl\">\n  <head><meta charset=\"UTF-8\"><title>اولین صفحه</title></head>\n  <body><h1>سلام وب!</h1></body>\n</html>","exercise":"فایلی به نام index.html بساز، کد را وارد کن، ذخیره کن و با مرورگر بازش کن. عنوان تب مرورگر را هم تغییر بده.","status":"published","sort_order":2,"estimated_minutes":25},{"id":"curriculum-324-html-03","course_id":"html","title":"ساختار استاندارد سند","slug":"html-beginner-03","summary":"در این درس ساختار استاندارد سند را به‌صورت عملی یاد می‌گیری. DOCTYPE حالت استاندارد HTML را فعال می‌کند. عنصر html ریشه سند است؛ head اطلاعات و تنظیمات سند را نگه می‌دارد و body محتوای قابل مشاهده را در بر می‌گیرد.","content_html":"<h3>هدف درس</h3><p>DOCTYPE حالت استاندارد HTML را فعال می‌کند. عنصر html ریشه سند است؛ head اطلاعات و تنظیمات سند را نگه می‌دارد و body محتوای قابل مشاهده را در بر می‌گیرد.</p><h3>نمونه و بررسی</h3><p>درخت سند را از html شروع کن و جایگاه head، body و main را در ابزار توسعه مرورگر پیدا کن.</p><pre><code>&lt;!doctype html&gt;\n&lt;html lang=\"fa\" dir=\"rtl\"&gt;\n&lt;head&gt;\n  &lt;meta charset=\"UTF-8\"&gt;\n  &lt;title&gt;ساختار سند&lt;/title&gt;\n&lt;/head&gt;\n&lt;body&gt;\n  &lt;main&gt;&lt;h1&gt;صفحه اصلی&lt;/h1&gt;&lt;/main&gt;\n&lt;/body&gt;\n&lt;/html&gt;</code></pre><h3>تمرین</h3><p>یک سند کامل بساز و جایگاه doctype، html، head و body را مشخص کن. سپس یک main به بدنه اضافه کن.</p><h3>نکته مهم</h3><p>محتوای قابل مشاهده را داخل head قرار نده.</p><h3>معیار موفقیت</h3><p>سند شامل doctype، html، head و body باشد و main فقط محتوای اصلی را در بر بگیرد.</p>","starter_code":"<!doctype html>\n<html lang=\"fa\" dir=\"rtl\">\n<head>\n  <meta charset=\"UTF-8\">\n  <title>ساختار سند</title>\n</head>\n<body>\n  <main><h1>صفحه اصلی</h1></main>\n</body>\n</html>","exercise":"یک سند کامل بساز و جایگاه doctype، html، head و body را مشخص کن. سپس یک main به بدنه اضافه کن.","status":"published","sort_order":3,"estimated_minutes":30},{"id":"curriculum-324-html-04","course_id":"html","title":"زبان صفحه و جهت نوشتار","slug":"html-beginner-04","summary":"در این درس زبان صفحه و جهت نوشتار را به‌صورت عملی یاد می‌گیری. ویژگی lang زبان اصلی محتوا را اعلام می‌کند و dir جهت متن را تعیین می‌کند. این اطلاعات به مرورگر، صفحه‌خوان و ابزارهای ترجمه کمک می‌کنند.","content_html":"<h3>هدف درس</h3><p>ویژگی lang زبان اصلی محتوا را اعلام می‌کند و dir جهت متن را تعیین می‌کند. این اطلاعات به مرورگر، صفحه‌خوان و ابزارهای ترجمه کمک می‌کنند.</p><h3>نمونه و بررسی</h3><p>مقدار lang و dir را تغییر بده و رفتار متن فارسی و عبارت انگلیسی را در یک صفحه راست‌به‌چپ مقایسه کن.</p><pre><code>&lt;html lang=\"fa\" dir=\"rtl\"&gt;\n&lt;head&gt;&lt;meta charset=\"UTF-8\"&gt;&lt;title&gt;متن فارسی&lt;/title&gt;&lt;/head&gt;\n&lt;body&gt;&lt;p&gt;این صفحه فارسی و راست‌چین است.&lt;/p&gt;&lt;/body&gt;\n&lt;/html&gt;</code></pre><h3>تمرین</h3><p>یک صفحه فارسی بساز و lang را fa و dir را rtl قرار بده. در یک بخش کوتاه انگلیسی، جهت را فقط برای همان بخش ltr کن.</p><h3>نکته مهم</h3><p>جهت کل صفحه را با فاصله یا کاراکترهای ساختگی اصلاح نکن؛ از ویژگی dir استفاده کن.</p><h3>معیار موفقیت</h3><p>زبان سند fa و جهت اصلی rtl باشد و بخش انگلیسی مستقل با ltr نمایش داده شود.</p>","starter_code":"<html lang=\"fa\" dir=\"rtl\">\n<head><meta charset=\"UTF-8\"><title>متن فارسی</title></head>\n<body><p>این صفحه فارسی و راست‌چین است.</p></body>\n</html>","exercise":"یک صفحه فارسی بساز و lang را fa و dir را rtl قرار بده. در یک بخش کوتاه انگلیسی، جهت را فقط برای همان بخش ltr کن.","status":"published","sort_order":4,"estimated_minutes":35},{"id":"curriculum-324-html-05","course_id":"html","title":"عنوان صفحه و اطلاعات head","slug":"html-beginner-05","summary":"در این درس عنوان صفحه و اطلاعات head را به‌صورت عملی یاد می‌گیری. عنصر title نام سند را در تب مرورگر و نتایج جست‌وجو نمایش می‌دهد. meta charset رمزگذاری نویسه‌ها را مشخص می‌کند تا حروف فارسی خراب نشوند.","content_html":"<h3>هدف درس</h3><p>عنصر title نام سند را در تب مرورگر و نتایج جست‌وجو نمایش می‌دهد. meta charset رمزگذاری نویسه‌ها را مشخص می‌کند تا حروف فارسی خراب نشوند.</p><h3>نمونه و بررسی</h3><p>عنوان تب را تغییر بده و meta description را در کد منبع پیدا کن؛ توجه کن که description متن قابل مشاهده داخل صفحه نیست.</p><pre><code>&lt;head&gt;\n  &lt;meta charset=\"UTF-8\"&gt;\n  &lt;meta name=\"description\" content=\"آموزش رایگان HTML به زبان فارسی\"&gt;\n  &lt;title&gt;آموزش HTML | NEXORA FORGE&lt;/title&gt;\n&lt;/head&gt;</code></pre><h3>تمرین</h3><p>برای یک صفحه آموزش HTML عنوانی دقیق و توضیح meta description کوتاه بنویس. صفحه را باز کن و عنوان تب را بررسی کن.</p><h3>نکته مهم</h3><p>title را خالی نگذار و برای هر صفحه عنوان مرتبط و متمایز انتخاب کن.</p><h3>معیار موفقیت</h3><p>تب مرورگر title درست داشته باشد و meta description در head با محتوای صفحه هماهنگ باشد.</p>","starter_code":"<head>\n  <meta charset=\"UTF-8\">\n  <meta name=\"description\" content=\"آموزش رایگان HTML به زبان فارسی\">\n  <title>آموزش HTML | NEXORA FORGE</title>\n</head>","exercise":"برای یک صفحه آموزش HTML عنوانی دقیق و توضیح meta description کوتاه بنویس. صفحه را باز کن و عنوان تب را بررسی کن.","status":"published","sort_order":5,"estimated_minutes":20},{"id":"curriculum-324-html-06","course_id":"html","title":"عنصر، تگ و ویژگی","slug":"html-beginner-06","summary":"در این درس عنصر، تگ و ویژگی را به‌صورت عملی یاد می‌گیری. تگ نشانه متنی مانند h1 است؛ عنصر معمولاً از تگ آغاز، محتوا و تگ پایان تشکیل می‌شود. ویژگی‌ها اطلاعات یا تنظیمات بیشتری به عنصر می‌دهند.","content_html":"<h3>هدف درس</h3><p>تگ نشانه متنی مانند h1 است؛ عنصر معمولاً از تگ آغاز، محتوا و تگ پایان تشکیل می‌شود. ویژگی‌ها اطلاعات یا تنظیمات بیشتری به عنصر می‌دهند.</p><h3>نمونه و بررسی</h3><p>در پیوند نمونه، href را مقصد و target و rel را ویژگی‌های رفتاری جداگانه بررسی کن؛ نام تگ با نام عنصر یکی نیست.</p><pre><code>&lt;a href=\"https://example.com\" target=\"_blank\" rel=\"noopener\"&gt;باز کردن نمونه&lt;/a&gt;</code></pre><h3>تمرین</h3><p>یک پیوند بساز و href آن را به نشانی دلخواه تغییر بده. نام ویژگی و مقدار آن را از هم تشخیص بده.</p><h3>نکته مهم</h3><p>نام ویژگی را بدون مقدار لازم یا با کوتیشن ناقص ننویس.</p><h3>معیار موفقیت</h3><p>پیوند مقصد درست داشته باشد و ویژگی‌های اختیاری آن با هدف بازشدن و امنیت پیوند سازگار باشند.</p>","starter_code":"<a href=\"https://example.com\" target=\"_blank\" rel=\"noopener\">باز کردن نمونه</a>","exercise":"یک پیوند بساز و href آن را به نشانی دلخواه تغییر بده. نام ویژگی و مقدار آن را از هم تشخیص بده.","status":"published","sort_order":6,"estimated_minutes":25},{"id":"curriculum-324-html-07","course_id":"html","title":"تیترها از h1 تا h6","slug":"html-beginner-07","summary":"در این درس تیترها از h1 تا h6 را به‌صورت عملی یاد می‌گیری. تیترها ساختار سلسله‌مراتبی محتوا را نشان می‌دهند. h1 عنوان اصلی صفحه و h2 و h3 زیرعنوان بخش‌ها هستند؛ اندازه ظاهری معیار انتخاب نیست.","content_html":"<h3>هدف درس</h3><p>تیترها ساختار سلسله‌مراتبی محتوا را نشان می‌دهند. h1 عنوان اصلی صفحه و h2 و h3 زیرعنوان بخش‌ها هستند؛ اندازه ظاهری معیار انتخاب نیست.</p><h3>نمونه و بررسی</h3><p>ساختار تیترها را در نمای دسترس‌پذیری یا outline بررسی کن و ببین آیا زیرعنوان‌ها زیر بخش درست قرار گرفته‌اند.</p><pre><code>&lt;h1&gt;راهنمای HTML&lt;/h1&gt;\n&lt;h2&gt;ساختار سند&lt;/h2&gt;\n&lt;h3&gt;بخش head&lt;/h3&gt;\n&lt;h2&gt;متن و پیوندها&lt;/h2&gt;</code></pre><h3>تمرین</h3><p>برای مقاله‌ای با سه بخش، یک h1 و چند h2 و h3 منطقی بساز. ترتیب را بر اساس ساختار موضوع انتخاب کن.</p><h3>نکته مهم</h3><p>از تیترها فقط برای بزرگ‌کردن متن استفاده نکن و سطح‌ها را بی‌دلیل نپر.</p><h3>معیار موفقیت</h3><p>فقط یک عنوان اصلی مناسب وجود داشته باشد و سطوح زیرعنوان ترتیب معنایی قابل دفاعی داشته باشند.</p>","starter_code":"<h1>راهنمای HTML</h1>\n<h2>ساختار سند</h2>\n<h3>بخش head</h3>\n<h2>متن و پیوندها</h2>","exercise":"برای مقاله‌ای با سه بخش، یک h1 و چند h2 و h3 منطقی بساز. ترتیب را بر اساس ساختار موضوع انتخاب کن.","status":"published","sort_order":7,"estimated_minutes":30},{"id":"curriculum-324-html-08","course_id":"html","title":"پاراگراف و شکست خط","slug":"html-beginner-08","summary":"در این درس پاراگراف و شکست خط را به‌صورت عملی یاد می‌گیری. p برای یک بند مستقل متن است. br فقط وقتی مناسب است که شکست خط بخشی از معنا باشد؛ برای فاصله‌گذاری بین بخش‌ها از آن استفاده نکن.","content_html":"<h3>هدف درس</h3><p>p برای یک بند مستقل متن است. br فقط وقتی مناسب است که شکست خط بخشی از معنا باشد؛ برای فاصله‌گذاری بین بخش‌ها از آن استفاده نکن.</p><h3>نمونه و بررسی</h3><p>سه بند را جداگانه بخوان و شکست خط نشانی را با br مقایسه کن؛ br نباید برای فاصله تزئینی استفاده شود.</p><pre><code>&lt;p&gt;HTML ساختار محتوا را مشخص می‌کند.&lt;/p&gt;\n&lt;p&gt;CSS ظاهر صفحه را کنترل می‌کند.&lt;/p&gt;\n&lt;p&gt;نشانی ما:&lt;br&gt;هرات، افغانستان&lt;/p&gt;</code></pre><h3>تمرین</h3><p>سه پاراگراف مستقل بنویس و فقط در یک نشانی یا شعر از br استفاده کن. تفاوت آن‌ها را توضیح بده.</p><h3>نکته مهم</h3><p>برای ایجاد فاصله عمودی چندین br پشت سر هم قرار نده.</p><h3>معیار موفقیت</h3><p>پاراگراف‌ها مستقل باشند و br فقط برای شکست خطی با معنای واقعی استفاده شود.</p>","starter_code":"<p>HTML ساختار محتوا را مشخص می‌کند.</p>\n<p>CSS ظاهر صفحه را کنترل می‌کند.</p>\n<p>نشانی ما:<br>هرات، افغانستان</p>","exercise":"سه پاراگراف مستقل بنویس و فقط در یک نشانی یا شعر از br استفاده کن. تفاوت آن‌ها را توضیح بده.","status":"published","sort_order":8,"estimated_minutes":35},{"id":"curriculum-324-html-09","course_id":"html","title":"تأکید معنایی با strong و em","slug":"html-beginner-09","summary":"در این درس تأکید معنایی با strong و em را به‌صورت عملی یاد می‌گیری. strong اهمیت زیاد و em تأکید گفتاری را منتقل می‌کند. این عناصر معنایی‌اند؛ صرفاً ابزار ضخیم یا مورب کردن متن نیستند.","content_html":"<h3>هدف درس</h3><p>strong اهمیت زیاد و em تأکید گفتاری را منتقل می‌کند. این عناصر معنایی‌اند؛ صرفاً ابزار ضخیم یا مورب کردن متن نیستند.</p><h3>نمونه و بررسی</h3><p>متن را با صفحه‌خوان یا ابزار دسترس‌پذیری بررسی کن و تفاوت اهمیت strong با تأکید em را توضیح بده.</p><pre><code>&lt;p&gt;&lt;strong&gt;هشدار:&lt;/strong&gt; پیش از بستن صفحه فایل را ذخیره کن.&lt;/p&gt;\n&lt;p&gt;این نکته &lt;em&gt;بسیار مهم&lt;/em&gt; است.&lt;/p&gt;</code></pre><h3>تمرین</h3><p>یک راهنمای کوتاه بنویس و در آن یک هشدار مهم و یک واژه با تأکید معنایی قرار بده.</p><h3>نکته مهم</h3><p>برای ظاهر صرف از CSS استفاده کن، نه اینکه معنای متن را با strong عوض کنی.</p><h3>معیار موفقیت</h3><p>strong و em بر اساس معنا انتخاب شوند و نه صرفاً برای تغییر ظاهر حروف.</p>","starter_code":"<p><strong>هشدار:</strong> پیش از بستن صفحه فایل را ذخیره کن.</p>\n<p>این نکته <em>بسیار مهم</em> است.</p>","exercise":"یک راهنمای کوتاه بنویس و در آن یک هشدار مهم و یک واژه با تأکید معنایی قرار بده.","status":"published","sort_order":9,"estimated_minutes":20},{"id":"curriculum-324-html-10","course_id":"html","title":"پیوند به صفحه دیگر","slug":"html-beginner-10","summary":"در این درس پیوند به صفحه دیگر را به‌صورت عملی یاد می‌گیری. عنصر a با href پیوند می‌سازد. متن پیوند باید مقصد را برای کاربر روشن کند؛ عباراتی مثل «اینجا کلیک کن» اطلاعات کمی می‌دهند.","content_html":"<h3>هدف درس</h3><p>عنصر a با href پیوند می‌سازد. متن پیوند باید مقصد را برای کاربر روشن کند؛ عباراتی مثل «اینجا کلیک کن» اطلاعات کمی می‌دهند.</p><h3>نمونه و بررسی</h3><p>دو فایل هم‌پوشه بساز و مسیر نسبی about.html را آزمایش کن؛ سپس مقصد پیوند خارجی را جداگانه باز کن.</p><pre><code>&lt;a href=\"about.html\"&gt;درباره آکادمی&lt;/a&gt;\n&lt;a href=\"https://developer.mozilla.org/\"&gt;مرجع MDN&lt;/a&gt;</code></pre><h3>تمرین</h3><p>دو فایل index.html و about.html بساز و بین آن‌ها پیوند نسبی برقرار کن. یک پیوند خارجی هم اضافه کن.</p><h3>نکته مهم</h3><p>برای پیوند داخلی نام و مسیر فایل را دقیق وارد کن.</p><h3>معیار موفقیت</h3><p>پیوند داخلی به فایل واقعی برسد و متن پیوند مقصد را بدون ابهام معرفی کند.</p>","starter_code":"<a href=\"about.html\">درباره آکادمی</a>\n<a href=\"https://developer.mozilla.org/\">مرجع MDN</a>","exercise":"دو فایل index.html و about.html بساز و بین آن‌ها پیوند نسبی برقرار کن. یک پیوند خارجی هم اضافه کن.","status":"published","sort_order":10,"estimated_minutes":25},{"id":"curriculum-324-html-11","course_id":"html","title":"پیوند ایمیل و تلفن","slug":"html-beginner-11","summary":"در این درس پیوند ایمیل و تلفن را به‌صورت عملی یاد می‌گیری. طرح‌های mailto و tel در href می‌توانند برنامه ایمیل یا تماس دستگاه را باز کنند. عملکرد آن‌ها به دستگاه و برنامه‌های نصب‌شده وابسته است.","content_html":"<h3>هدف درس</h3><p>طرح‌های mailto و tel در href می‌توانند برنامه ایمیل یا تماس دستگاه را باز کنند. عملکرد آن‌ها به دستگاه و برنامه‌های نصب‌شده وابسته است.</p><h3>نمونه و بررسی</h3><p>پیوندها را روی دستگاه دارای برنامه ایمیل و تماس آزمایش کن؛ به‌خاطر نمونه بودن نشانی‌ها، ارسال واقعی انجام نده.</p><pre><code>&lt;a href=\"mailto:hello@example.com\"&gt;ارسال ایمیل&lt;/a&gt;\n&lt;a href=\"tel:+93700000000\"&gt;تماس با ما&lt;/a&gt;</code></pre><h3>تمرین</h3><p>در صفحه تماس، پیوند ایمیل و تلفن بساز. از شماره و ایمیل آزمایشی استفاده کن و بدان که کلیک روی آن‌ها چه می‌کند.</p><h3>نکته مهم</h3><p>این پیوندها ارسال خودکار انجام نمی‌دهند؛ برنامه مناسب دستگاه را باز می‌کنند.</p><h3>معیار موفقیت</h3><p>هر دو پیوند دارای scheme درست باشند و کاربر بداند که mailto و tel برنامه دستگاه را باز می‌کنند.</p>","starter_code":"<a href=\"mailto:hello@example.com\">ارسال ایمیل</a>\n<a href=\"tel:+93700000000\">تماس با ما</a>","exercise":"در صفحه تماس، پیوند ایمیل و تلفن بساز. از شماره و ایمیل آزمایشی استفاده کن و بدان که کلیک روی آن‌ها چه می‌کند.","status":"published","sort_order":11,"estimated_minutes":30},{"id":"curriculum-324-html-12","course_id":"html","title":"تصویر و ویژگی src","slug":"html-beginner-12","summary":"در این درس تصویر و ویژگی src را به‌صورت عملی یاد می‌گیری. عنصر img تصویر را در صفحه قرار می‌دهد. src مسیر فایل تصویر و alt جایگزین متنی آن است. img عنصر تهی است و تگ پایان ندارد.","content_html":"<h3>هدف درس</h3><p>عنصر img تصویر را در صفحه قرار می‌دهد. src مسیر فایل تصویر و alt جایگزین متنی آن است. img عنصر تهی است و تگ پایان ندارد.</p><h3>نمونه و بررسی</h3><p>نام فایل تصویر و مسیر پوشه images را با ساختار پروژه خودت هماهنگ کن و عمداً یک مسیر اشتباه را برای دیدن رفتار alt امتحان کن.</p><pre><code>&lt;img src=\"images/workshop.jpg\" alt=\"دانش‌آموز در حال تمرین کدنویسی\" width=\"640\"&gt;</code></pre><h3>تمرین</h3><p>یک پوشه images بساز، تصویر مجاز خودت را در آن قرار بده و مسیر src را درست تنظیم کن. صفحه را در مرورگر بررسی کن.</p><h3>نکته مهم</h3><p>مسیر نسبی را نسبت به محل فایل HTML حساب کن.</p><h3>معیار موفقیت</h3><p>تصویر بارگذاری شود، مسیر نسبی درست باشد و alt محتوای مهم تصویر را منتقل کند.</p>","starter_code":"<img src=\"images/workshop.jpg\" alt=\"دانش‌آموز در حال تمرین کدنویسی\" width=\"640\">","exercise":"یک پوشه images بساز، تصویر مجاز خودت را در آن قرار بده و مسیر src را درست تنظیم کن. صفحه را در مرورگر بررسی کن.","status":"published","sort_order":12,"estimated_minutes":35},{"id":"curriculum-324-html-13","course_id":"html","title":"متن جایگزین تصویر","slug":"html-beginner-13","summary":"در این درس متن جایگزین تصویر را به‌صورت عملی یاد می‌گیری. alt باید هدف یا محتوای مهم تصویر را منتقل کند. تصویر تزئینی معمولاً alt خالی دارد؛ نوشتن نام فایل یا عبارت «عکس» کمک چندانی نمی‌کند.","content_html":"<h3>هدف درس</h3><p>alt باید هدف یا محتوای مهم تصویر را منتقل کند. تصویر تزئینی معمولاً alt خالی دارد؛ نوشتن نام فایل یا عبارت «عکس» کمک چندانی نمی‌کند.</p><h3>نمونه و بررسی</h3><p>برای تصویر اطلاعاتی و تزئینی altهای متفاوت بگذار و بررسی کن تصویر تزئینی با alt خالی برای صفحه‌خوان نادیده گرفته شود.</p><pre><code>&lt;img src=\"logo.svg\" alt=\"نشان NEXORA FORGE\"&gt;\n&lt;img src=\"divider.png\" alt=\"\"&gt;</code></pre><h3>تمرین</h3><p>برای یک تصویر آموزشی، یک عکس تزئینی و یک نمودار، alt مناسب بنویس. برای نمودار، اطلاعات ضروری را در متن صفحه هم شرح بده.</p><h3>نکته مهم</h3><p>alt خالی برای تصویر اطلاعاتی مناسب نیست؛ متن جایگزین باید متناسب با کاربرد تصویر باشد.</p><h3>معیار موفقیت</h3><p>تصویر تزئینی alt خالی داشته باشد و اطلاعات نمودار در متن جایگزین یا توضیح صفحه موجود باشد.</p>","starter_code":"<img src=\"logo.svg\" alt=\"نشان NEXORA FORGE\">\n<img src=\"divider.png\" alt=\"\">","exercise":"برای یک تصویر آموزشی، یک عکس تزئینی و یک نمودار، alt مناسب بنویس. برای نمودار، اطلاعات ضروری را در متن صفحه هم شرح بده.","status":"published","sort_order":13,"estimated_minutes":20},{"id":"curriculum-324-html-14","course_id":"html","title":"فهرست نامرتب ul","slug":"html-beginner-14","summary":"در این درس فهرست نامرتب ul را به‌صورت عملی یاد می‌گیری. ul برای مجموعه‌ای است که ترتیب آیتم‌هایش اهمیت ندارد. هر گزینه باید داخل li قرار گیرد؛ ظاهر نشانه‌گذاری را CSS تغییر می‌دهد.","content_html":"<h3>هدف درس</h3><p>ul برای مجموعه‌ای است که ترتیب آیتم‌هایش اهمیت ندارد. هر گزینه باید داخل li قرار گیرد؛ ظاهر نشانه‌گذاری را CSS تغییر می‌دهد.</p><h3>نمونه و بررسی</h3><p>یک li جدید به فهرست اضافه کن و ساختار DOM را بررسی کن تا همه گزینه‌ها فرزند مستقیم منطقی ul باشند.</p><pre><code>&lt;h2&gt;ابزارهای موردنیاز&lt;/h2&gt;\n&lt;ul&gt;&lt;li&gt;ویرایشگر کد&lt;/li&gt;&lt;li&gt;مرورگر&lt;/li&gt;&lt;li&gt;تمرین روزانه&lt;/li&gt;&lt;/ul&gt;</code></pre><h3>تمرین</h3><p>فهرست پنج ابزار یا موضوع موردنیاز برای یادگیری وب بساز و مطمئن شو هر مورد li است.</p><h3>نکته مهم</h3><p>متن آیتم‌ها را مستقیم و بدون li داخل ul قرار نده.</p><h3>معیار موفقیت</h3><p>تمام گزینه‌ها داخل li باشند و فهرست نامرتب برای موارد بدون ترتیب استفاده شود.</p>","starter_code":"<h2>ابزارهای موردنیاز</h2>\n<ul><li>ویرایشگر کد</li><li>مرورگر</li><li>تمرین روزانه</li></ul>","exercise":"فهرست پنج ابزار یا موضوع موردنیاز برای یادگیری وب بساز و مطمئن شو هر مورد li است.","status":"published","sort_order":14,"estimated_minutes":25},{"id":"curriculum-324-html-15","course_id":"html","title":"فهرست مرتب ol","slug":"html-beginner-15","summary":"در این درس فهرست مرتب ol را به‌صورت عملی یاد می‌گیری. ol برای مراحل یا مواردی است که ترتیب آن‌ها مهم است. مرورگر شماره‌گذاری را مدیریت می‌کند و با ویژگی start می‌توان شماره شروع را تعیین کرد.","content_html":"<h3>هدف درس</h3><p>ol برای مراحل یا مواردی است که ترتیب آن‌ها مهم است. مرورگر شماره‌گذاری را مدیریت می‌کند و با ویژگی start می‌توان شماره شروع را تعیین کرد.</p><h3>نمونه و بررسی</h3><p>ترتیب مراحل را جابه‌جا کن و مشاهده کن شماره‌گذاری خودکار چگونه با ترتیب DOM هماهنگ می‌شود.</p><pre><code>&lt;ol&gt;\n  &lt;li&gt;فایل را بساز.&lt;/li&gt;\n  &lt;li&gt;کد HTML را بنویس.&lt;/li&gt;\n  &lt;li&gt;در مرورگر آزمایش کن.&lt;/li&gt;\n&lt;/ol&gt;</code></pre><h3>تمرین</h3><p>مراحل انتشار یک صفحه ساده را با ol بنویس. ترتیب را عوض کن و تفاوت خروجی را مشاهده کن.</p><h3>نکته مهم</h3><p>اگر ترتیب مراحل مهم نیست، ul انتخاب مناسب‌تری است.</p><h3>معیار موفقیت</h3><p>ترتیب ol با ترتیب واقعی مراحل هماهنگ باشد و شماره‌گذاری دستی در متن نوشته نشده باشد.</p>","starter_code":"<ol>\n  <li>فایل را بساز.</li>\n  <li>کد HTML را بنویس.</li>\n  <li>در مرورگر آزمایش کن.</li>\n</ol>","exercise":"مراحل انتشار یک صفحه ساده را با ol بنویس. ترتیب را عوض کن و تفاوت خروجی را مشاهده کن.","status":"published","sort_order":15,"estimated_minutes":30},{"id":"curriculum-324-html-16","course_id":"html","title":"فهرست تو در تو","slug":"html-beginner-16","summary":"در این درس فهرست تو در تو را به‌صورت عملی یاد می‌گیری. می‌توان یک فهرست را داخل li فهرست دیگر قرار داد تا رابطه گروه و زیرگروه روشن شود. فهرست تو در تو باید از نظر ساختاری داخل یک آیتم باشد.","content_html":"<h3>هدف درس</h3><p>می‌توان یک فهرست را داخل li فهرست دیگر قرار داد تا رابطه گروه و زیرگروه روشن شود. فهرست تو در تو باید از نظر ساختاری داخل یک آیتم باشد.</p><h3>نمونه و بررسی</h3><p>یک زیرگروه دیگر اضافه کن و تورفتگی ساختاری آن را داخل li والد نگه دار.</p><pre><code>&lt;ul&gt;\n  &lt;li&gt;Front-end\n    &lt;ul&gt;&lt;li&gt;HTML&lt;/li&gt;&lt;li&gt;CSS&lt;/li&gt;&lt;li&gt;JavaScript&lt;/li&gt;&lt;/ul&gt;\n  &lt;/li&gt;\n  &lt;li&gt;Back-end&lt;/li&gt;\n&lt;/ul&gt;</code></pre><h3>تمرین</h3><p>یک نقشه یادگیری وب با دو گروه و حداقل دو زیرموضوع برای هر گروه بساز.</p><h3>نکته مهم</h3><p>فهرست فرزند را داخل li والد قرار بده، نه به‌صورت هم‌سطح و نامرتبط.</p><h3>معیار موفقیت</h3><p>فهرست تو در تو از نظر DOM داخل li والد قرار گیرد و گروه‌ها قابل تشخیص باشند.</p>","starter_code":"<ul>\n  <li>Front-end\n    <ul><li>HTML</li><li>CSS</li><li>JavaScript</li></ul>\n  </li>\n  <li>Back-end</li>\n</ul>","exercise":"یک نقشه یادگیری وب با دو گروه و حداقل دو زیرموضوع برای هر گروه بساز.","status":"published","sort_order":16,"estimated_minutes":35},{"id":"curriculum-324-html-17","course_id":"html","title":"معنای div و span","slug":"html-beginner-17","summary":"در این درس معنای div و span را به‌صورت عملی یاد می‌گیری. div ظرف عمومی بلوکی و span ظرف عمومی درون‌خطی است. وقتی عنصر معنایی مناسب‌تری وجود ندارد، از آن‌ها برای گروه‌بندی و هدف‌گذاری CSS استفاده کن.","content_html":"<h3>هدف درس</h3><p>div ظرف عمومی بلوکی و span ظرف عمومی درون‌خطی است. وقتی عنصر معنایی مناسب‌تری وجود ندارد، از آن‌ها برای گروه‌بندی و هدف‌گذاری CSS استفاده کن.</p><h3>نمونه و بررسی</h3><p>کلاس level را در چند کارت تکرار کن، اما id را فقط یک بار در همان سند به کار ببر.</p><pre><code>&lt;div class=\"card\"&gt;\n  &lt;h2&gt;دوره HTML&lt;/h2&gt;\n  &lt;p&gt;سطح: &lt;span class=\"level\"&gt;مقدماتی&lt;/span&gt;&lt;/p&gt;\n&lt;/div&gt;</code></pre><h3>تمرین</h3><p>یک کارت معرفی دوره بساز و از div برای گروه‌بندی و span برای مشخص‌کردن یک عبارت درون متن استفاده کن.</p><h3>نکته مهم</h3><p>برای header، nav، main یا article از div عمومی استفاده نکن، اگر عنصر معنایی دقیق‌تر مناسب است.</p><h3>معیار موفقیت</h3><p>div و span فقط برای گروه‌بندی عمومی استفاده شوند و عنصر معنایی مناسب‌تر نادیده گرفته نشود.</p>","starter_code":"<div class=\"card\">\n  <h2>دوره HTML</h2>\n  <p>سطح: <span class=\"level\">مقدماتی</span></p>\n</div>","exercise":"یک کارت معرفی دوره بساز و از div برای گروه‌بندی و span برای مشخص‌کردن یک عبارت درون متن استفاده کن.","status":"published","sort_order":17,"estimated_minutes":20},{"id":"curriculum-324-html-18","course_id":"html","title":"ساختار معنایی header و footer","slug":"html-beginner-18","summary":"در این درس ساختار معنایی header و footer را به‌صورت عملی یاد می‌گیری. header محتوای مقدماتی یک صفحه یا بخش را گروه‌بندی می‌کند و footer اطلاعات پایانی همان محدوده را نگه می‌دارد. این عناصر جایگاه معنایی دارند، نه صرفاً ظاهر ثابت.","content_html":"<h3>هدف درس</h3><p>header محتوای مقدماتی یک صفحه یا بخش را گروه‌بندی می‌کند و footer اطلاعات پایانی همان محدوده را نگه می‌دارد. این عناصر جایگاه معنایی دارند، نه صرفاً ظاهر ثابت.</p><h3>نمونه و بررسی</h3><p>header و footer را یک‌بار برای کل صفحه و سپس برای یک article آزمایش کن تا محدوده معنایی هرکدام را تشخیص بدهی.</p><pre><code>&lt;header&gt;&lt;h1&gt;آکادمی وب&lt;/h1&gt;&lt;p&gt;مسیر یادگیری&lt;/p&gt;&lt;/header&gt;\n&lt;main&gt;&lt;p&gt;محتوای اصلی&lt;/p&gt;&lt;/main&gt;\n&lt;footer&gt;&lt;p&gt;© 2026 NEXORA FORGE&lt;/p&gt;&lt;/footer&gt;</code></pre><h3>تمرین</h3><p>صفحه معرفی دوره را با header و footer بساز و مشخص کن هرکدام چه اطلاعاتی دارند.</p><h3>نکته مهم</h3><p>header را الزاماً فقط یک‌بار در کل سند به کار نبر؛ می‌تواند متعلق به بخش یا مقاله هم باشد.</p><h3>معیار موفقیت</h3><p>ساختار صفحه و بخش‌ها header و footer مناسب داشته باشند و محتوای اصلی در main باشد.</p>","starter_code":"<header><h1>آکادمی وب</h1><p>مسیر یادگیری</p></header>\n<main><p>محتوای اصلی</p></main>\n<footer><p>© 2026 NEXORA FORGE</p></footer>","exercise":"صفحه معرفی دوره را با header و footer بساز و مشخص کن هرکدام چه اطلاعاتی دارند.","status":"published","sort_order":18,"estimated_minutes":25}]$lessons$::jsonb) as x(id text,course_id text,title text,slug text,summary text,content_html text,starter_code text,exercise text,status text,sort_order integer,estimated_minutes integer)
join (values
('html','html','beginner'),('html-intermediate','html','intermediate'),('html-advanced','html','advanced'),
('css','css','beginner'),('css-intermediate','css','intermediate'),('css-advanced','css','advanced'),
('javascript','javascript','beginner'),('javascript-intermediate','javascript','intermediate'),('javascript-advanced','javascript','advanced')
) as cp(course_id,language_id,level_id) on cp.course_id=x.course_id
join public.academy_courses c on c.language_id=cp.language_id and c.level_id=cp.level_id
on conflict(id) do update set title=excluded.title,slug=excluded.slug,summary=excluded.summary,content_html=excluded.content_html,starter_code=excluded.starter_code,exercise=excluded.exercise,status='published',sort_order=excluded.sort_order,estimated_minutes=excluded.estimated_minutes,archived_at=null,updated_at=now();

-- NEXORA FORGE ACADEMY INSTALL — PART 4/21
-- Curriculum lessons 19-36 of 324

begin;
-- Curriculum batch 2/18; lessons 19-36
insert into public.academy_lessons(id,course_id,title,slug,summary,content_html,starter_code,exercise,status,sort_order,estimated_minutes)
select x.id,c.id,x.title,x.slug,x.summary,x.content_html,x.starter_code,x.exercise,x.status,x.sort_order,x.estimated_minutes
from jsonb_to_recordset($lessons$[{"id":"curriculum-324-html-19","course_id":"html","title":"ناوبری با nav","slug":"html-beginner-19","summary":"در این درس ناوبری با nav را به‌صورت عملی یاد می‌گیری. nav بخش مهمی از پیوندهای ناوبری صفحه یا سایت را مشخص می‌کند. همه پیوندها لازم نیست داخل nav باشند؛ فقط مجموعه‌های اصلی ناوبری را گروه‌بندی کن.","content_html":"<h3>هدف درس</h3><p>nav بخش مهمی از پیوندهای ناوبری صفحه یا سایت را مشخص می‌کند. همه پیوندها لازم نیست داخل nav باشند؛ فقط مجموعه‌های اصلی ناوبری را گروه‌بندی کن.</p><h3>نمونه و بررسی</h3><p>برای nav نام قابل فهم تعیین کن و با صفحه‌کلید بین مقصدهای اصلی حرکت کن.</p><pre><code>&lt;nav aria-label=\"ناوبری اصلی\"&gt;\n  &lt;ul&gt;&lt;li&gt;&lt;a href=\"index.html\"&gt;خانه&lt;/a&gt;&lt;/li&gt;&lt;li&gt;&lt;a href=\"courses.html\"&gt;دوره‌ها&lt;/a&gt;&lt;/li&gt;&lt;/ul&gt;\n&lt;/nav&gt;</code></pre><h3>تمرین</h3><p>یک نوار ناوبری با سه مقصد بساز و برای آن نام قابل فهم تعیین کن.</p><h3>نکته مهم</h3><p>nav را برای هر پیوند پراکنده یا لینک پاورقی بی‌دلیل استفاده نکن.</p><h3>معیار موفقیت</h3><p>nav فقط پیوندهای ناوبری مهم را گروه‌بندی کند و نام قابل فهم داشته باشد.</p>","starter_code":"<nav aria-label=\"ناوبری اصلی\">\n  <ul><li><a href=\"index.html\">خانه</a></li><li><a href=\"courses.html\">دوره‌ها</a></li></ul>\n</nav>","exercise":"یک نوار ناوبری با سه مقصد بساز و برای آن نام قابل فهم تعیین کن.","status":"published","sort_order":19,"estimated_minutes":30},{"id":"curriculum-324-html-20","course_id":"html","title":"محتوای اصلی با main و article","slug":"html-beginner-20","summary":"در این درس محتوای اصلی با main و article را به‌صورت عملی یاد می‌گیری. main محتوای غالب و منحصربه‌فرد صفحه را مشخص می‌کند و معمولاً در هر سند یک نمونه قابل مشاهده دارد. article محتوایی مستقل و قابل بازنشر را نمایش می‌دهد.","content_html":"<h3>هدف درس</h3><p>main محتوای غالب و منحصربه‌فرد صفحه را مشخص می‌کند و معمولاً در هر سند یک نمونه قابل مشاهده دارد. article محتوایی مستقل و قابل بازنشر را نمایش می‌دهد.</p><h3>نمونه و بررسی</h3><p>دو article مستقل درون main قرار بده و بررسی کن هر مقاله بدون وابستگی به مقاله دیگر قابل فهم باشد.</p><pre><code>&lt;main&gt;\n  &lt;article&gt;&lt;h1&gt;چرا HTML مهم است؟&lt;/h1&gt;&lt;p&gt;ساختار محتوا را توصیف می‌کند.&lt;/p&gt;&lt;/article&gt;\n&lt;/main&gt;</code></pre><h3>تمرین</h3><p>یک صفحه وبلاگ با main و دو article مستقل طراحی کن. عنوان هر مقاله را داخل همان article قرار بده.</p><h3>نکته مهم</h3><p>main را برای محتوای تکراری مانند منوی ثابت سایت به کار نبر.</p><h3>معیار موفقیت</h3><p>main محتوای اصلی صفحه را مشخص کند و articleها محتوای مستقل و قابل فهم داشته باشند.</p>","starter_code":"<main>\n  <article><h1>چرا HTML مهم است؟</h1><p>ساختار محتوا را توصیف می‌کند.</p></article>\n</main>","exercise":"یک صفحه وبلاگ با main و دو article مستقل طراحی کن. عنوان هر مقاله را داخل همان article قرار بده.","status":"published","sort_order":20,"estimated_minutes":35},{"id":"curriculum-324-html-21","course_id":"html","title":"بخش‌بندی با section و aside","slug":"html-beginner-21","summary":"در این درس بخش‌بندی با section و aside را به‌صورت عملی یاد می‌گیری. section یک بخش موضوعی با عنوان است. aside محتوای جانبی مرتبط را مشخص می‌کند. انتخاب عنصر باید بر اساس نقش محتوا باشد، نه صرفاً شکل ظاهری.","content_html":"<h3>هدف درس</h3><p>section یک بخش موضوعی با عنوان است. aside محتوای جانبی مرتبط را مشخص می‌کند. انتخاب عنصر باید بر اساس نقش محتوا باشد، نه صرفاً شکل ظاهری.</p><h3>نمونه و بررسی</h3><p>برای هر section عنوان مرتبط بساز و aside را فقط برای اطلاعات جانبی مرتبط نگه دار.</p><pre><code>&lt;main&gt;\n  &lt;section&gt;&lt;h2&gt;سرفصل دوره&lt;/h2&gt;&lt;p&gt;HTML پایه...&lt;/p&gt;&lt;/section&gt;\n  &lt;aside&gt;&lt;h2&gt;نکته&lt;/h2&gt;&lt;p&gt;تمرین روزانه را فراموش نکن.&lt;/p&gt;&lt;/aside&gt;\n&lt;/main&gt;</code></pre><h3>تمرین</h3><p>صفحه دوره‌ای بساز که دو section عنوان‌دار و یک aside شامل نکته جانبی داشته باشد.</p><h3>نکته مهم</h3><p>هر div را به‌زور section نکن؛ بخش موضوعی معمولاً باید عنوان یا مفهوم مشخص داشته باشد.</p><h3>معیار موفقیت</h3><p>sectionها موضوع مشخص و عنوان داشته باشند و aside نقش جانبی مرتبط را ایفا کند.</p>","starter_code":"<main>\n  <section><h2>سرفصل دوره</h2><p>HTML پایه...</p></section>\n  <aside><h2>نکته</h2><p>تمرین روزانه را فراموش نکن.</p></aside>\n</main>","exercise":"صفحه دوره‌ای بساز که دو section عنوان‌دار و یک aside شامل نکته جانبی داشته باشد.","status":"published","sort_order":21,"estimated_minutes":20},{"id":"curriculum-324-html-22","course_id":"html","title":"ویژگی‌های عمومی id و class","slug":"html-beginner-22","summary":"در این درس ویژگی‌های عمومی id و class را به‌صورت عملی یاد می‌گیری. id شناسه یکتا در یک سند است و class برای گروهی از عناصر قابل تکرار استفاده می‌شود. این ویژگی‌ها در CSS و JavaScript برای یافتن عناصر کاربرد دارند.","content_html":"<h3>هدف درس</h3><p>id شناسه یکتا در یک سند است و class برای گروهی از عناصر قابل تکرار استفاده می‌شود. این ویژگی‌ها در CSS و JavaScript برای یافتن عناصر کاربرد دارند.</p><h3>نمونه و بررسی</h3><p>با جست‌وجوی id در فایل مطمئن شو مقدار آن تکراری نیست و چند عنصر می‌توانند class یکسان داشته باشند.</p><pre><code>&lt;h2 id=\"requirements\"&gt;پیش‌نیازها&lt;/h2&gt;\n&lt;p class=\"muted\"&gt;آشنایی با کار با فایل‌ها کافی است.&lt;/p&gt;\n&lt;p class=\"muted\"&gt;مرورگر به‌روز داشته باش.&lt;/p&gt;</code></pre><h3>تمرین</h3><p>برای یک عنوان id یکتا و برای دو پاراگراف class مشترک تعیین کن. در کل صفحه id تکراری نداشته باش.</p><h3>نکته مهم</h3><p>class می‌تواند تکرار شود؛ id در همان سند باید یکتا باشد.</p><h3>معیار موفقیت</h3><p>id در سند یکتا باشد و class بتواند برای چند عنصر مشترک استفاده شود.</p>","starter_code":"<h2 id=\"requirements\">پیش‌نیازها</h2>\n<p class=\"muted\">آشنایی با کار با فایل‌ها کافی است.</p>\n<p class=\"muted\">مرورگر به‌روز داشته باش.</p>","exercise":"برای یک عنوان id یکتا و برای دو پاراگراف class مشترک تعیین کن. در کل صفحه id تکراری نداشته باش.","status":"published","sort_order":22,"estimated_minutes":25},{"id":"curriculum-324-html-23","course_id":"html","title":"ویژگی‌های data-*","slug":"html-beginner-23","summary":"در این درس ویژگی‌های data-* را به‌صورت عملی یاد می‌گیری. ویژگی‌های data-* داده سفارشی متنی را به عنصر متصل می‌کنند. JavaScript می‌تواند آن‌ها را از dataset بخواند؛ داده حساس را در HTML قرار نده.","content_html":"<h3>هدف درس</h3><p>ویژگی‌های data-* داده سفارشی متنی را به عنصر متصل می‌کنند. JavaScript می‌تواند آن‌ها را از dataset بخواند؛ داده حساس را در HTML قرار نده.</p><h3>نمونه و بررسی</h3><p>مقدار data-course را در ابزار توسعه مرورگر تغییر بده و تفاوت داده سفارشی با متن قابل مشاهده را توضیح بده.</p><pre><code>&lt;button type=\"button\" data-course=\"html\"&gt;مشاهده دوره HTML&lt;/button&gt;\n&lt;p data-level=\"beginner\"&gt;سطح مقدماتی&lt;/p&gt;</code></pre><h3>تمرین</h3><p>به سه کارت دوره ویژگی data-course اضافه کن و مقدار هرکدام را متفاوت قرار بده. با ابزار توسعه مرورگر مقدارها را ببین.</p><h3>نکته مهم</h3><p>data-* جایگزین پایگاه داده یا محل نگهداری رمز و اطلاعات خصوصی نیست.</p><h3>معیار موفقیت</h3><p>ویژگی‌های data-* مقدارهای غیرحساس و قابل خواندن داشته باشند و برای اطلاعات خصوصی استفاده نشوند.</p>","starter_code":"<button type=\"button\" data-course=\"html\">مشاهده دوره HTML</button>\n<p data-level=\"beginner\">سطح مقدماتی</p>","exercise":"به سه کارت دوره ویژگی data-course اضافه کن و مقدار هرکدام را متفاوت قرار بده. با ابزار توسعه مرورگر مقدارها را ببین.","status":"published","sort_order":23,"estimated_minutes":30},{"id":"curriculum-324-html-24","course_id":"html","title":"جدول و ساختار پایه","slug":"html-beginner-24","summary":"در این درس جدول و ساختار پایه را به‌صورت عملی یاد می‌گیری. table داده‌های رابطه‌ای را در ردیف و ستون نمایش می‌دهد. tr ردیف، th سلول عنوان و td سلول داده است؛ برای چیدمان صفحه از جدول استفاده نکن.","content_html":"<h3>هدف درس</h3><p>table داده‌های رابطه‌ای را در ردیف و ستون نمایش می‌دهد. tr ردیف، th سلول عنوان و td سلول داده است؛ برای چیدمان صفحه از جدول استفاده نکن.</p><h3>نمونه و بررسی</h3><p>یک ردیف و یک ستون دیگر اضافه کن و مطمئن شو هر سلول داده در td و هر سرستون در th قرار دارد.</p><pre><code>&lt;table&gt;\n  &lt;tr&gt;&lt;th&gt;درس&lt;/th&gt;&lt;th&gt;زمان&lt;/th&gt;&lt;/tr&gt;\n  &lt;tr&gt;&lt;td&gt;HTML&lt;/td&gt;&lt;td&gt;۳۰ دقیقه&lt;/td&gt;&lt;/tr&gt;\n&lt;/table&gt;</code></pre><h3>تمرین</h3><p>جدول برنامه هفتگی با سه ستون روز، موضوع و زمان و دست‌کم سه ردیف داده بساز.</p><h3>نکته مهم</h3><p>برای چیدمان عمومی صفحه از table استفاده نکن؛ جدول مخصوص داده جدولی است.</p><h3>معیار موفقیت</h3><p>جدول برای داده رابطه‌ای باشد و ردیف‌ها و سلول‌ها در ساختار درست قرار بگیرند.</p>","starter_code":"<table>\n  <tr><th>درس</th><th>زمان</th></tr>\n  <tr><td>HTML</td><td>۳۰ دقیقه</td></tr>\n</table>","exercise":"جدول برنامه هفتگی با سه ستون روز، موضوع و زمان و دست‌کم سه ردیف داده بساز.","status":"published","sort_order":24,"estimated_minutes":35},{"id":"curriculum-324-html-25","course_id":"html","title":"عنوان جدول با caption و thead و tbody","slug":"html-beginner-25","summary":"در این درس عنوان جدول با caption و thead و tbody را به‌صورت عملی یاد می‌گیری. caption عنوان جدول را معرفی می‌کند. thead سرستون‌ها و tbody ردیف‌های داده را گروه‌بندی می‌کنند و به فهم ساختار کمک می‌کنند.","content_html":"<h3>هدف درس</h3><p>caption عنوان جدول را معرفی می‌کند. thead سرستون‌ها و tbody ردیف‌های داده را گروه‌بندی می‌کنند و به فهم ساختار کمک می‌کنند.</p><h3>نمونه و بررسی</h3><p>caption را تغییر بده و جدول را بدون CSS بخوان؛ سرستون‌ها باید نوع داده هر ستون را مشخص کنند.</p><pre><code>&lt;table&gt;\n  &lt;caption&gt;برنامه دوره‌ها&lt;/caption&gt;\n  &lt;thead&gt;&lt;tr&gt;&lt;th scope=\"col\"&gt;دوره&lt;/th&gt;&lt;th scope=\"col\"&gt;سطح&lt;/th&gt;&lt;/tr&gt;&lt;/thead&gt;\n  &lt;tbody&gt;&lt;tr&gt;&lt;td&gt;HTML&lt;/td&gt;&lt;td&gt;مقدماتی&lt;/td&gt;&lt;/tr&gt;&lt;/tbody&gt;\n&lt;/table&gt;</code></pre><h3>تمرین</h3><p>جدول برنامه درسی را با caption، thead و tbody بازنویسی کن و برای سرستون‌ها scope=\"col\" بگذار.</p><h3>نکته مهم</h3><p>عنوان جدول را با یک تیتر بیرون جدول اشتباه نگیر؛ caption بخشی از جدول است.</p><h3>معیار موفقیت</h3><p>جدول caption و سرستون‌های روشن داشته باشد و ترتیب ردیف‌ها قابل فهم باشد.</p>","starter_code":"<table>\n  <caption>برنامه دوره‌ها</caption>\n  <thead><tr><th scope=\"col\">دوره</th><th scope=\"col\">سطح</th></tr></thead>\n  <tbody><tr><td>HTML</td><td>مقدماتی</td></tr></tbody>\n</table>","exercise":"جدول برنامه درسی را با caption، thead و tbody بازنویسی کن و برای سرستون‌ها scope=\"col\" بگذار.","status":"published","sort_order":25,"estimated_minutes":20},{"id":"curriculum-324-html-26","course_id":"html","title":"فرم و عنصر form","slug":"html-beginner-26","summary":"در این درس فرم و عنصر form را به‌صورت عملی یاد می‌گیری. form مجموعه‌ای از کنترل‌ها را برای دریافت و ارسال داده گروه‌بندی می‌کند. action مقصد ارسال و method روش ارسال را تعیین می‌کند؛ پردازش واقعی به سمت سرور نیاز دارد.","content_html":"<h3>هدف درس</h3><p>form مجموعه‌ای از کنترل‌ها را برای دریافت و ارسال داده گروه‌بندی می‌کند. action مقصد ارسال و method روش ارسال را تعیین می‌کند؛ پردازش واقعی به سمت سرور نیاز دارد.</p><h3>نمونه و بررسی</h3><p>فرم را بدون CSS اجرا کن و با دکمه ارسال بررسی کن که مرورگر داده‌ها را به کدام action می‌فرستد.</p><pre><code>&lt;form action=\"/register\" method=\"post\"&gt;\n  &lt;label for=\"student-name\"&gt;نام&lt;/label&gt;\n  &lt;input id=\"student-name\" name=\"name\" type=\"text\"&gt;\n  &lt;button type=\"submit\"&gt;ارسال&lt;/button&gt;\n&lt;/form&gt;</code></pre><h3>تمرین</h3><p>یک فرم ثبت‌نام آزمایشی بساز و برای ورودی name تعیین کن. توضیح بده چرا وجود فرم به‌تنهایی ذخیره‌سازی اطلاعات را انجام نمی‌دهد.</p><h3>نکته مهم</h3><p>اطلاعات حساس را با فرم آزمایشی به مقصد ناشناس ارسال نکن.</p><h3>معیار موفقیت</h3><p>هر ورودی فرم نام و روش ارسال مناسب داشته باشد و کاربر بتواند فرم را با صفحه‌کلید تکمیل کند.</p>","starter_code":"<form action=\"/register\" method=\"post\">\n  <label for=\"student-name\">نام</label>\n  <input id=\"student-name\" name=\"name\" type=\"text\">\n  <button type=\"submit\">ارسال</button>\n</form>","exercise":"یک فرم ثبت‌نام آزمایشی بساز و برای ورودی name تعیین کن. توضیح بده چرا وجود فرم به‌تنهایی ذخیره‌سازی اطلاعات را انجام نمی‌دهد.","status":"published","sort_order":26,"estimated_minutes":25},{"id":"curriculum-324-html-27","course_id":"html","title":"label و ارتباط با ورودی","slug":"html-beginner-27","summary":"در این درس label و ارتباط با ورودی را به‌صورت عملی یاد می‌گیری. label نام قابل فهم کنترل را مشخص می‌کند. اتصال for در label به id ورودی باعث می‌شود کلیک روی برچسب نیز کنترل را فعال کند و صفحه‌خوان نام آن را بخواند.","content_html":"<h3>هدف درس</h3><p>label نام قابل فهم کنترل را مشخص می‌کند. اتصال for در label به id ورودی باعث می‌شود کلیک روی برچسب نیز کنترل را فعال کند و صفحه‌خوان نام آن را بخواند.</p><h3>نمونه و بررسی</h3><p>روی متن label کلیک کن و ببین آیا فوکوس به ورودی متناظر منتقل می‌شود؛ مقدار for باید با id یکسان باشد.</p><pre><code>&lt;label for=\"email\"&gt;ایمیل&lt;/label&gt;\n&lt;input id=\"email\" name=\"email\" type=\"email\"&gt;</code></pre><h3>تمرین</h3><p>برای نام، ایمیل و رمز سه ورودی بساز و هرکدام را با label دارای for و id متناظر متصل کن.</p><h3>نکته مهم</h3><p>placeholder جایگزین label نیست؛ پس از واردکردن متن، placeholder ناپدید می‌شود.</p><h3>معیار موفقیت</h3><p>کلیک روی label ورودی درست را فعال کند و شناسه‌های for و id دقیقاً تطابق داشته باشند.</p>","starter_code":"<label for=\"email\">ایمیل</label>\n<input id=\"email\" name=\"email\" type=\"email\">","exercise":"برای نام، ایمیل و رمز سه ورودی بساز و هرکدام را با label دارای for و id متناظر متصل کن.","status":"published","sort_order":27,"estimated_minutes":30},{"id":"curriculum-324-html-28","course_id":"html","title":"انواع ورودی input","slug":"html-beginner-28","summary":"در این درس انواع ورودی input را به‌صورت عملی یاد می‌گیری. نوع input رفتار و صفحه‌کلید مناسب را تعیین می‌کند؛ مانند email، password، number، date و checkbox. انتخاب نوع درست اعتبارسنجی اولیه و تجربه کاربری را بهتر می‌کند.","content_html":"<h3>هدف درس</h3><p>نوع input رفتار و صفحه‌کلید مناسب را تعیین می‌کند؛ مانند email، password، number، date و checkbox. انتخاب نوع درست اعتبارسنجی اولیه و تجربه کاربری را بهتر می‌کند.</p><h3>نمونه و بررسی</h3><p>هر type را جداگانه آزمایش کن و تفاوت کنترل‌های مرورگر برای email، number و date را مشاهده کن.</p><pre><code>&lt;label for=\"age\"&gt;سن&lt;/label&gt;&lt;input id=\"age\" name=\"age\" type=\"number\" min=\"10\" max=\"99\"&gt;\n&lt;label&gt;&lt;input type=\"checkbox\" name=\"agree\"&gt; قوانین را می‌پذیرم&lt;/label&gt;</code></pre><h3>تمرین</h3><p>فرمی با ورودی تاریخ تولد، ایمیل، عدد و checkbox بساز. برای هرکدام نوع مناسب انتخاب کن.</p><h3>نکته مهم</h3><p>اعتبارسنجی مرورگر جای بررسی امن داده در سرور را نمی‌گیرد.</p><h3>معیار موفقیت</h3><p>هر کنترل نوع مناسب داشته باشد و مرورگر رفتار متناسب با نوع ورودی را ارائه کند.</p>","starter_code":"<label for=\"age\">سن</label><input id=\"age\" name=\"age\" type=\"number\" min=\"10\" max=\"99\">\n<label><input type=\"checkbox\" name=\"agree\"> قوانین را می‌پذیرم</label>","exercise":"فرمی با ورودی تاریخ تولد، ایمیل، عدد و checkbox بساز. برای هرکدام نوع مناسب انتخاب کن.","status":"published","sort_order":28,"estimated_minutes":35},{"id":"curriculum-324-html-29","course_id":"html","title":"ویژگی‌های required و minlength","slug":"html-beginner-29","summary":"در این درس ویژگی‌های required و minlength را به‌صورت عملی یاد می‌گیری. required ورود مقدار را الزامی می‌کند و minlength حداقل طول متن را مشخص می‌کند. مرورگر هنگام ارسال فرم اعتبارسنجی اولیه انجام می‌دهد.","content_html":"<h3>هدف درس</h3><p>required ورود مقدار را الزامی می‌کند و minlength حداقل طول متن را مشخص می‌کند. مرورگر هنگام ارسال فرم اعتبارسنجی اولیه انجام می‌دهد.</p><h3>نمونه و بررسی</h3><p>فرم را با مقدار خالی و سپس مقدار کوتاه ارسال کن تا اعتبارسنجی بومی مرورگر را ببینی.</p><pre><code>&lt;form&gt;\n  &lt;label for=\"user\"&gt;شناسه&lt;/label&gt;\n  &lt;input id=\"user\" name=\"user\" required minlength=\"4\"&gt;\n  &lt;button&gt;بررسی&lt;/button&gt;\n&lt;/form&gt;</code></pre><h3>تمرین</h3><p>فرم ساخت شناسه‌ای بساز که خالی نباشد و حداقل چهار نویسه داشته باشد. حالت خالی و مقدار کوتاه را آزمایش کن.</p><h3>نکته مهم</h3><p>این محدودیت‌ها به‌تنهایی امنیت یا اعتبار داده در سرور را تضمین نمی‌کنند.</p><h3>معیار موفقیت</h3><p>فرم مقدار خالی یا کوتاه را مطابق محدودیت‌های تعریف‌شده رد کند و پیام مرورگر قابل مشاهده باشد.</p>","starter_code":"<form>\n  <label for=\"user\">شناسه</label>\n  <input id=\"user\" name=\"user\" required minlength=\"4\">\n  <button>بررسی</button>\n</form>","exercise":"فرم ساخت شناسه‌ای بساز که خالی نباشد و حداقل چهار نویسه داشته باشد. حالت خالی و مقدار کوتاه را آزمایش کن.","status":"published","sort_order":29,"estimated_minutes":20},{"id":"curriculum-324-html-30","course_id":"html","title":"select و option","slug":"html-beginner-30","summary":"در این درس select و option را به‌صورت عملی یاد می‌گیری. select برای انتخاب از گزینه‌های از پیش تعریف‌شده مناسب است. هر option یک انتخاب و value مقدار ارسالی آن را تعیین می‌کند.","content_html":"<h3>هدف درس</h3><p>select برای انتخاب از گزینه‌های از پیش تعریف‌شده مناسب است. هر option یک انتخاب و value مقدار ارسالی آن را تعیین می‌کند.</p><h3>نمونه و بررسی</h3><p>گزینه پیش‌فرض و گزینه انتخاب‌شده را تغییر بده و مقدار نهایی select را بررسی کن.</p><pre><code>&lt;label for=\"level\"&gt;سطح دوره&lt;/label&gt;\n&lt;select id=\"level\" name=\"level\"&gt;\n  &lt;option value=\"beginner\"&gt;مقدماتی&lt;/option&gt;\n  &lt;option value=\"intermediate\"&gt;متوسط&lt;/option&gt;\n  &lt;option value=\"advanced\"&gt;پیشرفته&lt;/option&gt;\n&lt;/select&gt;</code></pre><h3>تمرین</h3><p>یک انتخاب‌گر سطح دوره با سه گزینه بساز و value انگلیسی و متن نمایشی فارسی قرار بده.</p><h3>نکته مهم</h3><p>متن نمایشی و value می‌توانند متفاوت باشند؛ مقدار ارسالی را آگاهانه انتخاب کن.</p><h3>معیار موفقیت</h3><p>select مقدار معتبر انتخاب‌شده داشته باشد و هر option مقدار و متن روشن ارائه کند.</p>","starter_code":"<label for=\"level\">سطح دوره</label>\n<select id=\"level\" name=\"level\">\n  <option value=\"beginner\">مقدماتی</option>\n  <option value=\"intermediate\">متوسط</option>\n  <option value=\"advanced\">پیشرفته</option>\n</select>","exercise":"یک انتخاب‌گر سطح دوره با سه گزینه بساز و value انگلیسی و متن نمایشی فارسی قرار بده.","status":"published","sort_order":30,"estimated_minutes":25},{"id":"curriculum-324-html-31","course_id":"html","title":"textarea برای متن چندخطی","slug":"html-beginner-31","summary":"در این درس textarea برای متن چندخطی را به‌صورت عملی یاد می‌گیری. textarea ورودی متن چندخطی است. برخلاف input، متن آن بین تگ آغاز و پایان قرار می‌گیرد و می‌توان اندازه اولیه را با rows و cols تعیین کرد.","content_html":"<h3>هدف درس</h3><p>textarea ورودی متن چندخطی است. برخلاف input، متن آن بین تگ آغاز و پایان قرار می‌گیرد و می‌توان اندازه اولیه را با rows و cols تعیین کرد.</p><h3>نمونه و بررسی</h3><p>چند خط متن وارد کن و اندازه textarea را با rows و cols تغییر بده.</p><pre><code>&lt;label for=\"message\"&gt;پیام&lt;/label&gt;\n&lt;textarea id=\"message\" name=\"message\" rows=\"5\" maxlength=\"500\"&gt;&lt;/textarea&gt;</code></pre><h3>تمرین</h3><p>فرم بازخورد بساز که یک textarea با حداکثر ۵۰۰ نویسه داشته باشد. برچسب واضح برای آن بنویس.</p><h3>نکته مهم</h3><p>برای متن چندخطی از input type=text استفاده نکن.</p><h3>معیار موفقیت</h3><p>textarea چندخطی باشد و label قابل مشاهده و مرتبط داشته باشد.</p>","starter_code":"<label for=\"message\">پیام</label>\n<textarea id=\"message\" name=\"message\" rows=\"5\" maxlength=\"500\"></textarea>","exercise":"فرم بازخورد بساز که یک textarea با حداکثر ۵۰۰ نویسه داشته باشد. برچسب واضح برای آن بنویس.","status":"published","sort_order":31,"estimated_minutes":30},{"id":"curriculum-324-html-32","course_id":"html","title":"button و نوع دکمه","slug":"html-beginner-32","summary":"در این درس button و نوع دکمه را به‌صورت عملی یاد می‌گیری. button می‌تواند submit، reset یا button باشد. داخل فرم، نوع پیش‌فرض ممکن است submit باشد؛ تعیین type رفتار را روشن و از ارسال ناخواسته جلوگیری می‌کند.","content_html":"<h3>هدف درس</h3><p>button می‌تواند submit، reset یا button باشد. داخل فرم، نوع پیش‌فرض ممکن است submit باشد؛ تعیین type رفتار را روشن و از ارسال ناخواسته جلوگیری می‌کند.</p><h3>نمونه و بررسی</h3><p>دکمه را درون فرم با type=button و type=submit مقایسه کن تا تفاوت رفتار ارسال مشخص شود.</p><pre><code>&lt;button type=\"button\"&gt;نمایش راهنما&lt;/button&gt;\n&lt;button type=\"submit\"&gt;ثبت فرم&lt;/button&gt;\n&lt;button type=\"reset\"&gt;پاک‌کردن فرم&lt;/button&gt;</code></pre><h3>تمرین</h3><p>در یک فرم سه دکمه با نوع‌های مشخص بساز و رفتار هرکدام را در مرورگر آزمایش کن.</p><h3>نکته مهم</h3><p>دکمه‌ای که فقط قرار است JavaScript را اجرا کند باید type=\"button\" داشته باشد.</p><h3>معیار موفقیت</h3><p>دکمه عملیاتی نوع درست داشته باشد و ارسال ناخواسته فرم رخ ندهد.</p>","starter_code":"<button type=\"button\">نمایش راهنما</button>\n<button type=\"submit\">ثبت فرم</button>\n<button type=\"reset\">پاک‌کردن فرم</button>","exercise":"در یک فرم سه دکمه با نوع‌های مشخص بساز و رفتار هرکدام را در مرورگر آزمایش کن.","status":"published","sort_order":32,"estimated_minutes":35},{"id":"curriculum-324-html-33","course_id":"html","title":"audio و video","slug":"html-beginner-33","summary":"در این درس audio و video را به‌صورت عملی یاد می‌گیری. audio و video رسانه را با کنترل‌های بومی مرورگر پخش می‌کنند. برای دسترس‌پذیری و سازگاری، در صورت نیاز چند source و متن جایگزین ارائه کن.","content_html":"<h3>هدف درس</h3><p>audio و video رسانه را با کنترل‌های بومی مرورگر پخش می‌کنند. برای دسترس‌پذیری و سازگاری، در صورت نیاز چند source و متن جایگزین ارائه کن.</p><h3>نمونه و بررسی</h3><p>فایل صوتی و ویدیویی مجاز در اختیار بگذار و کنترل‌های پخش، توقف و پیام fallback را آزمایش کن.</p><pre><code>&lt;video controls width=\"480\"&gt;\n  &lt;source src=\"intro.mp4\" type=\"video/mp4\"&gt;\n  مرورگر شما از ویدیو پشتیبانی نمی‌کند.\n&lt;/video&gt;</code></pre><h3>تمرین</h3><p>یک فایل رسانه‌ای مجاز در پوشه پروژه قرار بده و با video یا audio پخش کن. controls را فعال و مسیر را بررسی کن.</p><h3>نکته مهم</h3><p>فایل رسانه را بدون توجه به مجوز استفاده دیگران کپی نکن.</p><h3>معیار موفقیت</h3><p>رسانه با کنترل‌های بومی قابل استفاده باشد و در نبود فایل پیام یا fallback مناسب ارائه شود.</p>","starter_code":"<video controls width=\"480\">\n  <source src=\"intro.mp4\" type=\"video/mp4\">\n  مرورگر شما از ویدیو پشتیبانی نمی‌کند.\n</video>","exercise":"یک فایل رسانه‌ای مجاز در پوشه پروژه قرار بده و با video یا audio پخش کن. controls را فعال و مسیر را بررسی کن.","status":"published","sort_order":33,"estimated_minutes":20},{"id":"curriculum-324-html-34","course_id":"html","title":"قرار دادن محتوای خارجی با iframe","slug":"html-beginner-34","summary":"در این درس قرار دادن محتوای خارجی با iframe را به‌صورت عملی یاد می‌گیری. iframe یک صفحه یا محتوای خارجی را در محدوده‌ای از صفحه جاسازی می‌کند. فقط منبع قابل اعتماد را وارد کن و برای آن title توصیفی بگذار.","content_html":"<h3>هدف درس</h3><p>iframe یک صفحه یا محتوای خارجی را در محدوده‌ای از صفحه جاسازی می‌کند. فقط منبع قابل اعتماد را وارد کن و برای آن title توصیفی بگذار.</p><h3>نمونه و بررسی</h3><p>آدرس iframe را با صفحه‌ای که اجازه embedding می‌دهد جایگزین کن؛ بسیاری از سایت‌ها به دلایل امنیتی داخل iframe باز نمی‌شوند.</p><pre><code>&lt;iframe src=\"https://www.example.com\" title=\"صفحه نمونه\" width=\"600\" height=\"350\" loading=\"lazy\"&gt;&lt;/iframe&gt;</code></pre><h3>تمرین</h3><p>یک محتوای آزمایشی مجاز را با iframe جاسازی کن و title توصیفی اضافه کن. محدودیت‌های نمایش سایت‌های خارجی را بررسی کن.</p><h3>نکته مهم</h3><p>همه سایت‌ها اجازه جاسازی در iframe نمی‌دهند؛ این محدودیت را با دورزدن امنیتی حل نکن.</p><h3>معیار موفقیت</h3><p>iframe فقط منبع مجاز را بارگذاری کند و عنوان توصیفی و ابعاد مناسب داشته باشد.</p>","starter_code":"<iframe src=\"https://www.example.com\" title=\"صفحه نمونه\" width=\"600\" height=\"350\" loading=\"lazy\"></iframe>","exercise":"یک محتوای آزمایشی مجاز را با iframe جاسازی کن و title توصیفی اضافه کن. محدودیت‌های نمایش سایت‌های خارجی را بررسی کن.","status":"published","sort_order":34,"estimated_minutes":25},{"id":"curriculum-324-html-35","course_id":"html","title":"نشانه‌گذاری کد و نقل‌قول","slug":"html-beginner-35","summary":"در این درس نشانه‌گذاری کد و نقل‌قول را به‌صورت عملی یاد می‌گیری. code برای قطعه کد درون‌خطی و pre برای متن از پیش قالب‌بندی‌شده مناسب است. blockquote نقل‌قول بلند از منبع دیگر را مشخص می‌کند.","content_html":"<h3>هدف درس</h3><p>code برای قطعه کد درون‌خطی و pre برای متن از پیش قالب‌بندی‌شده مناسب است. blockquote نقل‌قول بلند از منبع دیگر را مشخص می‌کند.</p><h3>نمونه و بررسی</h3><p>تفاوت code درون‌خطی و pre برای بلوک چندخطی را بررسی کن و مطمئن شو فاصله‌های کد حفظ می‌شوند.</p><pre><code>&lt;p&gt;برای تیتر از &lt;code&gt;&amp;lt;h1&amp;gt;&lt;/code&gt; استفاده می‌کنیم.&lt;/p&gt;\n&lt;pre&gt;&lt;code&gt;const name = \"NEXORA\";\nconsole.log(name);&lt;/code&gt;&lt;/pre&gt;</code></pre><h3>تمرین</h3><p>در یک درس، یک تگ HTML را با code نمایش بده و یک نمونه چندخطی را داخل pre و code قرار بده.</p><h3>نکته مهم</h3><p>کد HTML را داخل نمونه با نویسه‌های &lt; و &gt; نمایش بده تا مرورگر آن را به‌عنوان تگ اجرا نکند.</p><h3>معیار موفقیت</h3><p>کد درون‌خطی و بلوک چندخطی از نظر معنایی درست نشانه‌گذاری شوند و فاصله کد حفظ شود.</p>","starter_code":"<p>برای تیتر از <code>&lt;h1&gt;</code> استفاده می‌کنیم.</p>\n<pre><code>const name = \"NEXORA\";\nconsole.log(name);</code></pre>","exercise":"در یک درس، یک تگ HTML را با code نمایش بده و یک نمونه چندخطی را داخل pre و code قرار بده.","status":"published","sort_order":35,"estimated_minutes":30},{"id":"curriculum-324-html-36","course_id":"html","title":"پروژه پایانی: ساخت صفحه معرفی دانش‌آموز","slug":"html-beginner-36-final-project","summary":"در پروژه پایانی HTML مقدماتی، ساختار سند، عناصر معنایی، پیوندها، فهرست‌ها، تصویر، جدول و فرم را در یک صفحه واقعی ترکیب می‌کنی.","content_html":"<h3>هدف پروژه</h3><p>اکنون باید آموخته‌های HTML مقدماتی را در یک صفحه منسجم به کار ببری. این پروژه فقط تمرین نشانه‌گذاری است؛ هنوز CSS یا ذخیره‌سازی سمت سرور ندارد.</p><h3>ساختار مورد انتظار</h3><ul><li>سند کامل با doctype، lang، charset و viewport</li><li>header، nav، main، section و footer</li><li>تصویر دارای alt معنادار</li><li>فهرست مهارت‌ها و جدول دارای caption و سرستون</li><li>فرم دارای label، textarea و دکمه با type مشخص</li></ul><h3>نمونه شروع</h3><p>کد starter را در فایل index.html قرار بده. فایل تصویر را در همان پوشه بگذار یا مسیر src را متناسب با پروژه خودت تغییر بده.</p><h3>تمرین نهایی</h3><p>صفحه معرفی خودت را کامل کن. دست‌کم سه بخش ناوبری داشته باش، اطلاعات واقعی و غیرحساس وارد کن، مسیر پیوندها را آزمایش کن و همه عناصر را با معنای درست انتخاب کن.</p><h3>معیار ارزیابی</h3><ol><li>صفحه در موبایل و رایانه باز شود.</li><li>ساختار سند و ترتیب تیترها منطقی باشد.</li><li>تصویر alt مناسب داشته باشد.</li><li>هر ورودی فرم برچسب قابل مشاهده داشته باشد.</li><li>اعتبارسنج HTML خطاهای مهم را گزارش نکند.</li></ol><h3>محدودیت مهم</h3><p>فرم نمونه بدون backend اطلاعات را ذخیره یا ارسال واقعی نمی‌کند. این پروژه عمداً فقط HTML است؛ ظاهر حرفه‌ای در دوره CSS ساخته خواهد شد.</p>","starter_code":"<!doctype html>\n<html lang=\"fa\" dir=\"rtl\">\n<head>\n  <meta charset=\"UTF-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n  <title>پروفایل دانش‌آموز</title>\n</head>\n<body>\n  <header>\n    <h1>پروفایل من</h1>\n    <nav aria-label=\"ناوبری اصلی\">\n      <a href=\"#about\">درباره من</a>\n      <a href=\"#skills\">مهارت‌ها</a>\n      <a href=\"#contact\">تماس</a>\n    </nav>\n  </header>\n  <main>\n    <section id=\"about\">\n      <h2>درباره من</h2>\n      <p>من در حال یادگیری طراحی وب هستم.</p>\n      <img src=\"profile.jpg\" alt=\"تصویر پروفایل دانش‌آموز\" width=\"180\">\n    </section>\n    <section id=\"skills\">\n      <h2>مهارت‌ها</h2>\n      <ul><li>HTML</li><li>حل مسئله</li></ul>\n      <table>\n        <caption>برنامه هفتگی</caption>\n        <thead><tr><th scope=\"col\">روز</th><th scope=\"col\">موضوع</th></tr></thead>\n        <tbody><tr><td>شنبه</td><td>HTML</td></tr></tbody>\n      </table>\n    </section>\n    <section id=\"contact\">\n      <h2>تماس</h2>\n      <form>\n        <label for=\"message\">پیام</label>\n        <textarea id=\"message\" name=\"message\" rows=\"4\"></textarea>\n        <button type=\"submit\">ارسال آزمایشی</button>\n      </form>\n    </section>\n  </main>\n  <footer><p>© NEXORA FORGE</p></footer>\n</body>\n</html>","exercise":"یک صفحه معرفی دانش‌آموز با header، nav، main، سه section، تصویر دارای alt، فهرست، جدول معنایی، فرم برچسب‌دار و footer بساز. آن را در مرورگر و اعتبارسنج HTML آزمایش کن و خطاها را اصلاح کن.","status":"published","sort_order":36,"estimated_minutes":60}]$lessons$::jsonb) as x(id text,course_id text,title text,slug text,summary text,content_html text,starter_code text,exercise text,status text,sort_order integer,estimated_minutes integer)
join (values
('html','html','beginner'),('html-intermediate','html','intermediate'),('html-advanced','html','advanced'),
('css','css','beginner'),('css-intermediate','css','intermediate'),('css-advanced','css','advanced'),
('javascript','javascript','beginner'),('javascript-intermediate','javascript','intermediate'),('javascript-advanced','javascript','advanced')
) as cp(course_id,language_id,level_id) on cp.course_id=x.course_id
join public.academy_courses c on c.language_id=cp.language_id and c.level_id=cp.level_id
on conflict(id) do update set title=excluded.title,slug=excluded.slug,summary=excluded.summary,content_html=excluded.content_html,starter_code=excluded.starter_code,exercise=excluded.exercise,status='published',sort_order=excluded.sort_order,estimated_minutes=excluded.estimated_minutes,archived_at=null,updated_at=now();
commit;
