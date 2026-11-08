import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS","Content-Type":"application/json; charset=utf-8"};
const json=(status:number,body:Record<string,unknown>)=>new Response(JSON.stringify(body),{status,headers:corsHeaders});
async function hashKey(value:string,pepper:string){const d=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(pepper+":"+value));return Array.from(new Uint8Array(d)).map(x=>x.toString(16).padStart(2,"0")).join("");}
Deno.serve(async req=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:corsHeaders});
 if(req.method!=="POST")return json(405,{error:"Method not allowed"});
 const url=Deno.env.get("SUPABASE_URL"),anon=Deno.env.get("SUPABASE_ANON_KEY"),service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!url||!anon||!service)return json(500,{error:"Server configuration is incomplete"});
 let body:{student_code?:string};try{body=await req.json();}catch{return json(400,{error:"درخواست نامعتبر است."});}
 const code=String(body.student_code??"").trim().toLowerCase();
 if(!/^[a-z0-9]{12}$/.test(code))return json(400,{error:"شناسه باید دقیقاً ۱۲ حرف یا عدد انگلیسی باشد."});
 const origin=req.headers.get("origin")||"";
 const allowedOrigin=/^https:\/\/[a-z0-9-]+\.pages\.dev$/i.test(origin)?"https://"+new URL(origin).host:"";
 if(!allowedOrigin)return json(400,{error:"نشانی بازگشت معتبر نیست."});
 const ip=req.headers.get("x-forwarded-for")?.split(",")[0]?.trim()||"unknown";
 const [ipHash,codeHash]=await Promise.all([hashKey("ip:"+ip,service),hashKey("code:"+code,service)]);
 const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
 const auth=createClient(url,anon,{auth:{persistSession:false,autoRefreshToken:false}});
 for(const key_hash of [ipHash,codeHash]){
  const {data,error}=await admin.rpc("academy_check_login_rate_limit",{p_key_hash:key_hash,p_failed:false});
  if(error)return json(503,{error:"سامانه بازیابی موقتاً در دسترس نیست."});
  if(data?.allowed===false)return json(429,{error:"درخواست‌های زیاد؛ ۱۵ دقیقه دیگر دوباره تلاش کن."});
 }
 const recordFailure=()=>Promise.all([ipHash,codeHash].map(key_hash=>admin.rpc("academy_check_login_rate_limit",{p_key_hash, p_failed:true})));
 const {data:profile}=await admin.from("academy_profiles").select("user_id,account_status").eq("student_code",code).maybeSingle();
 if(profile?.account_status==="active"){
  const {data:user}=await admin.auth.admin.getUserById(profile.user_id);
  if(user?.user?.email){
   await auth.auth.resetPasswordForEmail(user.user.email,{redirectTo:allowedOrigin+"/student.html"});
  }
 }else{
  await recordFailure();
 }
 return json(200,{ok:true,message:"اگر شناسه معتبر و حساب فعال باشد، لینک بازیابی به ایمیل ثبت‌شده ارسال می‌شود."});
});
