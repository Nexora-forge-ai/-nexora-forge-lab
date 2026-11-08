-- NEXORA FORGE ACADEMY — AUTH, STUDENT STATUS AND SECURE QUIZ PATCH
-- Run once after academy-v2-final.sql and academy-curriculum-324.sql.
begin;

alter table public.academy_profiles
  add column if not exists student_code text,
  add column if not exists account_status text not null default 'active';
alter table public.academy_profiles drop constraint if exists academy_profiles_account_status_check;
alter table public.academy_profiles add constraint academy_profiles_account_status_check
  check(account_status in ('active','blocked'));

create or replace function public.academy_generate_student_code()
returns text language plpgsql volatile set search_path=public
as $student_code_gen$
declare
 alphabet constant text:='abcdefghjkmnpqrstuvwxyz23456789';
 bytes bytea; result text; i integer;
begin
 loop
  bytes:=gen_random_bytes(12);result:='';
  for i in 0..11 loop
   result:=result||substr(alphabet,(get_byte(bytes,i)%length(alphabet))+1,1);
  end loop;
  exit when not exists(select 1 from public.academy_profiles where student_code=result);
 end loop;
 return result;
end;
$student_code_gen$;

update public.academy_profiles
set student_code=public.academy_generate_student_code()
where student_code is null or student_code='';
create unique index if not exists academy_profiles_student_code_uidx
on public.academy_profiles(student_code);

revoke update on public.academy_profiles from authenticated;
grant update(display_name,avatar_path) on public.academy_profiles to authenticated;
alter table public.academy_profiles
 alter column student_code set not null,
 alter column student_code set default public.academy_generate_student_code();

create or replace function public.academy_handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $academy_new_user$
declare requested_code text:=lower(coalesce(new.raw_user_meta_data->>'student_code',''));
begin
 if requested_code<>'' and requested_code !~ '^[a-z0-9]{12}$' then
  raise exception 'Student code must be exactly 12 lowercase letters or digits';
 end if;
 insert into public.academy_profiles(user_id,display_name,student_code,account_status)
 values(new.id,coalesce(new.raw_user_meta_data->>'display_name',''),
  case when requested_code='' then public.academy_generate_student_code() else requested_code end,'active')
 on conflict(user_id) do update set
  display_name=excluded.display_name,
  student_code=coalesce(public.academy_profiles.student_code,excluded.student_code);
 insert into public.academy_user_roles(user_id,role) values(new.id,'student') on conflict do nothing;
 return new;
end;
$academy_new_user$;

create or replace function public.academy_is_active_user()
returns boolean language sql stable security definer set search_path=public
as $academy_active_user$
 select exists(select 1 from public.academy_profiles p
  where p.user_id=(select auth.uid()) and p.account_status='active');
$academy_active_user$;
revoke all on function public.academy_is_active_user() from public;
grant execute on function public.academy_is_active_user() to authenticated;

create table if not exists public.academy_auth_rate_limits(
 key_hash text primary key,
 window_started_at timestamptz not null default now(),
 attempt_count integer not null default 0,
 blocked_until timestamptz
);
alter table public.academy_auth_rate_limits enable row level security;
revoke all on public.academy_auth_rate_limits from anon,authenticated;

create or replace function public.academy_check_login_rate_limit(p_key_hash text,p_failed boolean default false)
returns jsonb language plpgsql security definer set search_path=public
as $academy_rate_limit$
declare r public.academy_auth_rate_limits%rowtype; now_at timestamptz:=now();
begin
 if auth.role()<>'service_role' then raise exception 'Service role required'; end if;
 insert into public.academy_auth_rate_limits(key_hash) values(p_key_hash) on conflict(key_hash) do nothing;
 select * into r from public.academy_auth_rate_limits where key_hash=p_key_hash for update;
 if r.blocked_until is not null and r.blocked_until>now_at then
  return jsonb_build_object('allowed',false,'retry_after',ceil(extract(epoch from (r.blocked_until-now_at)))::integer);
 end if;
 if r.window_started_at<now_at-interval '15 minutes' then
  update public.academy_auth_rate_limits set window_started_at=now_at,
   attempt_count=case when p_failed then 1 else 0 end,blocked_until=null where key_hash=p_key_hash;
  return jsonb_build_object('allowed',true,'remaining',case when p_failed then 7 else 8 end);
 end if;
 if p_failed then
  update public.academy_auth_rate_limits set attempt_count=attempt_count+1,
   blocked_until=case when attempt_count+1>=8 then now_at+interval '15 minutes' else null end
   where key_hash=p_key_hash returning * into r;
 end if;
 if r.attempt_count>=8 and r.blocked_until is not null then
  return jsonb_build_object('allowed',false,'retry_after',900);
 end if;
 return jsonb_build_object('allowed',true,'remaining',greatest(0,8-r.attempt_count));
end;
$academy_rate_limit$;
revoke all on function public.academy_check_login_rate_limit(text,boolean) from public,anon,authenticated;
grant execute on function public.academy_check_login_rate_limit(text,boolean) to service_role;

drop function if exists public.academy_admin_student_overview();
create function public.academy_admin_student_overview()
returns table(user_id uuid,email text,display_name text,student_code text,account_status text,
 created_at timestamptz,completed_lessons bigint,quiz_attempts bigint)
language sql stable security definer set search_path=public
as $academy_admin_overview$
 select p.user_id,u.email,p.display_name,p.student_code,p.account_status,u.created_at,
  (select count(*) from public.academy_lesson_progress lp where lp.user_id=p.user_id and lp.status='completed'),
  (select count(*) from public.academy_quiz_attempts qa where qa.user_id=p.user_id)
 from public.academy_profiles p join auth.users u on u.id=p.user_id
 where public.academy_is_admin() order by u.created_at desc;
$academy_admin_overview$;
revoke all on function public.academy_admin_student_overview() from public,anon;
grant execute on function public.academy_admin_student_overview() to authenticated;

drop policy if exists "academy_avatars_owner_read" on storage.objects;
create policy "academy_avatars_owner_read" on storage.objects
for select to authenticated using(bucket_id='academy-avatars' and public.academy_is_active_user()
 and ((storage.foldername(name))[1]=(select auth.uid())::text or public.academy_is_admin()));
drop policy if exists "academy_avatars_owner_insert" on storage.objects;
create policy "academy_avatars_owner_insert" on storage.objects
for insert to authenticated with check(bucket_id='academy-avatars' and public.academy_is_active_user()
 and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "academy_avatars_owner_update" on storage.objects;
create policy "academy_avatars_owner_update" on storage.objects
for update to authenticated using(bucket_id='academy-avatars' and public.academy_is_active_user()
 and (storage.foldername(name))[1]=(select auth.uid())::text)
with check(bucket_id='academy-avatars' and public.academy_is_active_user()
 and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "academy_avatars_owner_delete" on storage.objects;
create policy "academy_avatars_owner_delete" on storage.objects
for delete to authenticated using(bucket_id='academy-avatars' and public.academy_is_active_user()
 and (storage.foldername(name))[1]=(select auth.uid())::text);

drop policy if exists "profile_update_self_or_admin" on public.academy_profiles;
create policy "profile_update_self_or_admin" on public.academy_profiles
for update to authenticated using((user_id=(select auth.uid()) and public.academy_is_active_user()) or public.academy_is_admin())
with check((user_id=(select auth.uid()) and public.academy_is_active_user()) or public.academy_is_admin());

drop policy if exists "progress_read_self_or_admin" on public.academy_lesson_progress;
create policy "progress_read_self_or_admin" on public.academy_lesson_progress
for select to authenticated using((user_id=(select auth.uid()) and public.academy_is_active_user()) or public.academy_is_admin());
drop policy if exists "progress_insert_self" on public.academy_lesson_progress;
create policy "progress_insert_self" on public.academy_lesson_progress
for insert to authenticated with check(user_id=(select auth.uid()) and public.academy_is_active_user()
 and exists(select 1 from public.academy_lessons l join public.academy_courses c on c.id=l.course_id
  where l.id=lesson_id and l.status='published' and c.status='published'));
drop policy if exists "progress_update_self" on public.academy_lesson_progress;
create policy "progress_update_self" on public.academy_lesson_progress
for update to authenticated using(user_id=(select auth.uid()) and public.academy_is_active_user())
with check(user_id=(select auth.uid()) and public.academy_is_active_user());

drop policy if exists "attempts_read_self_or_admin" on public.academy_quiz_attempts;
create policy "attempts_read_self_or_admin" on public.academy_quiz_attempts
for select to authenticated using((user_id=(select auth.uid()) and public.academy_is_active_user()) or public.academy_is_admin());
drop policy if exists "answers_read_self_or_admin" on public.academy_quiz_answers;
create policy "answers_read_self_or_admin" on public.academy_quiz_answers
for select to authenticated using(
 (exists(select 1 from public.academy_quiz_attempts a where a.id=attempt_id and a.user_id=(select auth.uid()))
  and public.academy_is_active_user()) or public.academy_is_admin());

create or replace function public.academy_submit_quiz(p_quiz_id uuid,p_answers jsonb)
returns jsonb language plpgsql security definer set search_path=public
as $academy_submit_secure$
declare
 v_user uuid:=auth.uid();v_attempt uuid:=gen_random_uuid();
 v_max numeric(8,2):=0;v_score numeric(8,2):=0;v_percent integer:=0;v_pass integer;
 q record;v_selected uuid;v_correct uuid;v_awarded numeric(8,2);
 v_question_count integer;v_submitted_count integer;
begin
 if v_user is null then raise exception 'AUTH_REQUIRED'; end if;
 if not public.academy_is_active_user() then raise exception 'ACCOUNT_BLOCKED'; end if;
 if coalesce(jsonb_typeof(p_answers),'null')<>'array' then raise exception 'INVALID_ANSWERS'; end if;
 if jsonb_array_length(p_answers)>100 then raise exception 'TOO_MANY_ANSWERS'; end if;
 if not exists(select 1 from public.academy_quizzes where id=p_quiz_id and status='published') then raise exception 'QUIZ_UNAVAILABLE'; end if;
 select pass_percent into v_pass from public.academy_quizzes where id=p_quiz_id;
 select count(*) into v_question_count from public.academy_quiz_questions where quiz_id=p_quiz_id;
 select count(distinct item->>'question_id') into v_submitted_count
 from jsonb_array_elements(p_answers) as a(item)
 where jsonb_typeof(item)='object' and item ? 'question_id' and item ? 'option_id';
 if v_question_count=0 or v_question_count<>v_submitted_count or jsonb_array_length(p_answers)<>v_question_count then
  raise exception 'INCOMPLETE_OR_DUPLICATE_ANSWERS';
 end if;
 if exists(select 1 from jsonb_array_elements(p_answers) as a(item)
  where jsonb_typeof(item)<>'object'
   or coalesce(item->>'question_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
   or coalesce(item->>'option_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then
  raise exception 'INVALID_ANSWER_FORMAT';
 end if;
 if exists(select 1 from jsonb_array_elements(p_answers) as a(item)
  where not exists(select 1 from public.academy_quiz_questions q
   join public.academy_quiz_options o on o.question_id=q.id
   where q.id=(item->>'question_id')::uuid and q.quiz_id=p_quiz_id
    and o.id=(item->>'option_id')::uuid)) then
  raise exception 'INVALID_ANSWER_REFERENCE';
 end if;
 for q in select id,points from public.academy_quiz_questions where quiz_id=p_quiz_id loop
  v_max:=v_max+q.points;
  select (item->>'option_id')::uuid into v_selected from jsonb_array_elements(p_answers) as a(item)
   where item->>'question_id'=q.id::text;
  select option_id into v_correct from public.academy_quiz_correct_answers where question_id=q.id;
  if v_correct is null then raise exception 'QUIZ_KEY_MISSING'; end if;
  v_awarded:=case when v_selected=v_correct then q.points else 0 end;
  v_score:=v_score+v_awarded;
 end loop;
 if v_max<=0 then raise exception 'QUIZ_HAS_NO_POINTS'; end if;
 v_percent:=round((v_score/v_max)*100)::integer;
 insert into public.academy_quiz_attempts(id,quiz_id,user_id,score,max_score,percent,passed)
 values(v_attempt,p_quiz_id,v_user,v_score,v_max,v_percent,v_percent>=v_pass);
 for q in select id from public.academy_quiz_questions where quiz_id=p_quiz_id loop
  select (item->>'option_id')::uuid into v_selected from jsonb_array_elements(p_answers) as a(item)
   where item->>'question_id'=q.id::text;
  select option_id into v_correct from public.academy_quiz_correct_answers where question_id=q.id;
  insert into public.academy_quiz_answers(attempt_id,question_id,selected_option_id,is_correct,awarded_points)
  values(v_attempt,q.id,v_selected,v_selected=v_correct,
   case when v_selected=v_correct then (select points from public.academy_quiz_questions where id=q.id) else 0 end);
 end loop;
 return jsonb_build_object('attempt_id',v_attempt,'score',v_score,'max_score',v_max,'percent',v_percent,'passed',v_percent>=v_pass);
end;
$academy_submit_secure$;
revoke all on function public.academy_submit_quiz(uuid,jsonb) from public,anon;
grant execute on function public.academy_submit_quiz(uuid,jsonb) to authenticated;

insert into public.academy_quizzes(id,course_id,title,description,pass_percent,status)
values('90000000-0000-4000-8000-000000000001','html','آزمون آغازین آکادمی','۹ پرسش پایه از HTML، CSS و JavaScript',60,'published')
on conflict(id) do update set title=excluded.title,description=excluded.description,pass_percent=excluded.pass_percent,status='published';
insert into public.academy_quiz_questions(id,quiz_id,question_text,explanation,points,sort_order)
values('91000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001','کدام تگ برای عنوان اصلی صفحه استفاده می‌شود؟','h1 عنوان اصلی و مهم صفحه را مشخص می‌کند.',1,1)
on conflict(id) do update set question_text=excluded.question_text,explanation=excluded.explanation,points=excluded.points,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','<p>',1)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000001','<h1>',2)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_correct_answers(question_id,option_id)
values('91000000-0000-4000-8000-000000000001','92000000-0000-4000-8000-000000000002') on conflict(question_id) do update set option_id=excluded.option_id;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000003','91000000-0000-4000-8000-000000000001','<img>',3)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_questions(id,quiz_id,question_text,explanation,points,sort_order)
values('91000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000001','برای ساخت پیوند در HTML از کدام تگ استفاده می‌شود؟','تگ a همراه ویژگی href یک پیوند ایجاد می‌کند.',1,2)
on conflict(id) do update set question_text=excluded.question_text,explanation=excluded.explanation,points=excluded.points,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000004','91000000-0000-4000-8000-000000000002','<a>',1)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_correct_answers(question_id,option_id)
values('91000000-0000-4000-8000-000000000002','92000000-0000-4000-8000-000000000004') on conflict(question_id) do update set option_id=excluded.option_id;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000005','91000000-0000-4000-8000-000000000002','<link>',2)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000006','91000000-0000-4000-8000-000000000002','<button>',3)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_questions(id,quiz_id,question_text,explanation,points,sort_order)
values('91000000-0000-4000-8000-000000000003','90000000-0000-4000-8000-000000000001','ویژگی alt در تصویر چه کاربردی دارد؟','alt توضیح متنی تصویر را برای دسترس‌پذیری و زمانی که تصویر بارگذاری نمی‌شود فراهم می‌کند.',1,3)
on conflict(id) do update set question_text=excluded.question_text,explanation=excluded.explanation,points=excluded.points,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000007','91000000-0000-4000-8000-000000000003','تغییر اندازه تصویر',1)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000008','91000000-0000-4000-8000-000000000003','متن جایگزین تصویر',2)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_correct_answers(question_id,option_id)
values('91000000-0000-4000-8000-000000000003','92000000-0000-4000-8000-000000000008') on conflict(question_id) do update set option_id=excluded.option_id;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000009','91000000-0000-4000-8000-000000000003','تعیین رنگ تصویر',3)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_questions(id,quiz_id,question_text,explanation,points,sort_order)
values('91000000-0000-4000-8000-000000000004','90000000-0000-4000-8000-000000000001','کدام ویژگی در CSS رنگ متن را تعیین می‌کند؟','ویژگی color رنگ متن را تعیین می‌کند.',1,4)
on conflict(id) do update set question_text=excluded.question_text,explanation=excluded.explanation,points=excluded.points,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000010','91000000-0000-4000-8000-000000000004','font-size',1)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000011','91000000-0000-4000-8000-000000000004','background',2)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000012','91000000-0000-4000-8000-000000000004','color',3)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_correct_answers(question_id,option_id)
values('91000000-0000-4000-8000-000000000004','92000000-0000-4000-8000-000000000012') on conflict(question_id) do update set option_id=excluded.option_id;
insert into public.academy_quiz_questions(id,quiz_id,question_text,explanation,points,sort_order)
values('91000000-0000-4000-8000-000000000005','90000000-0000-4000-8000-000000000001','برای چیدمان انعطاف‌پذیر یک‌بعدی معمولاً از چه چیزی استفاده می‌کنیم؟','Flexbox برای چیدمان انعطاف‌پذیر در یک محور مناسب است.',1,5)
on conflict(id) do update set question_text=excluded.question_text,explanation=excluded.explanation,points=excluded.points,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000013','91000000-0000-4000-8000-000000000005','display: flex',1)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_correct_answers(question_id,option_id)
values('91000000-0000-4000-8000-000000000005','92000000-0000-4000-8000-000000000013') on conflict(question_id) do update set option_id=excluded.option_id;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000014','91000000-0000-4000-8000-000000000005','font-style',2)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000015','91000000-0000-4000-8000-000000000005','text-align',3)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_questions(id,quiz_id,question_text,explanation,points,sort_order)
values('91000000-0000-4000-8000-000000000006','90000000-0000-4000-8000-000000000001','کدام ابزار CSS برای اعمال سبک در اندازه‌های مختلف صفحه استفاده می‌شود؟','Media Query امکان تعریف سبک‌های وابسته به اندازه صفحه یا ویژگی‌های دستگاه را می‌دهد.',1,6)
on conflict(id) do update set question_text=excluded.question_text,explanation=excluded.explanation,points=excluded.points,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000016','91000000-0000-4000-8000-000000000006','@media',1)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_correct_answers(question_id,option_id)
values('91000000-0000-4000-8000-000000000006','92000000-0000-4000-8000-000000000016') on conflict(question_id) do update set option_id=excluded.option_id;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000017','91000000-0000-4000-8000-000000000006','@font-face',2)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000018','91000000-0000-4000-8000-000000000006','@import',3)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_questions(id,quiz_id,question_text,explanation,points,sort_order)
values('91000000-0000-4000-8000-000000000007','90000000-0000-4000-8000-000000000001','برای تعریف متغیری که دوباره مقداردهی نمی‌شود از کدام کلمه استفاده می‌کنیم؟','const برای متغیری است که دوباره به آن مقدار نسبت داده نمی‌شود.',1,7)
on conflict(id) do update set question_text=excluded.question_text,explanation=excluded.explanation,points=excluded.points,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000019','91000000-0000-4000-8000-000000000007','const',1)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_correct_answers(question_id,option_id)
values('91000000-0000-4000-8000-000000000007','92000000-0000-4000-8000-000000000019') on conflict(question_id) do update set option_id=excluded.option_id;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000020','91000000-0000-4000-8000-000000000007','repeat',2)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000021','91000000-0000-4000-8000-000000000007','style',3)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_questions(id,quiz_id,question_text,explanation,points,sort_order)
values('91000000-0000-4000-8000-000000000008','90000000-0000-4000-8000-000000000001','برای شنیدن رویداد کلیک در JavaScript از کدام متد استفاده می‌شود؟','addEventListener شنونده رویداد را به عنصر متصل می‌کند.',1,8)
on conflict(id) do update set question_text=excluded.question_text,explanation=excluded.explanation,points=excluded.points,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000022','91000000-0000-4000-8000-000000000008','querySelector',1)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000023','91000000-0000-4000-8000-000000000008','addEventListener',2)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_correct_answers(question_id,option_id)
values('91000000-0000-4000-8000-000000000008','92000000-0000-4000-8000-000000000023') on conflict(question_id) do update set option_id=excluded.option_id;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000024','91000000-0000-4000-8000-000000000008','innerHTML',3)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_questions(id,quiz_id,question_text,explanation,points,sort_order)
values('91000000-0000-4000-8000-000000000009','90000000-0000-4000-8000-000000000001','اندیس اولین عضو آرایه در JavaScript چند است؟','اندیس آرایه‌ها در JavaScript از صفر شروع می‌شود.',1,9)
on conflict(id) do update set question_text=excluded.question_text,explanation=excluded.explanation,points=excluded.points,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000025','91000000-0000-4000-8000-000000000009','۱',1)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000026','91000000-0000-4000-8000-000000000009','۰',2)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;
insert into public.academy_quiz_correct_answers(question_id,option_id)
values('91000000-0000-4000-8000-000000000009','92000000-0000-4000-8000-000000000026') on conflict(question_id) do update set option_id=excluded.option_id;
insert into public.academy_quiz_options(id,question_id,option_text,sort_order)
values('92000000-0000-4000-8000-000000000027','91000000-0000-4000-8000-000000000009','-۱',3)
on conflict(id) do update set option_text=excluded.option_text,sort_order=excluded.sort_order;

commit;
