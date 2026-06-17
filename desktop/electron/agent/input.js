// ============================================================
// input.js — low-level keyboard/mouse via nut.js, with graceful
// fallback to AppleScript/clipboard when nut.js isn't installed or
// fails to load (e.g. native build missing). nut.js gives reliable,
// app-agnostic input without AppleScript's quirks.
// ============================================================
let nut = null;
let tried = false;

function load() {
  if (tried) return nut;
  tried = true;
  try {
    // @nut-tree-fork/nut-js is the free community fork.
    nut = require('@nut-tree-fork/nut-js');
    nut.keyboard.config.autoDelayMs = 2;
    nut.mouse.config.autoDelayMs = 4;
  } catch (e) {
    console.warn('[input] nut.js unavailable, falling back to AppleScript:', e.message);
    nut = null;
  }
  return nut;
}

const available = () => !!load();

async function typeText(text) {
  const n = load();
  if (!n) return false;
  await n.keyboard.type(text);
  return true;
}

async function pressEnter() {
  const n = load();
  if (!n) return false;
  await n.keyboard.pressKey(n.Key.Enter);
  await n.keyboard.releaseKey(n.Key.Enter);
  return true;
}

async function clickAt(x, y) {
  const n = load();
  if (!n) return false;
  await n.mouse.setPosition(new n.Point(x, y));
  await n.mouse.leftClick();
  return true;
}

async function click() {
  const n = load();
  if (!n) return false;
  await n.mouse.leftClick();
  return true;
}

module.exports = { available, typeText, pressEnter, clickAt, click };
