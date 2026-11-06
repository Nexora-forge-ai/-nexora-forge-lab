const courses = {
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
const $=id=>document.getElementById(id);
const keys=Object.keys(courses);
let activeCourse="html", activeLesson=0, activeTab="html";
const done=new Set(JSON.parse(localStorage.getItem("nexoraAcademyDone")||"[]"));
const samples={
 html:'<h1>سلام NEXORA!</h1>\n<p>من دارم HTML یاد می‌گیرم.</p>\n<button onclick="document.querySelector(\'p\').textContent=\'آفرین!\'">کلیک کن</button>',
 css:'<h1 class="title">سلام NEXORA!</h1>\n<p>این یک تمرین CSS است.</p>\n<button>دکمه نمونه</button>',
 js:'<h1 id="title">سلام!</h1>\n<button id="change">تغییر متن</button>\n<script>\ndocument.querySelector("#change").addEventListener("click",()=>{\n document.querySelector("#title").textContent="تو موفق شدی!";\n});\n<\\/script>'
};
const styles={
 html:"body{font-family:Arial,sans-serif;padding:20px;color:#222}h1{color:#c21d32}",
 css:"body{font-family:Arial,sans-serif;padding:20px;color:#222}.title{color:#c21d32;background:#fff0f1;padding:12px;border-radius:10px}button{padding:9px 14px;border:0;border-radius:8px;background:#c21d32;color:white}",
 js:"body{font-family:Arial,sans-serif;padding:20px;color:#222}button{padding:9px 14px;background:#c21d32;color:white;border:0;border-radius:8px}"
};
function saveDone(){localStorage.setItem("nexoraAcademyDone",JSON.stringify([...done]));updateProgress();}
function updateProgress(){const total=keys.reduce((n,k)=>n+courses[k].lessons.length,0);$("progressLabel").textContent=done.size+" از "+total+" درس";$("progressBar").style.width=(done.size/total*100)+"%";}
function renderCourses(){$("courseGrid").innerHTML=keys.map(k=>{const c=courses[k];return '<button class="course" data-open-course="'+k+'"><span class="course-icon">'+k.toUpperCase()+'</span><h3>'+c.name+'</h3><p>'+c.desc+'</p><span class="course-foot"><span>'+c.level+'</span><span>'+c.lessons.length+' درس ←</span></span></button>';}).join("");document.querySelectorAll("[data-open-course]").forEach(b=>b.addEventListener("click",()=>openCourse(b.dataset.openCourse)));}
function renderCourseSelect(){$("courseSelect").innerHTML=keys.map(k=>'<option value="'+k+'">'+courses[k].name+'</option>').join("");}
function renderLessonList(){$("lessonList").innerHTML=courses[activeCourse].lessons.map((l,i)=>{const id=activeCourse+":"+i;return '<button class="lesson-item '+(i===activeLesson?"active ":"")+(done.has(id)?"done":"")+'" data-index="'+i+'">'+(i+1)+". "+l.title+'<small>'+(done.has(id)?"تکمیل‌شده":"برای مطالعه انتخاب کن")+'</small></button>';}).join("");document.querySelectorAll("[data-index]").forEach(b=>b.addEventListener("click",()=>{activeLesson=Number(b.dataset.index);renderLesson();}));}
function renderLesson(){const c=courses[activeCourse],l=c.lessons[activeLesson];$("lessonCourse").textContent=c.name;$("lessonNumber").textContent="درس "+(activeLesson+1)+" از "+c.lessons.length;$("lessonTitle").textContent=l.title;$("lessonBody").innerHTML=l.body;$("lessonCode").textContent=l.code;$("prevLesson").disabled=activeLesson===0;$("nextLesson").disabled=activeLesson===c.lessons.length-1;$("completeLesson").textContent=done.has(activeCourse+":"+activeLesson)?"✓ این درس تکمیل شده":"علامت‌گذاری به‌عنوان تکمیل‌شده";$("lessonStatus").textContent="";renderLessonList();}
function openCourse(k){activeCourse=k;activeLesson=0;$("courseSelect").value=k;renderLesson();$("classroom").scrollIntoView({behavior:"smooth"});}
function renderPreview(){const html=activeTab==="html"?$("codeEditor").value:(activeTab==="css"?"<h1 class='title'>سلام NEXORA!</h1><p>این یک تمرین CSS است.</p><button>دکمه نمونه</button>":$("codeEditor").value);const css=activeTab==="css"?$("codeEditor").value:styles[activeTab];const js=activeTab==="js"?$("codeEditor").value:"";const safeJs=js.replace(/<\/script/gi,"<\\/script");const safeDoc='<!doctype html><html><head><meta charset="utf-8"><style>'+css+'</style></head><body>'+(activeTab==="css"?"<h1 class='title'>سلام NEXORA!</h1><p>این یک تمرین CSS است.</p><button>دکمه نمونه</button>":html)+'<scr'+'ipt>'+safeJs+'</scr'+'ipt></body></html>';$("preview").srcdoc=safeDoc;}
function selectTab(tab){activeTab=tab;document.querySelectorAll("[data-tab]").forEach(b=>b.classList.toggle("active",b.dataset.tab===tab));$("codeEditor").value=samples[tab];}
$("courseSelect").addEventListener("change",e=>openCourse(e.target.value));
$("prevLesson").addEventListener("click",()=>{if(activeLesson>0){activeLesson--;renderLesson();}});
$("nextLesson").addEventListener("click",()=>{if(activeLesson<courses[activeCourse].lessons.length-1){activeLesson++;renderLesson();}});
$("completeLesson").addEventListener("click",()=>{done.add(activeCourse+":"+activeLesson);saveDone();renderLesson();$("lessonStatus").textContent="پیشرفتت ذخیره شد." ;});
$("copyExample").addEventListener("click",async()=>{try{await navigator.clipboard.writeText(courses[activeCourse].lessons[activeLesson].code);$("lessonStatus").textContent="کد کپی شد.";}catch(e){$("lessonStatus").textContent="کپی خودکار در این مرورگر در دسترس نیست؛ کد را دستی انتخاب کن.";}});
document.querySelectorAll("[data-tab]").forEach(b=>b.addEventListener("click",()=>selectTab(b.dataset.tab)));
$("runCode").addEventListener("click",renderPreview);
$("resetCode").addEventListener("click",()=>{selectTab(activeTab);renderPreview();});
$("menuBtn").addEventListener("click",()=>$("navLinks").classList.toggle("open"));
document.querySelectorAll("#navLinks a").forEach(a=>a.addEventListener("click",()=>$("navLinks").classList.remove("open")));
const questions=[
 {q:"کدام تگ برای عنوان اصلی صفحه استفاده می‌شود؟",a:["<p>","<h1>","<img>"],correct:1,why:"h1 عنوان اصلی و مهم صفحه را مشخص می‌کند."},
 {q:"کدام ویژگی در CSS رنگ متن را تعیین می‌کند؟",a:["font-size","background","color"],correct:2,why:"ویژگی color رنگ متن را تعیین می‌کند."},
 {q:"برای تعریف متغیری که دوباره مقداردهی نمی‌شود از کدام کلمه استفاده می‌کنیم؟",a:["const","repeat","style"],correct:0,why:"const برای متغیری است که دوباره به آن مقدار نسبت داده نمی‌شود."}
];
let qi=0,score=0,answered=false;
function renderQuiz(){const q=questions[qi];$("quizCount").textContent="سؤال "+(qi+1)+" از "+questions.length;$("quizQuestion").textContent=q.q;$("quizOptions").innerHTML=q.a.map((a,i)=>'<button class="quiz-option" data-answer="'+i+'">'+a.replace(/</g,"&lt;").replace(/>/g,"&gt;")+'</button>').join("");$("quizFeedback").textContent="";$("nextQuestion").disabled=true;$("nextQuestion").textContent=qi===questions.length-1?"دیدن نتیجه":"سؤال بعدی";answered=false;document.querySelectorAll("[data-answer]").forEach(b=>b.addEventListener("click",()=>{if(answered)return;answered=true;const n=Number(b.dataset.answer),correct=n===q.correct;if(correct)score++;b.classList.add(correct?"correct":"wrong");document.querySelectorAll("[data-answer]")[q.correct].classList.add("correct");$("quizFeedback").textContent=(correct?"درست است. ":"پاسخ درست: ")+q.why;$("quizScore").textContent="امتیاز: "+score;$("nextQuestion").disabled=false;}));}
$("nextQuestion").addEventListener("click",()=>{if(qi<questions.length-1){qi++;renderQuiz();}else{$("quizQuestion").textContent="آزمون تمام شد؛ امتیاز تو "+score+" از "+questions.length+" است.";$("quizOptions").innerHTML="";$("quizFeedback").textContent="برای تمرین دوباره صفحه را تازه‌سازی کن.";$("nextQuestion").disabled=true;}});
$("year").textContent=new Date().getFullYear();
renderCourses();renderCourseSelect();updateProgress();renderLesson();selectTab("html");renderPreview();renderQuiz();
