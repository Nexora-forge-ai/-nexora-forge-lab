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
 let b:{current_password?:string;new_password?:string};try{b=await req.json()}catch{return out(400,{error:"درخواست نامعتبر است."})}
 const oldPass=String(b.current_password??""),newPass=String(b.new_password??"");
 if(oldPass.length<8||oldPass.length>128||newPass.length<8||newPass.length>16||!/[A-Za-z]/.test(newPass)||!/[0-9]/.test(newPass))return out(400,{error:"رمز جدید باید ۸ تا ۱۶ نویسه و شامل حرف انگلیسی و عدد باشد."});
 const {admin,auth}=clients(c);
 const {data:p,error:pErr}=await admin.from("academy_profiles").select("account_status").eq("user_id",user.id).maybeSingle();
 if(pErr||p?.account_status!=="active")return out(403,{error:"حساب فعال نیست."});
 const {data:u,error:uErr}=await admin.auth.admin.getUserById(user.id);
 if(uErr||!u.user?.email)return out(500,{error:"حساب احراز هویت پیدا نشد."});
 const {error:verifyErr}=await auth.auth.signInWithPassword({email:u.user.email,password:oldPass});
 if(verifyErr)return out(401,{error:"رمز فعلی اشتباه است."});
 const {error:updateErr}=await admin.auth.admin.updateUserById(user.id,{password:newPass});
 if(updateErr)return out(500,{error:"تغییر رمز انجام نشد."});
 return out(200,{ok:true,message:"رمز عبور با موفقیت تغییر کرد."});
});