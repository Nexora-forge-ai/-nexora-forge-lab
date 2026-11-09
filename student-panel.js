(() => {
"use strict";
const URL="https://nutgcqhcgytjglyuvmla.supabase.co",KEY="sb_publishable_2HmqcVNPPPhULFeNPIbRlg_54LwTQEt";
const db=window.supabase.createClient(URL,KEY,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
const $=id=>document.getElementById(id);
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const safeUrl=s=>{try{const u=new URL(s);return ["http:","https:"].includes(u.protocol)?u.href:""}catch{return""}};
async function start(){
 const {data:{session},error:sessionError}=await db.auth.getSession();if(sessionError)throw sessionError;
 if(!session){location.replace("index.html?auth=login");return;}
 const user=session.user;
 const [{data:profile,error:pErr},{data:progress,error:prErr},{data:courseRows,error:cErr},{data:lessonRows,error:lErr},{data:attempts,error:qErr},{count,error:qcErr},{data:ads,error:aErr},{data:roles,error:rErr}]=await Promise.all([
  db.from("academy_profiles").select("display_name,avatar_path,student_code").eq("user_id",user.id).maybeSingle(),
  db.from("academy_lesson_progress").select("lesson_id").eq("user_id",user.id).eq("status","completed"),
  db.from("academy_courses").select("id,title").eq("status","published").order("sort_order"),
  db.from("academy_lessons").select("id,course_id").eq("status","published").order("sort_order"),
  db.from("academy_quiz_attempts").select("score,max_score,percent,submitted_at").eq("user_id",user.id).order("submitted_at",{ascending:false}).limit(5),
  db.from("academy_quiz_attempts").select("id",{count:"exact",head:true}).eq("user_id",user.id),
  db.from("academy_ads").select("title,body,image_path,target_url,placement").eq("status","active").in("placement",["student","both","student_top","student_courses","student_bottom"]).order("sort_order"),
  db.from("academy_user_roles").select("role").eq("user_id",user.id)
 ]);
 for(const e of [pErr,prErr,cErr,lErr,qErr,qcErr,aErr,rErr])if(e)throw e;
 const validLessonIds=new Set((lessonRows||[]).map(x=>x.id));
 const done=(progress||[]).map(x=>x.lesson_id).filter(id=>validLessonIds.has(id)),total=validLessonIds.size;
 $("welcome").textContent="خوش آمدی، "+(profile?.display_name||user.user_metadata?.display_name||user.email||"دانش‌آموز");
 $("studentCodeValue").textContent=profile?.student_code||"شناسه ثبت نشده";
 $("copyStudentCode").onclick=async()=>{try{await navigator.clipboard.writeText(profile?.student_code||"");$("avatarStatus").textContent="شناسه کپی شد.";}catch{$("avatarStatus").textContent="کپی خودکار ممکن نیست؛ شناسه را دستی انتخاب کن."}};
 $("newStudentCode").value=profile?.student_code||"";
 $("changeCodeForm").addEventListener("submit",async e=>{e.preventDefault();const status=$("codeChangeStatus");const b=e.submitter;b.disabled=true;status.textContent="در حال تغییر شناسه...";try{const {data:{session}}=await db.auth.getSession();const response=await fetch(URL+"/functions/v1/student-account",{method:"POST",headers:{"Content-Type":"application/json","apikey":KEY,"Authorization":"Bearer "+session.access_token},body:JSON.stringify({action:"change_code",new_student_code:$("newStudentCode").value.trim().toLowerCase(),current_password:$("codeCurrentPassword").value})});const result=await response.json().catch(()=>({}));if(!response.ok)throw Error(result.error||"تغییر شناسه ناموفق بود.");$("studentCodeValue").textContent=result.student_code;$("newStudentCode").value=result.student_code;$("codeCurrentPassword").value="";status.textContent="شناسه با موفقیت تغییر کرد.";}catch(err){status.textContent=err.message;}finally{b.disabled=false;}});
 $("changePasswordForm").addEventListener("submit",async e=>{e.preventDefault();const status=$("passwordChangeStatus");const b=e.submitter;b.disabled=true;status.textContent="در حال تغییر رمز...";try{const {data:{session}}=await db.auth.getSession();const response=await fetch(URL+"/functions/v1/student-account",{method:"POST",headers:{"Content-Type":"application/json","apikey":KEY,"Authorization":"Bearer "+session.access_token},body:JSON.stringify({action:"change_password",current_password:$("currentPassword").value,new_password:$("newPassword").value})});const result=await response.json().catch(()=>({}));if(!response.ok)throw Error(result.error||"تغییر رمز ناموفق بود.");$("currentPassword").value="";$("newPassword").value="";status.textContent=result.message||"رمز تغییر کرد.";}catch(err){status.textContent=err.message;}finally{b.disabled=false;}});
 let currentAvatarPath=profile?.avatar_path||null;
 const avatarPath=currentAvatarPath;
 if(avatarPath){const {data,error}=await db.storage.from("academy-avatars").createSignedUrl(avatarPath,3600);if(error)throw error;$("avatarPreview").src=data.signedUrl;$("avatarPreview").hidden=false;$("avatarInitials").hidden=true;$("removeAvatar").hidden=false;}
 else{$("avatarPreview").hidden=true;$("avatarInitials").hidden=false;$("removeAvatar").hidden=true;}
 const avatarInput=$("avatarInput");
 avatarInput.addEventListener("change",async()=>{
  const file=avatarInput.files?.[0];if(!file)return;
  const status=$("avatarStatus");
  try{
   if(!["image/jpeg","image/png","image/webp"].includes(file.type))throw Error("فقط JPG، PNG یا WebP مجاز است.");
   if(file.size>2*1024*1024)throw Error("حجم تصویر نباید بیشتر از ۲ مگابایت باشد.");
   status.textContent="در حال بارگذاری تصویر...";
   const ext=file.type==="image/png"?"png":file.type==="image/webp"?"webp":"jpg";
   const path=user.id+"/avatar."+ext;
   const {error:uploadError}=await db.storage.from("academy-avatars").upload(path,file,{upsert:true,contentType:file.type});
   if(uploadError)throw uploadError;
   const previousPath=currentAvatarPath;
   const {error:updateError}=await db.from("academy_profiles").update({avatar_path:path}).eq("user_id",user.id);
   if(updateError)throw updateError;
   currentAvatarPath=path;
   if(previousPath&&previousPath!==path)await db.storage.from("academy-avatars").remove([previousPath]);
   const {data:privateData,error:signedError}=await db.storage.from("academy-avatars").createSignedUrl(path,3600);if(signedError)throw signedError;
   $("avatarPreview").src=privateData.signedUrl;$("avatarPreview").hidden=false;$("avatarInitials").hidden=true;$("removeAvatar").hidden=false;
   status.textContent="عکس پروفایل ذخیره شد.";
  }catch(e){status.textContent="بارگذاری عکس ناموفق بود: "+e.message;}
  finally{avatarInput.value="";}
 });
 $("removeAvatar").addEventListener("click",async()=>{
  if(!currentAvatarPath)return;
  const status=$("avatarStatus");status.textContent="در حال حذف تصویر...";
  try{
   const {error:removeError}=await db.storage.from("academy-avatars").remove([currentAvatarPath]);if(removeError)throw removeError;
   const {error:updateError}=await db.from("academy_profiles").update({avatar_path:null}).eq("user_id",user.id);if(updateError)throw updateError;
   currentAvatarPath=null;$("avatarPreview").hidden=true;$("avatarInitials").hidden=false;$("removeAvatar").hidden=true;status.textContent="عکس پروفایل حذف شد.";
  }catch(e){status.textContent="حذف عکس ناموفق بود: "+e.message;}
 });
 $("doneCount").textContent=done.length.toLocaleString("fa-IR");
 $("percent").textContent=(total?Math.round(done.length/total*100):0).toLocaleString("fa-IR")+"٪";
 $("quizCount").textContent=(count||0).toLocaleString("fa-IR");
 $("courseProgress").innerHTML=(courseRows||[]).map(c=>{const ids=(lessonRows||[]).filter(l=>l.course_id===c.id).map(l=>l.id),n=ids.filter(id=>done.includes(id)).length,pct=ids.length?Math.round(n/ids.length*100):0;return '<div class="student-course-row"><div class="student-course-title"><strong>'+esc(c.title)+'</strong><span>'+n+' از '+ids.length+' درس</span></div><div class="student-course-track"><span style="width:'+pct+'%"></span></div></div>';}).join("")||"هنوز دوره‌ای منتشر نشده است.";
 $("quizHistory").innerHTML=attempts?.length?attempts.map(q=>'<div class="student-quiz-row">امتیاز: <strong>'+q.score+' از '+q.max_score+'</strong> · '+q.percent+'٪ · '+new Date(q.submitted_at).toLocaleDateString("fa-IR")+'</div>').join(""):"هنوز آزمون نمره‌دار ثبت نشده است.";
 const adHtml=a=>'<article style="padding:12px 0;border-bottom:1px solid var(--line)"><strong>'+esc(a.title)+'</strong><p>'+esc(a.body)+'</p>'+(safeUrl(a.image_path)?'<img src="'+esc(safeUrl(a.image_path))+'" alt="" style="max-width:100%;max-height:180px;border-radius:10px">':"")+(safeUrl(a.target_url)?'<p><a class="btn small" href="'+esc(safeUrl(a.target_url))+'" target="_blank" rel="noopener noreferrer">مشاهده</a></p>':"")+'</article>';
 const showAds=(id,items)=>{$(id).innerHTML=items.length?items.map(adHtml).join(""):"فعلاً تبلیغی برای این بخش منتشر نشده است.";};
 showAds("studentAdsTop",ads.filter(a=>["student","both","student_top"].includes(a.placement)));
 showAds("studentAdsCourses",ads.filter(a=>a.placement==="student_courses"));
 showAds("studentAdsBottom",ads.filter(a=>a.placement==="student_bottom"));
 if((roles||[]).some(x=>["admin","super_admin"].includes(x.role)))$("adminShortcut").hidden=false;
}
$("logoutBtn").addEventListener("click",async()=>{const {error}=await db.auth.signOut();if(error){$("status").textContent=error.message;return;}location.replace("index.html");});
start().catch(e=>{$("status").textContent="بارگذاری پنل انجام نشد: "+(e.message||"خطای پایگاه داده");});
})();