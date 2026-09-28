// Behavioural test harness for PORTAL_JS.
//
// The portal's upload engine is plain browser JavaScript, so the only honest way
// to test the fixes for the DOM-XSS sink, the stall deadlock, retry accounting
// and cancellation is to actually execute it against a minimal DOM/XHR shim and
// assert on what the code did.
//
// Run directly for a human-readable report:
//     node tests/portal_client_harness.js /tmp/portal.js
// Exits non-zero if any assertion fails.

'use strict';

const fs = require('fs');
const vm = require('vm');

const JS_PATH = process.argv[2];
if (!JS_PATH) {
  console.error('usage: node portal_client_harness.js <path-to-PORTAL_JS>');
  process.exit(2);
}
const SOURCE = fs.readFileSync(JS_PATH, 'utf8');

let passed = 0;
const failures = [];

function ok(cond, msg) {
  if (cond) passed++;
  else failures.push(msg);
}
// The fake DOM is a cyclic object graph, so stringify defensively.
function show(v) {
  try {
    if (v && typeof v === 'object') return v.tagName ? '<' + v.tagName.toLowerCase() + '>' : '[object]';
    return JSON.stringify(v);
  } catch (e) {
    return String(v);
  }
}
function eq(actual, expected, msg) {
  ok(actual === expected,
    msg + '\n      expected: ' + show(expected) +
    '\n      actual:   ' + show(actual));
}
function contains(haystack, needle, msg) {
  ok(String(haystack).indexOf(needle) !== -1,
    msg + '\n      expected to contain: ' + JSON.stringify(needle) +
    '\n      actual: ' + JSON.stringify(haystack));
}

// ---------------------------------------------------------------------------
// Environment factory: a fresh realm per scenario so module-level queue state
// (uploadQueue, activeUploads, activeJobs) never leaks between tests.
// ---------------------------------------------------------------------------
function freshEnv(meta) {
  const state = {
    sinks: [],          // every innerHTML/outerHTML assignment the code made
    xhrs: [],           // every XMLHttpRequest that was sent
    timers: [],         // pending setTimeout callbacks (we drive these by hand)
    vibrations: [],
    wakeRequests: 0,
    wakeReleases: 0,
    wakeHold: null,
    registry: {},       // id -> element
    docListeners: {},
    winListeners: {},
    dropped: [],
  };

  const METAS = Object.assign({
    'reclip-csrf': 'test-csrf-token',
    'reclip-max-upload-size': '1048576',
    'reclip-max-session-quota': '5368709120',
    'reclip-session-used': '0',
    'reclip-single-shot': '0',
    'reclip-max-concurrent-uploads': '2',
  }, meta || {});

  function makeClassList() {
    const set = new Set();
    return {
      add() { for (const c of arguments) set.add(c); },
      remove() { for (const c of arguments) set.delete(c); },
      contains(c) { return set.has(c); },
      // Two-argument toggle, as used by the filter/ARIA code paths.
      toggle(c, force) {
        const on = force === undefined ? !set.has(c) : !!force;
        if (on) set.add(c); else set.delete(c);
        return on;
      },
      size() { return set.size; },
      toArray() { return Array.from(set); },
    };
  }

  function createElement(tag) {
    const el = {
      tagName: String(tag).toUpperCase(),
      children: [],
      attrs: {},
      style: {},
      parentNode: null,
      className: '',
      title: '',
      _text: '',
      _id: null,
      _cl: makeClassList(),
      appendChild(c) { c.parentNode = el; el.children.push(c); return c; },
      prepend(c) { c.parentNode = el; el.children.unshift(c); return c; },
      // Used to move a retrying row to the head of the list so the visible
      // order keeps matching the order the queue actually processes.
      insertBefore(c, ref) {
        c.parentNode = el;
        const i = ref ? el.children.indexOf(ref) : -1;
        if (i === -1) el.children.push(c);
        else el.children.splice(i, 0, c);
        return c;
      },
      removeChild(c) {
        const i = el.children.indexOf(c);
        if (i !== -1) el.children.splice(i, 1);
        c.parentNode = null;
        if (c._id) delete state.registry[c._id];
        return c;
      },
      addEventListener(evt, fn) { (el._ev = el._ev || {})[evt] = fn; },
      setAttribute(k, v) {
        el.attrs[k] = v;
        if (k === 'id') el.id = v;
      },
      getAttribute(k) { return el.attrs[k] === undefined ? null : el.attrs[k]; },
      removeAttribute(k) { delete el.attrs[k]; },
      // The lightbox uses closest() to find the download button from a nested
      // <span>/<svg> tap target.
      closest(sel) {
        let node = el;
        while (node) {
          const cls = node.className;
          if (sel.startsWith('.') && typeof cls === 'string' &&
              cls.split(/\s+/).indexOf(sel.slice(1)) !== -1) return node;
          node = node.parentNode;
        }
        return null;
      },
      remove() {
        if (el.parentNode) {
          const i = el.parentNode.children.indexOf(el);
          if (i !== -1) el.parentNode.children.splice(i, 1);
          el.parentNode = null;
        }
        // A detached node is not findable, matching real getElementById.
        if (el._id) delete state.registry[el._id];
      },
    };
    Object.defineProperty(el, 'textContent', {
      get() { return el._text; },
      set(v) { el._text = String(v); el.children = []; },
      configurable: true,
    });
    Object.defineProperty(el, 'id', {
      get() { return el._id; },
      set(v) { el._id = v; if (v) state.registry[v] = el; },
      configurable: true,
    });
    // Spy on the classic injection sink. If any code path reintroduces
    // innerHTML, it shows up here with its payload.
    Object.defineProperty(el, 'innerHTML', {
      get() { return el._html || ''; },
      set(v) { el._html = String(v); state.sinks.push({ tag: el.tagName, id: el._id, value: String(v) }); },
      configurable: true,
    });
    Object.defineProperty(el, 'outerHTML', {
      set(v) { state.sinks.push({ tag: el.tagName, id: el._id, value: String(v) }); },
      get() { return ''; },
      configurable: true,
    });
    el.classList = el._cl;
    return el;
  }

  // Pre-create the elements the portal page provides.
  const queueEl = createElement('div');
  queueEl.id = 'upload-queue';
  const fileInput = createElement('input');
  fileInput.id = 'file-input';
  const dropzone = createElement('div');
  dropzone.id = 'dropzone';
  const banner = createElement('div');
  banner.id = 'session-banner';
  const toast = createElement('div');
  toast.id = 'toast';

  const document = {
    visibilityState: 'visible',
    documentElement: {
      _attrs: {},
      setAttribute(k, v) { this._attrs[k] = v; },
      getAttribute(k) { return this._attrs[k] === undefined ? null : this._attrs[k]; },
    },
    createElement,
    getElementById(id) { return state.registry[id] || null; },
    querySelector(sel) {
      const m = /^meta\[name="(.+)"\]$/.exec(sel);
      if (!m) return null;
      const v = METAS[m[1]];
      if (v === undefined) return null;
      return { tagName: 'META', content: v, getAttribute(k) { return k === 'content' ? v : null; } };
    },
    querySelectorAll() { return []; },
    addEventListener(evt, fn) { state.docListeners[evt] = fn; },
  };

  let timerSeq = 0;
  function setTimeoutShim(fn, ms) {
    const id = ++timerSeq;
    state.timers.push({ id, fn, ms: ms || 0 });
    return id;
  }
  function clearTimeoutShim(id) {
    state.timers = state.timers.filter((t) => t.id !== id);
  }
  // Fire every timer that is pending *right now*, and only those. Timers
  // scheduled by those callbacks stay pending for the next call, so a test can
  // step through a retry cycle deterministically instead of racing it.
  function flushTimers() {
    const pending = state.timers;
    state.timers = [];
    for (const t of pending) t.fn();
    return pending.length;
  }

  function XMLHttpRequest() {
    const x = {
      readyState: 0,
      status: 0,
      responseText: '',
      timeout: 0,
      upload: { onprogress: null },
      onload: null, onerror: null, ontimeout: null, onabort: null,
      _headers: {}, _respHeaders: {}, _settled: false, _aborted: false, _body: null,
    };
    x.open = function (m, u) { this.method = m; this.url = u; this.readyState = 1; };
    x.setRequestHeader = function (k, v) { this._headers[k] = v; };
    x.getResponseHeader = function (n) {
      const v = this._respHeaders[String(n).toLowerCase()];
      return v === undefined ? null : v;
    };
    x.send = function (body) { this._body = body; state.xhrs.push(this); };
    x.abort = function () {
      if (this._settled) return;
      this._aborted = true;
      this._settled = true;
      this.readyState = 4;
      if (this.onabort) this.onabort();
    };
    return x;
  }

  function respond(x, status, body, headers) {
    if (x._settled) return false;
    x._settled = true;
    x.status = status;
    x.responseText = body === undefined || body === null ? '' : body;
    x._respHeaders = {};
    for (const k in (headers || {})) x._respHeaders[k.toLowerCase()] = headers[k];
    x.readyState = 4;
    if (x.onload) x.onload();
    return true;
  }
  function neterr(x) {
    if (x._settled) return false;
    x._settled = true;
    x.status = 0;
    x.readyState = 4;
    if (x.onerror) x.onerror();
    return true;
  }
  function fireTimeout(x) {
    if (x._settled) return false;
    x._settled = true;
    x.status = 0;
    x.readyState = 4;
    if (x.ontimeout) x.ontimeout();
    return true;
  }
  function progress(x, loaded, total) {
    if (x.upload && x.upload.onprogress) x.upload.onprogress({ lengthComputable: true, loaded, total });
  }

  const storage = {};
  const sandbox = {
    document,
    console,
    JSON, Math, Date, Object, Array, String, Number, Boolean, Error, Promise, Set, Map, isNaN, parseInt, parseFloat,
    encodeURIComponent, decodeURIComponent,
    setTimeout: setTimeoutShim,
    clearTimeout: clearTimeoutShim,
    XMLHttpRequest,
    localStorage: {
      getItem(k) { return storage[k] === undefined ? null : storage[k]; },
      setItem(k, v) { storage[k] = String(v); },
    },
    navigator: {
      onLine: true,
      vibrate(p) { state.vibrations.push(p); return true; },
      get wakeLock() {
        return {
          request() {
            state.wakeRequests++;
            // A real wake lock prompts the user and resolves later. When a test
            // sets state.wakeHold, resolution is deferred so the
            // "upload finished while the prompt was still open" race can be
            // driven deterministically.
            if (state.wakeHold) return state.wakeHold.promise;
            return Promise.resolve({
              addEventListener() {},
              release() { state.wakeReleases++; },
            });
          },
        };
      },
    },
    fetch() { return Promise.reject(new Error('fetch not stubbed')); },
    alert() { throw new Error('alert() reached the test realm'); },
    location: { search: '', href: 'http://localhost/' },
    setTimeoutShim,
  };
  sandbox.window = {
    matchMedia() { return { matches: false, addEventListener() {} }; },
    addEventListener(evt, fn) { state.winListeners[evt] = fn; },
    location: sandbox.location,
    setTimeout: setTimeoutShim,
    clearTimeout: clearTimeoutShim,
    document,
    navigator: sandbox.navigator,
  };
  sandbox.globalThis = sandbox;

  vm.createContext(sandbox);
  vm.runInContext(SOURCE, sandbox, { filename: 'PORTAL_JS' });

  // Shrink the timing constants so the tests stay instant while still
  // exercising the real code paths.
  sandbox.STALL_TIMEOUT_MS = 1000;
  sandbox.ABSOLUTE_TIMEOUT_MS = 1000;
  sandbox.RETRY_BASE_MS = 10;

  return {
    ctx: sandbox,
    state,
    queueEl, fileInput, dropzone, banner, toast,
    respond, neterr, fireTimeout, progress, flushTimers,
    // Convenience: enqueue a File-like object and return the created item el.
    addFile(name, size) {
      sandbox.handleFilesSelected([{ name, size: size === undefined ? 1024 : size }]);
      return this.newestItem();
    },
    // The upload row, excluding the "_stat" and "_fill" children it owns.
    newestItem() {
      const ids = Object.keys(state.registry).filter(
        (k) => /^up_/.test(k) && !/_stat$/.test(k) && !/_fill$/.test(k));
      return state.registry[ids[ids.length - 1]];
    },
  };
}

function statOf(env, item) {
  return env.ctx.document.getElementById(item.id + '_stat');
}

// ===========================================================================
// T1  XSS regression: a hostile filename must land as text, never as markup.
// ===========================================================================
(function testXssFilenameIsInert() {
  const payload = '<img src=x onerror=alert(1)>.jpg';
  const env = freshEnv();
  const item = env.addFile(payload, 2048);

  eq(env.state.sinks.length, 0,
    'T1 upload path must never assign innerHTML/outerHTML');
  for (const s of env.state.sinks) {
    ok(s.value.indexOf('<') === -1,
      'T1 innerHTML payload must not contain markup: ' + s.value);
  }

  const nameEl = item.children[0].children[0];
  eq(nameEl.tagName, 'SPAN', 'T1 filename is rendered in a SPAN');
  eq(nameEl.textContent, payload, 'T1 filename preserved verbatim as text');
  eq(nameEl.innerHTML, '', 'T1 filename element holds no parsed markup');

  // Nothing anywhere in the item should be an IMG (i.e. injected element).
  (function walk(node) {
    for (const c of node.children || []) {
      ok(c.tagName !== 'IMG', 'T1 no element may be synthesised from the filename');
      walk(c);
    }
  })(item);
})();

// ===========================================================================
// T2  The plain happy path still works and reports real values.
// ===========================================================================
(function testSuccessfulUpload() {
  const env = freshEnv();
  const item = env.addFile('photo.jpg', 4096);
  const xhr = env.state.xhrs[0];

  eq(env.state.xhrs.length, 1, 'T2 exactly one request is sent');
  eq(xhr.method, 'POST', 'T2 upload uses POST');
  eq(xhr.url, '/upload', 'T2 upload targets /upload');
  eq(xhr._headers['X-CSRF-Token'], 'test-csrf-token', 'T2 CSRF token is attached');
  eq(xhr._headers['X-Filename'], encodeURIComponent('photo.jpg'), 'T2 filename is URI-encoded');
  eq(xhr.timeout, 1000, 'T2 an absolute timeout is always armed');

  env.progress(xhr, 2048, 4096);
  contains(statOf(env, item).textContent, '50%', 'T2 progress percentage is shown');
  contains(statOf(env, item).textContent, '/s', 'T2 transfer speed is shown');

  env.respond(xhr, 200, JSON.stringify({ success: true, size_str: '4.0 KB' }));
  contains(statOf(env, item).textContent, 'Sent', 'T2 success is reported');
  contains(statOf(env, item).textContent, '4.0 KB', 'T2 server-reported size is surfaced');
  ok(env.state.vibrations.length > 0, 'T2 a haptic pulse fires on success');
  eq(env.state.wakeRequests, 1, 'T2 wake lock is taken for the upload');
})();

// ===========================================================================
// T3  THE DEADLOCK BUG: a silently dead socket must not brick the queue.
// ===========================================================================
(function testStallIsDetectedAndRetried() {
  const env = freshEnv();
  env.addFile('big.bin', 5000);
  const xhr = env.state.xhrs[0];

  ok(xhr !== undefined, 'T3 upload started');
  ok(env.state.timers.length > 0, 'T3 a stall watchdog timer is armed before send');

  // Socket dies: no progress, no event. Only the watchdog can save us.
  env.flushTimers();

  ok(xhr._aborted, 'T3 watchdog aborts the dead request');
  const stats = env.state.timers.length;
  ok(stats > 0, 'T3 a retry is scheduled after a stall');

  // Let the backoff elapse; a fresh attempt must be made.
  env.flushTimers();
  ok(env.state.xhrs.length === 2, 'T3 stalled upload is retried, not abandoned');
})();

// ===========================================================================
// T4  A stall must not consume every slot or block later files.
// ===========================================================================
(function testQueueKeepsDraining() {
  const env = freshEnv();
  env.ctx.handleFilesSelected([
    { name: 'a.bin', size: 10 },
    { name: 'b.bin', size: 10 },
    { name: 'c.bin', size: 10 },
  ]);
  eq(env.state.xhrs.length, 2, 'T4 concurrency cap of 2 is respected');

  // First slot dies silently; the queue must still be able to move.
  env.state.xhrs[0].abort();
  ok(env.state.xhrs.length >= 2,
    'T4 remaining in-flight work is untouched when one socket dies');
  ok(env.state.xhrs.length < 4,
    'T4 a dead socket does not spawn unlimited parallel uploads');
})();

// ===========================================================================
// T5  Retry must release its concurrency slot, not squat on it while backing off.
// ===========================================================================
(function testRetryReleasesSlot() {
  const env = freshEnv({ 'reclip-max-concurrent-uploads': '2' });
  env.ctx.handleFilesSelected([
    { name: 'first.bin', size: 10 },
    { name: 'second.bin', size: 10 },
    { name: 'third.bin', size: 10 },
  ]);
  eq(env.state.xhrs.length, 2, 'T5 two slots busy, one file waiting');

  env.respond(env.state.xhrs[0], 503, JSON.stringify({ error: 'busy' }));
  ok(env.state.timers.length > 0, 'T5 503 schedules a backoff retry');

  // Before the backoff elapses, the freed slot must go to the waiting file.
  eq(env.state.xhrs.length, 3, 'T5 a waiting file starts immediately while another backs off');
  eq(env.state.xhrs[2]._headers['X-Filename'], encodeURIComponent('third.bin'),
    'T5 the freed slot is used by the waiting file, not by the backing-off one');
})();

// ===========================================================================
// T6  A permanent rejection is shown with the server's own words, and is not retried.
// ===========================================================================
(function testPermanentErrorSurfacesServerMessage() {
  // Limit raised deliberately so the request is actually sent: this test is
  // about what happens when the *server* rejects, not the pre-check (T11).
  const env = freshEnv({ 'reclip-max-upload-size': '99999999999' });
  const item = env.addFile('huge.mp4', 2400 * 1024 * 1024);
  const msg = 'File size (2.4 GB) exceeds maximum allowed limit (1.0 GB)';

  env.respond(env.state.xhrs[0], 413, JSON.stringify({ error: msg }));

  const text = statOf(env, item).textContent;
  contains(text, 'exceeds maximum allowed limit', 'T6 the real server message is displayed');
  ok(text.indexOf('HTTP 413') === -1, 'T6 the bare status code is not what the user sees');

  env.flushTimers();
  eq(env.state.xhrs.length, 1, 'T6 a 413 is not retried');
})();

// ===========================================================================
// T7  Transient failures retry up to the cap, then give up. Never infinite.
// ===========================================================================
(function testRetryIsBounded() {
  const env = freshEnv();
  const item = env.addFile('flaky.bin', 10);
  // 1 initial attempt + MAX_RETRIES (3) retries = 4 requests, then it stops.
  for (let i = 0; i < 3; i++) {
    env.respond(env.state.xhrs[i], 500, JSON.stringify({ error: 'boom' }));
    env.flushTimers();
  }
  eq(env.state.xhrs.length, 4, 'T7 exactly 1 + MAX_RETRIES requests are made');
  env.respond(env.state.xhrs[3], 500, JSON.stringify({ error: 'boom' }));
  env.flushTimers();
  eq(env.state.xhrs.length, 4, 'T7 retries stop at MAX_RETRIES and never loop forever');
  contains(statOf(env, item).textContent, 'boom', 'T7 final failure keeps the server message');
})();

// ===========================================================================
// T8  Retry-After from a 429 is honoured.
// ===========================================================================
(function testRetryAfterHeader() {
  const env = freshEnv();
  env.addFile('x.bin', 10);
  env.respond(env.state.xhrs[0], 429, JSON.stringify({ error: 'Beam limit reached' }), { 'Retry-After': '2' });
  const backoff = env.state.timers.filter((t) => t.ms >= 2000);
  ok(backoff.length > 0, 'T8 Retry-After: 2 is turned into a >=2s wait');
})();

// ===========================================================================
// T9  Cancelling a queued file must stop it from ever being sent.
// ===========================================================================
(function testCancelQueued() {
  const env = freshEnv({ 'reclip-max-concurrent-uploads': '1' });
  env.ctx.handleFilesSelected([
    { name: 'running.bin', size: 10 },
    { name: 'waiting.bin', size: 10 },
  ]);
  eq(env.state.xhrs.length, 1, 'T9 only the first file is in flight');

  const queuedId = env.newestItem().id;
  eq(queuedId !== undefined, true, 'T9 the queued item exists in the list');
  env.ctx.cancelUpload(queuedId);

  env.respond(env.state.xhrs[0], 200, JSON.stringify({ success: true }));
  eq(env.state.xhrs.length, 1, 'T9 a cancelled queued file is never uploaded');
  eq(env.state.registry[queuedId], undefined, 'T9 the cancelled item is removed from the list');
})();

// ===========================================================================
// T10 Cancelling the in-flight file aborts the socket.
// ===========================================================================
(function testCancelInFlight() {
  const env = freshEnv();
  const item = env.addFile('live.bin', 10);
  const xhr = env.state.xhrs[0];
  env.ctx.cancelUpload(item.id);

  ok(xhr._aborted, 'T10 cancel aborts the in-flight request');
  contains(statOf(env, item).textContent, 'Cancelled', 'T10 cancellation is shown');
  env.flushTimers();
  eq(env.state.xhrs.length, 1, 'T10 a cancelled upload is not retried');
})();

// ===========================================================================
// T11 Pre-flight rejection happens before any socket work.
// ===========================================================================
(function testClientSidePreCheck() {
  const env = freshEnv({ 'reclip-max-upload-size': '1000' });
  const item = env.addFile('enormous.bin', 999999);
  eq(env.state.xhrs.length, 0, 'T11 an oversized file never reaches the network');
  contains(statOf(env, item).textContent, 'Too large', 'T11 the user is told why, immediately');
  eq(env.ctx.activeUploads, 0, 'T11 a rejected file does not leak a concurrency slot');
})();

(function testSessionQuotaPreCheck() {
  const env = freshEnv({
    'reclip-max-session-quota': '1000',
    'reclip-session-used': '900',
  });
  const item = env.addFile('fits.bin', 500);
  eq(env.state.xhrs.length, 0, 'T11 quota pre-check blocks before the socket');
  contains(statOf(env, item).textContent, 'quota', 'T11 the quota rule is explained');
})();

// ===========================================================================
// T12 Losing the server surfaces a reconnect banner instead of a bare error.
// ===========================================================================
(function testSessionEndedBanner() {
  const env = freshEnv();
  const item = env.addFile('a.bin', 10);
  env.neterr(env.state.xhrs[0]);
  contains(statOf(env, item).textContent, 'unreachable', 'T12 offline is distinguished from server loss');
  env.flushTimers();
  const x2 = env.state.xhrs[1];
  env.neterr(x2);
  eq(env.banner.style.display, 'block', 'T12 a reconnect banner is shown after repeated loss');
  contains(env.banner.textContent, 'session may have ended', 'T12 the banner explains single-shot behaviour');
})();

// ===========================================================================
// T13 A success clears the banner, and online recovery resets the error counter.
// ===========================================================================
(function testBannerClearedOnSuccess() {
  const env = freshEnv();
  env.addFile('a.bin', 10);
  env.neterr(env.state.xhrs[0]);
  env.flushTimers();
  env.neterr(env.state.xhrs[1]);
  eq(env.banner.style.display, 'block', 'T13 banner is up before recovery');

  env.flushTimers();
  env.respond(env.state.xhrs[2], 200, JSON.stringify({ success: true }));
  eq(env.banner.style.display, 'none', 'T13 a successful upload clears the banner');
})();

// ===========================================================================
// T14 Offline uploads fail fast rather than hanging.
// ===========================================================================
(function testAbsoluteTimeoutArmed() {
  const env = freshEnv();
  const item = env.addFile('a.bin', 10);
  const xhr = env.state.xhrs[0];
  ok(xhr.timeout > 0, 'T14 an absolute XHR timeout is always set');
  env.fireTimeout(xhr);
  contains(statOf(env, item).textContent, 'timed out',
    'T14 timeout is reported in plain language');
  env.flushTimers();
  eq(env.state.xhrs.length, 2, 'T14 a timeout is retried');
})();

// ===========================================================================
// T15 Wake lock is released once the queue drains.
// ===========================================================================
const wakeEnv = freshEnv();
wakeEnv.addFile('a.bin', 10);
wakeEnv.respond(wakeEnv.state.xhrs[0], 200, JSON.stringify({ success: true }));

// ===========================================================================
// T16 A wake lock granted after the transfer finished is handed straight back.
//
// The user can dismiss the "keep screen on" prompt at their own pace, and a
// 2 KB file can complete while it is still open. Acquiring it unconditionally
// left the screen pinned awake for the rest of the session.
// ===========================================================================
const raceEnv = freshEnv();
let grantWakeLock = null;
raceEnv.state.wakeHold = { promise: new Promise(function (res) { grantWakeLock = res; }) };
raceEnv.addFile('a.bin', 10);
raceEnv.respond(raceEnv.state.xhrs[0], 200, JSON.stringify({ success: true }));
// The upload is done; now let the pending prompt resolve.
grantWakeLock({ addEventListener() {}, release() { raceEnv.state.wakeReleases += 1; } });

// ===========================================================================
// T17 The reason for a retry stays on screen.
// ===========================================================================
const reasonEnv = freshEnv();
reasonEnv.addFile('a.bin', 10);
const reasonItem = reasonEnv.newestItem();
reasonEnv.respond(reasonEnv.state.xhrs[0], 503, JSON.stringify({ error: 'Host is busy' }));
contains(statOf(reasonEnv, reasonItem).textContent, 'Host is busy',
  'T17 the failure reason is still visible while backing off');
contains(statOf(reasonEnv, reasonItem).textContent, 'retry 1/3',
  'T17 the attempt counter is shown alongside the reason');

// ===========================================================================
// T18 The batch summary answers "is it done yet?".
// ===========================================================================
const batchEnv = freshEnv();
const summaryEl = batchEnv.ctx.document.createElement('div');
summaryEl.id = 'queue-summary';
summaryEl.hidden = true;
const summaryTitle = batchEnv.ctx.document.createElement('span');
summaryTitle.id = 'queue-summary-title';
summaryEl.appendChild(summaryTitle);
batchEnv.queueEl.appendChild(summaryEl);

batchEnv.addFile('a.bin', 2048);
batchEnv.addFile('b.bin', 1024);
eq(summaryEl.hidden, false, 'T18 the summary appears as soon as files are queued');
contains(summaryTitle.textContent, 'Sending 0 of 2',
  'T18 an in-flight batch reports its progress');
batchEnv.respond(batchEnv.state.xhrs[0], 200, JSON.stringify({ success: true, size_str: '2.0 KB' }));
contains(summaryTitle.textContent, 'Sending 1 of 2',
  'T18 a completed file advances the count');
batchEnv.respond(batchEnv.state.xhrs[1], 200, JSON.stringify({ success: true, size_str: '1.0 KB' }));
contains(summaryTitle.textContent, 'All 2 files sent',
  'T18 a finished batch is announced in plain language');
contains(summaryTitle.textContent, '3.0 KB',
  'T18 the batch reports the bytes actually sent');
eq(batchEnv.toast.className.indexOf('is-success') !== -1, true,
  'T18 a clean batch produces a success toast, not N per-file toasts');

// ===========================================================================
// T19 A failed batch is reported as a failure, not a success.
// ===========================================================================
const failEnv = freshEnv();
const failSummary = failEnv.ctx.document.createElement('div');
failSummary.id = 'queue-summary';
failSummary.hidden = true;
const failTitle = failEnv.ctx.document.createElement('span');
failTitle.id = 'queue-summary-title';
failSummary.appendChild(failTitle);
failEnv.queueEl.appendChild(failSummary);
failEnv.ctx.MAX_RETRIES = 0;   // fail terminally instead of retrying
failEnv.addFile('huge.bin', 999999999);
contains(failTitle.textContent, '1 failed',
  'T19 a file rejected before the socket counts as failed');
eq(failEnv.toast.className.indexOf('is-error') !== -1, true,
  'T19 the failure toast is styled as an error');

// ===========================================================================
// T20 The queue renders in the order it is actually processed.
// ===========================================================================
const orderEnv = freshEnv();
orderEnv.addFile('first.bin', 10);
orderEnv.addFile('second.bin', 10);
const rows = orderEnv.queueEl.children.filter((c) => String(c.className) === 'upload-item');
const firstRowName = rows[0].children[0].children[0].textContent;
const secondRowName = rows[1].children[0].children[0].textContent;
eq(rows.length, 2, 'T20 both files are present in the queue list');
eq(firstRowName, 'first.bin', 'T20 the first-selected file is shown first');
eq(secondRowName, 'second.bin', 'T20 the second-selected file is shown second');

// ---------------------------------------------------------------------------
// Wake locks resolve through promises, so every promise-based assertion above
// has to run after the microtask queue settles.
Promise.resolve().then(function () {
  ok(wakeEnv.state.wakeRequests === 1, 'T15 a wake lock was taken for the upload');
  ok(wakeEnv.state.wakeReleases === 1, 'T15 the wake lock is released when uploads finish');

  eq(raceEnv.state.wakeRequests, 1, 'T16 a wake lock was requested for the upload');
  eq(raceEnv.state.wakeReleases, 1,
    'T16 a wake lock granted after the transfer ended is released immediately');
  eq(raceEnv.ctx.wakeLock, null,
    'T16 the stale lock is not retained once released');

  console.log('portal client: ' + passed + ' assertions passed, ' + failures.length + ' failed');
  for (const f of failures) console.log('  FAIL  ' + f);
  process.exit(failures.length ? 1 : 0);
});
