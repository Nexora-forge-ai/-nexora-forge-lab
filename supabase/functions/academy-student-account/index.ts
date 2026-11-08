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
    try { const keys = JSON.parse(raw); if (typeof keys.default === "string") return keys.default; } catch { /* legacy fallback */ }
  }
  return Deno.env.get(legacyName) ?? "";
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = readKey("SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_ANON_KEY");
  const serviceKey = readKey("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return json(500, { error: "Server configuration is incomplete" });

  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return json(401, { error: "ورود مدیر لازم است." });

  const caller = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: authData, error: authError } = await caller.auth.getUser(token);
  if (authError || !authData.user) return json(401, { error: "نشست مدیر معتبر نیست." });

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: roles, error: roleError } = await admin
    .from("academy_user_roles").select("role").eq("user_id", authData.user.id)
    .in("role", ["admin", "super_admin"]);
  if (roleError || !roles?.length) return json(403, { error: "اجازه مدیریت دانش‌آموزان را نداری." });

  let body: { user_id?: string; status?: string };
  try { body = await req.json(); } catch { return json(400, { error: "درخواست نامعتبر است." }); }
  const userId = String(body.user_id ?? "");
  const status = String(body.status ?? "");
  if (!/^[0-9a-f-]{36}$/i.test(userId) || !["active", "blocked"].includes(status)) {
    return json(400, { error: "شناسه کاربر یا وضعیت نامعتبر است." });
  }
  if (userId === authData.user.id) return json(400, { error: "نمی‌توانی حساب خودت را از این بخش مسدود کنی." });

  const { data: targetRoles, error: targetRoleError } = await admin
    .from("academy_user_roles").select("role").eq("user_id", userId)
    .in("role", ["admin", "super_admin"]);
  if (targetRoleError) return json(500, { error: "بررسی نقش حساب مقصد ناموفق بود." });
  if (targetRoles?.length) return json(403, { error: "حساب مدیر را نمی‌توان از فهرست دانش‌آموزان مسدود کرد." });

  const { data: target, error: targetError } = await admin
    .from("academy_profiles").select("user_id").eq("user_id", userId).maybeSingle();
  if (targetError || !target) return json(404, { error: "حساب دانش‌آموز پیدا نشد." });

  if (status === "active") {
    const { error: unbanError } = await admin.auth.admin.updateUserById(userId, { ban_duration: "none" });
    if (unbanError) return json(500, { error: "رفع مسدودیت Auth ناموفق بود؛ وضعیت حساب تغییر نکرد." });
    const { error: activateError } = await admin.from("academy_profiles")
      .update({ account_status: "active" }).eq("user_id", userId);
    if (activateError) {
      await admin.auth.admin.updateUserById(userId, { ban_duration: "876000h" });
      return json(500, { error: "فعال‌سازی پایگاه داده ناموفق بود؛ حساب دوباره مسدود شد." });
    }
    return json(200, { ok: true, status });
  }

  const { error: blockError } = await admin.from("academy_profiles")
    .update({ account_status: "blocked" }).eq("user_id", userId);
  if (blockError) return json(500, { error: "ذخیره وضعیت مسدودسازی ناموفق بود." });
  const { error: banError } = await admin.auth.admin.updateUserById(userId, { ban_duration: "876000h" });
  if (banError) {
    // RLS and the student login function still enforce account_status.
    return json(200, { ok: true, status, warning: "حساب در پایگاه داده مسدود شد؛ نشست Auth نیز نیازمند بررسی است." });
  }
  return json(200, { ok: true, status });
});
