-- NEXORA FORGE ACADEMY
-- Run once in Supabase SQL Editor. Creates 9 separate quizzes (5 questions each)
-- and enables multiple advertising placements in the student dashboard.

begin;
alter table public.academy_ads drop constraint if exists academy_ads_placement_check;
alter table public.academy_ads add constraint academy_ads_placement_check
 check (placement in ('home','student','student_top','student_courses','student_bottom','both'));
commit;

do $seed$
declare
 cfg jsonb; q jsonb; opt jsonb;
 v_quiz_id uuid; v_question_id uuid; v_option_id uuid; v_correct_id uuid;
 v_index integer;
 configs jsonb := '[
 {"course":"html","title":"آزمون سطح مقدماتی — HTML","desc":"۵ سؤال پایه درباره ساختار HTML، عنوان، پاراگراف، پیوند و تصویر.","questions":[
 ["HTML چه کاری انجام می‌دهد؟","HTML ساختار و معنای محتوای صفحه را مشخص می‌کند.",["ساختار صفحه وب را مشخص می‌کند","سرعت اینترنت را زیاد می‌کند","رنگ مانیتور را عوض می‌کند","پایگاه داده را مدیریت می‌کند"],0],
 ["کدام تگ عنوان اصلی صفحه را می‌سازد؟","تگ h1 عنوان اصلی و مهم صفحه است.",["<p>","<h1>","<img>","<br>"],1],
 ["برای نوشتن یک پاراگراف از کدام تگ استفاده می‌شود؟","محتوای متنی پاراگراف داخل تگ p قرار می‌گیرد.",["<div>","<a>","<p>","<title>"],2],
 ["کدام ویژگی مقصد یک پیوند را تعیین می‌کند؟","ویژگی href نشانی مقصد پیوند را نگه می‌دارد.",["src","alt","class","href"],3],
 ["برای نمایش تصویر از کدام تگ استفاده می‌شود؟","تگ img تصویر را نمایش می‌دهد و src مسیر فایل است.",["<img>","<image-link>","<picture-text>","<media>"],0]
 ]},
 {"course":"css","title":"آزمون سطح مقدماتی — CSS","desc":"۵ سؤال پایه درباره انتخابگرها، رنگ، اندازه متن، فاصله و پس‌زمینه.","questions":[
 ["CSS چه چیزی را کنترل می‌کند؟","CSS ظاهر، رنگ‌ها، فاصله‌ها و چیدمان عناصر را تعیین می‌کند.",["ساختار داده","ظاهر و چیدمان صفحه","ورود کاربران","ذخیره فایل"],1],
 ["برای تغییر رنگ متن از کدام ویژگی استفاده می‌شود؟","ویژگی color رنگ نوشته را تعیین می‌کند.",["font","background","color","border"],2],
 ["نقطه قبل از نام در انتخابگر CSS معمولاً چه چیزی را انتخاب می‌کند؟","نقطه برای انتخاب عنصرهایی با class مشخص به کار می‌رود.",["شناسه id","همه عناصر","نام تگ","کلاس class"],3],
 ["کدام ویژگی اندازه نوشته را تغییر می‌دهد؟","font-size اندازه متن را مشخص می‌کند.",["font-size","text-color","line","size-box"],0],
 ["کدام ویژگی رنگ پس‌زمینه عنصر را تنظیم می‌کند؟","background-color رنگ پس‌زمینه را تعیین می‌کند.",["color","background-color","padding","display"],1]
 ]},
 {"course":"js","title":"آزمون سطح مقدماتی — JavaScript","desc":"۵ سؤال پایه درباره متغیر، شرط، تابع، رویداد و خروجی.","questions":[
 ["JavaScript در صفحه وب بیشتر برای چه کاری استفاده می‌شود؟","JavaScript رفتار و تعامل صفحه را کنترل می‌کند.",["تعامل و منطق صفحه","ساختاردهی متن به‌تنهایی","تنظیم رنگ چاپگر","ساخت کابل شبکه"],0],
 ["کدام کلمه برای تعریف متغیری با مقدار قابل‌تغییر مناسب است؟","let متغیری می‌سازد که مقدارش بعداً قابل تغییر است.",["const","let","style","href"],1],
 ["برای بررسی یک شرط از کدام ساختار استفاده می‌کنیم؟","if کد را بر اساس درست یا نادرست بودن شرط اجرا می‌کند.",["for","function","if","return"],2],
 ["کدام دستور پیامی را در کنسول می‌نویسد؟","console.log برای نمایش مقدارها در کنسول است.",["print.page()","show.html()","write.css()","console.log()"],3],
 ["تابع در برنامه‌نویسی چه فایده‌ای دارد؟","تابع مجموعه‌ای از دستورها را در یک بخش قابل استفاده دوباره قرار می‌دهد.",["بسته‌بندی دستورهای قابل استفاده دوباره","تغییر خودکار اینترنت","حذف مرورگر","ساخت تصویر بدون کد"],0]
 ]},
 {"course":"html-intermediate","title":"آزمون سطح متوسط — HTML","desc":"۵ سؤال درباره فرم‌ها، عناصر معنایی، جدول و دسترس‌پذیری.","questions":[
 ["برای اتصال متن توضیحی به ورودی فرم از کدام ویژگی label استفاده می‌شود؟","ویژگی for در label باید با id ورودی برابر باشد.",["name","for","src","target"],1],
 ["کدام عنصر برای محتوای مستقل و قابل بازنشر مناسب‌تر است؟","article برای محتوای مستقل مانند نوشته یا خبر مناسب است.",["span","b","article","i"],2],
 ["برای افزودن عنوان به جدول از کدام عنصر استفاده می‌شود؟","caption عنوان یا توضیح جدول را مشخص می‌کند.",["thead","tbody","tfoot","caption"],3],
 ["کدام ویژگی باعث می‌شود ورودی فرم بدون پر کردن قابل ارسال نباشد؟","ویژگی required خالی بودن ورودی را نامعتبر می‌کند.",["required","checked","multiple","hidden"],0],
 ["برای مشخص کردن محتوای اصلی صفحه از کدام عنصر استفاده می‌شود؟","main محتوای اصلی صفحه را مشخص می‌کند.",["aside","main","footer","nav"],1]
 ]},
 {"course":"css-intermediate","title":"آزمون سطح متوسط — CSS","desc":"۵ سؤال درباره Flexbox، Grid، واکنش‌گرایی و شبه‌کلاس‌ها.","questions":[
 ["برای فعال کردن چیدمان Flexbox روی یک والد از چه مقداری استفاده می‌شود؟","display:flex فرزندان مستقیم را به آیتم‌های فلکس تبدیل می‌کند.",["position:flex","display:flex","layout:block","flex:true"],1],
 ["کدام ویژگی فاصله بین آیتم‌های Flexbox یا Grid را تنظیم می‌کند؟","gap فاصله بین ردیف‌ها و ستون‌ها را تعیین می‌کند.",["padding","margin-top","gap","outline"],2],
 ["برای تعریف ستون‌های شبکه CSS Grid از کدام ویژگی استفاده می‌شود؟","grid-template-columns ساختار ستون‌های گرید را تعریف می‌کند.",["grid-auto","grid-column-gap","column-count","grid-template-columns"],3],
 ["کدام قانون برای اعمال سبک در عرض‌های مختلف صفحه به کار می‌رود؟","media query امکان شرط‌گذاری بر اساس اندازه viewport را می‌دهد.",["@media","@font-face","@import فقط","@keyframes"],0],
 ["شبه‌کلاس hover چه زمانی فعال می‌شود؟","hover هنگام قرار گرفتن نشانگر روی عنصر فعال می‌شود.",["پس از حذف عنصر","هنگام قرار گرفتن نشانگر روی عنصر","فقط هنگام چاپ","پس از بارگذاری فونت"],1]
 ]},
 {"course":"js-intermediate","title":"آزمون سطح متوسط — JavaScript","desc":"۵ سؤال درباره آرایه، حلقه، رویداد، DOM و متدهای آرایه.","questions":[
 ["کدام متد یک عنصر را به انتهای آرایه اضافه می‌کند؟","push مقدار جدید را به انتهای آرایه می‌افزاید.",["pop","shift","push","slice"],2],
 ["برای انتخاب عنصر با شناسه مشخص در DOM از چه روشی استفاده می‌شود؟","getElementById عنصر دارای id مشخص را برمی‌گرداند.",["queryClass()","getElementById()","selectTagName()","findStyle()"],1],
 ["رویداد click چه زمانی رخ می‌دهد؟","وقتی کاربر روی عنصر کلیک می‌کند.",["با تغییر رنگ","با بستن تب","با بارگذاری فونت","هنگام کلیک روی عنصر"],3],
 ["کدام متد برای اجرای تابع روی تک‌تک اعضای آرایه مناسب است؟","forEach تابع داده‌شده را برای هر عضو آرایه اجرا می‌کند.",["forEach()","parseInt()","JSON.stringify()","alert()"],0],
 ["نشانه تابع پیکانی در JavaScript کدام است؟","تابع پیکانی با نشانه => نوشته می‌شود.",["->","=>","<=","::"],1]
 ]},
 {"course":"html-advanced","title":"آزمون سطح پیشرفته — HTML","desc":"۵ سؤال درباره DOCTYPE، دسترس‌پذیری، فرم و ساختار معنایی.","questions":[
 ["اعلان استاندارد شروع سند HTML5 کدام است؟","DOCTYPE html حالت استاندارد HTML را برای مرورگر مشخص می‌کند.",["<html5>","<version>","<!DOCTYPE html>","<meta version>"],2],
 ["کدام ویژگی برای ارائه متن جایگزین تصویر مهم است؟","alt توضیح متنی تصویر را فراهم می‌کند.",["title فقط","srcset","loading","alt"],3],
 ["برای بارگذاری فایل از طریق فرم، کدام مقدار enctype رایج است؟","multipart/form-data برای ارسال فایل لازم است.",["multipart/form-data","text/plain فقط","application/json","form/file"],0],
 ["کدام عنصر برای محتوای جانبی مرتبط با محتوای اصلی مناسب است؟","aside محتوای جانبی مانند کادر مرتبط را نشان می‌دهد.",["main","aside","strong","label"],1],
 ["کدام مقدار meta viewport عرض صفحه را با دستگاه هماهنگ می‌کند؟","meta viewport برای تنظیم نمای واکنش‌گرا استفاده می‌شود.",["charset","description","viewport","author"],2]
 ]},
 {"course":"css-advanced","title":"آزمون سطح پیشرفته — CSS","desc":"۵ سؤال درباره specificity، متغیرها، توابع و دسترس‌پذیری.","questions":[
 ["در محاسبه specificity، کدام انتخابگر وزن بیشتری از کلاس دارد؟","انتخابگر ID از کلاس و عنصر وزن بیشتری دارد.",["عنصر","کلاس","ID","شبه‌عنصر"],2],
 ["برای تعریف متغیر سفارشی CSS نام معمولاً با چه چیزی آغاز می‌شود؟","متغیرهای CSS با دو خط تیره تعریف می‌شوند.",["$","--","@@","var-"],1],
 ["تابع var() چه کاری انجام می‌دهد؟","var مقدار یک custom property را در ویژگی CSS جای‌گذاری می‌کند.",["ساخت انیمیشن","انتخاب عنصر","محاسبه زمان","خواندن متغیر سفارشی"],3],
 ["prefers-reduced-motion برای چه هدفی است؟","این media feature ترجیح کاربر برای کاهش حرکت و انیمیشن را رعایت می‌کند.",["کاهش حرکت برای کاربران متقاضی","افزایش وضوح تصویر","تغییر زبان صفحه","فشرده‌سازی فونت"],0],
 ["ویژگی z-index معمولاً چه چیزی را کنترل می‌کند؟","z-index ترتیب روی‌هم‌قرارگیری عناصر موقعیت‌یافته را کنترل می‌کند.",["اندازه فونت","ترتیب لایه‌ای عناصر","عرض صفحه","سرعت انیمیشن"],1]
 ]},
 {"course":"js-advanced","title":"آزمون سطح پیشرفته — JavaScript","desc":"۵ سؤال درباره Promise، async/await، ماژول‌ها، خطا و JSON.","questions":[
 ["Promise در JavaScript چه چیزی را نمایش می‌دهد؟","Promise نتیجه یک عملیات ناهمگام را که ممکن است بعداً آماده شود نمایش می‌دهد.",["یک عنصر HTML","یک نوع حلقه","نتیجه آینده یک عملیات ناهمگام","یک قانون CSS"],2],
 ["کلمه await معمولاً در چه زمینه‌ای استفاده می‌شود؟","await در تابع async برای منتظر ماندن تا تعیین تکلیف Promise استفاده می‌شود.",["داخل selector","برای ساخت کلاس CSS","در تگ HTML","در تابع async برای انتظار Promise"],3],
 ["کدام ساختار برای مدیریت خطا در عملیات async مناسب است؟","try/catch خطاهای پرتاب‌شده در جریان اجرای await را می‌گیرد.",["try/catch","if/style","for/in فقط","switch/css"],0],
 ["JSON.parse() چه کاری انجام می‌دهد؟","JSON.parse متن JSON را به مقدار JavaScript تبدیل می‌کند.",["تبدیل شیء به متن JSON","تبدیل متن JSON به مقدار JavaScript","ارسال درخواست HTTP","ساخت عنصر DOM"],1],
 ["برای در دسترس قرار دادن یک مقدار از فایل ماژول از چه کلمه‌ای استفاده می‌شود؟","export تابع، مقدار یا کلاس را از یک ماژول در دسترس قرار می‌دهد.",["public","include","export","module.open"],2]
 ]}
 ]'::jsonb;
begin
 for cfg in select value from jsonb_array_elements(configs) as x(value) loop
  if exists(select 1 from public.academy_quizzes where title=cfg->>'title' and course_id=cfg->>'course') then
   continue;
  end if;
  insert into public.academy_quizzes(course_id,title,description,pass_percent,status)
  values(cfg->>'course',cfg->>'title',cfg->>'desc',60,'published') returning id into v_quiz_id;
  for q in select value from jsonb_array_elements(cfg->'questions') as x(value) loop
   insert into public.academy_quiz_questions(quiz_id,question_text,explanation,points,sort_order)
   values(v_quiz_id,q->>0,q->>1,1,(select count(*)+1 from public.academy_quiz_questions where quiz_id=v_quiz_id))
   returning id into v_question_id;
   v_index:=0;v_correct_id:=null;
   for opt in select value from jsonb_array_elements(q->2) as x(value) loop
    insert into public.academy_quiz_options(question_id,option_text,sort_order)
    values(v_question_id,opt#>>'{}',v_index+1) returning id into v_option_id;
    if v_index=(q->>3)::integer then v_correct_id:=v_option_id; end if;
    v_index:=v_index+1;
   end loop;
   if v_correct_id is null then raise exception 'Correct answer missing: %',q->>0; end if;
   insert into public.academy_quiz_correct_answers(question_id,option_id) values(v_question_id,v_correct_id);
  end loop;
 end loop;
end;
$seed$;

-- Verify: should return exactly 9 seeded quizzes and 45 questions.
select q.title,q.course_id,count(qq.id) as question_count
from public.academy_quizzes q
left join public.academy_quiz_questions qq on qq.quiz_id=q.id
where q.title like 'آزمون سطح%'
group by q.id,q.title,q.course_id
order by q.course_id;
