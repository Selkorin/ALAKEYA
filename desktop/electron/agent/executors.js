// ============================================================
// executors.js — the actuator layer (real computer control).
//
// Control cascade on macOS (DOC1/DOC2):
//   Apple Events / AppleScript  →  `open`  →  clipboard + ⌘V  →  CGEvent.
//
// Real control is ON by default on macOS. Set ALAKEYA_REAL_CONTROL=0 to
// force safe simulation (used in CI / on non-mac dev machines). Every
// risky action is still gated by the permission layer before it runs.
// ============================================================
const { execFile } = require('child_process');
const { promisify } = require('util');
const pexecFile = promisify(execFile);
const input = require('./input'); // nut.js wrapper (with AppleScript fallback)

const IS_MAC = process.platform === 'darwin';
// Simulate only when explicitly disabled, or when not on macOS.
const SIMULATE = process.env.ALAKEYA_REAL_CONTROL === '0' || !IS_MAC;

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

/** Run an AppleScript snippet on macOS. */
async function osascript(script) {
  if (SIMULATE) { await wait(180); return { simulated: true, script }; }
  const { stdout } = await pexecFile('osascript', ['-e', script]);
  return { stdout: stdout.trim() };
}

/** Type text into the frontmost app. Prefers nut.js (reliable, app-agnostic);
 *  falls back to clipboard + ⌘V which preserves unicode and is fast. */
async function pasteText(text) {
  if (SIMULATE) { await wait(180); return; }
  if (input.available()) {
    if (await input.typeText(text)) return;
  }
  // Fallback: clipboard + paste.
  await new Promise((resolve, reject) => {
    const p = execFile('pbcopy', (e) => (e ? reject(e) : resolve()));
    p.stdin.end(text);
  });
  await osascript('tell application "System Events" to keystroke "v" using command down');
}

/** Press Return in the frontmost app (nut.js, else AppleScript key code 36). */
async function pressEnter() {
  if (SIMULATE) { await wait(60); return; }
  if (input.available() && await input.pressEnter()) return;
  await osascript('tell application "System Events" to key code 36');
}

const EXECUTORS = {
  // ── low risk ──────────────────────────────────────────────
  async read_screen() {
    if (SIMULATE) { await wait(160); return { ok: true, summary: 'Прочитал активное окно (симуляция).' }; }
    // Name + title of the frontmost window via Accessibility-lite AppleScript.
    const { stdout } = await osascript(
      'tell application "System Events" to get name of first application process whose frontmost is true'
    );
    return { ok: true, summary: `Активное приложение: ${stdout || '—'}` };
  },
  async screenshot() {
    if (SIMULATE) { await wait(160); return { ok: true, summary: 'Снимок экрана (симуляция).' }; }
    const out = `/tmp/alakeya-shot-${Date.now()}.png`;
    await pexecFile('screencapture', ['-x', out]);
    return { ok: true, summary: `Снимок экрана: ${out}` };
  },
  async search(a) {
    const query = a.query || a.text || '';
    if (SIMULATE) { await wait(180); return { ok: true, summary: `Поиск: ${query}` }; }
    const url = `https://www.google.com/search?q=${encodeURIComponent(query)}`;
    await pexecFile('open', [url]);
    return { ok: true, summary: `Поиск: ${query}` };
  },

  // ── medium risk (gated) ───────────────────────────────────
  async open_app(a) {
    if (SIMULATE) { await wait(220); return { ok: true, summary: `Открыл ${a.app} (симуляция)` }; }
    await pexecFile('open', ['-a', a.app]);
    return { ok: true, summary: `Открыл ${a.app}` };
  },
  async navigate_url(a) {
    if (SIMULATE) { await wait(200); return { ok: true, summary: `Открыл ${a.url} (симуляция)` }; }
    await pexecFile('open', [a.url]);
    return { ok: true, summary: `Открыл ${a.url}` };
  },
  async type_text(a) {
    await pasteText(a.text || '');
    return { ok: true, summary: `Ввёл текст (${(a.text || '').length} симв.)` };
  },
  async click_element(a) {
    if (SIMULATE) { await wait(200); return { ok: true, summary: `Кликнул по «${a.text || a.target}»` }; }
    // Best-effort: click a UI element by its title in the frontmost app.
    await osascript(
      `tell application "System Events" to tell (first application process whose frontmost is true) ` +
      `to click (first UI element whose name is ${JSON.stringify(a.text || a.target || '')})`
    );
    return { ok: true, summary: `Кликнул по «${a.text || a.target}»` };
  },
  async apple_script(a) {
    await osascript(a.script || 'return 1');
    return { ok: true, summary: a.title || 'Выполнил AppleScript' };
  },

  // ── high risk (always gated) ──────────────────────────────
  async send_message(a) {
    // Generic path: ensure text is in the field, then press Return.
    if (!SIMULATE) {
      if (a.text) await pasteText(a.text);
      await pressEnter();
    } else { await wait(240); }
    return { ok: true, summary: `Отправил сообщение в ${a.target || a.app || ''}`.trim() };
  },
  async send_email(a) {
    if (SIMULATE) { await wait(260); return { ok: true, summary: `Отправил письмо: ${a.target}` }; }
    await osascript('tell application "System Events" to keystroke "d" using {command down, shift down}'); // send in Mail
    return { ok: true, summary: `Отправил письмо: ${a.target}` };
  },
  async delete_file(a) {
    if (SIMULATE) { await wait(200); return { ok: true, summary: `Удалил ${a.target}` }; }
    await osascript(`tell application "Finder" to delete (POSIX file ${JSON.stringify(a.target)})`);
    return { ok: true, summary: `Переместил в Корзину: ${a.target}` };
  },
  async run_shell(a) {
    const cmd = a.code || a.command || '';
    if (SIMULATE) { await wait(200); return { ok: true, summary: `Выполнил: ${cmd}` }; }
    const { stdout } = await pexecFile('/bin/sh', ['-c', cmd]);
    return { ok: true, summary: `Выполнил: ${cmd}`, stdout };
  },
  async make_payment(a) {
    // Never executed automatically — surfaced for explicit human action.
    await wait(200);
    return { ok: true, summary: `Платёж требует ручного подтверждения: ${a.target}` };
  },
};

module.exports = { EXECUTORS, osascript, pasteText, pressEnter, SIMULATE, IS_MAC };
