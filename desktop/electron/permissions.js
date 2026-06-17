// ============================================================
// permissions.js — risk classifier + confirmation gate + rule store.
//
// Implements HANDOFF.md §6.2 (classifyRisk), §6.3 (shouldAutoConfirm)
// and wai-agent-integration.md §2.3 (askUser / pending map).
//
// `askUser` returns a Promise that resolves when the renderer sends back
// a decision ('once' | 'always' | 'deny') for the PermissionCard.
// ============================================================
const path = require('path');
const fs = require('fs');
const { app } = require('electron');

// ── Risk tables ─────────────────────────────────────────────
const HIGH_RISK_ACTIONS = new Set([
  'send_email', 'send_message', 'delete_file',
  'run_shell', 'make_payment', 'submit_form',
]);
const MEDIUM_RISK_ACTIONS = new Set([
  'open_app', 'click_element', 'type_text', 'drag_drop',
  'apple_script', 'navigate_url',
]);
// everything else (read_screen, parse_page, search, screenshot…) → low

function classifyRisk(action) {
  if (HIGH_RISK_ACTIONS.has(action.type)) return 'high';
  if (MEDIUM_RISK_ACTIONS.has(action.type)) return 'medium';
  return 'low';
}

function isReversible(action) {
  return !HIGH_RISK_ACTIONS.has(action.type);
}

// ── Manual vs Auto decision (HANDOFF §6.3) ──────────────────
function shouldAutoConfirm(risk, mode, rememberedRules, action) {
  // Hard limits — never auto-confirm, regardless of mode.
  if (action.type === 'send_email') return false;
  if (action.type === 'delete_file') return false;
  if (action.type === 'make_payment') return false;

  const key = `${action.type}:${action.target}`;
  if (rememberedRules.has(key)) return true;

  if (mode === 'manual') return false;
  if (mode === 'auto' && risk === 'low') return true;
  if (mode === 'auto' && risk === 'medium') return false; // auto still asks on medium
  return false;
}

// ── Remembered-rules persistence (electron-store-lite) ──────
function rulesPath() {
  return path.join(app.getPath('userData'), 'alakeya-rules.json');
}

function loadRules() {
  try {
    const raw = JSON.parse(fs.readFileSync(rulesPath(), 'utf-8'));
    return new Set(Array.isArray(raw) ? raw : []);
  } catch {
    return new Set();
  }
}

const rememberedRules = loadRules();

function saveRules() {
  try {
    fs.mkdirSync(path.dirname(rulesPath()), { recursive: true });
    fs.writeFileSync(rulesPath(), JSON.stringify([...rememberedRules], null, 2));
  } catch (e) {
    console.error('[permissions] failed to persist rules:', e.message);
  }
}

// ── askUser — bridge a pending approval to the renderer ─────
const pending = new Map(); // id → resolve fn

function askUser(targetWebContents, action) {
  return new Promise((resolve) => {
    const id = `act_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
    pending.set(id, resolve);
    targetWebContents?.send('agent:action-requires-approval', {
      id,
      type: action.type,
      title: action.title,
      description: action.description,
      target: action.target,
      risk: classifyRisk(action),
      reversible: isReversible(action),
      scope: action.scope,
      code: action.code || null,
    });
  });
}

/** Renderer → main: resolve a pending approval. */
function resolveDecision(id, decision) {
  const resolve = pending.get(id);
  if (!resolve) return;
  pending.delete(id);
  resolve(decision); // 'once' | 'always' | 'deny'
}

module.exports = {
  classifyRisk,
  isReversible,
  shouldAutoConfirm,
  rememberedRules,
  saveRules,
  askUser,
  resolveDecision,
  HIGH_RISK_ACTIONS,
  MEDIUM_RISK_ACTIONS,
};
