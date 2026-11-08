import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS","Content-Type":"application/json; charset=utf-8"};
const out=(s:number,b:Record<string,unknown>)=>new Response(JSON.stringify(b),{status:s,headers:cors});
const key=(plural:string,legacy:string)=>{const raw=Deno.env.get(plural);if(raw){try{const v=JSON.parse(raw);if(typeof v.default==="string")return v.default;}catch{}}return Deno.env.get(legacy)??"";};
const cfg=()=>({url:Deno.env.get("SUPABASE_URL")??"",anon:key("SUPABASE_PUBLISHABLE_KEYS","SUPABASE_ANON_KEY"),secret:key("SUPABASE_SECRET_KEYS","SUPABASE_SERVICE_ROLE_KEY")});
const clients=(c:ReturnType<typeof cfg>)=>({admin:createClient(c.url,c.secret,{auth:{persistSession:false,autoRefreshToken:false}}),auth:createClient(c.url,c.anon,{auth:{persistSession:false,autoRefreshToken:false}})});
const validCode=(s:string)=>/^[a-z0-9]{12}$/.test(s);
const internalEmail=(s:string)=>s+"@students.nexoraforge.invalid";
async function getCaller(req:Request,c:ReturnType<typeof cfg>){const token=req.headers.get("Authorization")?.replace(/^Bearer\s+/i,"");if(!token)return null;const {auth}=clients(c);const {data,error}=await auth.auth.getUser(token);return error?null:data.user??null;}
async function hash(value:string,secret:string){const d=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(secret+":"+value));return Array.from(new Uint8Array(d)).map(x=>x.toString(16).padStart(2,"0")).join("");}
Deno.serve(async req=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method!=="POST")return out(405,{error:"Method not allowed"});
 const c=cfg();if(!c.url||!c.anon||!c.secret)return out(500,{error:"Server configuration is incomplete"});
 let b:Record<string,unknown>;try{b=await req.json()}catch{return out(400,{error:"درخواست نامعتبر است."})}
 const action=String(b.action??"");
 const {admin,auth}=clients(c);
 if(action==="register"){
  const name=String(b.display_name??"").trim(),code=String(b.student_code??"").trim().toLowerCase(),password=String(b.password??"");
  if(name.length<2||name.length>60)return out(400,{error:"نام باید بین ۲ تا ۶۰ نویسه باشد."});
  if(!validCode(code))return out(400,{error:"شناسه باید دقیقاً ۱۲ حرف یا عدد انگلیسی باشد."});
  if(!/^(?=.*[A-Za-z])(?=.*\d).{8,16}$/.test(password))return out(400,{error:"رمز باید ۸ تا ۱۶ نویسه و شامل حرف انگلیسی و عدد باشد."});
  const ip=req.headers.get("x-forwarded-for")?.split(",")[0]?.trim()||"unknown",ipHash=await hash("signup:"+ip,c.secret);
  const {data:limit,error:limitErr}=await admin.rpc("academy_check_login_rate_limit",{p_key_hash:ipHash,p_failed:false});
  if(limitErr)return out(503,{error:"سامانه ثبت‌نام موقتاً در دسترس نیست."});
  if(limit?.allowed===false)return out(429,{error:"درخواست‌های ثبت‌نام زیاد است؛ ۱۵ دقیقه دیگر دوباره تلاش کن."});
  await admin.rpc("academy_check_login_rate_limit",{p_key_hash:ipHash,p_failed:true});
  const {data:existing,error:lookupErr}=await admin.from("academy_profiles").select("user_id").eq("student_code",code).maybeSingle();
  if(lookupErr)return out(503,{error:"بررسی شناسه ممکن نشد."});
  if(existing)return out(409,{error:"این شناسه قبلاً انتخاب شده است."});
  const {data:created,error:createErr}=await admin.auth.admin.createUser({email:internalEmail(code),password,email_confirm:true,user_metadata:{display_name:name,student_code:code}});
  if(createErr||!created.user)return out(400,{error:createErr?.message||"ساخت حساب انجام نشد."});
  const id=created.user.id;
  const {error:profileErr}=await admin.from("academy_profiles").upsert({user_id:id,display_name:name,student_code:code,account_status:"active"},{onConflict:"user_id"});
  if(profileErr){await admin.auth.admin.deleteUser(id);return out(500,{error:"ساخت پروفایل انجام نشد؛ حساب ناقص پاک شد."});}
  await admin.from("academy_user_roles").insert({user_id:id,role:"student"});
  const {data:login,error:loginErr}=await auth.auth.signInWithPassword({email:internalEmail(code),password});
  if(loginErr||!login.session){await admin.auth.admin.deleteUser(id);return out(500,{error:"ورود اولیه ناموفق بود؛ دوباره ثبت‌نام کن."});}
  return out(201,{access_token:login.session.access_token,refresh_token:login.session.refresh_token,user:login.user,student_code:code});
 }
 const user=await getCaller(req,c);if(!user)return out(401,{error:"ابتدا وارد حساب شو."});
 if(action==="change_code"){
  const next=String(b.new_student_code??"").trim().toLowerCase(),password=String(b.current_password??"");
  if(!validCode(next))return out(400,{error:"شناسه جدید باید دقیقاً ۱۲ حرف یا عدد انگلیسی باشد."});
  if(password.length<8||password.length>128)return out(400,{error:"رمز فعلی معتبر نیست."});
  const {data:p,error:pErr}=await admin.from("academy_profiles").select("student_code,account_status").eq("user_id",user.id).maybeSingle();
  if(pErr||!p||p.account_status!=="active")return out(403,{error:"حساب فعال پیدا نشد."});
  if(p.student_code===next)return out(400,{error:"شناسه جدید با شناسه فعلی یکسان است."});
  const {data:exists,error:eErr}=await admin.from("academy_profiles").select("user_id").eq("student_code",next).maybeSingle();
  if(eErr)return out(503,{error:"بررسی شناسه جدید ناموفق بود."});if(exists)return out(409,{error:"این شناسه قبلاً انتخاب شده است."});
  const {data:u,error:uErr}=await admin.auth.admin.getUserById(user.id);if(uErr||!u.user?.email)return out(500,{error:"حساب احراز هویت پیدا نشد."});
  const {error:vErr}=await auth.auth.signInWithPassword({email:u.user.email,password});if(vErr)return out(401,{error:"رمز فعلی اشتباه است."});
  const {error:updateErr}=await admin.from("academy_profiles").update({student_code:next}).eq("user_id",user.id);
  if(updateErr)return out(409,{error:"ذخیره شناسه جدید انجام نشد؛ ممکن است شناسه قبلاً گرفته شده باشد."});
  await admin.auth.admin.updateUserById(user.id,{user_metadata:{...u.user.user_metadata,student_code:next}});
  return out(200,{ok:true,student_code:next});
 }
 if(action==="change_password"){
  const oldPass=String(b.current_password??""),newPass=String(b.new_password??"");
  if(oldPass.length<8||oldPass.length>128||newPass.length<8||newPass.length>16||!/[A-Za-z]/.test(newPass)||!/[0-9]/.test(newPass))return out(400,{error:"رمز جدید باید ۸ تا ۱۶ نویسه و شامل حرف انگلیسی و عدد باشد."});
  const {data:p,error:pErr}=await admin.from("academy_profiles").select("account_status").eq("user_id",user.id).maybeSingle();
  if(pErr||p?.account_status!=="active")return out(403,{error:"حساب فعال نیست."});
  const {data:u,error:uErr}=await admin.auth.admin.getUserById(user.id);if(uErr||!u.user?.email)return out(500,{error:"حساب احراز هویت پیدا نشد."});
  const {error:vErr}=await auth.auth.signInWithPassword({email:u.user.email,password:oldPass});if(vErr)return out(401,{error:"رمز فعلی اشتباه است."});
  const {error:updateErr}=await admin.auth.admin.updateUserById(user.id,{password:newPass});if(updateErr)return out(500,{error:"تغییر رمز انجام نشد."});
  return out(200,{ok:true,message:"رمز عبور با موفقیت تغییر کرد."});
 }
 if(action==="admin_reset"){
  const {data:roles,error:roleErr}=await admin.from("academy_user_roles").select("role").eq("user_id",user.id).in("role",["admin","super_admin"]);
  if(roleErr||!roles?.length)return out(403,{error:"اجازه مدیر لازم است."});
  const id=String(b.user_id??"");if(!/^[0-9a-f-]{36}$/i.test(id)||id===user.id)return out(400,{error:"حساب مقصد نامعتبر است."});
  const {data:targetRoles}=await admin.from("academy_user_roles").select("role").eq("user_id",id).in("role",["admin","super_admin"]);
  if(targetRoles?.length)return out(403,{error:"رمز حساب مدیر از این بخش تغییر نمی‌کند."});
  const {data:p,error:pErr}=await admin.from("academy_profiles").select("user_id").eq("user_id",id).maybeSingle();
  if(pErr||!p)return out(404,{error:"دانش‌آموز پیدا نشد."});
  const alphabet="ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%";
  const bytes=crypto.getRandomValues(new Uint8Array(16)),temporary=Array.from(bytes,x=>alphabet[x%alphabet.length]).join("");
  const {error:updateErr}=await admin.auth.admin.updateUserById(id,{password:temporary});
  if(updateErr)return out(500,{error:"تعیین رمز موقت انجام نشد."});
  return out(200,{ok:true,temporary_password:temporary,message:"رمز موقت فقط همین بار نمایش داده می‌شود؛ آن را امن به دانش‌آموز تحویل بده."});
 }
 return out(400,{error:"عملیات نامعتبر است."});
});