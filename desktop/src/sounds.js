// ============================================================
// sounds.js — tiny synthesized UI sound library (Web Audio).
// No asset files / no network: each cue is a short, soft envelope
// of sine/triangle tones so it feels calm and "premium".
//   wake      — Alakeya appears / starts listening (pleasant rising chime)
//   listen    — mic opened (soft blip)
//   send      — task submitted
//   success   — task done (two-note up)
//   error     — something blocked (gentle low)
//   sleep     — goes idle/asleep (soft descending)
// Respect a global enable flag set from settings.
// ============================================================

let ctx = null;
let enabled = true;

export function setSoundEnabled(v) { enabled = !!v; }

function ac() {
  if (typeof window === 'undefined') return null;
  if (!ctx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
  }
  if (ctx.state === 'suspended') ctx.resume().catch(() => {});
  return ctx;
}

// One soft tone with an attack/decay envelope.
function tone(freq, start, dur, { type = 'sine', gain = 0.12 } = {}) {
  const a = ac(); if (!a) return;
  const t0 = a.currentTime + start;
  const osc = a.createOscillator();
  const g = a.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, t0);
  g.gain.setValueAtTime(0.0001, t0);
  g.gain.exponentialRampToValueAtTime(gain, t0 + 0.02);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  osc.connect(g).connect(a.destination);
  osc.start(t0);
  osc.stop(t0 + dur + 0.02);
}

function play(seq) {
  if (!enabled) return;
  if (!ac()) return;
  seq();
}

// Notes (Hz): C5 523, E5 659, G5 784, A5 880, C6 1047, G4 392, E4 330
export const sounds = {
  wake:    () => play(() => { tone(659, 0, 0.18); tone(880, 0.08, 0.22); tone(1047, 0.16, 0.3, { gain: 0.1 }); }),
  listen:  () => play(() => { tone(784, 0, 0.12, { gain: 0.08 }); }),
  send:    () => play(() => { tone(659, 0, 0.10, { gain: 0.07, type: 'triangle' }); }),
  success: () => play(() => { tone(784, 0, 0.14); tone(1047, 0.1, 0.24, { gain: 0.1 }); }),
  error:   () => play(() => { tone(330, 0, 0.22, { type: 'triangle', gain: 0.1 }); tone(247, 0.12, 0.26, { type: 'triangle', gain: 0.09 }); }),
  sleep:   () => play(() => { tone(523, 0, 0.22, { gain: 0.07 }); tone(392, 0.14, 0.34, { gain: 0.06 }); }),
};
