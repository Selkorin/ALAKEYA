// ============================================================
// preload.js — contextBridge → window.api (HANDOFF §6.4).
// ============================================================
const { contextBridge, ipcRenderer } = require('electron');

const on = (channel) => (cb) => {
  const handler = (_e, payload) => cb(payload);
  ipcRenderer.on(channel, handler);
  return () => ipcRenderer.removeListener(channel, handler);
};

contextBridge.exposeInMainWorld('api', {
  // listeners (main → renderer)
  onStatus: on('agent:status'),
  onTranscript: on('agent:transcript'),
  onTask: on('agent:task-update'),
  onApproval: on('agent:action-requires-approval'),
  onError: on('agent:error'),
  onActivity: on('agent:activity'),
  onOpenSettings: on('agent:open-settings'),

  // commands (renderer → main)
  runTask: (text) => ipcRenderer.send('agent:run-task', { text }),
  startListening: () => ipcRenderer.send('agent:start-listening'),
  stopListening: () => ipcRenderer.send('agent:stop-listening'),
  cancel: () => ipcRenderer.send('agent:cancel'),
  approveAction: (id, decision) => ipcRenderer.send('agent:approve-action', { id, decision }),
  denyAction: (id) => ipcRenderer.send('agent:approve-action', { id, decision: 'deny' }),
  setMode: (mode) => ipcRenderer.send('agent:set-mode', mode),
  setConfig: (patch) => ipcRenderer.send('agent:set-config', patch),
  setCorner: (corner) => ipcRenderer.send('agent:set-corner', corner),
  openSettings: (tab) => ipcRenderer.send('agent:open-settings', tab),

  // voice
  tts: (text) => ipcRenderer.invoke('agent:tts', text),
  stt: (bytes, mime) => ipcRenderer.invoke('agent:stt', { bytes, mime }),

  // queries
  getStatus: () => ipcRenderer.invoke('agent:get-status'),
  getActivity: () => ipcRenderer.invoke('agent:get-activity'),
});
