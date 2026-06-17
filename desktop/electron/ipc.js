// ============================================================
// ipc.js — wires the documented IPC channels (HANDOFF §6.4).
//   main → renderer : agent:status / transcript / task-update /
//                     action-requires-approval / action-result /
//                     error / activity
//   renderer → main : run-task / start-listening / stop-listening /
//                     cancel / approve-action / set-mode / get-* /
//                     open-settings
// ============================================================
const { ipcMain } = require('electron');
const { agentStatus, STATUS } = require('./agent/status');
const { runTask } = require('./agent/toolRunner');
const { resolveDecision } = require('./permissions');
const voice = require('./agent/voice');
const ctx = require('./context');

let listening = false;

function registerIpc() {
  // Broadcast every status change to the renderer.
  agentStatus.on('change', (s) => ctx.send('agent:status', s));

  // ── commands ──────────────────────────────────────────────
  ipcMain.on('agent:run-task', (_e, { text }) => {
    if (text && text.trim()) runTask(text.trim());
  });

  ipcMain.on('agent:start-listening', () => {
    listening = true;
    agentStatus.set(STATUS.LISTENING);
    // Real build: whisper.recordUntilSilence() + partial transcripts.
    ctx.send('agent:transcript', { text: '', partial: true });
  });

  ipcMain.on('agent:stop-listening', async () => {
    if (!listening) return;
    listening = false;
    // Real build: transcribe captured audio. Here we just go idle unless
    // the renderer already submitted text.
    agentStatus.set(STATUS.READY);
  });

  ipcMain.on('agent:cancel', () => {
    listening = false;
    agentStatus.set(STATUS.READY);
  });

  ipcMain.on('agent:approve-action', (_e, { id, decision }) => {
    resolveDecision(id, decision);
  });

  ipcMain.on('agent:set-mode', (_e, mode) => ctx.setMode(mode));

  ipcMain.on('agent:set-config', (_e, patch) => ctx.setConfig(patch || {}));

  ipcMain.on('agent:set-corner', (_e, corner) => moveToCorner(corner));

  ipcMain.on('agent:open-settings', (_e, _tab) => {
    ctx.send('agent:open-settings', _tab || 'permissions');
  });

  // ── voice ─────────────────────────────────────────────────
  // TTS: renderer asks main to synthesize; main returns base64 mp3 to play.
  ipcMain.handle('agent:tts', async (_e, text) => {
    try { return await voice.speak(text); }
    catch (e) { console.error('[tts]', e.message); return null; }
  });

  // STT: renderer sends recorded audio bytes; main returns recognized text.
  ipcMain.handle('agent:stt', async (_e, { bytes, mime }) => {
    try {
      const text = await voice.transcribe(Buffer.from(bytes), mime);
      return { ok: true, text };
    } catch (e) {
      console.error('[stt]', e.message);
      return { ok: false, error: e.message };
    }
  });

  // ── queries ───────────────────────────────────────────────
  ipcMain.handle('agent:get-status', () => agentStatus.current);
  ipcMain.handle('agent:get-activity', () => ctx.getLog());
}

// Reposition the overlay window into the chosen screen corner.
function moveToCorner(corner) {
  const { screen } = require('electron');
  const win = ctx.windows.orb;
  if (!win || win.isDestroyed()) return;
  const wa = screen.getPrimaryDisplay().workArea;
  const [w, h] = win.getSize();
  const m = 16;
  const pos = {
    'top-left':     [wa.x + m, wa.y + m],
    'top-right':    [wa.x + wa.width - w - m, wa.y + m],
    'bottom-left':  [wa.x + m, wa.y + wa.height - h - m],
    'bottom-right': [wa.x + wa.width - w - m, wa.y + wa.height - h - m],
  }[corner] || [wa.x + wa.width - w - m, wa.y + wa.height - h - m];
  win.setPosition(Math.round(pos[0]), Math.round(pos[1]), true);
}

module.exports = { registerIpc };
