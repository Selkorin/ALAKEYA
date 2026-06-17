// ============================================================
// context.js — shared runtime state for the main process.
// Avoids circular deps between ipc / toolRunner / windows.
// ============================================================
const path = require('path');
const fs = require('fs');
const { app } = require('electron');

const windows = { orb: null }; // BrowserWindow for the orb/panel overlay

let mode = 'manual'; // 'manual' | 'auto' — confirmation policy

function getMode() { return mode; }
function setMode(next) { mode = next === 'auto' ? 'auto' : 'manual'; }

// ── Runtime config (model / voice), pushed from the renderer's settings ──
const config = {
  model: process.env.ALAKEYA_MODEL || 'gpt-4o',
  apiKey: process.env.OPENAI_API_KEY || '',
  ttsEnabled: true,
  ttsVoice: 'onyx',     // deep, velvety, mature
  sttModel: 'whisper-1',
  speed: 1.0,
};
function getConfig() { return config; }
function setConfig(patch = {}) {
  for (const [k, v] of Object.entries(patch)) {
    if (v !== undefined && v !== null && v !== '') config[k] = v;
  }
}

function send(channel, payload) {
  const wc = windows.orb && !windows.orb.isDestroyed() ? windows.orb.webContents : null;
  wc?.send(channel, payload);
}

// ── Activity log (action journal, DOC1 §"наблюдаемость") ────
const log = [];

function logPath() {
  return path.join(app.getPath('userData'), 'alakeya-activity.json');
}

function loadLog() {
  try {
    const raw = JSON.parse(fs.readFileSync(logPath(), 'utf-8'));
    if (Array.isArray(raw)) log.push(...raw);
  } catch { /* first run */ }
}

function persistLog() {
  try {
    fs.mkdirSync(path.dirname(logPath()), { recursive: true });
    fs.writeFileSync(logPath(), JSON.stringify(log.slice(-500), null, 2));
  } catch (e) {
    console.error('[context] failed to persist log:', e.message);
  }
}

function addLog(entry) {
  const row = {
    id: `log_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
    time: Date.now(),
    ...entry,
  };
  log.push(row);
  persistLog();
  send('agent:activity', row);
  return row;
}

function getLog() { return log; }

module.exports = {
  windows, getMode, setMode, send, addLog, getLog, loadLog,
  getConfig, setConfig,
};
