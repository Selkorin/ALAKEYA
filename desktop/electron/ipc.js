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

  ipcMain.on('agent:open-settings', (_e, _tab) => {
    ctx.send('agent:open-settings', _tab || 'permissions');
  });

  // ── queries ───────────────────────────────────────────────
  ipcMain.handle('agent:get-status', () => agentStatus.current);
  ipcMain.handle('agent:get-activity', () => ctx.getLog());
}

module.exports = { registerIpc };
