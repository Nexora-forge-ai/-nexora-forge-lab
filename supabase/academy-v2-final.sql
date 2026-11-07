-- NEXORA FORGE ACADEMY — FINAL BASELINE
-- Target project: nutgcqhcgytjglyuvmla
-- Run ONCE in Supabase SQL Editor after reviewing this file.
-- This script creates the academy schema, RLS, role bootstrap helper, quiz grading,
-- public media bucket, nine courses, and imports the existing 58 beginner lessons.
-- Do not rerun after editing lesson content: the lesson seed uses ON CONFLICT DO NOTHING.

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
for insert to authenticated with check (user_id=(select auth.uid()));
create policy "progress_update_self" on public.academy_lesson_progress
for update to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
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
grant select, insert, update, delete on public.academy_languages, public.academy_levels, public.academy_courses,
  public.academy_lessons, public.academy_lesson_attachments, public.academy_quizzes,
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
as $
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
$;
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
as $
  select p.user_id, u.email, p.display_name, u.created_at,
    (select count(*) from public.academy_lesson_progress lp
      where lp.user_id=p.user_id and lp.status='completed'),
    (select count(*) from public.academy_quiz_attempts qa where qa.user_id=p.user_id)
  from public.academy_profiles p
  join auth.users u on u.id=p.user_id
  where public.academy_is_admin()
  order by u.created_at desc;
$;
revoke all on function public.academy_admin_student_overview() from public, anon;
grant execute on function public.academy_admin_student_overview() to authenticated;

commit;

-- ONE-TIME OWNER BOOTSTRAP:
-- 1. Register the owner's account through the website and verify the email.
-- 2. Replace the email below with the exact owner email and run this statement separately.
-- 3. Do not expose role changes from client-side JavaScript.
--
-- insert into public.academy_user_roles(user_id,role)
-- select id,'super_admin' from auth.users where lower(email)=lower('YOUR-EMAIL@example.com')
-- on conflict do nothing;
