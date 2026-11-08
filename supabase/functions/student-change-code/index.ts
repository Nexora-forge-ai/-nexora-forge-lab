import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS","Content-Type":"application/json; charset=utf-8"};
const out=(s:number,b:Record<string,unknown>)=>new Response(JSON.stringify(b),{status:s,headers:cors});
const key=(plural:string,legacy:string)=>{const raw=Deno.env.get(plural);if(raw){try{const v=JSON.parse(raw);if(typeof v.default==="string")return v.default;}catch{}}return Deno.env.get(legacy)??"";};
const cfg=()=>({url:Deno.env.get("SUPABASE_URL")??"",anon:key("SUPABASE_PUBLISHABLE_KEYS","SUPABASE_ANON_KEY"),secret:key("SUPABASE_SECRET_KEYS","SUPABASE_SERVICE_ROLE_KEY")});
const clients=(c:ReturnType<typeof cfg>)=>({admin:createClient(c.url,c.secret,{auth:{persistSession:false,autoRefreshToken:false}}),auth:createClient(c.url,c.anon,{auth:{persistSession:false,autoRefreshToken:false}})});
const codeOk=(s:string)=>/^[a-z0-9]{12}$/.test(s);
const emailFor=(s:string)=>s+"@students.nexoraforge.invalid";
async function caller(req:Request,c:ReturnType<typeof cfg>){const token=req.headers.get("Authorization")?.replace(/^Bearer\s+/i,"");if(!token)return null;const {auth}=clients(c);const {data,error}=await auth.auth.getUser(token);return error?null:data.user??null;}

Deno.serve(async req=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method!=="POST")return out(405,{error:"Method not allowed"});
 const c=cfg();if(!c.url||!c.secret||!c.anon)return out(500,{error:"Server configuration is incomplete"});
 const user=await caller(req,c);if(!user)return out(401,{error:"ابتدا وارد حساب شو."});
 let b:{new_student_code?:string;current_password?:string};try{b=await req.json()}catch{return out(400,{error:"درخواست نامعتبر است."})}
 const next=String(b.new_student_code??"").trim().toLowerCase(),password=String(b.current_password??"");
 if(!codeOk(next))return out(400,{error:"شناسه جدید باید دقیقاً ۱۲ حرف یا عدد انگلیسی باشد."});
 if(password.length<8||password.length>128)return out(400,{error:"رمز فعلی معتبر نیست."});
 const {admin,auth}=clients(c);
 const {data:profile,error:pErr}=await admin.from("academy_profiles").select("student_code,account_status").eq("user_id",user.id).maybeSingle();
 if(pErr||!profile||profile.account_status!=="active")return out(403,{error:"حساب فعال پیدا نشد."});
 if(profile.student_code===next)return out(400,{error:"شناسه جدید با شناسه فعلی یکسان است."});
 const {data:check,error:checkErr}=await admin.from("academy_profiles").select("user_id").eq("student_code",next).maybeSingle();
 if(checkErr)return out(503,{error:"بررسی شناسه جدید ناموفق بود."});
 if(check)return out(409,{error:"این شناسه قبلاً انتخاب شده است."});
 const {data:authUser,error:uErr}=await admin.auth.admin.getUserById(user.id);
 if(uErr||!authUser.user?.email)return out(500,{error:"حساب احراز هویت پیدا نشد."});
 const {error:verifyErr}=await auth.auth.signInWithPassword({email:authUser.user.email,password});
 if(verifyErr)return out(401,{error:"رمز فعلی اشتباه است."});
 const {error:updateErr}=await admin.from("academy_profiles").update({student_code:next}).eq("user_id",user.id);
 if(updateErr)return out(409,{error:"ذخیره شناسه جدید انجام نشد؛ ممکن است شناسه قبلاً گرفته شده باشد."});
 await admin.auth.admin.updateUserById(user.id,{user_metadata:{...authUser.user.user_metadata,student_code:next}});
 return out(200,{ok:true,student_code:next});
});