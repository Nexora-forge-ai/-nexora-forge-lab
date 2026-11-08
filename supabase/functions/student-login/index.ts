import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: corsHeaders });
const readKey = (pluralName: string, legacyName: string) => {
  const raw = Deno.env.get(pluralName);
  if (raw) {
    try { const keys = JSON.parse(raw); if (typeof keys.default === "string") return keys.default; } catch { /* use legacy fallback */ }
  }
  return Deno.env.get(legacyName) ?? "";
};

async function hashKey(value: string, pepper: string) {
  const bytes = new TextEncoder().encode(pepper + ":" + value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((x) => x.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = readKey("SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_ANON_KEY");
  const serviceKey = readKey("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return json(500, { error: "Server configuration is incomplete" });

  let body: { student_code?: string; password?: string };
  try { body = await req.json(); } catch { return json(400, { error: "درخواست نامعتبر است." }); }

  const code = String(body.student_code ?? "").trim().toLowerCase();
  const password = String(body.password ?? "");
  if (!/^[a-z0-9]{12}$/.test(code) || password.length < 8 || password.length > 128) {
    return json(400, { error: "شناسه یا رمز عبور معتبر نیست." });
  }

  const forwarded = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  const pepper = serviceKey;
  const [ipHash, codeHash] = await Promise.all([
    hashKey("ip:" + forwarded, pepper),
    hashKey("code:" + code, pepper),
  ]);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const authClient = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });

  for (const keyHash of [ipHash, codeHash]) {
    const { data, error } = await admin.rpc("academy_check_login_rate_limit", {
      p_key_hash: keyHash,
      p_failed: false,
    });
    if (error) return json(503, { error: "سامانه ورود موقتاً در دسترس نیست." });
    if (data?.allowed === false) return json(429, { error: "تلاش‌های ورود زیاد بوده است. ۱۵ دقیقه دیگر دوباره تلاش کن." });
  }

  const fail = async () => {
    await Promise.all([ipHash, codeHash].map((keyHash) =>
      admin.rpc("academy_check_login_rate_limit", { p_key_hash: keyHash, p_failed: true })
    ));
  };

  const { data: profile, error: profileError } = await admin
    .from("academy_profiles")
    .select("user_id,account_status")
    .eq("student_code", code)
    .maybeSingle();

  if (profileError || !profile || profile.account_status !== "active") {
    await fail();
    return json(401, { error: "شناسه یا رمز عبور اشتباه است، یا حساب فعال نیست." });
  }

  const { data: userResult, error: userError } = await admin.auth.admin.getUserById(profile.user_id);
  const email = userResult?.user?.email;
  if (userError || !email) {
    await fail();
    return json(401, { error: "شناسه یا رمز عبور اشتباه است، یا حساب فعال نیست." });
  }

  const { data: signedIn, error: signInError } = await authClient.auth.signInWithPassword({ email, password });
  if (signInError || !signedIn.session) {
    await fail();
    return json(401, { error: "شناسه یا رمز عبور اشتباه است، یا حساب فعال نیست." });
  }

  return json(200, {
    access_token: signedIn.session.access_token,
    refresh_token: signedIn.session.refresh_token,
    expires_in: signedIn.session.expires_in,
    token_type: signedIn.session.token_type,
    user: signedIn.user,
  });
});
