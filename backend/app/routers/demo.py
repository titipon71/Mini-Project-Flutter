from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["demo"])

_HTML = """<!DOCTYPE html>
<html lang="th">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Twebtoon — Dev Login</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <script src="https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js"></script>
  <script src="https://www.gstatic.com/firebasejs/10.12.2/firebase-auth-compat.js"></script>
  <style>
    body { background: #0d0d14; font-family: 'Segoe UI', sans-serif; }
    .glass {
      background: rgba(255,255,255,0.04);
      backdrop-filter: blur(16px);
      border: 1px solid rgba(255,255,255,0.08);
    }
    .token-box {
      font-family: 'Courier New', monospace;
      word-break: break-all;
      scrollbar-width: thin;
      scrollbar-color: #4f46e5 transparent;
    }
    .google-btn {
      transition: all 0.25s cubic-bezier(.4,0,.2,1);
      box-shadow: 0 4px 24px rgba(99,102,241,0.25);
    }
    .google-btn:hover {
      transform: translateY(-2px);
      box-shadow: 0 8px 32px rgba(99,102,241,0.45);
    }
    .google-btn:active { transform: translateY(0); }
    .fade-in { animation: fadeIn 0.4s ease; }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(12px); }
      to   { opacity: 1; transform: translateY(0); }
    }
    .spin { animation: spin 0.9s linear infinite; }
    @keyframes spin { to { transform: rotate(360deg); } }
    .blob1 {
      position: fixed; top: -10rem; right: -10rem;
      width: 28rem; height: 28rem;
      background: radial-gradient(circle, #6366f1 0%, transparent 70%);
      opacity: 0.15; pointer-events: none;
    }
    .blob2 {
      position: fixed; bottom: -10rem; left: -8rem;
      width: 24rem; height: 24rem;
      background: radial-gradient(circle, #a855f7 0%, transparent 70%);
      opacity: 0.12; pointer-events: none;
    }
    .copy-btn { transition: all 0.2s; }
    .copy-btn:active { transform: scale(0.95); }
    .tab-btn { transition: all 0.2s; border-bottom: 2px solid transparent; }
    .tab-btn.active { border-color: #6366f1; color: #a5b4fc; }
    pre { white-space: pre-wrap; }
  </style>
</head>
<body class="min-h-screen flex items-center justify-center p-4">

  <div class="blob1"></div>
  <div class="blob2"></div>

  <div class="relative z-10 w-full max-w-md">

    <!-- Logo -->
    <div class="text-center mb-8">
      <div class="inline-flex items-center justify-center w-16 h-16 rounded-2xl mb-4"
           style="background:linear-gradient(135deg,#6366f1,#a855f7);box-shadow:0 8px 32px rgba(99,102,241,0.4)">
        <svg class="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13
               C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13
               C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13
               C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
        </svg>
      </div>
      <h1 class="text-3xl font-bold text-white tracking-tight">Twebtoon</h1>
      <p class="text-gray-500 mt-1 text-sm">Developer Login &middot; ทดสอบ API</p>
    </div>

    <!-- Card -->
    <div class="glass rounded-2xl p-8 shadow-2xl">

      <!-- ── LOGIN ── -->
      <div id="panel-login">
        <p class="text-gray-400 text-sm text-center mb-6">
          เข้าสู่ระบบเพื่อรับ JWT token สำหรับทดสอบ API
        </p>
        <button id="google-btn" onclick="doSignIn()"
          class="google-btn w-full flex items-center justify-center gap-3
                 bg-white text-gray-700 font-semibold py-3 px-6 rounded-xl cursor-pointer">
          <svg width="20" height="20" viewBox="0 0 48 48">
            <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
            <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
            <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
            <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.18 1.48-4.97 2.29-8.16 2.29-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
          </svg>
          Sign in with Google
        </button>
        <div id="login-error"
             class="hidden mt-4 p-3 bg-red-900/30 border border-red-500/30 rounded-lg text-red-300 text-sm text-center">
        </div>
      </div>

      <!-- ── LOADING ── -->
      <div id="panel-loading" class="hidden text-center py-6">
        <div class="spin inline-block w-10 h-10 rounded-full border-2 border-indigo-500 border-t-transparent mb-3"></div>
        <p id="loading-msg" class="text-gray-400 text-sm">กำลังเข้าสู่ระบบ...</p>
      </div>

      <!-- ── PROFILE ── -->
      <div id="panel-profile" class="hidden fade-in">

        <!-- User row -->
        <div class="flex items-center gap-3 p-3 rounded-xl mb-5"
             style="background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.07)">
          <img id="u-photo" src="" alt="" class="w-11 h-11 rounded-full ring-2 ring-indigo-500/60 object-cover">
          <div class="flex-1 min-w-0">
            <p id="u-name" class="text-white font-semibold text-sm truncate"></p>
            <p id="u-email" class="text-gray-400 text-xs truncate"></p>
          </div>
          <span id="u-badge" class="text-xs font-bold px-2.5 py-0.5 rounded-full"></span>
        </div>

        <!-- Tabs: JWT / Firebase / Test -->
        <div class="flex gap-1 mb-4 border-b border-white/10">
          <button onclick="showTab('jwt')"   id="tab-jwt"      class="tab-btn active  text-xs text-gray-300 pb-2 px-3">JWT Token</button>
          <button onclick="showTab('fb')"    id="tab-fb"       class="tab-btn text-xs text-gray-500 pb-2 px-3">Firebase Token</button>
          <button onclick="showTab('test')"  id="tab-test"     class="tab-btn text-xs text-gray-500 pb-2 px-3">Quick Test</button>
        </div>

        <!-- Tab: JWT -->
        <div id="tab-jwt-panel">
          <div class="flex justify-between items-center mb-1.5">
            <span class="text-xs text-indigo-400 font-semibold uppercase tracking-wider">Access Token</span>
            <button onclick="copyEl('t-jwt', this)"
              class="copy-btn text-xs text-gray-400 hover:text-white bg-white/10 hover:bg-white/20 px-2.5 py-0.5 rounded-md">
              Copy
            </button>
          </div>
          <div id="t-jwt" class="token-box text-xs text-green-300 rounded-lg p-3 max-h-28 overflow-auto"
               style="background:#0a0a14;border:1px solid rgba(52,211,153,0.15)"></div>
          <p class="text-xs text-gray-600 mt-2">
            ใช้ใน header: <code class="text-gray-400">Authorization: Bearer &lt;token&gt;</code>
          </p>
        </div>

        <!-- Tab: Firebase -->
        <div id="tab-fb-panel" class="hidden">
          <div class="flex justify-between items-center mb-1.5">
            <span class="text-xs text-yellow-500 font-semibold uppercase tracking-wider">Firebase ID Token</span>
            <button onclick="copyEl('t-fb', this)"
              class="copy-btn text-xs text-gray-400 hover:text-white bg-white/10 hover:bg-white/20 px-2.5 py-0.5 rounded-md">
              Copy
            </button>
          </div>
          <div id="t-fb" class="token-box text-xs text-yellow-300/80 rounded-lg p-3 max-h-28 overflow-auto"
               style="background:#0a0a14;border:1px solid rgba(234,179,8,0.15)"></div>
        </div>

        <!-- Tab: Quick Test -->
        <div id="tab-test-panel" class="hidden">
          <div class="grid grid-cols-2 gap-2 mb-3">
            <button onclick="runTest('GET','/api/v1/me')"
              class="text-xs bg-indigo-600/80 hover:bg-indigo-600 text-white py-2 rounded-lg transition-colors">
              GET /me
            </button>
            <button onclick="runTest('GET','/api/v1/me/roles')"
              class="text-xs bg-indigo-600/80 hover:bg-indigo-600 text-white py-2 rounded-lg transition-colors">
              GET /me/roles
            </button>
            <button onclick="runTest('GET','/api/v1/mangas')"
              class="text-xs bg-purple-600/80 hover:bg-purple-600 text-white py-2 rounded-lg transition-colors">
              GET /mangas
            </button>
            <button onclick="runTest('GET','/health')"
              class="text-xs bg-emerald-600/80 hover:bg-emerald-600 text-white py-2 rounded-lg transition-colors">
              GET /health
            </button>
          </div>
          <pre id="api-result"
               class="hidden text-xs text-gray-300 rounded-lg p-3 overflow-auto max-h-44"
               style="background:#0a0a14;border:1px solid rgba(255,255,255,0.08)"></pre>
        </div>

        <!-- Sign Out -->
        <button onclick="doSignOut()"
          class="mt-5 w-full text-sm text-gray-500 hover:text-white border border-white/10 hover:border-white/30
                 py-2 rounded-lg transition-colors">
          Sign Out
        </button>
      </div>

    </div>

    <p class="text-center text-gray-700 text-xs mt-5">Dev only &mdash; ไม่แสดงใน production</p>
  </div>

  <script>
    firebase.initializeApp({
      apiKey:            "AIzaSyDGJl4PAy_gimylpoEpp5avMXYjqowTDPE",
      authDomain:        "flutterapp-3d291.firebaseapp.com",
      projectId:         "flutterapp-3d291",
      storageBucket:     "flutterapp-3d291.firebasestorage.app",
      messagingSenderId: "843254746575",
      appId:             "1:843254746575:web:5b73c02b137c365f9396ba",
    });

    const auth = firebase.auth();
    let jwt = "";

    // ── panels ──────────────────────────────────────────────────
    function show(name) {
      ["login","loading","profile"].forEach(n =>
        document.getElementById("panel-"+n).classList.add("hidden")
      );
      document.getElementById("panel-"+name).classList.remove("hidden");
    }

    // ── tabs ─────────────────────────────────────────────────────
    function showTab(name) {
      ["jwt","fb","test"].forEach(t => {
        document.getElementById("tab-"+t+"-panel").classList.add("hidden");
        document.getElementById("tab-"+t).classList.remove("active","text-gray-300");
        document.getElementById("tab-"+t).classList.add("text-gray-500");
      });
      document.getElementById("tab-"+name+"-panel").classList.remove("hidden");
      document.getElementById("tab-"+name).classList.add("active","text-gray-300");
      document.getElementById("tab-"+name).classList.remove("text-gray-500");
    }

    // ── auth ──────────────────────────────────────────────────────
    async function doSignIn() {
      show("loading");
      document.getElementById("loading-msg").textContent = "กำลังเปิดหน้าต่าง Google...";
      try {
        await auth.signInWithPopup(new firebase.auth.GoogleAuthProvider());
      } catch(e) {
        show("login");
        showError(e.message);
      }
    }

    async function doSignOut() {
      await auth.signOut();
      show("login");
      document.getElementById("login-error").classList.add("hidden");
      document.getElementById("api-result").classList.add("hidden");
      jwt = "";
    }

    function showError(msg) {
      const el = document.getElementById("login-error");
      el.textContent = msg;
      el.classList.remove("hidden");
    }

    auth.onAuthStateChanged(async (user) => {
      if (!user) { show("login"); return; }
      show("loading");
      document.getElementById("loading-msg").textContent = "กำลังแลก JWT token...";
      try {
        const fbToken = await user.getIdToken(true);
        const res = await fetch("/auth/token", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ firebase_token: fbToken }),
        });
        if (!res.ok) throw new Error("/auth/token → " + res.status);
        const data = await res.json();
        jwt = data.access_token;

        document.getElementById("u-photo").src = user.photoURL || "https://ui-avatars.com/api/?name=" + encodeURIComponent(user.displayName||"?") + "&background=6366f1&color=fff";
        document.getElementById("u-name").textContent  = user.displayName || "Unknown";
        document.getElementById("u-email").textContent = user.email || "";
        document.getElementById("t-jwt").textContent = jwt;
        document.getElementById("t-fb").textContent  = fbToken;

        // role badge
        try {
          const p = JSON.parse(atob(jwt.split(".")[1]));
          const badge = document.getElementById("u-badge");
          if (p.is_admin) {
            badge.textContent = "Admin";
            badge.className = "text-xs font-bold px-2.5 py-0.5 rounded-full bg-red-500/20 text-red-300 border border-red-500/30";
          } else if (p.is_vip) {
            badge.textContent = "VIP";
            badge.className = "text-xs font-bold px-2.5 py-0.5 rounded-full bg-yellow-500/20 text-yellow-300 border border-yellow-500/30";
          } else {
            badge.textContent = "User";
            badge.className = "text-xs font-bold px-2.5 py-0.5 rounded-full bg-gray-500/20 text-gray-400 border border-gray-600/30";
          }
        } catch(_) {}

        showTab("jwt");
        show("profile");
      } catch(e) {
        await auth.signOut();
        show("login");
        showError("เกิดข้อผิดพลาด: " + e.message);
      }
    });

    // ── utilities ─────────────────────────────────────────────────
    async function copyEl(id, btn) {
      await navigator.clipboard.writeText(document.getElementById(id).textContent);
      const orig = btn.textContent;
      btn.textContent = "Copied ✓";
      btn.classList.add("text-green-400");
      setTimeout(() => { btn.textContent = orig; btn.classList.remove("text-green-400"); }, 1500);
    }

    async function runTest(method, path) {
      const box = document.getElementById("api-result");
      box.classList.remove("hidden");
      box.textContent = "Loading...";
      try {
        const res = await fetch(path, {
          method,
          headers: jwt ? { "Authorization": "Bearer " + jwt } : {},
        });
        const body = await res.json();
        // trim long arrays
        if (body.items && body.items.length > 3) body.items = body.items.slice(0,3).concat(["... +" + (body.items.length-3) + " more"]);
        box.textContent = method + " " + path + "  →  " + res.status + "\\n\\n" + JSON.stringify(body, null, 2);
      } catch(e) {
        box.textContent = "Error: " + e.message;
      }
    }
  </script>
</body>
</html>"""


@router.get("/demo-login", response_class=HTMLResponse, include_in_schema=False)
async def demo_login():
    return HTMLResponse(_HTML)
