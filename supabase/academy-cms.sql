-- NEXORA FORGE ACADEMY CMS
-- Run once in Supabase SQL Editor for project ufranjjvhmsrkoxtlqcl.
create table if not exists public.academy_courses (
 id text primary key,
 title text not null check (char_length(title) between 2 and 120),
 description text not null default '',
 level text not null default 'مقدماتی',
 sort_order int not null default 0,
 is_published boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.academy_lessons (
 id text primary key,
 course_id text not null references public.academy_courses(id) on delete cascade,
 title text not null check (char_length(title) between 2 and 180),
 content_html text not null default '',
 starter_code text not null default '',
 exercise text not null default '',
 sort_order int not null default 0,
 is_published boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists academy_lessons_course_order_idx on public.academy_lessons(course_id,sort_order);
alter table public.academy_courses enable row level security;
alter table public.academy_lessons enable row level security;
drop policy if exists "Public reads published academy courses" on public.academy_courses;
create policy "Public reads published academy courses" on public.academy_courses for select to anon,authenticated using (is_published or public.is_academy_admin());
drop policy if exists "Admins manage academy courses" on public.academy_courses;
create policy "Admins manage academy courses" on public.academy_courses for all to authenticated using (public.is_academy_admin()) with check (public.is_academy_admin());
drop policy if exists "Public reads published academy lessons" on public.academy_lessons;
create policy "Public reads published academy lessons" on public.academy_lessons for select to anon,authenticated using (is_published or public.is_academy_admin());
drop policy if exists "Admins manage academy lessons" on public.academy_lessons;
create policy "Admins manage academy lessons" on public.academy_lessons for all to authenticated using (public.is_academy_admin()) with check (public.is_academy_admin());
grant select on public.academy_courses,public.academy_lessons to anon,authenticated;
grant insert,update,delete on public.academy_courses,public.academy_lessons to authenticated;

-- Limited student overview for admins. No passwords or authentication tokens are exposed.
create or replace function public.academy_admin_student_overview()
returns table(user_id uuid,email text,created_at timestamptz,completed_lessons integer,quiz_attempts bigint)
language plpgsql stable security definer set search_path=public,auth
as $$
begin
 if not public.is_academy_admin() then raise exception 'not authorized'; end if;
 return query
 select u.id,u.email,u.created_at,
        coalesce(cardinality(p.completed_lessons),0),
        (select count(*) from public.student_quiz_attempts q where q.user_id=u.id)
 from auth.users u
 left join public.student_progress p on p.user_id=u.id
 order by u.created_at desc
 limit 200;
end $$;
revoke all on function public.academy_admin_student_overview() from public,anon;
grant execute on function public.academy_admin_student_overview() to authenticated;

insert into public.academy_courses(id,title,description,level,sort_order,is_published) values
('html','HTML — ساختار وب','ساختار معنایی صفحات، فرم‌ها، رسانه و دسترس‌پذیری.','مقدماتی',1,true),
('css','CSS — طراحی وب','رنگ، تایپوگرافی، مدل جعبه‌ای، Flexbox، Grid و واکنش‌گرایی.','مقدماتی تا متوسط',2,true),
('js','JavaScript — منطق وب','داده، شرط، حلقه، تابع، DOM، رویداد و ذخیره‌سازی مرورگر.','مقدماتی تا متوسط',3,true)
on conflict(id) do update set title=excluded.title,description=excluded.description,level=excluded.level,sort_order=excluded.sort_order;

with seed as (
 select * from jsonb_to_recordset('[
{"id":"html:0","course_id":"html","title":"HTML چیست؟","exercise":"یک صفحه ساده بساز که عنوان «آکادمی من» و یک پاراگراف معرفی داشته باشد.","code":"<h1>آکادمی من</h1>\n<p>به وب خوش آمدی.</p>"},
{"id":"html:1","course_id":"html","title":"ساختار استاندارد صفحه","exercise":"یک سند کامل HTML با lang فارسی، charset، عنوان صفحه و بخش body بساز.","code":"<!doctype html>\n<html lang=\"fa\">\n<head>\n<meta charset=\"UTF-8\">\n<title>صفحه من</title>\n</head>\n<body><h1>سلام</h1></body>\n</html>"},
{"id":"html:2","course_id":"html","title":"عنوان‌ها و پاراگراف‌ها","exercise":"برای یک مقاله، یک عنوان اصلی، دو عنوان فرعی و سه پاراگراف ایجاد کن.","code":"<h1>عنوان اصلی</h1>\n<h2>بخش اول</h2>\n<p>متن پاراگراف</p>"},
{"id":"html:3","course_id":"html","title":"لینک‌ها","exercise":"یک لینک به سایت دلخواه و یک لینک که در زبانه جدید باز شود بساز.","code":"<a href=\"https://example.com\">باز کردن سایت</a>"},
{"id":"html:4","course_id":"html","title":"تصاویر و متن جایگزین","exercise":"یک تصویر اضافه کن و برای آن alt توصیفی و عرض ۲۵۰ پیکسل تعیین کن.","code":"<img src=\"photo.jpg\" alt=\"توضیح تصویر\" width=\"250\">"},
{"id":"html:5","course_id":"html","title":"فهرست‌ها","exercise":"فهرست شماره‌دار سه مرحله‌ای و فهرست بدون ترتیب سه مهارت بساز.","code":"<ul><li>HTML</li><li>CSS</li></ul>\n<ol><li>یادگیری</li><li>تمرین</li></ol>"},
{"id":"html:6","course_id":"html","title":"عناصر معنایی HTML","exercise":"صفحه‌ای با header، nav، main، section و footer بساز.","code":"<header>سربرگ</header>\n<nav>منو</nav>\n<main><section>محتوا</section></main>\n<footer>پاورقی</footer>"},
{"id":"html:7","course_id":"html","title":"ساخت فرم","exercise":"فرمی با ورودی نام و دکمه ارسال بساز و label مرتبط اضافه کن.","code":"<form><label for=\"name\">نام</label><input id=\"name\"><button>ارسال</button></form>"},
{"id":"html:8","course_id":"html","title":"انواع ورودی‌ها","exercise":"ورودی ایمیل، رمز عبور، تاریخ و checkbox ایجاد کن.","code":"<input type=\"email\">\n<input type=\"password\">\n<input type=\"date\">\n<input type=\"checkbox\">"},
{"id":"html:9","course_id":"html","title":"دکمه‌ها و ارسال فرم","exercise":"فرمی بساز که دکمه ارسال و دکمه عادی با عملکرد متفاوت داشته باشد.","code":"<form><button type=\"submit\">ارسال</button><button type=\"button\">عمل دیگر</button></form>"},
{"id":"html:10","course_id":"html","title":"جدول‌ها","exercise":"جدولی با سه ستون نام، درس و نمره و حداقل دو ردیف داده بساز.","code":"<table><tr><th>نام</th><th>درس</th><th>نمره</th></tr><tr><td>علی</td><td>HTML</td><td>۹۰</td></tr></table>"},
{"id":"html:11","course_id":"html","title":"صدا و ویدیو","exercise":"یک عنصر video با controls و متن جایگزین در صورت پشتیبانی‌نشدن اضافه کن.","code":"<video controls width=\"320\"><source src=\"movie.mp4\" type=\"video/mp4\">مرورگر ویدیو را پشتیبانی نمی‌کند.</video>"},
{"id":"html:12","course_id":"html","title":"ویژگی‌های عمومی و data","exercise":"برای یک کارت id، class و data-level تعریف کن.","code":"<article id=\"card\" class=\"lesson\" data-level=\"beginner\">درس</article>"},
{"id":"html:13","course_id":"html","title":"div و span","exercise":"با div دو بخش بساز و با span یک کلمه را درون پاراگراف مشخص کن.","code":"<div>بخش اول</div><div>بخش دوم</div>\n<p>این <span>کلمه</span> مهم است.</p>"},
{"id":"html:14","course_id":"html","title":"دسترس‌پذیری و HTML درست","exercise":"برای تصویر alt، برای ورودی label و برای دکمه متن واضح قرار بده.","code":"<label for=\"email\">ایمیل</label><input id=\"email\" type=\"email\">\n<img src=\"x.jpg\" alt=\"توضیح دقیق\">"},
{"id":"css:0","course_id":"css","title":"CSS چیست؟","exercise":"رنگ عنوان را قرمز و اندازه آن را ۳۲ پیکسل کن.","code":"h1 { color: crimson; font-size: 32px; }"},
{"id":"css:1","course_id":"css","title":"سه روش افزودن CSS","exercise":"یک فایل style.css بساز و آن را به فایل HTML وصل کن.","code":"<link rel=\"stylesheet\" href=\"style.css\">"},
{"id":"css:2","course_id":"css","title":"انتخابگرها","exercise":"با انتخابگر تگ، کلاس و شناسه سه عنصر متفاوت را استایل بده.","code":"p { color: #ddd; }\n.card { padding: 16px; }\n#main { color: red; }"},
{"id":"css:3","course_id":"css","title":"رنگ و پس‌زمینه","exercise":"برای صفحه پس‌زمینه تیره و برای متن رنگ روشن انتخاب کن.","code":"body { background: #101018; color: #f5f5f5; }"},
{"id":"css:4","course_id":"css","title":"مدل جعبه‌ای","exercise":"یک کارت با padding، border و margin بساز و box-sizing را تنظیم کن.","code":"* { box-sizing: border-box; }\n.card { padding: 20px; border: 1px solid #aaa; margin: 12px; }"},
{"id":"css:5","course_id":"css","title":"Flexbox و واکنش‌گرایی","exercise":"سه کارت را با Flexbox کنار هم بچین و در عرض کمتر از ۶۰۰ پیکسل ستونی کن.","code":".row { display:flex; gap:12px; }\n@media(max-width:600px){.row{flex-direction:column}}"},
{"id":"css:6","course_id":"css","title":"آبشار و وراثت CSS","exercise":"رنگ متن body را تعیین کن و رنگ یک عنصر فرزند را جداگانه تغییر بده.","code":"body { color: #ddd; }\nstrong { color: crimson; }"},
{"id":"css:7","course_id":"css","title":"اختصاصیت انتخابگرها","exercise":"برای یک عنصر قانون تگ، کلاس و شناسه بنویس و نتیجه را مقایسه کن.","code":"p { color: white; }\n.note { color: orange; }\n#special { color: red; }"},
{"id":"css:8","course_id":"css","title":"واحدهای اندازه‌گیری","exercise":"یک کارت با rem برای فونت و درصد برای عرض بساز.","code":".card { width: 80%; padding: 1rem; font-size: 1.1rem; }"},
{"id":"css:9","course_id":"css","title":"فونت و خوانایی متن","exercise":"برای متن فارسی فونت مناسب، line-height و اندازه خوانا تنظیم کن.","code":"body { font-family: Tahoma, sans-serif; font-size: 16px; line-height: 1.8; }"},
{"id":"css:10","course_id":"css","title":"display و جریان عناصر","exercise":"دو عنصر را با inline-block کنار هم قرار بده و تفاوت block را بررسی کن.","code":".item { display: inline-block; padding: 12px; }"},
{"id":"css:11","course_id":"css","title":"موقعیت‌دهی عناصر","exercise":"یک نشان کوچک را در گوشه بالای کارت با position قرار بده.","code":".card { position: relative; }\n.badge { position: absolute; top: 8px; right: 8px; }"},
{"id":"css:12","course_id":"css","title":"CSS Grid","exercise":"یک شبکه سه‌ستونه بساز و فاصله بین کارت‌ها را تنظیم کن.","code":".grid { display:grid; grid-template-columns:repeat(3,1fr); gap:16px; }"},
{"id":"css:13","course_id":"css","title":"شبه‌کلاس‌ها","exercise":"برای لینک حالت hover و برای ورودی حالت focus تعریف کن.","code":"a:hover { color: crimson; }\ninput:focus { outline: 2px solid crimson; }"},
{"id":"css:14","course_id":"css","title":"شبه‌عنصرها","exercise":"با ::before یک نشان تزئینی پیش از عنوان ایجاد کن.","code":"h2::before { content: '✦ '; color: crimson; }"},
{"id":"css:15","course_id":"css","title":"رنگ، شفافیت و سایه","exercise":"برای کارت پس‌زمینه نیمه‌شفاف و سایه ملایم بساز.","code":".card { background: rgb(30 30 40 / 80%); box-shadow: 0 8px 24px #0004; }"},
{"id":"css:16","course_id":"css","title":"انتقال و تبدیل","exercise":"با hover کارت را کمی بزرگ کن و تغییر را با transition نرم کن.","code":".card { transition: transform .2s ease; }\n.card:hover { transform: scale(1.03); }"},
{"id":"css:17","course_id":"css","title":"متغیرهای CSS","exercise":"رنگ اصلی را در :root تعریف کن و در دو عنصر استفاده کن.","code":":root { --brand: #ef3340; }\nbutton { background: var(--brand); }"},
{"id":"js:0","course_id":"js","title":"JavaScript چیست؟","exercise":"با console.log یک پیام خوش‌آمدگویی در کنسول نمایش بده.","code":"console.log('سلام از JavaScript');"},
{"id":"js:1","course_id":"js","title":"متغیرها","exercise":"نام آکادمی را با const و تعداد درس‌ها را با let ذخیره و چاپ کن.","code":"const academy = 'NEXORA';\nlet lessons = 58;\nconsole.log(academy, lessons);"},
{"id":"js:2","course_id":"js","title":"نوع داده‌ها","exercise":"یک رشته، عدد، مقدار بولی، آرایه و شیء بساز و نوع داده‌ها را بررسی کن.","code":"const name='Sara', age=18, active=true;\nconsole.log(typeof name, typeof age, typeof active);"},
{"id":"js:3","course_id":"js","title":"شرط‌ها","exercise":"بر اساس نمره، پیام قبولی یا نیاز به تمرین نمایش بده.","code":"const score=75;\nif(score>=50){console.log('قبول');}else{console.log('تمرین بیشتر');}"},
{"id":"js:4","course_id":"js","title":"تابع‌ها","exercise":"تابعی بنویس که نام را بگیرد و پیام خوش‌آمدگویی برگرداند.","code":"function greet(name){ return 'سلام '+name; }\nconsole.log(greet('دوست'));"},
{"id":"js:5","course_id":"js","title":"رویداد کلیک","exercise":"با کلیک روی دکمه، متن یک پاراگراف را تغییر بده.","code":"document.querySelector('button').addEventListener('click',()=>{document.querySelector('p').textContent='انجام شد';});"},
{"id":"js:6","course_id":"js","title":"عملگرهای ریاضی و مقایسه","exercise":"دو عدد را با عملگرهای +، * و === مقایسه و نتیجه را چاپ کن.","code":"const a=8,b=4;\nconsole.log(a+b,a*b,a===b);"},
{"id":"js:7","course_id":"js","title":"عملگرهای منطقی","exercise":"شرطی بنویس که فقط در صورت درست بودن دو شرط پیام دسترسی بدهد.","code":"const loggedIn=true, isAdmin=false;\nif(loggedIn && isAdmin) console.log('دسترسی مدیر');"},
{"id":"js:8","course_id":"js","title":"حلقه for","exercise":"اعداد ۱ تا ۱۰ را با حلقه for در کنسول چاپ کن.","code":"for(let i=1;i<=10;i++){ console.log(i); }"},
{"id":"js:9","course_id":"js","title":"حلقه while و کنترل تکرار","exercise":"با while تا رسیدن شمارنده به ۵ ادامه بده و سپس متوقف شو.","code":"let i=0; while(i<5){ i++; console.log(i); }"},
{"id":"js:10","course_id":"js","title":"آرایه‌ها","exercise":"آرایه‌ای از سه نام درس بساز و عضو اول و آخر را چاپ کن.","code":"const courses=['HTML','CSS','JavaScript'];\nconsole.log(courses[0],courses[courses.length-1]);"},
{"id":"js:11","course_id":"js","title":"افزودن و حذف از آرایه","exercise":"یک درس به انتهای آرایه اضافه و سپس آخرین عضو را حذف کن.","code":"const items=['HTML','CSS'];\nitems.push('JavaScript');\nitems.pop();\nconsole.log(items);"},
{"id":"js:12","course_id":"js","title":"پیمایش آرایه با forEach","exercise":"نام هر عضو آرایه را با forEach در کنسول چاپ کن.","code":"['HTML','CSS','JS'].forEach(item=>console.log(item));"},
{"id":"js:13","course_id":"js","title":"متد map و filter","exercise":"از آرایه نمره‌ها با map نمره‌ها را دو برابر و با filter نمره‌های بالای ۵۰ را جدا کن.","code":"const scores=[30,60,80];\nconsole.log(scores.map(x=>x*2));\nconsole.log(scores.filter(x=>x>50));"},
{"id":"js:14","course_id":"js","title":"شیءها","exercise":"شیئی برای دانش‌آموز با name، age و course بساز و مقدارها را بخوان.","code":"const student={name:'Ali',age:18,course:'HTML'};\nconsole.log(student.name);"},
{"id":"js:15","course_id":"js","title":"توابع پیکانی و پارامتر پیش‌فرض","exercise":"تابع پیکانی بساز که اگر نامی داده نشد، مقدار پیش‌فرض استفاده کند.","code":"const greet=(name='دوست')=>'سلام '+name;\nconsole.log(greet());"},
{"id":"js:16","course_id":"js","title":"انتخاب عناصر صفحه با DOM","exercise":"با querySelector عنوان صفحه را پیدا کن و متنش را تغییر بده.","code":"const title=document.querySelector('h1');\ntitle.textContent='عنوان جدید';"},
{"id":"js:17","course_id":"js","title":"رویدادها و event","exercise":"رویداد کلیک را دریافت کن و مشخصات event را در کنسول نمایش بده.","code":"document.addEventListener('click',event=>console.log(event.target));"},
{"id":"js:18","course_id":"js","title":"کار با فرم و ورودی کاربر","exercise":"مقدار یک input را هنگام ارسال فرم بخوان و از بارگذاری مجدد صفحه جلوگیری کن.","code":"form.addEventListener('submit',event=>{event.preventDefault(); console.log(input.value);});"},
{"id":"js:19","course_id":"js","title":"اعتبارسنجی ساده فرم","exercise":"خالی نبودن نام و معتبر بودن طول آن را پیش از ارسال بررسی کن.","code":"if(name.trim().length<2){console.log('نام کوتاه است');}"},
{"id":"js:20","course_id":"js","title":"ذخیره‌سازی در localStorage","exercise":"نام کاربر را ذخیره کن و در بارگذاری بعدی بخوان.","code":"localStorage.setItem('name','Sara');\nconsole.log(localStorage.getItem('name'));"},
{"id":"js:21","course_id":"js","title":"JSON و تبدیل داده","exercise":"یک شیء را به JSON تبدیل کن و دوباره به شیء JavaScript برگردان.","code":"const text=JSON.stringify({name:'Ali'});\nconst data=JSON.parse(text);"},
{"id":"js:22","course_id":"js","title":"مدیریت خطا با try و catch","exercise":"تبدیل JSON نامعتبر را با try/catch ایمن مدیریت کن.","code":"try{ JSON.parse('{bad'); }catch(error){ console.error(error.message); }"},
{"id":"js:23","course_id":"js","title":"تاریخ و زمان","exercise":"تاریخ امروز را بساز و روز و سال را نمایش بده.","code":"const now=new Date();\nconsole.log(now.toLocaleDateString('fa-IR'));"},
{"id":"js:24","course_id":"js","title":"پروژه کوچک: شمارنده","exercise":"شمارنده‌ای با دکمه افزایش، کاهش و صفرکردن بساز.","code":"let count=0;\nfunction update(){document.querySelector('#count').textContent=count;}\n// دکمه‌ها را به update متصل کن."}
]') as x(id text,course_id text,title text,exercise text,code text)
)
insert into public.academy_lessons(id,course_id,title,content_html,starter_code,exercise,sort_order,is_published)
select id,course_id,title,
 '<p>در این درس با مفهوم «'||replace(title,'&','&amp;')||'» آشنا می‌شوی. ابتدا نمونه را اجرا کن، سپس بخش‌های آن را تغییر بده و نتیجه را بررسی کن.</p><p>هنگام تمرین به ساختار، نام‌گذاری روشن و خطاهای احتمالی توجه کن. سعی کن مثال را بدون نگاه‌کردن دوباره بنویسی.</p>',
 code,exercise,
 case course_id when 'html' then cast(substring(id from 6) as int) when 'css' then cast(substring(id from 5) as int) else cast(substring(id from 4) as int) end,
 true
from seed
on conflict(id) do update set
 course_id=excluded.course_id,title=excluded.title,exercise=excluded.exercise,
 starter_code=excluded.starter_code,sort_order=excluded.sort_order;
