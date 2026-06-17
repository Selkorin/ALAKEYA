// ============================================================
// voice.js — OpenAI voice I/O for the main process.
//   • speak(text)        → TTS (gpt-4o-mini-tts / tts-1) with the
//                          configured voice. Default "onyx": deep,
//                          velvety, mature. Returns base64 mp3.
//   • transcribe(buffer) → Whisper STT. Returns recognized text.
// The API key never leaves the main process.
// ============================================================
const ctx = require('../context');

function apiKey() {
  const c = ctx.getConfig();
  return c.apiKey || process.env.OPENAI_API_KEY || '';
}

/** Text → speech. Returns { base64, mime } or null when disabled/no key. */
async function speak(text) {
  const c = ctx.getConfig();
  if (!c.ttsEnabled || !text || !apiKey()) return null;

  const res = await fetch('https://api.openai.com/v1/audio/speech', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey()}` },
    body: JSON.stringify({
      model: 'gpt-4o-mini-tts',  // expressive, natural; falls back below if unavailable
      voice: c.ttsVoice || 'onyx',
      input: text,
      speed: c.speed || 1.0,
      response_format: 'mp3',
    }),
  });

  if (!res.ok) {
    // Older accounts: retry with the classic tts-1 model.
    const retry = await fetch('https://api.openai.com/v1/audio/speech', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey()}` },
      body: JSON.stringify({
        model: 'tts-1-hd', voice: c.ttsVoice || 'onyx',
        input: text, speed: c.speed || 1.0, response_format: 'mp3',
      }),
    });
    if (!retry.ok) throw new Error(`TTS ${retry.status}: ${await retry.text()}`);
    const buf = Buffer.from(await retry.arrayBuffer());
    return { base64: buf.toString('base64'), mime: 'audio/mpeg' };
  }

  const buf = Buffer.from(await res.arrayBuffer());
  return { base64: buf.toString('base64'), mime: 'audio/mpeg' };
}

/** Speech → text. `audio` is a Node Buffer of webm/ogg/wav. */
async function transcribe(audio, mime = 'audio/webm') {
  const c = ctx.getConfig();
  if (!apiKey()) throw new Error('Нет API-ключа для распознавания речи.');

  const ext = mime.includes('ogg') ? 'ogg' : mime.includes('wav') ? 'wav' : 'webm';
  const form = new FormData();
  form.append('file', new Blob([audio], { type: mime }), `audio.${ext}`);
  form.append('model', c.sttModel || 'whisper-1');
  form.append('language', 'ru');

  const res = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey()}` },
    body: form,
  });
  if (!res.ok) throw new Error(`STT ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return (data.text || '').trim();
}

module.exports = { speak, transcribe };
