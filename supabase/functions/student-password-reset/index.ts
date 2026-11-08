const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS","Content-Type":"application/json; charset=utf-8"};
Deno.serve(async req=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 return new Response(JSON.stringify({error:"بازیابی ایمیلی غیرفعال است. برای دریافت رمز موقت با مدیر آکادمی تماس بگیر."}),{status:410,headers:cors});
});