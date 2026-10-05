// Shared code for every Innovation Hub page.
// Load order on each page: js/config.js, js/hub.js (and js/data.js where projects are shown)
//
// Login: the Hub uses Digital Design Explorer accounts (USN + email + password).
//  * If the student is already logged in on Explorer (same website domain), that login is reused.
//  * Logging in on the Hub creates a Hub-only session, so Explorer's own progress saving
//    is never touched.

const HUB_TOKEN = 'hubSessionToken';      // session created by the Hub login page
const TEACHER_TOKEN = 'hubTeacherToken';  // faculty session (this browser tab only)

function lget(k){ try{ return localStorage.getItem(k); }catch(e){ return null; } }
function lset(k,v){ try{ v==null ? localStorage.removeItem(k) : localStorage.setItem(k,v); }catch(e){} }
function sget(k){ try{ return sessionStorage.getItem(k); }catch(e){ return null; } }
function sset(k,v){ try{ v==null ? sessionStorage.removeItem(k) : sessionStorage.setItem(k,v); }catch(e){} }

// Which student session to use: the Hub's own, else an active Explorer login
function studentToken(){
  if (lget(HUB_TOKEN)) return { token: lget(HUB_TOKEN), source: 'hub' };
  if (lget('studentLoggedIn') === 'true' && lget('ddeSessionToken')) return { token: lget('ddeSessionToken'), source: 'explorer' };
  return null;
}
function teacherToken(){ return sget(TEACHER_TOKEN); }

// Escape any text typed by users before putting it into the page
function esc(v){
  return String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

// Call a Supabase function (same way Explorer does)
async function rpc(name, args){
  let res;
  try{
    res = await fetch(SUPABASE_URL + '/rest/v1/rpc/' + name, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY, Authorization: 'Bearer ' + SUPABASE_ANON_KEY },
      body: JSON.stringify(args || {})
    });
  }catch(e){ throw new Error('No internet connection. Please try again.'); }
  const txt = await res.text();
  let data; try{ data = txt ? JSON.parse(txt) : null; }catch(e){ data = txt; }
  if (res.ok) return data;
  const m = (data && data.message) || txt || ('Error ' + res.status);
  if (res.status === 404 || /PGRST202|Could not find the function/i.test(m))
    throw new Error('The Hub database is not set up yet. Faculty: run supabase/hub_setup.sql in Supabase.');
  throw new Error(m);
}
// Student call: adds the session token
async function srpc(name, args){
  const t = studentToken();
  if (!t) throw new Error('Please log in again (your session has ended).');
  try{ return await rpc(name, Object.assign({ p_token: t.token }, args || {})); }
  catch(e){ if (/log in again/i.test(e.message) && t.source === 'hub') lset(HUB_TOKEN, null); throw e; }
}
// Faculty call
async function trpc(name, args){
  return rpc(name, Object.assign({ p_token: teacherToken() || '' }, args || {}));
}

function errText(e){ return (e && e.message) || String(e); }

function msg(el, text, kind){
  if (!el) return;
  el.className = 'msg ' + (kind || '');
  el.textContent = text || '';
  el.hidden = !text;
}

async function logout(){
  const t = studentToken();
  if (t && t.source === 'explorer'){
    if (!confirm('You are logged in through Digital Design Explorer. Logging out here also logs you out of Explorer on this device. Continue?')) return;
    lset('studentLoggedIn', null); lset('ddeSessionToken', null);       // same as Explorer's logout
  }
  if (t) { try{ await rpc('dde_logout', { p_token: t.token }); }catch(e){} }
  lset(HUB_TOKEN, null);
  location.href = 'index.html';
}

// ---------- Explorer level locks: read live from Explorer's access-control.js ----------
let EXPLORER_RELEASED = new Set(EXPLORER_RELEASED_FALLBACK);
async function loadExplorerAccess(){
  try{
    const r = await fetch(EXPLORER_BASE + 'access-control.js', { cache: 'no-store' });
    if (!r.ok) return;
    const m = (await r.text()).match(/LEVEL_ACCESS\s*=\s*\{([\s\S]*?)\};/);
    if (!m) return;
    const set = new Set();
    m[1].replace(/level(\d+)\s*:\s*true/g, (_, n) => set.add(+n));
    EXPLORER_RELEASED = set;
  }catch(e){ /* keep fallback */ }
}

// Explorer link for a topic (one-way link)
function topicLink(topic){
  const t = EXPLORER_TOPICS[topic];
  if (!t) return '';
  const open = EXPLORER_RELEASED.has(t.level);
  const partB = t.level >= 7;
  let href = t.page, label = esc(topic), extra = '', cls = '';
  if (!open && t.alt){ href = t.alt; extra = ' <span class="lock">lab</span>'; }
  else if (!open){ cls = 'locked'; extra = ` <span class="lock">🔒 Level ${t.level}</span>`; }
  else if (partB){ extra = ' <span class="lock">Part B</span>'; }
  const title = !open && !t.alt ? `Level ${t.level} opens when your faculty releases it`
              : !open ? `Level ${t.level} is not released yet, so this opens the Digital Logic Lab section`
              : partB ? 'Part B needs Part B access from your faculty' : '';
  return `<a class="${cls}" href="${EXPLORER_BASE + href}" target="_blank" rel="noopener" title="${esc(title)}">${label}${extra} ↗</a>`;
}

// ---------- Same header and footer on every page ----------
async function renderShell(active){
  const accessReady = loadExplorerAccess();
  const t = studentToken();
  const links = [['index.html','Home'],['projects.html','Projects'],['student.html','My Team'],['certificate.html','Certificates'],['faculty.html','Faculty']];
  const header = document.createElement('header');
  header.innerHTML = `
    <a class="brand" href="index.html"><svg class="logo" viewBox="0 0 40 40" aria-hidden="true"><g stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M14 4v5M20 4v5M26 4v5M14 31v5M20 31v5M26 31v5M4 14h5M4 20h5M4 26h5M31 14h5M31 20h5M31 26h5"/></g><rect x="9" y="9" width="22" height="22" rx="4" fill="currentColor"/><path d="M15 25V15h5a5 5 0 0 1 0 10z" fill="none" stroke="#F5F6F2" stroke-width="2.4"/></svg><span>Digital-VLSI Innovation Hub<small>Design • Innovate • Research</small></span></a>
    <nav>
      ${links.map(([h,l]) => `<a href="${h}" ${h===active?'class="active"':''}>${l}</a>`).join('')}
      <a class="explorer-nav" href="${EXPLORER_BASE}" target="_blank" rel="noopener">Digital Design Explorer ↗</a>
      ${t ? '<button class="linkbtn" id="logoutBtn">Log out</button>' : `<a href="login.html" ${active==='login.html'?'class="active"':''}>Log in</a>`}
    </nav>`;
  document.body.prepend(header);
  const lb = document.getElementById('logoutBtn'); if (lb) lb.onclick = logout;
  const footer = document.createElement('footer');
  footer.textContent = 'Digital-VLSI Innovation Hub · Faculty / Mentor: Mrs. Padma R, Assistant Professor, Department of ECE, GSSSIETW, Mysuru';
  document.body.append(footer);
  await accessReady;
  return t;
}

const STATUS_CLASS = {
  'Forming':'s-grey','Selected':'s-blue','Pending Approval':'s-amber','Changes Required':'s-red',
  'Approved':'s-green','Ready for Final Review':'s-amber','Completed':'s-green'
};
function statusBadge(s){ return `<span class="status ${STATUS_CLASS[s]||'s-grey'}">${esc(s)}</span>`; }
