(() => {
"use strict";
const URL="https://nutgcqhcgytjglyuvmla.supabase.co",KEY="sb_publishable_2HmqcVNPPPhULFeNPIbRlg_54LwTQEt";
const db=window.supabase.createClient(URL,KEY,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
const $=id=>document.getElementById(id),esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const say=(s,ok=false)=>{$("adminStatus").textContent=s;$("adminStatus").classList.toggle("success",ok)};
let courses=[],lessons=[],ads=[],students=[];
const safeUrl=s=>{if(!s)return null;const u=new URL(s);if(!["http:","https:"].includes(u.protocol))throw Error("فقط نشانی http یا https مجاز است.");return u.href;};
function showLogin(message="برای ورود به مرکز مدیریت، ایمیل و رمز عبور مدیر را وارد کن."){$("adminLogout").hidden=true;$("adminLoginBox").hidden=false;$("adminWorkspace").hidden=true;$("adminIdentity").textContent="ورود مستقل مدیر";say(message);}
async function verifyAdmin(session){
 $("adminIdentity").textContent="حساب: "+(session.user.email||"مدیر");
 const {data,error}=await db.from("academy_user_roles").select("role").eq("user_id",session.user.id).in("role",["admin","super_admin"]);
 if(error)throw error;
 if(!data?.length){await db.auth.signOut();showLogin("این حساب نقش مدیر ندارد. نقش مدیریت باید از مسیر امن super-admin ثبت شود.");return false;}
 $("adminLoginBox").hidden=true;$("adminWorkspace").hidden=false;$("adminLogout").hidden=false;say("دسترسی مدیر تأیید شد.",true);
 await Promise.all([loadCourses(),loadLessons(),loadAds()]);return true;
}
async function guard(){const {data:{session},error}=await db.auth.getSession();if(error)throw error;if(!session){showLogin();return;}await verifyAdmin(session);}
$("adminLoginForm").onsubmit=async e=>{e.preventDefault();const b=$("adminLoginButton");b.disabled=true;say("در حال بررسی...");try{const {data,error}=await db.auth.signInWithPassword({email:$("adminEmail").value.trim(),password:$("adminPassword").value});if(error)throw error;if(!data.session)throw Error("نشست ورود ساخته نشد.");await verifyAdmin(data.session);}catch(err){say(err.message==="Invalid login credentials"?"ایمیل یا رمز اشتباه است.":err.message);}finally{b.disabled=false;}};
$("adminForgotPassword").onclick=async()=>{const email=$("adminEmail").value.trim();if(!email){say("ابتدا ایمیل مدیر را وارد کن.");return;}try{const {error}=await db.auth.resetPasswordForEmail(email,{redirectTo:location.origin+location.pathname});if(error)throw error;say("اگر حسابی با این ایمیل وجود داشته باشد، لینک بازیابی ارسال می‌شود.",true);}catch(e){say(e.message);}};
function languageFor(id){if(id.startsWith("html"))return"html";if(id.startsWith("css"))return"css";if(id.startsWith("javascript")||id.startsWith("js"))return"javascript";throw Error("شناسه دوره باید با html، css یا javascript شروع شود.");}
function levelFor(value){const v=String(value||"").toLowerCase();if(v.includes("متوسط")||v.includes("intermediate"))return"intermediate";if(v.includes("پیشرفته")||v.includes("advanced"))return"advanced";return"beginner";}
async function loadCourses(){
 const {data,error}=await db.from("academy_courses").select("*").order("sort_order");if(error)throw error;courses=data||[];
 $("courseList").innerHTML=courses.map(c=>'<article class="student-box cms-row"><strong>'+esc(c.title)+'</strong><p>'+esc(c.description)+'</p><small>'+esc(c.id)+' · '+(c.status==="published"?"منتشر":"پیش‌نویس")+'</small><div class="actions"><button class="btn small" data-course-edit="'+esc(c.id)+'">ویرایش</button><button class="btn danger small" data-course-del="'+esc(c.id)+'">حذف</button></div></article>').join("")||"دوره‌ای وجود ندارد.";
 $("lessonCourse").innerHTML=courses.map(c=>'<option value="'+esc(c.id)+'">'+esc(c.title)+'</option>').join("");
 document.querySelectorAll("[data-course-edit]").forEach(b=>b.onclick=()=>editCourse(courses.find(c=>c.id===b.dataset.courseEdit)));
 document.querySelectorAll("[data-course-del]").forEach(b=>b.onclick=()=>deleteCourse(b.dataset.courseDel));
}
async function loadLessons(){
 const {data,error}=await db.from("academy_lessons").select("*").order("course_id").order("sort_order");if(error)throw error;lessons=data||[];
 $("lessonListAdmin").innerHTML=lessons.map(l=>'<article class="student-box cms-row"><strong>'+esc(l.title)+'</strong><p>'+esc(l.course_id)+' · '+esc(l.id)+' · '+(l.status==="published"?"منتشر":"پیش‌نویس")+'</p><div class="actions"><button class="btn small" data-lesson-edit="'+esc(l.id)+'">ویرایش</button><button class="btn danger small" data-lesson-del="'+esc(l.id)+'">حذف</button></div></article>').join("")||"درسی وجود ندارد.";
 document.querySelectorAll("[data-lesson-edit]").forEach(b=>b.onclick=()=>editLesson(lessons.find(l=>l.id===b.dataset.lessonEdit)));
 document.querySelectorAll("[data-lesson-del]").forEach(b=>b.onclick=()=>deleteLesson(b.dataset.lessonDel));
}
function resetCourse(){$("courseForm").reset();$("courseOldId").value="";$("coursePublished").checked=true;$("courseId").disabled=false;}
function editCourse(c){$("courseOldId").value=c.id;$("courseId").value=c.id;$("courseId").disabled=true;$("courseTitle").value=c.title;$("courseDescription").value=c.description;$("courseLevel").value=c.level_id==="advanced"?"پیشرفته":c.level_id==="intermediate"?"متوسط":"مقدماتی";$("courseOrder").value=c.sort_order;$("coursePublished").checked=c.status==="published";}
async function deleteCourse(id){if(!confirm("حذف دوره ممکن است به‌دلیل وجود درس‌ها رد شود. بهتر است ابتدا آن را آرشیو کنی. ادامه می‌دهی؟"))return;const {error}=await db.from("academy_courses").update({status:"archived",archived_at:new Date().toISOString()}).eq("id",id);if(error)throw error;await loadCourses();say("دوره آرشیو شد؛ سابقه درس‌ها حذف نشد.",true);}
$("courseForm").onsubmit=async e=>{e.preventDefault();try{const id=$("courseOldId").value||$("courseId").value.trim(),language_id=languageFor(id),level_id=levelFor($("courseLevel").value);const payload={id,language_id,level_id,title:$("courseTitle").value.trim(),slug:id+"-course",description:$("courseDescription").value.trim(),status:$("coursePublished").checked?"published":"draft",sort_order:Number($("courseOrder").value)||0};const {error}=await db.from("academy_courses").upsert(payload,{onConflict:"id"});if(error)throw error;resetCourse();await loadCourses();say("دوره ذخیره شد.",true);}catch(e){say(e.message);}};
$("courseReset").onclick=resetCourse;
function resetLesson(){$("lessonForm").reset();$("lessonOldId").value="";$("lessonPublished").checked=true;$("lessonOrder").value=0;$("lessonId").disabled=false;}
function editLesson(l){$("lessonOldId").value=l.id;$("lessonId").value=l.id;$("lessonId").disabled=true;$("lessonCourse").value=l.course_id;$("lessonTitle").value=l.title;$("lessonBody").value=l.content_html;$("lessonCode").value=l.starter_code;$("lessonExercise").value=l.exercise;$("lessonOrder").value=l.sort_order;$("lessonPublished").checked=l.status==="published";}
async function deleteLesson(id){if(!confirm("این درس آرشیو شود؟ سابقه دانش‌آموزان حفظ می‌شود."))return;const {error}=await db.from("academy_lessons").update({status:"archived",archived_at:new Date().toISOString()}).eq("id",id);if(error)throw error;await loadLessons();say("درس آرشیو شد.",true);}
$("lessonForm").onsubmit=async e=>{e.preventDefault();try{const id=$("lessonOldId").value||$("lessonId").value.trim(),payload={id,course_id:$("lessonCourse").value,title:$("lessonTitle").value.trim(),slug:id,summary:$("lessonTitle").value.trim(),content_html:$("lessonBody").value,starter_code:$("lessonCode").value,exercise:$("lessonExercise").value,sort_order:Number($("lessonOrder").value)||0,status:$("lessonPublished").checked?"published":"draft"};const {error}=await db.from("academy_lessons").upsert(payload,{onConflict:"id"});if(error)throw error;resetLesson();await loadLessons();say("درس ذخیره شد.",true);}catch(e){say(e.message);}};
$("lessonReset").onclick=resetLesson;
function renderStudents(){
 const q=$("studentSearch").value.trim().toLowerCase();
 const filtered=students.filter(x=>[x.display_name,x.user_id,x.student_code].some(v=>String(v||"").toLowerCase().includes(q)));
 $("studentListAdmin").innerHTML=filtered.length?filtered.map(x=>'<article class="student-box cms-row"><strong>'+esc(x.display_name||"دانش‌آموز")+'</strong><p>ثبت‌نام: '+new Date(x.created_at).toLocaleDateString("fa-IR")+' · درس تکمیل‌شده: '+x.completed_lessons+' · آزمون: '+x.quiz_attempts+'</p><small>شناسه دانش‌آموزی: <b>'+esc(x.student_code||"ثبت نشده")+'</b></small><br><small>وضعیت: '+(x.account_status==="blocked"?"مسدود":"فعال")+'</small><div class="actions"><button class="btn small" data-admin-reset="'+esc(x.user_id)+'">تعیین رمز موقت</button><button class="btn small '+(x.account_status==="blocked"?"primary":"danger")+'" data-toggle-student="'+esc(x.user_id)+'" data-next-status="'+(x.account_status==="blocked"?"active":"blocked")+'">'+(x.account_status==="blocked"?"فعال‌سازی حساب":"مسدودسازی حساب")+'</button></div></article>').join(""):(students.length?"دانش‌آموزی با این جستجو پیدا نشد.":"هنوز دانش‌آموزی ثبت‌نام نکرده است.");
 document.querySelectorAll("[data-toggle-student]").forEach(b=>b.onclick=async()=>{
  const user_id=b.dataset.toggleStudent,status=b.dataset.nextStatus,action=status==="blocked"?"مسدودسازی":"فعال‌سازی";
  if(!confirm(action+" حساب این دانش‌آموز انجام شود؟"))return;b.disabled=true;
  try{const {data,error}=await db.functions.invoke("academy-student-account",{body:{user_id,status}});if(error)throw error;if(data?.error)throw Error(data.error);say(data?.warning||(status==="blocked"?"حساب دانش‌آموز مسدود شد.":"حساب دانش‌آموز فعال شد."),!data?.warning);await loadStudents();}
  catch(e){say("تغییر وضعیت انجام نشد: "+e.message);}finally{b.disabled=false;}
 });
 document.querySelectorAll("[data-admin-reset]").forEach(b=>b.onclick=async()=>{
  const user_id=b.dataset.adminReset;if(!confirm("برای این دانش‌آموز رمز موقت جدید ساخته شود؟ رمز قبلی بلافاصله بی‌اعتبار می‌شود."))return;b.disabled=true;
  try{const {data,error}=await db.functions.invoke("admin-reset-student-password",{body:{user_id}});if(error)throw error;if(data?.error)throw Error(data.error);window.prompt("این رمز فقط یک بار نمایش داده می‌شود. آن را امن به دانش‌آموز تحویل بده:",data.temporary_password);say("رمز موقت ساخته شد. دانش‌آموز باید پس از ورود آن را تغییر دهد.",true);}
  catch(e){say("تعیین رمز موقت ناموفق بود: "+e.message);}finally{b.disabled=false;}
 });
}
async function loadStudents(){const {data,error}=await db.rpc("academy_admin_student_overview");if(error)throw error;students=data||[];renderStudents();}
$("studentSearch").addEventListener("input",renderStudents);
$("refreshStudents").onclick=()=>loadStudents().catch(e=>say(e.message));
async function loadAds(){const {data,error}=await db.from("academy_ads").select("*").order("created_at",{ascending:false});if(error)throw error;ads=data||[];$("adList").innerHTML=ads.map(a=>'<article class="student-box cms-row"><strong>'+esc(a.title)+'</strong><p>'+esc(a.body)+'</p><small>'+esc(a.placement)+' · '+(a.status==="active"?"فعال":"غیرفعال")+'</small><div class="actions"><button class="btn small" data-ad-edit="'+a.id+'">ویرایش</button><button class="btn danger small" data-ad-del="'+a.id+'">حذف</button></div></article>').join("")||"تبلیغی وجود ندارد.";document.querySelectorAll("[data-ad-edit]").forEach(b=>b.onclick=()=>{const a=ads.find(x=>x.id===b.dataset.adEdit);$("adId").value=a.id;$("adTitle").value=a.title;$("adBody").value=a.body;$("adImage").value=a.image_path||"";$("adTarget").value=a.target_url||"";$("adPlacement").value=a.placement;$("adActive").checked=a.status==="active";});document.querySelectorAll("[data-ad-del]").forEach(b=>b.onclick=async()=>{if(!confirm("حذف پیام انجام شود؟"))return;const {error}=await db.from("academy_ads").delete().eq("id",b.dataset.adDel);if(error)throw error;await loadAds();});}
$("adForm").onsubmit=async e=>{e.preventDefault();try{const payload={title:$("adTitle").value.trim(),body:$("adBody").value.trim(),image_path:safeUrl($("adImage").value.trim()),target_url:safeUrl($("adTarget").value.trim()),placement:$("adPlacement").value,status:$("adActive").checked?"active":"paused"};const id=$("adId").value;const {error}=id?await db.from("academy_ads").update(payload).eq("id",id):await db.from("academy_ads").insert(payload);if(error)throw error;$("adForm").reset();$("adId").value="";await loadAds();say("پیام ذخیره شد.",true);}catch(e){say(e.message);}};
$("clearAd").onclick=()=>$("adForm").reset();
document.querySelectorAll("[data-admin-tab]").forEach(b=>b.onclick=()=>{document.querySelectorAll("[data-admin-tab]").forEach(x=>x.classList.toggle("primary",x===b));document.querySelectorAll(".cms-panel").forEach(x=>x.hidden=x.id!==b.dataset.adminTab+"Panel");});
$("adminLogout").onclick=async()=>{const {error}=await db.auth.signOut();if(error){say(error.message);return;}location.reload();};
guard().catch(e=>say("خطا: "+e.message));
})();