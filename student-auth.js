/* NEXORA FORGE ACADEMY - optional student accounts */
(() => {
  "use strict";
  const SUPABASE_URL = "https://ufranjjvhmsrkoxtlqcl.supabase.co";
  const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_PiggBtDvCsSOwiT62J21Ag_fJA7M_v_";
  const $ = id => document.getElementById(id);
  const modal = $("authModal");
  const panel = $("studentPanel");
  const message = $("authMessage");
  if (!window.supabase || !window.supabase.createClient) {
    if ($("authOpenBtn")) $("authOpenBtn").addEventListener("click", () => alert("سرویس ورود بارگذاری نشد. اتصال اینترنت را بررسی و صفحه را تازه‌سازی کن."));
    return;
  }
  const client = window.supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
  });
  let currentUser = null;
  let busy = false;
  const safeText = value => String(value ?? "").replace(/[&<>"']/g, ch => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[ch]));
  const getLocalDone = () => {
    try { const value = JSON.parse(localStorage.getItem("nexoraAcademyDone") || "[]"); return Array.isArray(value) ? value.filter(x => typeof x === "string") : []; }
    catch (_) { return []; }
  };
  function setMessage(text, success=false) {
    message.textContent = text;
    message.classList.toggle("success", success);
  }
  function openModal(tab="login") {
    modal.hidden = false;
    document.body.style.overflow = "hidden";
    showTab(tab);
    setMessage("");
  }
  function closeModal() {
    modal.hidden = true;
    document.body.style.overflow = "";
  }
  function showTab(tab) {
    const signup = tab === "signup";
    $("loginForm").hidden = signup;
    $("signupForm").hidden = !signup;
    $("showLogin").classList.toggle("active", !signup);
    $("showSignup").classList.toggle("active", signup);
    $("authTitle").textContent = signup ? "ساخت حساب دانش‌آموزی" : "ورود به حساب دانش‌آموزی";
    setMessage("");
  }
  function setBusy(value) {
    busy = value;
    document.querySelectorAll(".auth-form button").forEach(button => button.disabled = value);
  }
  async function syncProgress() {
    if (!currentUser) return;
    const local = getLocalDone();
    const { data, error } = await client.from("student_progress").select("completed_lessons").eq("user_id", currentUser.id).maybeSingle();
    if (error) throw error;
    const merged = [...new Set([...local, ...((data && Array.isArray(data.completed_lessons)) ? data.completed_lessons : [])])];
    const { error: saveError } = await client.from("student_progress").upsert({
      user_id: currentUser.id,
      completed_lessons: merged,
      updated_at: new Date().toISOString()
    }, { onConflict: "user_id" });
    if (saveError) throw saveError;
    window.dispatchEvent(new CustomEvent("nexora:progress-loaded", { detail: merged }));
  }
  async function saveQuizResult(result) {
    if (!currentUser || !result || !Number.isInteger(result.score) || !Number.isInteger(result.total)) return;
    const { error } = await client.from("student_quiz_attempts").insert({
      user_id: currentUser.id, score: result.score, total: result.total
    });
    if (error) console.error("Quiz result could not be saved:", error.message);
    await renderDashboard();
  }
  async function renderDashboard() {
    if (!currentUser) return;
    const name = currentUser.user_metadata?.full_name || currentUser.email || "دانش‌آموز";
    $("studentWelcome").textContent = "خوش آمدی، " + name;
    const local = getLocalDone();
    $("studentDoneCount").textContent = local.length.toLocaleString("fa-IR");
    $("studentPercent").textContent = Math.round(local.length / 58 * 100).toLocaleString("fa-IR") + "٪";
    const courseMap = [
      {key:"html",name:"HTML",count:15},
      {key:"css",name:"CSS",count:18},
      {key:"js",name:"JavaScript",count:25}
    ];
    $("studentCourseProgress").innerHTML = courseMap.map(course => {
      const count = local.filter(id => id.startsWith(course.key + ":")).length;
      const pct = Math.round(count / course.count * 100);
      return '<div class="student-course-row"><div class="student-course-title"><strong>'+course.name+'</strong><span>'+count+' از '+course.count+' درس</span></div><div class="student-course-track"><span style="width:'+pct+'%"></span></div></div>';
    }).join("");
    const [{ data, error }, countResult] = await Promise.all([
      client.from("student_quiz_attempts").select("score,total,created_at").eq("user_id", currentUser.id).order("created_at", {ascending:false}).limit(5),
      client.from("student_quiz_attempts").select("id", {count:"exact", head:true}).eq("user_id", currentUser.id)
    ]);
    if (error) throw error;
    if (countResult.error) throw countResult.error;
    $("studentQuizCount").textContent = (countResult.count || 0).toLocaleString("fa-IR");
    $("studentQuizHistory").innerHTML = data && data.length ? data.map(item =>
      '<div class="student-quiz-row">امتیاز: <strong>'+item.score+' از '+item.total+'</strong> <span>· '+new Date(item.created_at).toLocaleDateString("fa-IR")+'</span></div>'
    ).join("") : "هنوز نتیجه‌ای ثبت نشده است.";
  }
  async function applySession(session) {
    currentUser = session?.user || null;
    if (currentUser) {
      $("authOpenBtn").textContent = "پنل دانش‌آموزی";
      $("authOpenBtn").onclick = () => { window.location.href = "student.html"; };
      panel.hidden = true;
    } else {
      $("authOpenBtn").textContent = "ورود / ثبت‌نام";
      $("authOpenBtn").onclick = () => openModal("login");
      panel.hidden = true;
    }
  }
  $("authOpenBtn").onclick = () => openModal("login");
  $("showLogin").addEventListener("click", () => showTab("login"));
  $("showSignup").addEventListener("click", () => showTab("signup"));
  document.querySelectorAll("[data-auth-close]").forEach(el => el.addEventListener("click", closeModal));
  document.addEventListener("keydown", event => { if (event.key === "Escape" && !modal.hidden) closeModal(); });

  $("loginForm").addEventListener("submit", async event => {
    event.preventDefault();
    if (busy) return;
    setBusy(true); setMessage("در حال ورود...");
    try {
      const { error } = await client.auth.signInWithPassword({
        email: $("loginEmail").value.trim(),
        password: $("loginPassword").value
      });
      if (error) throw error;
      setMessage("ورود موفق بود.", true);
      closeModal();
      const { data } = await client.auth.getSession();
      await applySession(data.session);
      window.location.href = "student.html";
    } catch (error) {
      setMessage(error.message || "ورود انجام نشد.");
    } finally { setBusy(false); }
  });

  $("signupForm").addEventListener("submit", async event => {
    event.preventDefault();
    if (busy) return;
    setBusy(true); setMessage("در حال ساخت حساب...");
    try {
      if ($("signupPassword").value !== $("signupPasswordConfirm").value) throw new Error("رمز عبور و تکرار آن یکسان نیستند.");
      if (!/^(?=.*[A-Za-z])(?=.*\d).{10,}$/.test($("signupPassword").value)) throw new Error("رمز باید حداقل ۱۰ نویسه و شامل حرف انگلیسی و عدد باشد.");
      const { data, error } = await client.auth.signUp({
        email: $("signupEmail").value.trim(),
        password: $("signupPassword").value,
        options: { data: { full_name: $("signupName").value.trim() }, emailRedirectTo: new URL("student.html", window.location.href).href }
      });
      if (error) throw error;
      if (data.session) {
        setMessage("حساب ساخته شد و وارد شدی.", true);
        closeModal();
        await applySession(data.session);
        window.location.href = "student.html";
      } else {
        setMessage("حساب ساخته شد. ایمیلت را تأیید کن؛ سپس با همان حساب وارد می‌شوی.", true);
      }
    } catch (error) {
      setMessage(error.message || "ثبت‌نام انجام نشد.");
    } finally { setBusy(false); }
  });

  $("studentLogout").addEventListener("click", async () => {
    const { error } = await client.auth.signOut();
    if (error) { alert("خروج انجام نشد: " + error.message); return; }
    panel.hidden = true;
    await applySession(null);
  });

  window.addEventListener("nexora:progress-updated", async event => {
    if (!currentUser || !Array.isArray(event.detail)) return;
    const { error } = await client.from("student_progress").upsert({
      user_id: currentUser.id,
      completed_lessons: event.detail,
      updated_at: new Date().toISOString()
    }, { onConflict: "user_id" });
    if (error) console.error("Progress sync failed:", error.message);
    else renderDashboard().catch(console.error);
  });
  window.addEventListener("nexora:quiz-finished", event => saveQuizResult(event.detail).catch(console.error));

  client.auth.getSession().then(({data, error}) => {
    if (error) throw error;
    applySession(data.session);
    if (new URLSearchParams(location.search).get("auth") === "login" && !data.session) openModal("login");
  }).catch(error => console.error("Auth initialization failed:", error));

  const homeAds = $("homeAds");
  if (homeAds) client.from("academy_ads").select("title,body,image_url,target_url").in("placement",["home","both"]).then(({data,error}) => {
    if (error || !data || !data.length) { homeAds.hidden = true; return; }
    homeAds.hidden = false;
    homeAds.innerHTML = data.map(ad => '<article class="student-box" style="margin:10px 0"><strong>'+safeText(ad.title)+'</strong><p>'+safeText(ad.body)+'</p>'+(ad.image_url?'<img src="'+safeText(ad.image_url)+'" alt="" style="max-width:100%;max-height:180px;border-radius:10px">':"")+(ad.target_url?'<p><a class="btn small" href="'+safeText(ad.target_url)+'" target="_blank" rel="noopener noreferrer">مشاهده</a></p>':"")+'</article>').join("");
  });
})();