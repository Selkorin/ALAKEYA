// ============================================================
// executors.js — the actuator layer (computer control).
//
// On a real Mac these call into the documented control cascade
// (DOC1/DOC2): Apple Events / AppleScript first, then Accessibility
// (AXUIElement), then clipboard + ⌘V, then CGEvent as last resort.
//
// Here they are SAFE SIMULATIONS so the full flow (orb states,
// permission gate, activity log) is demoable cross-platform and in CI.
// Swap each body for the native bridge when wiring the Swift/AX host.
// ============================================================
const { execFile } = require('child_process');
const { promisify } = require('util');
const pexecFile = promisify(execFile);

const IS_MAC = process.platform === 'darwin';
const SIMULATE = process.env.ALAKEYA_REAL_CONTROL !== '1';

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

/** Run an AppleScript snippet (used by several executors on macOS). */
async function osascript(script) {
  if (SIMULATE || !IS_MAC) {
    await wait(220);
    return { simulated: true, script };
  }
  const { stdout } = await pexecFile('osascript', ['-e', script]);
  return { stdout: stdout.trim() };
}

const EXECUTORS = {
  // ── low risk ──────────────────────────────────────────────
  async read_screen() {
    await wait(180);
    return { ok: true, summary: 'Прочитал активное окно (AX-дерево).' };
  },
  async screenshot() {
    await wait(180);
    return { ok: true, summary: 'Сделал снимок экрана для верификации.' };
  },
  async search(a) {
    await wait(200);
    return { ok: true, summary: `Поиск: ${a.query || a.text || ''}` };
  },

  // ── medium risk ───────────────────────────────────────────
  async open_app(a) {
    if (!SIMULATE && IS_MAC) await pexecFile('open', ['-a', a.app]);
    else await wait(300);
    return { ok: true, summary: `Открыл ${a.app}` };
  },
  async navigate_url(a) {
    await osascript(`tell application "Safari" to set URL of front document to "${a.url}"`);
    return { ok: true, summary: `Открыл ${a.url}` };
  },
  async type_text(a) {
    // Semantic-first in production: AXSetAttributeValue → paste → CGEvent.
    await osascript(`tell application "System Events" to keystroke ${JSON.stringify(a.text || '')}`);
    return { ok: true, summary: `Ввёл текст (${(a.text || '').length} симв.)` };
  },
  async click_element(a) {
    await wait(220);
    return { ok: true, summary: `Кликнул по «${a.text || a.target}»` };
  },
  async apple_script(a) {
    await osascript(a.script || 'return 1');
    return { ok: true, summary: a.title || 'Выполнил AppleScript' };
  },

  // ── high risk (always gated) ──────────────────────────────
  async send_message(a) {
    await wait(280);
    return { ok: true, summary: `Отправил сообщение в ${a.target}` };
  },
  async send_email(a) {
    await wait(280);
    return { ok: true, summary: `Отправил письмо: ${a.target}` };
  },
  async delete_file(a) {
    await wait(200);
    return { ok: true, summary: `Удалил ${a.target}` };
  },
  async run_shell(a) {
    await wait(200);
    return { ok: true, summary: `Выполнил команду: ${a.code || a.command}` };
  },
  async make_payment(a) {
    await wait(200);
    return { ok: true, summary: `Платёж: ${a.target}` };
  },
};

module.exports = { EXECUTORS, osascript, SIMULATE, IS_MAC };
