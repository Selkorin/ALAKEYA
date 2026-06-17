// ============================================================
// main.js — Electron entry. Creates the floating overlay window
// per HANDOFF §5.2 (transparent · frameless · always-on-top · vibrancy).
// ============================================================
const path = require('path');
require('./env').loadEnv(); // load desktop/.env (OPENAI_API_KEY, …) before anything reads it
const { app, BrowserWindow, systemPreferences } = require('electron');
const ctx = require('./context');
const { registerIpc } = require('./ipc');
const { attachSnap } = require('./snap');

const WIN = { width: 400, height: 600 };
const isDev = !app.isPackaged;
const DEV_URL = process.env.ELECTRON_RENDERER_URL || 'http://localhost:5173';

function createOrbWindow() {
  const { screen } = require('electron');
  const { width: sw, height: sh } = screen.getPrimaryDisplay().workAreaSize;

  const win = new BrowserWindow({
    width: WIN.width,
    height: WIN.height,
    x: sw - WIN.width - 16,
    y: sh - WIN.height - 16,
    frame: false,
    transparent: true,
    // Fully transparent backing — the rounded glass panel paints its own
    // blur via CSS backdrop-filter. (Do NOT set `vibrancy`: it fills the
    // ENTIRE window with an opaque material, producing a black rectangle
    // behind the panel.)
    backgroundColor: '#00000000',
    resizable: false,
    hasShadow: false,
    alwaysOnTop: true,
    skipTaskbar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  win.setAlwaysOnTop(true, 'screen-saver');
  if (process.platform === 'darwin') {
    win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  }

  if (isDev) {
    win.loadURL(DEV_URL);
  } else {
    win.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));
  }

  ctx.windows.orb = win;
  attachSnap(win, WIN);
  win.on('closed', () => { ctx.windows.orb = null; });
  return win;
}

app.whenReady().then(() => {
  ctx.loadLog();
  registerIpc();
  createOrbWindow();

  // Microphone access for voice input (DOC2 onboarding step 3).
  if (process.platform === 'darwin') {
    systemPreferences.askForMediaAccess?.('microphone').catch(() => {});
  }

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createOrbWindow();
  });
});

// Overlay companion stays resident; keep running with no windows on macOS.
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
