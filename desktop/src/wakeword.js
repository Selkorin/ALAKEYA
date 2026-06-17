// ============================================================
// wakeword.js — lightweight always-on wake-word listener.
//
// Uses the browser SpeechRecognition engine (available in Electron's
// Chromium) to continuously listen for "Alakeya" / "Алакея". When heard,
// it fires onWake() so the app can surface the orb and start a real
// push-to-talk capture. It deliberately does NOT transcribe commands —
// that's Whisper's job — it only spots the wake phrase.
//
// Gracefully no-ops where SpeechRecognition is unavailable.
// ============================================================

const WAKE_PATTERNS = [
  /\bалак(е|э)я\b/i, /\bалак(е|э)и\b/i, /\bалак\b/i,
  /\balak(e|a)ya\b/i, /\bhey\s+alak/i, /\bалекс/i,
];

function matchesWake(text) {
  const t = (text || '').toLowerCase();
  return WAKE_PATTERNS.some((re) => re.test(t));
}

export function createWakeWord(onWake) {
  const SR = typeof window !== 'undefined'
    ? (window.SpeechRecognition || window.webkitSpeechRecognition)
    : null;
  if (!SR) {
    return { start() {}, stop() {}, supported: false };
  }

  let rec = null;
  let running = false;
  let cooldown = 0;

  function build() {
    const r = new SR();
    r.lang = 'ru-RU';
    r.continuous = true;
    r.interimResults = true;
    r.maxAlternatives = 1;
    r.onresult = (e) => {
      for (let i = e.resultIndex; i < e.results.length; i++) {
        const text = e.results[i][0].transcript;
        if (matchesWake(text)) {
          const now = Date.now();
          if (now - cooldown > 2500) {   // debounce repeated hits
            cooldown = now;
            onWake?.();
          }
        }
      }
    };
    // Chromium stops periodically; restart to stay always-on.
    r.onend = () => { if (running) { try { r.start(); } catch {} } };
    r.onerror = () => { /* keep trying via onend */ };
    return r;
  }

  return {
    supported: true,
    start() {
      if (running) return;
      running = true;
      rec = build();
      try { rec.start(); } catch {}
    },
    stop() {
      running = false;
      try { rec && rec.stop(); } catch {}
      rec = null;
    },
  };
}
