(() => {
"use strict";
const URL="https://vfatmvmgtgpmnxqbgszm.supabase.co",KEY="sb_publishable_PiggBtDvCsSOwiT62J21Ag_fJA7M_v_";
const db=window.supabase.createClient(URL,KEY,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
const $=id=>document.getElementById(id),esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const say=(s,ok=false)=>{$("adminStatus").textContent=s;$("adminStatus").classList.toggle("success",ok)};
let courses=[],lessons=[],ads=[],allowed=false;
const urlSafe=s=>{if(!s)return null;const u=new URL(s);if(!["http:","https:"].includes(u.protocol))throw Error("فقط نشانی http یا https مجاز است.");return u.href;};
function showLogin(message="برای ورود به مرکز مدیریت، ایمیل و رمز عبور مدیر را وارد کن.") {
  $("adminLogout").hidden=true;
  $("adminLoginBox").hidden=false;
  $("adminWorkspace").hidden=true;
  $("adminIdentity").textContent="ورود مستقل مدیر";
  say(message);
}
async function verifyAdmin(session) {
  $("adminIdentity").textContent="حساب: "+(session.user.email||"مدیر");
  const {data,error}=await db.from("academy_admins").select("user_id").eq("user_id",session.user.id).maybeSingle();
  if(error) throw error;
  if(!data) {
    await db.auth.signOut();
    showLogin("این ایمیل حساب مدیر نیست یا هنوز نقش مدیریت برای آن ثبت نشده است.");
    return false;
  }
  allowed=true;
  $("adminLoginBox").hidden=true;
  $("adminWorkspace").hidden=false;
  $("adminLogout").hidden=false;
  say("دسترسی مدیر تأیید شد.",true);
  await Promise.all([loadCourses(),loadLessons(),loadAds()]);
  return true;
}
async function guard() {
  const {data:{session},error}=await db.auth.getSession();
  if(error) throw error;
  if(!session) { showLogin(); return; }
  await verifyAdmin(session);
}
$("adminLoginForm").onsubmit=async e=>{
  e.preventDefault();
  const button=$("adminLoginButton");
  button.disabled=true;
  say("در حال بررسی اطلاعات ورود...");
  try {
    const email=$("adminEmail").value.trim();
    const password=$("adminPassword").value;
    const {data,error}=await db.auth.signInWithPassword({email,password});
    if(error) throw error;
    if(!data.session) throw new Error("ورود انجام نشد؛ وضعیت حساب را بررسی کن.");
    const ok=await verifyAdmin(data.session);
    if(!ok) return;
  } catch(error) {
    say(error.message==="Invalid login credentials"?"ایمیل یا رمز عبور اشتباه است.":error.message);
  } finally { button.disabled=false; }
};
$("adminForgotPassword").onclick=async()=>{
  const email=$("adminEmail").value.trim();
  if(!email){say("ابتدا ایمیل حساب مدیر را وارد کن.");$("adminEmail").focus();return;}
  try {
    const {error}=await db.auth.resetPasswordForEmail(email,{redirectTo:location.origin+location.pathname});
    if(error) throw error;
    say("اگر این ایمیل در سامانه ثبت شده باشد، لینک بازیابی برایش ارسال می‌شود.",true);
  } catch(error) { say(error.message); }
};
async function loadCourses(){const {data,error}=await db.from("academy_courses").select("*").order("sort_order");if(error)throw error;courses=data||[];$("courseList").innerHTML=courses.map(c=>'<article class="student-box cms-row"><strong>'+esc(c.title)+'</strong><p>'+esc(c.description)+'</p><small>'+esc(c.id)+' · '+(c.is_published?"منتشر":"پیش‌نویس")+'</small><div class="actions"><button class="btn small" data-course-edit="'+esc(c.id)+'">ویرایش</button><button class="btn danger small" data-course-del="'+esc(c.id)+'">حذف</button></div></article>').join("")||"دوره‌ای وجود ندارد."; $("lessonCourse").innerHTML=courses.map(c=>'<option value="'+esc(c.id)+'">'+esc(c.title)+'</option>').join("");document.querySelectorAll("[data-course-edit]").forEach(b=>b.onclick=()=>editCourse(courses.find(c=>c.id===b.dataset.courseEdit)));document.querySelectorAll("[data-course-del]").forEach(b=>b.onclick=()=>deleteCourse(b.dataset.courseDel));}
async function loadLessons(){const {data,error}=await db.from("academy_lessons").select("*").order("course_id").order("sort_order");if(error)throw error;lessons=data||[];$("lessonListAdmin").innerHTML=lessons.map(l=>'<article class="student-box cms-row"><strong>'+esc(l.title)+'</strong><p>'+esc(l.course_id)+' · '+esc(l.id)+' · '+(l.is_published?"منتشر":"پیش‌نویس")+'</p><div class="actions"><button class="btn small" data-lesson-edit="'+esc(l.id)+'">ویرایش</button><button class="btn danger small" data-lesson-del="'+esc(l.id)+'">حذف</button></div></article>').join("")||"درسی وجود ندارد.";document.querySelectorAll("[data-lesson-edit]").forEach(b=>b.onclick=()=>editLesson(lessons.find(l=>l.id===b.dataset.lessonEdit)));document.querySelectorAll("[data-lesson-del]").forEach(b=>b.onclick=()=>deleteLesson(b.dataset.lessonDel));}
function resetCourse(){$("courseForm").reset();$("courseOldId").value="";$("coursePublished").checked=true;}
function editCourse(c){$("courseOldId").value=c.id;$("courseId").value=c.id;$("courseId").disabled=true;$("courseTitle").value=c.title;$("courseDescription").value=c.description;$("courseLevel").value=c.level;$("courseOrder").value=c.sort_order;$("coursePublished").checked=c.is_published;}
async function deleteCourse(id){if(!confirm("با حذف دوره، درس‌های آن نیز حذف می‌شوند. ادامه می‌دهی؟"))return;const {error}=await db.from("academy_courses").delete().eq("id",id);if(error)throw error;await loadCourses();await loadLessons();say("دوره حذف شد.",true);}
$("courseForm").onsubmit=async e=>{e.preventDefault();try{const id=$("courseOldId").value||$("courseId").value.trim();const p={id,title:$("courseTitle").value.trim(),description:$("courseDescription").value.trim(),level:$("courseLevel").value.trim(),sort_order:Number($("courseOrder").value)||0,is_published:$("coursePublished").checked,is_cms_managed:true,updated_at:new Date().toISOString()};const {error}=await db.from("academy_courses").upsert(p);if(error)throw error;resetCourse();$("courseId").disabled=false;await loadCourses();say("دوره ذخیره شد.",true);}catch(e){say(e.message);}};
$("courseReset").onclick=()=>{$("courseId").disabled=false;resetCourse();};
function resetLesson(){$("lessonForm").reset();$("lessonOldId").value="";$("lessonPublished").checked=true;$("lessonOrder").value=0;}
function editLesson(l){$("lessonOldId").value=l.id;$("lessonId").value=l.id;$("lessonId").disabled=true;$("lessonCourse").value=l.course_id;$("lessonTitle").value=l.title;$("lessonBody").value=l.content_html;$("lessonCode").value=l.starter_code;$("lessonExercise").value=l.exercise;$("lessonOrder").value=l.sort_order;$("lessonPublished").checked=l.is_published;}
async function deleteLesson(id){if(!confirm("این درس حذف شود؟"))return;const {error}=await db.from("academy_lessons").delete().eq("id",id);if(error)throw error;await loadLessons();say("درس حذف شد.",true);}
$("lessonForm").onsubmit=async e=>{e.preventDefault();try{const p={id:$("lessonOldId").value||$("lessonId").value.trim(),course_id:$("lessonCourse").value,title:$("lessonTitle").value.trim(),content_html:$("lessonBody").value,starter_code:$("lessonCode").value,exercise:$("lessonExercise").value,sort_order:Number($("lessonOrder").value)||0,is_published:$("lessonPublished").checked,is_cms_managed:true,updated_at:new Date().toISOString()};const {error}=await db.from("academy_lessons").upsert(p);if(error)throw error;resetLesson();$("lessonId").disabled=false;await loadLessons();say("درس ذخیره شد.",true);}catch(e){say(e.message);}};
$("lessonReset").onclick=()=>{$("lessonId").disabled=false;resetLesson();};
async function loadStudents(){const {data,error}=await db.rpc("academy_admin_student_overview");if(error)throw error;$("studentListAdmin").innerHTML=data?.length?data.map(s=>'<article class="student-box cms-row"><strong>'+esc(s.email||"بدون ایمیل")+'</strong><p>ثبت‌نام: '+new Date(s.created_at).toLocaleDateString("fa-IR")+' · درس تکمیل‌شده: '+s.completed_lessons+' · آزمون: '+s.quiz_attempts+'</p></article>').join(""):"هنوز دانش‌آموزی ثبت‌نام نکرده است.";}
$("refreshStudents").onclick=()=>loadStudents().catch(e=>say(e.message));
async function loadAds(){const {data,error}=await db.from("academy_ads").select("*").order("created_at",{ascending:false});if(error)throw error;ads=data||[];$("adList").innerHTML=ads.map(a=>'<article class="student-box cms-row"><strong>'+esc(a.title)+'</strong><p>'+esc(a.body)+'</p><small>'+esc(a.placement)+' · '+(a.is_active?"فعال":"غیرفعال")+'</small><div class="actions"><button class="btn small" data-ad-edit="'+a.id+'">ویرایش</button><button class="btn danger small" data-ad-del="'+a.id+'">حذف</button></div></article>').join("")||"تبلیغی وجود ندارد.";document.querySelectorAll("[data-ad-edit]").forEach(b=>b.onclick=()=>{const a=ads.find(x=>x.id===b.dataset.adEdit);$("adId").value=a.id;$("adTitle").value=a.title;$("adBody").value=a.body;$("adImage").value=a.image_url||"";$("adTarget").value=a.target_url||"";$("adPlacement").value=a.placement;$("adActive").checked=a.is_active;});document.querySelectorAll("[data-ad-del]").forEach(b=>b.onclick=async()=>{if(!confirm("حذف شود؟"))return;const {error}=await db.from("academy_ads").delete().eq("id",b.dataset.adDel);if(error)throw error;await loadAds();});}
$("adForm").onsubmit=async e=>{e.preventDefault();try{const payload={title:$("adTitle").value.trim(),body:$("adBody").value.trim(),image_url:urlSafe($("adImage").value.trim()),target_url:urlSafe($("adTarget").value.trim()),placement:$("adPlacement").value,is_active:$("adActive").checked,updated_at:new Date().toISOString()};const id=$("adId").value;const {error}=id?await db.from("academy_ads").update(payload).eq("id",id):await db.from("academy_ads").insert(payload);if(error)throw error;$("adForm").reset();$("adId").value="";await loadAds();say("تبلیغ ذخیره شد.",true);}catch(e){say(e.message);}};
$("clearAd").onclick=()=>$("adForm").reset();
document.querySelectorAll("[data-admin-tab]").forEach(b=>b.onclick=()=>{document.querySelectorAll("[data-admin-tab]").forEach(x=>x.classList.toggle("primary",x===b));document.querySelectorAll(".cms-panel").forEach(x=>x.hidden=x.id!==b.dataset.adminTab+"Panel");});
$("adminLogout").onclick=async()=>{const {error}=await db.auth.signOut();if(error){say(error.message);return;}allowed=false;location.reload();};
guard().catch(e=>say("خطا: "+e.message));
})();