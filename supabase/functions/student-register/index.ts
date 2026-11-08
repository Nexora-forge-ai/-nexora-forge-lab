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
 let b:{display_name?:string;student_code?:string;password?:string};try{b=await req.json()}catch{return out(400,{error:"درخواست نامعتبر است."})}
 const name=String(b.display_name??"").trim(),code=String(b.student_code??"").trim().toLowerCase(),password=String(b.password??"");
 if(name.length<2||name.length>60)return out(400,{error:"نام باید بین ۲ تا ۶۰ نویسه باشد."});
 if(!codeOk(code))return out(400,{error:"شناسه باید دقیقاً ۱۲ حرف یا عدد انگلیسی باشد."});
 if(!/^(?=.*[A-Za-z])(?=.*\d).{8,16}$/.test(password))return out(400,{error:"رمز باید ۸ تا ۱۶ نویسه و شامل حرف انگلیسی و عدد باشد."});
 const {admin,auth}=clients(c);
 const {data:exists,error:lookupError}=await admin.from("academy_profiles").select("user_id").eq("student_code",code).maybeSingle();
 if(lookupError)return out(503,{error:"بررسی شناسه ممکن نشد."});
 if(exists)return out(409,{error:"این شناسه قبلاً انتخاب شده است."});
 const {data:created,error:createError}=await admin.auth.admin.createUser({email:emailFor(code),password,email_confirm:true,user_metadata:{display_name:name,student_code:code}});
 if(createError||!created.user)return out(400,{error:createError?.message||"ساخت حساب انجام نشد."});
 const userId=created.user.id;
 const {error:profileError}=await admin.from("academy_profiles").upsert({user_id:userId,display_name:name,student_code:code,account_status:"active"},{onConflict:"user_id"});
 if(profileError){await admin.auth.admin.deleteUser(userId);return out(500,{error:"ساخت پروفایل انجام نشد؛ حساب ناقص پاک شد."});}
 await admin.from("academy_user_roles").insert({user_id:userId,role:"student"});
 const {data:session,error:loginError}=await auth.auth.signInWithPassword({email:emailFor(code),password});
 if(loginError||!session.session){await admin.auth.admin.deleteUser(userId);return out(500,{error:"حساب ساخته شد اما ورود اولیه ناموفق بود؛ دوباره ثبت‌نام کن."});}
 return out(201,{access_token:session.session.access_token,refresh_token:session.session.refresh_token,user:session.user,student_code:code});
});