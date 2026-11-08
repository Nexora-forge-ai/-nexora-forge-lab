let courses = {
 html:{name:"HTML — ساختار وب",level:"مقدماتی",desc:"ساختار و محتوای صفحات وب را یاد بگیر.",lessons:[
  {title:"HTML چیست؟",body:"<p>HTML مخفف HyperText Markup Language است. با آن ساختار محتوای یک صفحه وب را مشخص می‌کنیم؛ مثلاً عنوان، پاراگراف، تصویر و لینک.</p><ul><li>HTML زبان نشانه‌گذاری است، نه زبان برنامه‌نویسی.</li><li>مرورگر تگ‌ها را می‌خواند و محتوا را نمایش می‌دهد.</li></ul>",code:"<h1>سلام دنیا</h1>\n<p>این اولین صفحه من است.</p>"},
  {title:"ساختار استاندارد صفحه",body:"<p>هر سند HTML با اعلام نوع سند شروع می‌شود. عنصر html ریشه صفحه است، head اطلاعات صفحه را نگه می‌دارد و body محتوای قابل مشاهده را.</p>",code:"<!doctype html>\n<html lang=\"fa\">\n<head>\n  <meta charset=\"UTF-8\">\n  <title>صفحه من</title>\n</head>\n<body>\n  <h1>سلام!</h1>\n</body>\n</html>"},
  {title:"عنوان‌ها و پاراگراف‌ها",body:"<p>برای عنوان‌ها از h1 تا h6 استفاده می‌شود. تگ p برای پاراگراف است. عنوان‌ها باید ترتیب منطقی داشته باشند و فقط برای بزرگ کردن متن استفاده نشوند.</p>",code:"<h1>عنوان اصلی</h1>\n<h2>عنوان بخش</h2>\n<p>این یک پاراگراف است.</p>"},
  {title:"لینک‌ها",body:"<p>تگ a برای ساخت لینک است. آدرس مقصد را در ویژگی href قرار می‌دهیم. برای باز کردن لینک در زبانه جدید از target استفاده می‌شود و بهتر است rel نیز تنظیم شود.</p>",code:"<a href=\"https://example.com\">بازدید از سایت</a>\n<a href=\"https://example.com\" target=\"_blank\" rel=\"noopener\">در زبانه جدید</a>"},
  {title:"تصاویر و متن جایگزین",body:"<p>تگ img تصویر را نمایش می‌دهد. ویژگی src مسیر تصویر و alt توضیح متنی تصویر است. متن alt برای دسترس‌پذیری و زمانی که تصویر بارگذاری نشود اهمیت دارد.</p>",code:"<img src=\"photo.jpg\" alt=\"نمایی از طبیعت\" width=\"300\">"},
  {title:"فهرست‌ها",body:"<p>برای فهرست بدون ترتیب از ul و برای فهرست شماره‌دار از ol استفاده کن. هر مورد فهرست داخل li قرار می‌گیرد.</p>",code:"<ul>\n  <li>HTML</li>\n  <li>CSS</li>\n</ul>\n<ol>\n  <li>یادگیری</li>\n  <li>تمرین</li>\n</ol>"},
 ]},
 css:{name:"CSS — طراحی وب",level:"مقدماتی",desc:"رنگ، فاصله، چیدمان و واکنش‌گرایی را یاد بگیر.",lessons:[
  {title:"CSS چیست؟",body:"<p>CSS مخفف Cascading Style Sheets است و ظاهر عناصر HTML را کنترل می‌کند؛ مانند رنگ، اندازه، فاصله و چیدمان.</p><p>قانون CSS از انتخابگر و مجموعه‌ای از ویژگی‌ها و مقدارها تشکیل می‌شود.</p>",code:"h1 {\n  color: crimson;\n  font-size: 32px;\n}"},
  {title:"سه روش افزودن CSS",body:"<p>CSS را می‌توان در ویژگی style، داخل تگ style یا در فایل جداگانه با پسوند css نوشت. برای پروژه‌های واقعی، فایل جداگانه معمولاً نگهداری را ساده‌تر می‌کند.</p>",code:"<!-- در فایل HTML -->\n<link rel=\"stylesheet\" href=\"style.css\">\n\n/* در فایل style.css */\nbody { font-family: Arial; }"},
  {title:"انتخابگرها",body:"<p>انتخابگر مشخص می‌کند کدام عنصر استایل بگیرد. نام تگ، کلاس با نقطه و شناسه با # انتخابگرهای رایج هستند.</p>",code:"p { color: #444; }\n.card { padding: 16px; }\n#main-title { color: red; }"},
  {title:"رنگ و پس‌زمینه",body:"<p>رنگ را می‌توان با نام، کد HEX یا تابع rgb مشخص کرد. ویژگی background-color رنگ پس‌زمینه را تعیین می‌کند.</p>",code:"body { background-color: #101018; }\nh1 { color: #ff303b; }\n.note { color: rgb(180,180,190); }"},
  {title:"مدل جعبه‌ای",body:"<p>هر عنصر در CSS مانند یک جعبه است: محتوا، padding، border و margin. استفاده از box-sizing: border-box محاسبه اندازه‌ها را قابل پیش‌بینی‌تر می‌کند.</p>",code:"* { box-sizing: border-box; }\n.card {\n  padding: 20px;\n  border: 1px solid #ccc;\n  margin: 12px;\n}"},
  {title:"Flexbox و واکنش‌گرایی",body:"<p>Flexbox برای چیدمان یک‌بعدی کاربرد دارد. با media query می‌توان ظاهر صفحه را برای نمایشگرهای کوچک تغییر داد.</p>",code:".row { display: flex; gap: 12px; }\n@media (max-width: 600px) {\n  .row { flex-direction: column; }\n}"},
 ]},
 js:{name:"JavaScript — منطق وب",level:"مقدماتی",desc:"به صفحات وب رفتار و تعامل اضافه کن.",lessons:[
  {title:"JavaScript چیست؟",body:"<p>JavaScript زبان برنامه‌نویسی است که می‌تواند به صفحه وب رفتار اضافه کند؛ مثل واکنش به کلیک، محاسبه و تغییر محتوا.</p>",code:"console.log('سلام از JavaScript!');"},
  {title:"متغیرها",body:"<p>برای نگهداری داده از let و const استفاده می‌کنیم. مقدار const دوباره به متغیر نسبت داده نمی‌شود؛ let برای مقداری است که ممکن است تغییر کند.</p>",code:"const academy = 'NEXORA';\nlet lessons = 6;\nlessons = 7;\nconsole.log(academy, lessons);"},
  {title:"نوع داده‌ها",body:"<p>رشته، عدد، مقدار بولی، آرایه و شیء از انواع داده رایج هستند. typeof نوع بسیاری از مقدارها را نشان می‌دهد.</p>",code:"const name = 'Ali';\nconst age = 18;\nconst active = true;\nconsole.log(typeof name);\nconsole.log(typeof age);"},
  {title:"شرط‌ها",body:"<p>با if و else می‌توان بر اساس درست یا نادرست بودن یک شرط مسیرهای متفاوتی اجرا کرد. برای مقایسه مقدار و نوع، معمولاً از === استفاده کن.</p>",code:"const score = 75;\nif (score >= 50) {\n  console.log('قبول شدی');\n} else {\n  console.log('بیشتر تمرین کن');\n}"},
  {title:"تابع‌ها",body:"<p>تابع مجموعه‌ای از دستورهاست که می‌توان آن را دوباره اجرا کرد. تابع می‌تواند ورودی بگیرد و با return نتیجه برگرداند.</p>",code:"function greet(name) {\n  return 'سلام ' + name;\n}\nconsole.log(greet('دوست من'));"},
  {title:"رویداد کلیک",body:"<p>رویدادها به ما اجازه می‌دهند به کار کاربر واکنش نشان دهیم. در این مثال با کلیک روی دکمه، متن صفحه تغییر می‌کند.</p>",code:"<button id=\"helloBtn\">کلیک کن</button>\n<p id=\"message\"></p>\n<script>\ndocument.querySelector('#helloBtn').addEventListener('click', () => {\n document.querySelector('#message').textContent = 'آفرین!';\n});\n<\\/script>"},
 ]}
};

courses.html.lessons.push(
 {title:"عناصر معنایی HTML",body:"<p>عناصر معنایی نامی دارند که نقش محتوا را روشن می‌کند. header برای سربرگ، nav برای ناوبری، main برای محتوای اصلی، section برای بخش و footer برای پابرگ مناسب است.</p><p>از این عناصر به‌جای استفاده بی‌دلیل از div استفاده کن تا ساختار صفحه برای مرورگرها و ابزارهای کمکی قابل فهم‌تر باشد.</p>",code:"<header>سربرگ سایت</header>\n<nav><a href='#home'>خانه</a></nav>\n<main>\n  <section><h2>درباره ما</h2><p>متن بخش</p></section>\n</main>\n<footer>پابرگ</footer>"},
 {title:"ساخت فرم",body:"<p>فرم‌ها اطلاعات را از کاربر می‌گیرند. عنصر form محدوده فرم را می‌سازد و label عنوان هر ورودی را مشخص می‌کند. ویژگی for در label باید با id ورودی برابر باشد.</p>",code:"<form>\n  <label for='fullname'>نام:</label>\n  <input id='fullname' name='fullname'>\n  <button type='submit'>ارسال</button>\n</form>"},
 {title:"انواع ورودی‌ها",body:"<p>ویژگی type نوع ورودی را مشخص می‌کند. email برای ایمیل، password برای رمز، number برای عدد، date برای تاریخ و checkbox برای انتخاب روشن/خاموش کاربرد دارند.</p><p>برای هر ورودی یک label قابل کلیک فراهم کن و در صورت نیاز از required استفاده کن.</p>",code:"<label for='email'>ایمیل</label>\n<input id='email' type='email' required>\n<label for='age'>سن</label>\n<input id='age' type='number' min='1' max='120'>\n<label><input type='checkbox'> قوانین را می‌پذیرم</label>"},
 {title:"دکمه‌ها و ارسال فرم",body:"<p>دکمه داخل فرم به‌طور پیش‌فرض ممکن است فرم را ارسال کند. type='submit' برای ارسال و type='button' برای عملیاتی که نباید فرم را ارسال کند استفاده می‌شود.</p>",code:"<form action='/register' method='post'>\n  <input name='username' required>\n  <button type='submit'>ثبت‌نام</button>\n  <button type='button' onclick='alert(\'سلام\')'>نمایش پیام</button>\n</form>"},
 {title:"جدول‌ها",body:"<p>برای داده‌های جدولی از table استفاده کن. tr ردیف، th عنوان ستون و td خانه داده است. caption عنوان جدول را می‌دهد و thead و tbody بخش‌های جدول را جدا می‌کنند.</p>",code:"<table>\n  <caption>نمره‌ها</caption>\n  <thead><tr><th>نام</th><th>نمره</th></tr></thead>\n  <tbody><tr><td>سارا</td><td>۱۸</td></tr></tbody>\n</table>"},
 {title:"صدا و ویدیو",body:"<p>عناصر audio و video برای پخش رسانه هستند. ویژگی controls کنترل‌های پخش را نمایش می‌دهد. می‌توان چند source با قالب‌های متفاوت تعریف کرد تا مرورگر گزینه سازگار را انتخاب کند.</p>",code:"<video controls width='320'>\n  <source src='movie.mp4' type='video/mp4'>\n  مرورگر شما از ویدیو پشتیبانی نمی‌کند.\n</video>\n<audio controls src='sound.mp3'></audio>"},
 {title:"ویژگی‌های عمومی و data",body:"<p>ویژگی‌هایی مانند id و class روی عناصر مختلف قابل استفاده‌اند. id باید در صفحه یکتا باشد؛ class برای گروهی از عناصر مناسب است. ویژگی‌های data-* برای نگهداری داده‌های سفارشی در HTML هستند.</p>",code:"<article id='lesson-1' class='card' data-level='beginner'>\n  <h2>درس اول</h2>\n  <p>شروع یادگیری</p>\n</article>"},
 {title:"div و span",body:"<p>div یک ظرف بلوکی عمومی و span یک ظرف درون‌خطی عمومی است. وقتی عنصر معنایی مناسب وجود ندارد، از آن‌ها برای گروه‌بندی و استایل‌دهی استفاده کن؛ نه اینکه همه صفحه را با div بسازی.</p>",code:"<div class='profile'>\n  <h2>مشخصات</h2>\n  <p>نام: <span class='highlight'>علی</span></p>\n</div>"},
 {title:"دسترس‌پذیری و HTML درست",body:"<p>برای دسترس‌پذیری، تصویر معنادار باید alt مناسب داشته باشد، فرم‌ها label داشته باشند، ترتیب عنوان‌ها منطقی باشد و لینک‌ها متن توصیفی داشته باشند. از عنصر درست برای کار درست استفاده کن.</p>",code:"<img src='team.jpg' alt='اعضای تیم در جلسه کاری'>\n<h1>آموزش وب</h1>\n<h2>درس‌های رایگان</h2>\n<a href='/courses'>مشاهده دوره‌های آموزشی</a>"}
);
courses.css.lessons.push(
 {title:"آبشار و وراثت CSS",body:"<p>وقتی چند قانون روی یک عنصر اثر می‌گذارند، آبشار CSS با توجه به اهمیت، اختصاصیت و ترتیب قوانین تصمیم می‌گیرد کدام مقدار اعمال شود. بعضی ویژگی‌ها مانند color به فرزندان به ارث می‌رسند.</p>",code:"body { color: #333; }\n.card { color: #b21e35; }\n.card p { color: inherit; }"},
 {title:"اختصاصیت انتخابگرها",body:"<p>انتخابگر id معمولاً از class اختصاصی‌تر است و class از انتخابگر نام تگ اختصاصی‌تر. برای جلوگیری از پیچیدگی، تا حد ممکن از کلاس‌های قابل استفاده مجدد استفاده کن و به !important وابسته نشو.</p>",code:"p { color: gray; }\n.note { color: crimson; }\n#intro { color: navy; }"},
 {title:"واحدهای اندازه‌گیری",body:"<p>px واحد ثابت، درصد نسبی به اندازه والد، em وابسته به اندازه فونت عنصر والد و rem وابسته به اندازه فونت ریشه است. برای اندازه‌های قابل تطبیق معمولاً rem و درصد انتخاب‌های مناسبی‌اند.</p>",code:"html { font-size: 16px; }\nh1 { font-size: 2rem; }\n.container { width: 90%; max-width: 1100px; }\n.card { padding: 1em; }"},
 {title:"فونت و خوانایی متن",body:"<p>با font-family نوع قلم، font-size اندازه، font-weight ضخامت و line-height فاصله خطوط را کنترل می‌کنی. برای متن فارسی، قلم مناسب و فاصله خطوط کافی خوانایی را بهتر می‌کند.</p>",code:"body { font-family: Tahoma, Arial, sans-serif; }\np { font-size: 16px; line-height: 1.9; }\nh1 { font-weight: 800; }"},
 {title:"display و جریان عناصر",body:"<p>display رفتار چیدمان عنصر را تعیین می‌کند. block تمام عرض در دسترس را می‌گیرد، inline در جریان متن قرار می‌گیرد، inline-block امکان تعیین ابعاد را می‌دهد و none عنصر را از چیدمان حذف می‌کند.</p>",code:".badge { display: inline-block; padding: 6px 10px; }\n.hidden { display: none; }\n.card { display: block; }"},
 {title:"موقعیت‌دهی عناصر",body:"<p>position با مقادیر static، relative، absolute، fixed و sticky موقعیت عنصر را کنترل می‌کند. absolute نسبت به نزدیک‌ترین والد موقعیت‌دار محاسبه می‌شود؛ sticky هنگام پیمایش می‌تواند به لبه صفحه بچسبد.</p>",code:".parent { position: relative; }\n.label { position: absolute; top: 8px; right: 8px; }\nheader { position: sticky; top: 0; }"},
 {title:"CSS Grid",body:"<p>Grid برای چیدمان دوبعدی ردیف و ستون مناسب است. با grid-template-columns ستون‌ها و با gap فاصله خانه‌ها را تعیین می‌کنی. repeat و minmax ساخت شبکه‌های منعطف را آسان می‌کنند.</p>",code:".grid {\n  display: grid;\n  grid-template-columns: repeat(3, minmax(0, 1fr));\n  gap: 16px;\n}\n@media (max-width: 650px) {\n  .grid { grid-template-columns: 1fr; }\n}"},
 {title:"شبه‌کلاس‌ها",body:"<p>شبه‌کلاس‌ها وضعیت عنصر را هدف می‌گیرند. :hover هنگام قرار گرفتن نشانگر، :focus هنگام دریافت تمرکز و :first-child برای اولین فرزند کاربرد دارند. برای کاربران صفحه‌کلید، حالت focus را حذف نکن.</p>",code:"a:hover { color: crimson; }\ninput:focus { outline: 2px solid crimson; }\nli:first-child { font-weight: bold; }"},
 {title:"شبه‌عنصرها",body:"<p>شبه‌عنصرهایی مانند ::before و ::after بخشی مجازی برای نمایش تزئینات ایجاد می‌کنند. برای محتوای مهم و ضروری به آن‌ها تکیه نکن؛ چون هدف اصلی‌شان ارائه ظاهری است.</p>",code:".title::after {\n  content: '';\n  display: block;\n  width: 50px;\n  height: 3px;\n  background: crimson;\n}"},
 {title:"رنگ، شفافیت و سایه",body:"<p>برای رنگ می‌توان از HEX، rgb و hsl استفاده کرد. opacity شفافیت کل عنصر و box-shadow سایه جعبه را کنترل می‌کند. برای متن، کنتراست کافی با پس‌زمینه ضروری است.</p>",code:".card {\n  color: #222;\n  background: rgba(255,255,255,.95);\n  box-shadow: 0 8px 24px rgba(0,0,0,.15);\n}"},
 {title:"انتقال و تبدیل",body:"<p>transition تغییر ویژگی را نرم می‌کند و transform عنصر را جابه‌جا، چرخان یا بزرگ و کوچک می‌کند. فقط ویژگی‌هایی را متحرک کن که تجربه کاربر را بهتر می‌کنند.</p>",code:".button { transition: transform .2s, background .2s; }\n.button:hover { transform: translateY(-2px); }"},
 {title:"متغیرهای CSS",body:"<p>متغیرهای سفارشی با دو خط تیره تعریف می‌شوند و با var خوانده می‌شوند. آن‌ها برای رنگ‌های برند، فاصله‌ها و تنظیمات مشترک بسیار مفیدند.</p>",code:":root {\n  --brand: #e32636;\n  --space: 16px;\n}\n.button { background: var(--brand); padding: var(--space); }"}
);
courses.js.lessons.push(
 {title:"عملگرهای ریاضی و مقایسه",body:"<p>عملگرهای +، -، * و / محاسبه می‌کنند. عملگرهای ===، !==، بزرگ‌تر و کوچک‌تر برای مقایسه‌اند. برای مقایسه مقدار و نوع، از مقایسه سخت‌گیرانه استفاده کن.</p>",code:"const price = 120;\nconst count = 3;\nconsole.log(price * count);\nconsole.log(count >= 2);\nconsole.log(5 === '5'); // false"},
 {title:"عملگرهای منطقی",body:"<p>عملگر && وقتی هر دو شرط درست باشند نتیجه درست می‌دهد؛ || وقتی دست‌کم یکی درست باشد و ! مقدار منطقی را برعکس می‌کند.</p>",code:"const age = 20;\nconst hasTicket = true;\nconsole.log(age >= 18 && hasTicket);\nconsole.log(!hasTicket);"},
 {title:"حلقه for",body:"<p>حلقه for برای تکرار تعداد مشخصی از دفعات مناسب است. بخش آغاز، شرط ادامه و تغییر شمارنده در سرآیند حلقه نوشته می‌شوند.</p>",code:"for (let i = 1; i <= 5; i++) {\n  console.log('شماره ' + i);\n}"},
 {title:"حلقه while و کنترل تکرار",body:"<p>while تا زمانی اجرا می‌شود که شرط درست باشد. مراقب باش شرط در نهایت نادرست شود؛ وگرنه حلقه بی‌نهایت ایجاد می‌شود. break حلقه را متوقف و continue به تکرار بعدی می‌رود.</p>",code:"let number = 1;\nwhile (number <= 5) {\n  console.log(number);\n  number++;\n}"},
 {title:"آرایه‌ها",body:"<p>آرایه چند مقدار را در یک متغیر نگه می‌دارد. اندیس آرایه از صفر شروع می‌شود؛ length تعداد عناصر را می‌دهد و می‌توان با اندیس به یک عضو دسترسی داشت.</p>",code:"const skills = ['HTML', 'CSS', 'JavaScript'];\nconsole.log(skills[0]);\nconsole.log(skills.length);"},
 {title:"افزودن و حذف از آرایه",body:"<p>push عضو را به انتها اضافه و pop عضو آخر را حذف می‌کند. unshift به ابتدا اضافه و shift عضو اول را حذف می‌کند. این روش‌ها آرایه اصلی را تغییر می‌دهند.</p>",code:"const tasks = ['مطالعه'];\ntasks.push('تمرین');\ntasks.pop();\nconsole.log(tasks);"},
 {title:"پیمایش آرایه با forEach",body:"<p>forEach یک تابع را برای هر عضو آرایه اجرا می‌کند. این روش برای انجام کاری روی هر عضو مناسب است و آرایه جدید برنمی‌گرداند.</p>",code:"const names = ['سارا', 'علی', 'مینا'];\nnames.forEach(name => {\n  console.log('سلام ' + name);\n});"},
 {title:"متد map و filter",body:"<p>map از هر عضو آرایه مقداری می‌سازد و آرایه جدید برمی‌گرداند. filter فقط عضوهایی را نگه می‌دارد که شرط را بگذرانند؛ هر دو آرایه اصلی را دست‌نخورده می‌گذارند.</p>",code:"const numbers = [1, 2, 3, 4];\nconst doubled = numbers.map(n => n * 2);\nconst even = numbers.filter(n => n % 2 === 0);\nconsole.log(doubled, even);"},
 {title:"شیءها",body:"<p>شیء داده‌ها را به شکل ویژگی و مقدار نگه می‌دارد. به ویژگی‌ها با نقطه یا براکت دسترسی پیدا می‌کنی. برای داده‌های مرتبط، شیء ساختار روشنی ایجاد می‌کند.</p>",code:"const student = {\n  name: 'مریم',\n  age: 19,\n  active: true\n};\nconsole.log(student.name);\nstudent.age = 20;"},
 {title:"توابع پیکانی و پارامتر پیش‌فرض",body:"<p>تابع پیکانی شکل کوتاه‌تری برای تعریف تابع است. می‌توان برای پارامتر مقدار پیش‌فرض گذاشت تا اگر ورودی ارسال نشد از آن استفاده شود.</p>",code:"const greet = (name = 'دوست') => {\n  return 'سلام ' + name;\n};\nconsole.log(greet());\nconsole.log(greet('سارا'));"},
 {title:"انتخاب عناصر صفحه با DOM",body:"<p>DOM نمای درختی صفحه است. با querySelector اولین عنصر مطابق انتخابگر و با querySelectorAll همه موارد مطابق را پیدا می‌کنی. سپس می‌توان متن یا ویژگی‌های آن‌ها را تغییر داد.</p>",code:"const heading = document.querySelector('h1');\nif (heading) {\n  heading.textContent = 'عنوان تازه';\n}"},
 {title:"رویدادها و event",body:"<p>با addEventListener به رویدادهایی مثل click و input گوش می‌دهیم. شیء event اطلاعات رویداد را دارد و currentTarget عنصری را نشان می‌دهد که شنونده روی آن نصب شده است.</p>",code:"const button = document.querySelector('button');\nbutton.addEventListener('click', event => {\n  event.currentTarget.textContent = 'کلیک شد';\n});"},
 {title:"کار با فرم و ورودی کاربر",body:"<p>برای دریافت مقدار ورودی از value استفاده کن. رویداد submit فرم را می‌توان کنترل کرد و با preventDefault از بارگذاری دوباره صفحه جلوگیری کرد. داده کاربر را قبل از استفاده بررسی کن.</p>",code:"const form = document.querySelector('form');\nform.addEventListener('submit', event => {\n  event.preventDefault();\n  const name = document.querySelector('#name').value.trim();\n  console.log(name);\n});"},
 {title:"اعتبارسنجی ساده فرم",body:"<p>اعتبارسنجی یعنی بررسی اینکه داده ورودی قابل قبول است. برای ایمیل و فیلدهای ضروری می‌توان از ویژگی‌های HTML مثل required و type استفاده کرد و در JavaScript پیام دقیق‌تری نمایش داد.</p>",code:"const username = 'Nexora';\nif (username.trim().length < 3) {\n  console.log('نام باید حداقل ۳ حرف باشد');\n} else {\n  console.log('نام معتبر است');\n}"},
 {title:"ذخیره‌سازی در localStorage",body:"<p>localStorage داده متنی را در مرورگر همان دستگاه نگه می‌دارد و پس از بستن صفحه باقی می‌ماند. این داده به‌صورت خودکار بین دستگاه‌ها همگام نمی‌شود و برای رمز عبور یا اطلاعات حساس مناسب نیست.</p>",code:"localStorage.setItem('theme', 'dark');\nconst theme = localStorage.getItem('theme');\nconsole.log(theme);\n// localStorage.removeItem('theme');"},
 {title:"JSON و تبدیل داده",body:"<p>JSON قالبی متنی برای تبادل داده است. JSON.stringify شیء را به متن تبدیل می‌کند و JSON.parse متن معتبر JSON را به داده JavaScript تبدیل می‌کند.</p>",code:"const user = { name: 'Ali', level: 1 };\nconst text = JSON.stringify(user);\nconst copy = JSON.parse(text);\nconsole.log(copy.name);"},
 {title:"مدیریت خطا با try و catch",body:"<p>گاهی اجرای یک دستور با خطا روبه‌رو می‌شود. try کد پرخطر را در بر می‌گیرد و catch خطا را دریافت می‌کند تا برنامه بتواند واکنش کنترل‌شده نشان دهد.</p>",code:"try {\n  const data = JSON.parse('{bad json}');\n  console.log(data);\n} catch (error) {\n  console.log('داده معتبر نیست');\n}"},
 {title:"تاریخ و زمان",body:"<p>شیء Date برای کار با تاریخ و زمان استفاده می‌شود. getFullYear سال و getMonth ماه را از صفر تا یازده برمی‌گرداند؛ برای نمایش ماه انسانی معمولاً یک واحد اضافه می‌کنیم.</p>",code:"const now = new Date();\nconsole.log(now.getFullYear());\nconsole.log(now.getMonth() + 1);\nconsole.log(now.toLocaleDateString('fa-IR'));"},
 {title:"پروژه کوچک: شمارنده",body:"<p>در این تمرین یک شمارنده می‌سازیم. متغیر count وضعیت را نگه می‌دارد و هر کلیک مقدار را یک واحد افزایش می‌دهد. در پروژه واقعی، HTML دکمه و خروجی باید در صفحه وجود داشته باشند.</p>",code:"let count = 0;\nconst button = document.querySelector('#plus');\nconst output = document.querySelector('#count');\nbutton.addEventListener('click', () => {\n  count++;\n  output.textContent = count;\n});"}
);

const $=id=>document.getElementById(id);
let keys=Object.keys(courses);
let activeCourse="html", activeLesson=0, activeTab="html";
const done=new Set(JSON.parse(localStorage.getItem("nexoraAcademyDone")||"[]"));
const samples={
 html:'<h1>سلام NEXORA!</h1>\n<p>من دارم HTML یاد می‌گیرم.</p>\n<button onclick="document.querySelector(\'p\').textContent=\'آفرین!\'">کلیک کن</button>',
 css:'<h1 class="title">سلام NEXORA!</h1>\n<p>این یک تمرین CSS است.</p>\n<button>دکمه نمونه</button>',
 js:'document.querySelector("#change").addEventListener("click",()=>{\n document.querySelector("#title").textContent="تو موفق شدی!";\n});'
};
const codeStorageKey="nexoraAcademyCodeV1";
function loadCodeBuffers(){
  try{
    const saved=JSON.parse(localStorage.getItem(codeStorageKey)||"null");
    return saved&&typeof saved==="object"?{
      html:typeof saved.html==="string"?saved.html:samples.html,
      css:typeof saved.css==="string"?saved.css:samples.css,
      js:typeof saved.js==="string"?saved.js:samples.js
    }:{...samples};
  }catch(error){return {...samples};}
}
const codeBuffers=loadCodeBuffers();
function saveCodeBuffers(){
  try{localStorage.setItem(codeStorageKey,JSON.stringify(codeBuffers));}
  catch(error){const status=$("codeStatus");if(status)status.textContent="ذخیره خودکار در این مرورگر در دسترس نیست.";}
}
const styles={
 html:"body{font-family:Arial,sans-serif;padding:20px;color:#222}h1{color:#c21d32}",
 css:"body{font-family:Arial,sans-serif;padding:20px;color:#222}.title{color:#c21d32;background:#fff0f1;padding:12px;border-radius:10px}button{padding:9px 14px;border:0;border-radius:8px;background:#c21d32;color:white}",
 js:"body{font-family:Arial,sans-serif;padding:20px;color:#222}button{padding:9px 14px;background:#c21d32;color:white;border:0;border-radius:8px}"
};
function saveDone(){localStorage.setItem("nexoraAcademyDone",JSON.stringify([...done]));updateProgress();window.dispatchEvent(new CustomEvent("nexora:progress-updated",{detail:[...done]}));}
window.addEventListener("nexora:progress-loaded",event=>{if(!Array.isArray(event.detail))return;done.clear();event.detail.forEach(id=>done.add(id));localStorage.setItem("nexoraAcademyDone",JSON.stringify([...done]));updateProgress();renderLessonList();renderLesson();});
function updateProgress(){const total=keys.reduce((n,k)=>n+courses[k].lessons.length,0);const count=$("lessonCount");if(count)count.textContent=total.toLocaleString("fa-IR");$("progressLabel").textContent=done.size.toLocaleString("fa-IR")+" از "+total.toLocaleString("fa-IR")+" درس";$("progressBar").style.width=(done.size/total*100)+"%";}
function renderCourses(){$("courseGrid").innerHTML=keys.map(k=>{const c=courses[k];return '<button class="course" data-open-course="'+k+'"><span class="course-icon">'+k.toUpperCase()+'</span><h3>'+c.name+'</h3><p>'+c.desc+'</p><span class="course-foot"><span>'+c.level+'</span><span>'+c.lessons.length+' درس ←</span></span></button>';}).join("");document.querySelectorAll("[data-open-course]").forEach(b=>b.addEventListener("click",()=>openCourse(b.dataset.openCourse)));}
function renderCourseSelect(){$("courseSelect").innerHTML=keys.map(k=>'<option value="'+k+'">'+courses[k].name+'</option>').join("");}
function renderLessonList(){$("lessonList").innerHTML=courses[activeCourse].lessons.map((l,i)=>{const id=l.id||activeCourse+":"+i;return '<button class="lesson-item '+(i===activeLesson?"active ":"")+(done.has(id)?"done":"")+'" data-index="'+i+'">'+(i+1)+". "+l.title+'<small>'+(done.has(id)?"تکمیل‌شده":"برای مطالعه انتخاب کن")+'</small></button>';}).join("");document.querySelectorAll("[data-index]").forEach(b=>b.addEventListener("click",()=>{activeLesson=Number(b.dataset.index);renderLesson();}));}
const lessonExercises = {"HTML چیست؟":"یک صفحه ساده بساز که عنوان «آکادمی من» و یک پاراگراف معرفی داشته باشد.","ساختار استاندارد صفحه":"یک سند کامل HTML با lang فارسی، charset، عنوان صفحه و بخش body بساز.","عنوان‌ها و پاراگراف‌ها":"برای یک مقاله، یک عنوان اصلی، دو عنوان فرعی و سه پاراگراف ایجاد کن.","لینک‌ها":"یک لینک به سایت دلخواه و یک لینک که در زبانه جدید باز شود بساز.","تصاویر و متن جایگزین":"یک تصویر اضافه کن و برای آن alt توصیفی و عرض ۲۵۰ پیکسل تعیین کن.","فهرست‌ها":"فهرست شماره‌دار سه مرحله‌ای و فهرست بدون ترتیب سه مهارت بساز.","CSS چیست؟":"رنگ عنوان را قرمز و اندازه آن را ۳۲ پیکسل کن.","سه روش افزودن CSS":"یک فایل style.css بساز و آن را به فایل HTML وصل کن.","انتخابگرها":"با انتخابگر تگ، کلاس و شناسه سه عنصر متفاوت را استایل بده.","رنگ و پس‌زمینه":"برای صفحه پس‌زمینه تیره و برای متن رنگ روشن انتخاب کن.","مدل جعبه‌ای":"یک کارت با padding، border و margin بساز و box-sizing را تنظیم کن.","Flexbox و واکنش‌گرایی":"سه کارت را با Flexbox کنار هم بچین و در عرض کمتر از ۶۰۰ پیکسل ستونی کن.","JavaScript چیست؟":"با console.log یک پیام خوش‌آمدگویی در کنسول نمایش بده.","متغیرها":"نام آکادمی را با const و تعداد درس‌ها را با let ذخیره و چاپ کن.","نوع داده‌ها":"یک رشته، عدد، مقدار بولی، آرایه و شیء بساز و نوع داده‌ها را بررسی کن.","شرط‌ها":"بر اساس نمره، پیام قبولی یا نیاز به تمرین نمایش بده.","تابع‌ها":"تابعی بنویس که نام را بگیرد و پیام خوش‌آمدگویی برگرداند.","رویداد کلیک":"با کلیک روی دکمه، متن یک پاراگراف را تغییر بده.","عناصر معنایی HTML":"صفحه‌ای با header، nav، main، section و footer بساز.","ساخت فرم":"فرمی با ورودی نام و دکمه ارسال بساز و label مرتبط اضافه کن.","انواع ورودی‌ها":"ورودی ایمیل، رمز عبور، تاریخ و checkbox ایجاد کن.","دکمه‌ها و ارسال فرم":"فرمی بساز که دکمه ارسال و دکمه عادی با عملکرد متفاوت داشته باشد.","جدول‌ها":"جدولی با سه ستون نام، درس و نمره و حداقل دو ردیف داده بساز.","صدا و ویدیو":"یک عنصر video با controls و متن جایگزین در صورت پشتیبانی‌نشدن اضافه کن.","ویژگی‌های عمومی و data":"برای یک کارت id، class و data-level تعریف کن.","div و span":"با div دو بخش بساز و با span یک کلمه را درون پاراگراف مشخص کن.","دسترس‌پذیری و HTML درست":"برای تصویر alt، برای ورودی label و برای دکمه متن واضح قرار بده.","آبشار و وراثت CSS":"رنگ متن body را تعیین کن و رنگ یک عنصر فرزند را جداگانه تغییر بده.","اختصاصیت انتخابگرها":"برای یک عنصر قانون تگ، کلاس و شناسه بنویس و نتیجه را مقایسه کن.","واحدهای اندازه‌گیری":"یک کارت با rem برای فونت و درصد برای عرض بساز.","فونت و خوانایی متن":"برای متن فارسی فونت مناسب، line-height و اندازه خوانا تنظیم کن.","display و جریان عناصر":"دو عنصر را با inline-block کنار هم قرار بده و تفاوت block را بررسی کن.","موقعیت‌دهی عناصر":"یک نشان کوچک را در گوشه بالای کارت با position قرار بده.","CSS Grid":"یک شبکه سه‌ستونه بساز و فاصله بین کارت‌ها را تنظیم کن.","شبه‌کلاس‌ها":"برای لینک حالت hover و برای ورودی حالت focus تعریف کن.","شبه‌عنصرها":"با ::before یک نشان تزئینی پیش از عنوان ایجاد کن.","رنگ، شفافیت و سایه":"برای کارت پس‌زمینه نیمه‌شفاف و سایه ملایم بساز.","انتقال و تبدیل":"با hover کارت را کمی بزرگ کن و تغییر را با transition نرم کن.","متغیرهای CSS":"رنگ اصلی را در :root تعریف کن و در دو عنصر استفاده کن.","عملگرهای ریاضی و مقایسه":"دو عدد را با عملگرهای +، * و === مقایسه و نتیجه را چاپ کن.","عملگرهای منطقی":"شرطی بنویس که فقط در صورت درست بودن دو شرط پیام دسترسی بدهد.","حلقه for":"اعداد ۱ تا ۱۰ را با حلقه for در کنسول چاپ کن.","حلقه while و کنترل تکرار":"با while تا رسیدن شمارنده به ۵ ادامه بده و سپس متوقف شو.","آرایه‌ها":"آرایه‌ای از سه نام درس بساز و عضو اول و آخر را چاپ کن.","افزودن و حذف از آرایه":"یک درس به انتهای آرایه اضافه و سپس آخرین عضو را حذف کن.","پیمایش آرایه با forEach":"نام هر عضو آرایه را با forEach در کنسول چاپ کن.","متد map و filter":"از آرایه نمره‌ها با map نمره‌ها را دو برابر و با filter نمره‌های بالای ۵۰ را جدا کن.","شیءها":"شیئی برای دانش‌آموز با name، age و course بساز و مقدارها را بخوان.","توابع پیکانی و پارامتر پیش‌فرض":"تابع پیکانی بساز که اگر نامی داده نشد، مقدار پیش‌فرض استفاده کند.","انتخاب عناصر صفحه با DOM":"با querySelector عنوان صفحه را پیدا کن و متنش را تغییر بده.","رویدادها و event":"رویداد کلیک را ثبت کن و نوع رویداد را از شیء event بخوان.","کار با فرم و ورودی کاربر":"با submit مقدار ورودی را بخوان و از بارگذاری دوباره صفحه جلوگیری کن.","اعتبارسنجی ساده فرم":"بررسی کن ورودی خالی نباشد و ایمیل شامل @ باشد.","ذخیره‌سازی در localStorage":"نام کاربر را ذخیره کن و در بارگذاری بعدی بخوان.","JSON و تبدیل داده":"یک شیء را با JSON.stringify به متن و با JSON.parse به شیء تبدیل کن.","مدیریت خطا با try و catch":"تبدیل یک متن نامعتبر JSON را در try/catch قرار بده و پیام خطا را نمایش بده.","تاریخ و زمان":"تاریخ و ساعت فعلی را با شیء Date نمایش بده.","پروژه کوچک: شمارنده":"شمارنده‌ای با دکمه‌های افزایش، کاهش و صفرکردن بساز."};
function renderLesson(){const c=courses[activeCourse],l=c.lessons[activeLesson];$("lessonCourse").textContent=c.name;$("lessonNumber").textContent="درس "+(activeLesson+1)+" از "+c.lessons.length;$("lessonTitle").textContent=l.title;$("lessonBody").innerHTML=l.body;$("lessonExercise").innerHTML="<strong>تمرین این درس</strong><p>"+(l.exercise||lessonExercises[l.title]||"یک نمونه مستقل از این مبحث بساز و نتیجه را آزمایش کن.")+"</p>";$("lessonCode").textContent=l.code;$("prevLesson").disabled=activeLesson===0;$("nextLesson").disabled=activeLesson===c.lessons.length-1;$("completeLesson").textContent=done.has(courses[activeCourse].lessons[activeLesson].id||activeCourse+":"+activeLesson)?"✓ این درس تکمیل شده":"علامت‌گذاری به‌عنوان تکمیل‌شده";$("lessonStatus").textContent="";renderLessonList();}
function openCourse(k){activeCourse=k;activeLesson=0;$("courseSelect").value=k;renderLesson();$("classroom").scrollIntoView({behavior:"smooth"});}
function renderPreview(){
const hasAnyCode=Object.values(codeBuffers).some(code=>code.trim().length>0);
const defaultHtml=!hasAnyCode?"":(activeTab==="css"?"<h1 class='title'>سلام NEXORA!</h1><p>این یک تمرین CSS است.</p><button>دکمه نمونه</button>":(activeTab==="js"?"<h1 id='title'>سلام!</h1><button id='change'>تغییر متن</button>":""));
const html=activeTab==="html"?$("codeEditor").value:defaultHtml;
const css=activeTab==="css"?$("codeEditor").value:styles[activeTab];
const js=activeTab==="js"?$("codeEditor").value:"";
const safeJs=js.replace(/<\/script/gi,"<\\/script");
const safeDoc='<!doctype html><html><head><meta charset="utf-8"><style>'+css+'</style></head><body>'+html+'<scr'+'ipt>'+safeJs+'</scr'+'ipt></body></html>';
$("preview").srcdoc=safeDoc;
}
function selectTab(tab){
  if(tab!==activeTab){codeBuffers[activeTab]=$("codeEditor").value;saveCodeBuffers();}
  activeTab=tab;
  document.querySelectorAll("[data-tab]").forEach(b=>b.classList.toggle("active",b.dataset.tab===tab));
  $("codeEditor").value=codeBuffers[tab];
  renderPreview();
}
$("courseSelect").addEventListener("change",e=>openCourse(e.target.value));
$("prevLesson").addEventListener("click",()=>{if(activeLesson>0){activeLesson--;renderLesson();}});
$("nextLesson").addEventListener("click",()=>{if(activeLesson<courses[activeCourse].lessons.length-1){activeLesson++;renderLesson();}});
$("completeLesson").addEventListener("click",()=>{done.add(courses[activeCourse].lessons[activeLesson].id||activeCourse+":"+activeLesson);saveDone();renderLesson();$("lessonStatus").textContent="پیشرفتت ذخیره شد." ;});
$("copyExample").addEventListener("click",async()=>{try{await navigator.clipboard.writeText(courses[activeCourse].lessons[activeLesson].code);$("lessonStatus").textContent="کد کپی شد.";}catch(e){$("lessonStatus").textContent="کپی خودکار در این مرورگر در دسترس نیست؛ کد را دستی انتخاب کن.";}});
document.querySelectorAll("[data-tab]").forEach(b=>b.addEventListener("click",()=>selectTab(b.dataset.tab)));
$("runCode").addEventListener("click",()=>{codeBuffers[activeTab]=$("codeEditor").value;saveCodeBuffers();renderPreview();$("codeStatus").textContent="کد اجرا شد.";});
$("codeEditor").addEventListener("input",()=>{codeBuffers[activeTab]=$("codeEditor").value;saveCodeBuffers();$("codeStatus").textContent="تغییرات به‌صورت خودکار ذخیره شد.";});
$("resetCode").addEventListener("click",()=>{codeBuffers[activeTab]=samples[activeTab];$("codeEditor").value=samples[activeTab];saveCodeBuffers();renderPreview();$("codeStatus").textContent="نمونه کد این زبانه بازنشانی شد.";});
$("clearAllCode").addEventListener("click",()=>{
  for(const tab of Object.keys(codeBuffers))codeBuffers[tab]="";
  $("codeEditor").value="";
  saveCodeBuffers();
  renderPreview();
  $("codeStatus").textContent="همه کدهای آزمایشی HTML، CSS و JavaScript حذف شدند.";
});
$("menuBtn").addEventListener("click",()=>$("navLinks").classList.toggle("open"));
document.querySelectorAll("#navLinks a").forEach(a=>a.addEventListener("click",()=>$("navLinks").classList.remove("open")));
let quiz=null,questions=[],qi=0,answers={},quizBusy=false,quizSubmitted=false;
const quizDb=window.supabase?.createClient(
 "https://nutgcqhcgytjglyuvmla.supabase.co",
 "sb_publishable_2HmqcVNPPPhULFeNPIbRlg_54LwTQEt",
 {auth:{persistSession:true,autoRefreshToken:false,detectSessionInUrl:false}}
);
const quizEscape=value=>String(value??"").replace(/[&<>"']/g,ch=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[ch]));
async function loadQuiz(){
 if(!quizDb){$("quizFeedback").textContent="سرویس آزمون بارگذاری نشد.";return;}
 const {data:quizRow,error:quizError}=await quizDb.from("academy_quizzes").select("id,title").eq("status","published").order("created_at").limit(1).maybeSingle();
 if(quizError)throw quizError;
 if(!quizRow){$("quizQuestion").textContent="هنوز آزمونی منتشر نشده است."; $("quizOptions").innerHTML="";$("nextQuestion").disabled=true;return;}
 const {data:qRows,error:qError}=await quizDb.from("academy_quiz_questions").select("id,question_text,sort_order").eq("quiz_id",quizRow.id).order("sort_order");
 if(qError)throw qError;
 if(!qRows?.length){$("quizQuestion").textContent="این آزمون هنوز سؤال ندارد."; $("quizOptions").innerHTML="";$("nextQuestion").disabled=true;return;}
 const ids=qRows.map(q=>q.id);
 const {data:oRows,error:oError}=await quizDb.from("academy_quiz_options").select("id,question_id,option_text,sort_order").in("question_id",ids).order("sort_order");
 if(oError)throw oError;
 quiz=quizRow;
 questions=qRows.map(q=>({...q,options:(oRows||[]).filter(o=>o.question_id===q.id)}));
 if(questions.some(q=>q.options.length<2))throw Error("یکی از سؤال‌های آزمون گزینه‌های کافی ندارد.");
 qi=0;answers={};quizSubmitted=false;renderQuiz();
}
function renderQuiz(){
 if(!questions.length)return;
 const q=questions[qi];
 $("quizCount").textContent="سؤال "+(qi+1)+" از "+questions.length;
 $("quizQuestion").textContent=q.question_text;
 $("quizOptions").innerHTML=q.options.map(o=>'<button type="button" class="quiz-option'+(answers[q.id]===o.id?" selected":"")+'" data-option-id="'+o.id+'">'+quizEscape(o.option_text)+'</button>').join("");
 $("quizFeedback").textContent="";
 $("nextQuestion").disabled=!answers[q.id]||quizBusy;
 $("nextQuestion").textContent=qi===questions.length-1?"ثبت پاسخ‌ها و دیدن نتیجه":"سؤال بعدی";
 document.querySelectorAll("[data-option-id]").forEach(b=>b.addEventListener("click",()=>{
  if(quizBusy||quizSubmitted)return;
  answers[q.id]=b.dataset.optionId;
  document.querySelectorAll("[data-option-id]").forEach(x=>x.classList.toggle("selected",x===b));
  $("nextQuestion").disabled=false;
 }));
}
async function submitQuiz(){
 if(quizBusy||quizSubmitted)return;
 quizBusy=true;$("nextQuestion").disabled=true;$("nextQuestion").textContent="در حال ثبت نتیجه...";
 try{
  const {data:{session},error:sessionError}=await quizDb.auth.getSession();
  if(sessionError)throw sessionError;
  if(!session){$("quizFeedback").textContent="برای ثبت نمره باید وارد حساب دانش‌آموزی شوی؛ پاسخ‌ها تا اینجا در همین صفحه باقی می‌مانند.";quizBusy=false;$("nextQuestion").textContent="برای ثبت نمره از دکمه ورود بالای صفحه استفاده کن";$("nextQuestion").disabled=true;return;}
  const payload=questions.map(q=>({question_id:q.id,option_id:answers[q.id]}));
  const {data,error}=await quizDb.rpc("academy_submit_quiz",{p_quiz_id:quiz.id,p_answers:payload});
  if(error)throw error;
  quizSubmitted=true;
  $("quizCount").textContent="آزمون تکمیل شد";
  $("quizQuestion").textContent="نتیجهٔ آزمون: "+data.percent+"٪";
  $("quizOptions").innerHTML="";
  $("quizFeedback").textContent=(data.passed?"قبول شدی. ":"نیاز به تمرین بیشتر داری. ")+"نمرهٔ "+data.score+" از "+data.max_score+" در پنل دانش‌آموز ذخیره شد.";
  window.dispatchEvent(new CustomEvent("nexora:quiz-finished",{detail:data}));
  $("nextQuestion").textContent="شروع دوباره آزمون";
  $("nextQuestion").disabled=false;
 }catch(error){
  $("quizFeedback").textContent=error.message==="ACCOUNT_BLOCKED"?"حساب تو مسدود است و امکان شرکت در آزمون نداری.":"ثبت آزمون انجام نشد: "+error.message;
  $("nextQuestion").textContent="تلاش دوباره";
  $("nextQuestion").disabled=false;
 }finally{quizBusy=false;}
}
$("nextQuestion").addEventListener("click",async()=>{
 if(quizSubmitted){qi=0;answers={};quizSubmitted=false;renderQuiz();return;}
 if(!questions.length)return;
 if(!answers[questions[qi].id])return;
 if(qi<questions.length-1){qi++;renderQuiz();return;}
 await submitQuiz();
});
async function loadPublishedCurriculum(){
 try{
  if(!window.supabase?.createClient)return;
  const db=window.supabase.createClient(
   "https://nutgcqhcgytjglyuvmla.supabase.co",
   "sb_publishable_2HmqcVNPPPhULFeNPIbRlg_54LwTQEt",
   {auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false,storageKey:"nexora-academy-public-catalog"}}
  );
  const [courseResult,lessonResult]=await Promise.all([
   db.from("academy_courses")
    .select("id,language_id,level_id,title,description,sort_order,status")
    .eq("status","published")
    .order("sort_order")
    .order("language_id"),
   db.from("academy_lessons")
    .select("id,course_id,title,summary,content_html,starter_code,exercise,sort_order,status")
    .eq("status","published")
    .order("sort_order")
  ]);
  if(courseResult.error)throw courseResult.error;
  if(lessonResult.error)throw lessonResult.error;
  if(!courseResult.data?.length)return;
  const levelNames={beginner:"مقدماتی",intermediate:"متوسط",advanced:"پیشرفته"};
  const next={};
  for(const c of courseResult.data){
   const list=(lessonResult.data||[])
    .filter(l=>l.course_id===c.id)
    .map(l=>({id:l.id,title:l.title,body:l.content_html||("<p>"+(l.summary||"")+"</p>"),code:l.starter_code||"",exercise:l.exercise||""}));
   if(list.length)next[c.id]={
    name:c.title,
    level:levelNames[c.level_id]||c.level_id,
    desc:c.description||"",
    lessons:list
   };
  }
  if(Object.keys(next).length){
   courses=next;
   keys=Object.keys(courses);
   activeCourse=keys.includes(activeCourse)?activeCourse:keys[0];
   activeLesson=0;
  }
 }catch(error){
  console.error("Curriculum database load failed:",error);
 }
}
$("year").textContent=new Date().getFullYear();
(async()=>{await loadPublishedCurriculum();renderCourses();renderCourseSelect();updateProgress();renderLesson();selectTab("html");renderPreview();await loadQuiz().catch(error=>{$("quizFeedback").textContent="بارگذاری آزمون ناموفق بود: "+error.message;console.error("Quiz load failed:",error);});})();
