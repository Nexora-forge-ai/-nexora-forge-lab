(() => {
"use strict";
const URL="https://ufranjjvhmsrkoxtlqcl.supabase.co",KEY="sb_publishable_PiggBtDvCsSOwiT62J21Ag_fJA7M_v_";
const client=window.supabase.createClient(URL,KEY,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
const $=id=>document.getElementById(id);let allowed=false;
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
function status(s,ok=false){$("adminStatus").textContent=s;$("adminStatus").classList.toggle("success",ok);}
function reset(){ $("adForm").reset();$("adId").value=""; }
async function guard(){
 const {data:{session}}=await client.auth.getSession();
 if(!session){location.replace("index.html?auth=login");return;}
 $("adminIdentity").textContent="حساب: "+(session.user.email||"مدیر");
 const {data,error}=await client.from("academy_admins").select("user_id").eq("user_id",session.user.id).maybeSingle();
 if(error)throw error;
 if(!data){status("این حساب مجوز مدیریت ندارد. نقش مدیر باید فقط از SQL Editor پروژه توسط مالک پایگاه داده اعطا شود.");$("adForm").hidden=true;return;}
 allowed=true;status("دسترسی مدیر تأیید شد.",true);await loadAds();
}
async function loadAds(){
 const {data,error}=await client.from("academy_ads").select("*").order("created_at",{ascending:false});
 if(error)throw error;
 $("adList").innerHTML=data?.length?data.map(a=>'<article class="student-box" style="margin:10px 0"><div style="display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap"><strong>'+esc(a.title)+'</strong><span class="tag">'+(a.is_active?"فعال":"غیرفعال")+'</span></div><p>'+esc(a.body)+'</p><small class="micro">جایگاه: '+esc(a.placement)+'</small><div class="actions"><button class="btn small" data-edit="'+a.id+'">ویرایش</button><button class="btn danger small" data-delete="'+a.id+'">حذف</button></div></article>').join(""):"هنوز تبلیغی ثبت نشده است.";
 document.querySelectorAll("[data-edit]").forEach(b=>b.onclick=()=>edit(data.find(x=>x.id===b.dataset.edit)));
 document.querySelectorAll("[data-delete]").forEach(b=>b.onclick=()=>removeAd(b.dataset.delete));
}
function edit(a){$("adId").value=a.id;$("adTitle").value=a.title;$("adBody").value=a.body;$("adImage").value=a.image_url||"";$("adTarget").value=a.target_url||"";$("adPlacement").value=a.placement;$("adActive").checked=a.is_active;window.scrollTo({top:0,behavior:"smooth"});}
async function removeAd(id){if(!confirm("این تبلیغ حذف شود؟"))return;const {error}=await client.from("academy_ads").delete().eq("id",id);if(error){status(error.message);return;}status("تبلیغ حذف شد.",true);await loadAds();}
$("adForm").addEventListener("submit",async e=>{e.preventDefault();if(!allowed)return;const payload={title:$("adTitle").value.trim(),body:$("adBody").value.trim(),image_url:$("adImage").value.trim()||null,target_url:$("adTarget").value.trim()||null,placement:$("adPlacement").value,is_active:$("adActive").checked,updated_at:new Date().toISOString()};const id=$("adId").value;const result=id?await client.from("academy_ads").update(payload).eq("id",id):await client.from("academy_ads").insert(payload);if(result.error){status("ذخیره انجام نشد: "+result.error.message);return;}status("تبلیغ ذخیره شد.",true);reset();await loadAds();});
$("clearAd").onclick=reset;
guard().catch(e=>status("خطا در بررسی دسترسی یا بارگذاری داده: "+e.message));
})();