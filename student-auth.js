/* NEXORA FORGE ACADEMY — Supabase Auth + academy schema */
(() => {
"use strict";
const SUPABASE_URL="https://nutgcqhcgytjglyuvmla.supabase.co";
const SUPABASE_KEY="sb_publishable_2HmqcVNPPPhULFeNPIbRlg_54LwTQEt";
const $=id=>document.getElementById(id);
const modal=$("authModal"), panel=$("studentPanel"), message=$("authMessage");
if(!window.supabase?.createClient){$("authOpenBtn")?.addEventListener("click",()=>alert("سرویس ورود بارگذاری نشد. اتصال اینترنت را بررسی کن."));return;}
const db=window.supabase.createClient(SUPABASE_URL,SUPABASE_KEY,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
let currentUser=null,busy=false;
const safeUrl=value=>{try{const u=new URL(value);return ["http:","https:"].includes(u.protocol)?u.href:""}catch{return""}};
const safeText=value=>String(value??"").replace(/[&<>"']/g,ch=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[ch]));
const localDone=()=>{try{const x=JSON.parse(localStorage.getItem("nexoraAcademyDone")||"[]");return Array.isArray(x)?[...new Set(x.filter(v=>typeof v==="string"))]:[]}catch{return[]}};
function setMessage(text,success=false){if(!message)return;message.textContent=text;message.classList.toggle("success",success);}
function openModal(tab="login"){modal.hidden=false;document.body.style.overflow="hidden";showTab(tab);}
function closeModal(){modal.hidden=true;document.body.style.overflow="";}
function makeStudentCode(){
 const alphabet="abcdefghjkmnpqrstuvwxyz23456789",bytes=new Uint8Array(12);
 crypto.getRandomValues(bytes);
 return Array.from(bytes,b=>alphabet[b%alphabet.length]).join("");
}
function showTab(tab){const signup=tab==="signup";if(signup&&!$("signupStudentCode").value)$("signupStudentCode").value=makeStudentCode();$("loginForm").hidden=signup;$("signupForm").hidden=!signup;$("showLogin").classList.toggle("active",!signup);$("showSignup").classList.toggle("active",signup);$("authTitle").textContent=signup?"ساخت حساب دانش‌آموزی":"ورود به حساب دانش‌آموزی";setMessage("");}
function setBusy(value){busy=value;document.querySelectorAll(".auth-form button").forEach(b=>b.disabled=value);}
async function syncProgress(){
 if(!currentUser)return;
 const local=localDone();
 const [{data,error},{data:catalog,error:catalogError}]=await Promise.all([
  db.from("academy_lesson_progress").select("lesson_id").eq("user_id",currentUser.id),
  db.from("academy_lessons").select("id").eq("status","published")
 ]);
 if(error)throw error;if(catalogError)throw catalogError;
 const validIds=new Set((catalog||[]).map(x=>x.id));
 const merged=[...new Set([...(data||[]).map(x=>x.lesson_id).filter(id=>validIds.has(id)),...local.filter(id=>validIds.has(id))])];
 if(merged.length){
  const rows=merged.map(lesson_id=>({user_id:currentUser.id,lesson_id,status:"completed",completed_at:new Date().toISOString()}));
  const {error:saveError}=await db.from("academy_lesson_progress").upsert(rows,{onConflict:"user_id,lesson_id"});
  if(saveError)throw saveError;
 }
 localStorage.setItem("nexoraAcademyDone",JSON.stringify(merged));
 window.dispatchEvent(new CustomEvent("nexora:progress-loaded",{detail:merged}));
}
async function renderDashboard(){
 if(!currentUser||!panel)return;
 const [{data:profile,error:profileError},{data:progress,error:progressError},{data:lessons,error:lessonsError},{data:courses,error:coursesError},{count:quizCount,error:quizError}]=await Promise.all([
  db.from("academy_profiles").select("display_name,avatar_path").eq("user_id",currentUser.id).maybeSingle(),
  db.from("academy_lesson_progress").select("lesson_id").eq("user_id",currentUser.id).eq("status","completed"),
  db.from("academy_lessons").select("id,course_id").eq("status","published"),
  db.from("academy_courses").select("id,title").eq("status","published"),
  db.from("academy_quiz_attempts").select("id",{count:"exact",head:true}).eq("user_id",currentUser.id)
 ]);
 for(const e of [profileError,progressError,lessonsError,coursesError,quizError])if(e)throw e;
 const validLessonIds=new Set((lessons||[]).map(x=>x.id));
 const done=(progress||[]).map(x=>x.lesson_id).filter(id=>validLessonIds.has(id)),total=validLessonIds.size;
 $("studentWelcome").textContent="خوش آمدی، "+(profile?.display_name||currentUser.user_metadata?.display_name||currentUser.email||"دانش‌آموز");
 $("studentDoneCount").textContent=done.length.toLocaleString("fa-IR");
 $("studentPercent").textContent=(total?Math.round(done.length/total*100):0).toLocaleString("fa-IR")+"٪";
 $("studentQuizCount").textContent=(quizCount||0).toLocaleString("fa-IR");
 $("studentCourseProgress").innerHTML=(courses||[]).map(c=>{
  const ids=(lessons||[]).filter(l=>l.course_id===c.id).map(l=>l.id),n=ids.filter(id=>done.includes(id)).length,pct=ids.length?Math.round(n/ids.length*100):0;
  return '<div class="student-course-row"><div class="student-course-title"><strong>'+safeText(c.title)+'</strong><span>'+n.toLocaleString("fa-IR")+' از '+ids.length.toLocaleString("fa-IR")+' درس</span></div><div class="student-course-track"><span style="width:'+pct+'%"></span></div></div>';
 }).join("")||"هنوز دوره منتشرشده‌ای وجود ندارد.";
 $("studentQuizHistory").textContent="آزمون‌های تعاملی فعلی در مرورگر اجرا می‌شوند و هنوز به سامانه ثبت نمره امن متصل نشده‌اند؛ بنابراین نتیجه‌ای در سوابق ابری ثبت نمی‌شود.";
}
async function applySession(session){
 currentUser=session?.user||null;
 if(currentUser){
  $("authOpenBtn").textContent="پنل دانش‌آموزی";
  $("authOpenBtn").onclick=()=>location.href="student.html";
  if(panel)panel.hidden=false;
  try{await syncProgress();await renderDashboard();}catch(e){$("studentDataStatus").textContent="ورود انجام شد، اما همگام‌سازی پیشرفت کامل نشد: "+e.message;}
 }else{
  $("authOpenBtn").textContent="ورود / ثبت‌نام";
  $("authOpenBtn").onclick=()=>openModal("login");
  if(panel)panel.hidden=true;
 }
}
$("authOpenBtn").onclick=()=>openModal("login");
$("showLogin").addEventListener("click",()=>showTab("login"));
$("showSignup").addEventListener("click",()=>showTab("signup"));
document.querySelectorAll("[data-auth-close]").forEach(el=>el.addEventListener("click",closeModal));
document.addEventListener("keydown",e=>{if(e.key==="Escape"&&!modal.hidden)closeModal();});
$("loginForm").addEventListener("submit",async e=>{
 e.preventDefault();if(busy)return;setBusy(true);setMessage("در حال ورود...");
 try{
  const student_code=$("loginEmail").value.trim().toLowerCase();
  if(!/^[a-z0-9]{12}$/.test(student_code))throw Error("شناسه باید دقیقاً ۱۲ حرف یا عدد انگلیسی باشد.");
  const response=await fetch(SUPABASE_URL+"/functions/v1/student-login",{method:"POST",headers:{"Content-Type":"application/json","apikey":SUPABASE_KEY},body:JSON.stringify({student_code,password:$("loginPassword").value})});
  const result=await response.json().catch(()=>({}));
  if(!response.ok)throw Error(result.error||"ورود انجام نشد. شناسه و رمز را بررسی کن.");
  const {data,error}=await db.auth.setSession({access_token:result.access_token,refresh_token:result.refresh_token});
  if(error)throw error;closeModal();await applySession(data.session);location.href="student.html";
 }
 catch(err){setMessage(err.message||"ورود انجام نشد.");}finally{setBusy(false);}
});
$("studentForgotPassword").addEventListener("click",async()=>{
 const student_code=$("loginEmail").value.trim().toLowerCase();
 if(!/^[a-z0-9]{12}$/.test(student_code)){setMessage("ابتدا شناسهٔ ۱۲ کاراکتری حساب را وارد کن.");$("loginEmail").focus();return;}
 setMessage("در حال بررسی و ارسال لینک بازیابی...");
 try{
  const response=await fetch(SUPABASE_URL+"/functions/v1/student-password-reset",{method:"POST",headers:{"Content-Type":"application/json","apikey":SUPABASE_KEY},body:JSON.stringify({student_code})});
  const result=await response.json().catch(()=>({}));
  if(!response.ok)throw Error(result.error||"درخواست بازیابی انجام نشد.");
  setMessage(result.message||"اگر حساب فعال باشد، لینک بازیابی ارسال می‌شود.",true);
 }catch(err){setMessage(err.message||"ارسال لینک بازیابی انجام نشد.");}
});
$("signupForm").addEventListener("submit",async e=>{
 e.preventDefault();if(busy)return;setBusy(true);setMessage("در حال ساخت حساب...");
 try{
  const name=$("signupName").value.trim(),password=$("signupPassword").value;
  if(password!==$("signupPasswordConfirm").value)throw Error("رمز عبور و تکرار آن یکسان نیستند.");
  if(!/^(?=.*[A-Za-z])(?=.*\d).{8,16}$/.test(password))throw Error("رمز باید ۸ تا ۱۶ نویسه و شامل حداقل یک حرف انگلیسی و یک عدد باشد.");
  const student_code=$("signupStudentCode").value.trim().toLowerCase();
  if(!/^[a-z0-9]{12}$/.test(student_code))throw Error("شناسه باید دقیقاً ۱۲ حرف یا عدد انگلیسی باشد.");
  const {data,error}=await db.auth.signUp({email:$("signupEmail").value.trim(),password,options:{data:{display_name:name,student_code},emailRedirectTo:new URL("student.html",location.href).href}});
  if(error)throw error;
  if(data.session){closeModal();await applySession(data.session);location.href="student.html";}
  else setMessage("حساب ساخته شد. ایمیلت را تأیید کن؛ سپس وارد شو.",true);
 }catch(err){setMessage(err.message||"ثبت‌نام انجام نشد.");}finally{setBusy(false);}
});
$("studentLogout").addEventListener("click",async()=>{const {error}=await db.auth.signOut();if(error){alert("خروج انجام نشد: "+error.message);return;}await applySession(null);});
window.addEventListener("nexora:progress-updated",async e=>{
 if(!currentUser||!Array.isArray(e.detail))return;
 try{const rows=e.detail.map(lesson_id=>({user_id:currentUser.id,lesson_id,status:"completed",completed_at:new Date().toISOString()}));if(rows.length){const {error}=await db.from("academy_lesson_progress").upsert(rows,{onConflict:"user_id,lesson_id"});if(error)throw error;}await renderDashboard();}
 catch(err){const status=$("studentDataStatus");if(status)status.textContent="ذخیره پیشرفت ناموفق بود: "+err.message;}
});
db.auth.getSession().then(({data,error})=>{if(error)throw error;return applySession(data.session).then(()=>{if(new URLSearchParams(location.search).get("auth")==="login"&&!data.session)openModal("login");});}).catch(e=>console.error("Auth initialization failed:",e));
const homeAds=$("homeAds");
if(homeAds)db.from("academy_ads").select("title,body,image_path,target_url,placement").eq("status","active").in("placement",["home","both"]).then(({data,error})=>{
 if(error||!data?.length){homeAds.hidden=true;return;}
 homeAds.hidden=false;
 homeAds.innerHTML='<div class="wrap"><div class="section-head"><div><h2>تبلیغات و اطلاعیه‌ها</h2><p class="sub">پیام‌های منتشرشده از مدیریت آکادمی</p></div></div>'+data.map(a=>'<article class="student-box" style="margin:10px 0"><strong>'+safeText(a.title)+'</strong><p>'+safeText(a.body)+'</p>'+(safeUrl(a.image_path)?'<img src="'+safeText(safeUrl(a.image_path))+'" alt="" style="max-width:100%;max-height:180px;border-radius:10px">':"")+(safeUrl(a.target_url)?'<p><a class="btn small" href="'+safeText(safeUrl(a.target_url))+'" target="_blank" rel="noopener noreferrer">مشاهده</a></p>':"")+'</article>').join("")+'</div>';
});
})();