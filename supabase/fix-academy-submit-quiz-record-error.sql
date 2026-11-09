-- NEXORA FORGE ACADEMY — FIX QUIZ SUBMISSION RECORD VARIABLE COLLISION
-- Fixes: record "q" is not assigned yet
-- Run in Supabase SQL Editor.

create or replace function public.academy_submit_quiz(p_quiz_id uuid,p_answers jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $academy_submit_quiz_fixed$
declare
 v_user uuid:=auth.uid();
 v_attempt uuid:=gen_random_uuid();
 v_max numeric(8,2):=0;
 v_score numeric(8,2):=0;
 v_percent integer:=0;
 v_pass integer;
 v_question record;
 v_selected uuid;
 v_correct uuid;
 v_awarded numeric(8,2);
 v_question_count integer;
 v_submitted_count integer;
begin
 if v_user is null then raise exception 'AUTH_REQUIRED'; end if;
 if not public.academy_is_active_user() then raise exception 'ACCOUNT_BLOCKED'; end if;
 if coalesce(jsonb_typeof(p_answers),'null')<>'array' then raise exception 'INVALID_ANSWERS'; end if;
 if jsonb_array_length(p_answers)>100 then raise exception 'TOO_MANY_ANSWERS'; end if;
 if not exists(select 1 from public.academy_quizzes where id=p_quiz_id and status='published') then
  raise exception 'QUIZ_UNAVAILABLE';
 end if;

 select pass_percent into v_pass
 from public.academy_quizzes where id=p_quiz_id;

 select count(*) into v_question_count
 from public.academy_quiz_questions where quiz_id=p_quiz_id;

 select count(distinct item->>'question_id') into v_submitted_count
 from jsonb_array_elements(p_answers) as a(item)
 where jsonb_typeof(item)='object' and item ? 'question_id' and item ? 'option_id';

 if v_question_count=0 or v_question_count<>v_submitted_count
    or jsonb_array_length(p_answers)<>v_question_count then
  raise exception 'INCOMPLETE_OR_DUPLICATE_ANSWERS';
 end if;

 if exists(
  select 1 from jsonb_array_elements(p_answers) as a(item)
  where jsonb_typeof(item)<>'object'
   or coalesce(item->>'question_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
   or coalesce(item->>'option_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 ) then
  raise exception 'INVALID_ANSWER_FORMAT';
 end if;

 if exists(
  select 1 from jsonb_array_elements(p_answers) as a(item)
  where not exists(
   select 1
   from public.academy_quiz_questions as qq
   join public.academy_quiz_options as oo on oo.question_id=qq.id
   where qq.id=(item->>'question_id')::uuid
    and qq.quiz_id=p_quiz_id
    and oo.id=(item->>'option_id')::uuid
  )
 ) then
  raise exception 'INVALID_ANSWER_REFERENCE';
 end if;

 for v_question in
  select id,points
  from public.academy_quiz_questions
  where quiz_id=p_quiz_id
 loop
  v_max:=v_max+v_question.points;

  select (item->>'option_id')::uuid into v_selected
  from jsonb_array_elements(p_answers) as a(item)
  where item->>'question_id'=v_question.id::text;

  select option_id into v_correct
  from public.academy_quiz_correct_answers
  where question_id=v_question.id;

  if v_correct is null then raise exception 'QUIZ_KEY_MISSING'; end if;

  v_awarded:=case when v_selected=v_correct then v_question.points else 0 end;
  v_score:=v_score+v_awarded;
 end loop;

 if v_max<=0 then raise exception 'QUIZ_HAS_NO_POINTS'; end if;
 v_percent:=round((v_score/v_max)*100)::integer;

 insert into public.academy_quiz_attempts(id,quiz_id,user_id,score,max_score,percent,passed)
 values(v_attempt,p_quiz_id,v_user,v_score,v_max,v_percent,v_percent>=v_pass);

 for v_question in
  select id from public.academy_quiz_questions where quiz_id=p_quiz_id
 loop
  select (item->>'option_id')::uuid into v_selected
  from jsonb_array_elements(p_answers) as a(item)
  where item->>'question_id'=v_question.id::text;

  select option_id into v_correct
  from public.academy_quiz_correct_answers
  where question_id=v_question.id;

  insert into public.academy_quiz_answers(
   attempt_id,question_id,selected_option_id,is_correct,awarded_points
  )
  values(
   v_attempt,v_question.id,v_selected,v_selected=v_correct,
   case when v_selected=v_correct then
    (select points from public.academy_quiz_questions where id=v_question.id)
    else 0 end
  );
 end loop;

 return jsonb_build_object(
  'attempt_id',v_attempt,
  'score',v_score,
  'max_score',v_max,
  'percent',v_percent,
  'passed',v_percent>=v_pass
 );
end;
$academy_submit_quiz_fixed$;

revoke all on function public.academy_submit_quiz(uuid,jsonb) from public,anon;
grant execute on function public.academy_submit_quiz(uuid,jsonb) to authenticated;
