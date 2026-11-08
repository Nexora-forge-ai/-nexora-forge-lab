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
 const callerUser=await caller(req,c);if(!callerUser)return out(401,{error:"ورود مدیر لازم است."});
 const {admin}=clients(c);
 const {data:roles,error:roleErr}=await admin.from("academy_user_roles").select("role").eq("user_id",callerUser.id).in("role",["admin","super_admin"]);
 if(roleErr||!roles?.length)return out(403,{error:"اجازه مدیر لازم است."});
 let b:{user_id?:string};try{b=await req.json()}catch{return out(400,{error:"درخواست نامعتبر است."})}
 const id=String(b.user_id??"");if(!/^[0-9a-f-]{36}$/i.test(id)||id===callerUser.id)return out(400,{error:"حساب مقصد نامعتبر است."});
 const {data:targetRoles}=await admin.from("academy_user_roles").select("role").eq("user_id",id).in("role",["admin","super_admin"]);
 if(targetRoles?.length)return out(403,{error:"رمز حساب مدیر از این بخش تغییر نمی‌کند."});
 const {data:profile,error:pErr}=await admin.from("academy_profiles").select("user_id").eq("user_id",id).maybeSingle();
 if(pErr||!profile)return out(404,{error:"دانش‌آموز پیدا نشد."});
 const alphabet="ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%";
 const bytes=crypto.getRandomValues(new Uint8Array(16));
 const temporary=Array.from(bytes,x=>alphabet[x%alphabet.length]).join("");
 const {error:updateErr}=await admin.auth.admin.updateUserById(id,{password:temporary});
 if(updateErr)return out(500,{error:"تعیین رمز موقت انجام نشد."});
 return out(200,{ok:true,temporary_password:temporary,message:"رمز موقت فقط همین بار نمایش داده می‌شود؛ آن را امن به دانش‌آموز تحویل بده."});
});