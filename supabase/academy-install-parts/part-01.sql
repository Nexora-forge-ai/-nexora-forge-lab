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
commit;
