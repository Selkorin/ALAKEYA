// ============================================================
// voice.js (renderer) — plays TTS audio returned by the main process
// and records the mic for Whisper STT. Audio APIs live in the renderer,
// the OpenAI key stays in main.
// ============================================================

let currentAudio = null;

/** Play base64 mp3 returned from api.tts(). Resolves when playback ends. */
export function playAudio({ base64, mime } = {}) {
  return new Promise((resolve) => {
    if (!base64) return resolve();
    try {
      stopAudio();
      const audio = new Audio(`data:${mime || 'audio/mpeg'};base64,${base64}`);
      currentAudio = audio;
      audio.onended = audio.onerror = () => { currentAudio = null; resolve(); };
      audio.play().catch(() => resolve());
    } catch {
      resolve();
    }
  });
}

export function stopAudio() {
  if (currentAudio) { try { currentAudio.pause(); } catch {} currentAudio = null; }
}

// ── Mic recorder (push-to-talk) ─────────────────────────────
export function createRecorder() {
  let mediaRecorder = null;
  let chunks = [];
  let stream = null;

  async function start() {
    stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const mime = MediaRecorder.isTypeSupported('audio/webm')
      ? 'audio/webm' : 'audio/ogg';
    mediaRecorder = new MediaRecorder(stream, { mimeType: mime });
    chunks = [];
    mediaRecorder.ondataavailable = (e) => e.data.size && chunks.push(e.data);
    mediaRecorder.start();
    return mime;
  }

  /** Stop and return { bytes: ArrayBuffer, mime } for the captured audio. */
  function stop() {
    return new Promise((resolve) => {
      if (!mediaRecorder) return resolve(null);
      const mime = mediaRecorder.mimeType;
      mediaRecorder.onstop = async () => {
        const blob = new Blob(chunks, { type: mime });
        const bytes = await blob.arrayBuffer();
        stream?.getTracks().forEach((t) => t.stop());
        mediaRecorder = null; stream = null;
        resolve({ bytes, mime });
      };
      mediaRecorder.stop();
    });
  }

  return { start, stop };
}
