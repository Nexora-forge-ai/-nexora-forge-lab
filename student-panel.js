(() => {
"use strict";
const URL="https://ufranjjvhmsrkoxtlqcl.supabase.co";
const KEY="sb_publishable_PiggBtDvCsSOwiT62J21Ag_fJA7M_v_";
const client=window.supabase.createClient(URL,KEY,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
const $=id=>document.getElementById(id);
const done=()=>{try{const x=JSON.parse(localStorage.getItem("nexoraAcademyDone")||"[]");return Array.isArray(x)?x:[]}catch{return[]}};
const safeUrl=s=>{try{const u=new URL(s);return ["http:","https:"].includes(u.protocol)?u.href:""}catch{return""}};
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
async function start(){
 const {data:{session}}=await client.auth.getSession();
 if(!session){location.replace("index.html?auth=login");return;}
 const user=session.user;
 $("welcome").textContent="خوش آمدی، "+(user.user_metadata?.full_name||user.email||"دانش‌آموز");
 const local=done();
 const {data:progress,error:pErr}=await client.from("student_progress").select("completed_lessons").eq("user_id",user.id).maybeSingle();
 if(pErr) throw pErr;
 const lessons=[...new Set([...local,...(progress?.completed_lessons||[])])];
 localStorage.setItem("nexoraAcademyDone",JSON.stringify(lessons));
 const {error:syncErr}=await client.from("student_progress").upsert({user_id:user.id,completed_lessons:lessons,updated_at:new Date().toISOString()},{onConflict:"user_id"});
 if(syncErr)throw syncErr;
 $("doneCount").textContent=lessons.length.toLocaleString("fa-IR");
 const {data:courseRows,error:courseErr}=await client.from("academy_courses").select("id,title").eq("is_published",true);
 if(courseErr)throw courseErr;
 const {data:lessonRows,error:lessonErr}=await client.from("academy_lessons").select("id,course_id").eq("is_published",true);
 if(lessonErr)throw lessonErr;
 const totalLessons=lessonRows?.length||58;
 $("percent").textContent=Math.round(lessons.length/totalLessons*100).toLocaleString("fa-IR")+"٪";
 $("courseProgress").innerHTML=(courseRows||[{id:"html",title:"HTML"},{id:"css",title:"CSS"},{id:"js",title:"JavaScript"}]).map(({id:key,title:name})=>{const total=(lessonRows||[]).filter(x=>x.course_id===key).length||({html:15,css:18,js:25}[key]||0);const n=lessons.filter(x=>x.startsWith(key+":")).length;return '<div class="student-course-row"><div class="student-course-title"><strong>'+name+'</strong><span>'+n+' از '+total+' درس</span></div><div class="student-course-track"><span style="width:'+Math.min(100,n/total*100)+'%"></span></div></div>'}).join("");
 const [{data:quizzes,error:qErr},count]=await Promise.all([client.from("student_quiz_attempts").select("score,total,created_at").eq("user_id",user.id).order("created_at",{ascending:false}).limit(5),client.from("student_quiz_attempts").select("id",{count:"exact",head:true}).eq("user_id",user.id)]);
 if(qErr)throw qErr;if(count.error)throw count.error;
 $("quizCount").textContent=(count.count||0).toLocaleString("fa-IR");
 $("quizHistory").innerHTML=quizzes?.length?quizzes.map(q=>'<div class="student-quiz-row">امتیاز: <strong>'+q.score+' از '+q.total+'</strong> · '+new Date(q.created_at).toLocaleDateString("fa-IR")+'</div>').join(""):"هنوز نتیجه‌ای ثبت نشده است.";
 const {data:ads,error:aErr}=await client.from("academy_ads").select("title,body,image_url,target_url").in("placement",["student","both"]).order("created_at",{ascending:false});
 if(aErr)throw aErr;
 $("studentAds").innerHTML=ads?.length?ads.map(a=>'<article style="padding:12px 0;border-bottom:1px solid var(--line)"><strong>'+esc(a.title)+'</strong><p>'+esc(a.body)+'</p>'+(safeUrl(a.image_url)?'<img src="'+esc(safeUrl(a.image_url))+'" alt="" style="max-width:100%;max-height:180px;border-radius:10px">':"")+(safeUrl(a.target_url)?'<p><a class="btn small" href="'+esc(safeUrl(a.target_url))+'" target="_blank" rel="noopener noreferrer">مشاهده</a></p>':"")+'</article>').join(""):"فعلاً اطلاعیه‌ای منتشر نشده است.";
 const {data:admin}=await client.from("academy_admins").select("user_id").eq("user_id",user.id).maybeSingle();
 if(admin)$("adminShortcut").hidden=false;
}
$("logoutBtn").addEventListener("click",async()=>{const {error}=await client.auth.signOut();if(error){$("status").textContent=error.message;return;}location.replace("index.html");});
start().catch(e=>{$("status").textContent="بارگذاری پنل انجام نشد: "+(e.message||"خطای پایگاه داده");});
})();