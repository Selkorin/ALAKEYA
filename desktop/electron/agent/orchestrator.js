// ============================================================
// orchestrator.js — task → plan (tool calls) + spoken reply.
//
// Mirrors the documented agent loop (DOC2): model proposes typed
// tool calls, the app executes them through the policy gate.
//
// Two providers:
//   • mock  (default) — deterministic, offline intent parser so the
//     whole experience is demoable without any API key.
//   • openai — used automatically when OPENAI_API_KEY is set; calls the
//     Responses/Chat API with strict tool schemas (DOC2 §"Пример tool schema").
//
// A plan is: { steps: [{label}], toolCalls: [{id,name,arguments}], reply }
// ============================================================

let _seq = 0;
const id = () => `tc_${Date.now()}_${_seq++}`;

// ── Mock intent parser ──────────────────────────────────────
const APP_ALIASES = {
  телеграм: 'Telegram', telegram: 'Telegram', тг: 'Telegram',
  сафари: 'Safari', safari: 'Safari', браузер: 'Safari',
  хром: 'Chrome', chrome: 'Chrome',
  почта: 'Mail', mail: 'Mail',
  заметки: 'Notes', notes: 'Notes',
  finder: 'Finder', файлы: 'Finder',
};

function detectApp(text) {
  const low = text.toLowerCase();
  for (const [k, v] of Object.entries(APP_ALIASES)) {
    if (low.includes(k)) return v;
  }
  return null;
}

function mockPlan(text) {
  const low = text.toLowerCase();
  const app = detectApp(text);
  const toolCalls = [];
  const steps = [];

  const push = (name, args, label) => {
    toolCalls.push({ id: id(), name, arguments: args });
    steps.push({ label });
  };

  // open / launch
  if (/(открой|открыть|запусти|open|launch)/.test(low) && app) {
    push('open_app', { app }, `Открыть ${app}`);
  }

  // search
  const searchM = text.match(/(?:найди|найти|поиск|search)[:\s]+(.+)$/i);
  if (searchM) {
    if (!app) push('open_app', { app: 'Safari' }, 'Открыть Safari');
    push('search', { query: searchM[1].trim(), app: 'Safari' }, `Найти: ${searchM[1].trim().slice(0, 30)}`);
  }

  // write / send a message
  const writeM = text.match(/(?:напиши|написать|отправь|send)\s+(.+)$/i);
  if (writeM && app && /(telegram|mail|почт|сообщ|message)/.test(low + app.toLowerCase())) {
    // crude "<recipient> <message>" split
    const rest = writeM[1].trim();
    const firstSpace = rest.indexOf(' ');
    const recipient = firstSpace > 0 ? rest.slice(0, firstSpace) : rest;
    const message = firstSpace > 0 ? rest.slice(firstSpace + 1) : 'Привет!';
    push('type_text', { text: recipient, app, target: 'поиск чата' }, `Найти чат: ${recipient}`);
    push('type_text', { text: message, app, target: 'поле ввода' }, 'Ввести сообщение');
    push('send_message', { text: message, target: `${app}·${recipient}`, app }, 'Отправить сообщение');
  }

  // delete
  const delM = text.match(/(?:удали|удалить|delete)\s+(.+)$/i);
  if (delM) push('delete_file', { target: delM[1].trim() }, `Удалить ${delM[1].trim()}`);

  // "what's on screen"
  if (/(что на экране|опиши экран|what.*screen)/.test(low)) {
    push('read_screen', {}, 'Прочитать экран');
  }

  // fallback: just read the screen for context
  if (toolCalls.length === 0) {
    push('read_screen', {}, 'Осмотреть экран');
  }

  const reply = buildReply(text, toolCalls);
  return { steps, toolCalls, reply };
}

function buildReply(text, toolCalls) {
  if (toolCalls.some((t) => t.name === 'send_message')) return 'Готово, сообщение отправлено.';
  if (toolCalls.some((t) => t.name === 'open_app')) return 'Открыл, что просил.';
  if (toolCalls.some((t) => t.name === 'search')) return 'Вот результаты поиска.';
  return 'Готово.';
}

// ── OpenAI provider (optional) ──────────────────────────────
async function openaiPlan(text) {
  const key = process.env.OPENAI_API_KEY;
  const model = process.env.ALAKEYA_MODEL || 'gpt-4o';
  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: text },
      ],
      tools: TOOL_SCHEMAS,
      tool_choice: 'auto',
    }),
  });
  if (!res.ok) throw new Error(`OpenAI ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const msg = data.choices?.[0]?.message || {};
  const toolCalls = (msg.tool_calls || []).map((tc) => ({
    id: tc.id,
    name: tc.function.name,
    arguments: safeJSON(tc.function.arguments),
  }));
  const steps = toolCalls.map((t) => ({ label: t.name }));
  return { steps, toolCalls, reply: msg.content || 'Готово.' };
}

function safeJSON(s) { try { return JSON.parse(s); } catch { return {}; } }

const SYSTEM_PROMPT =
  'Ты — Alakeya, локальный macOS-ассистент. Преобразуй задачу пользователя в ' +
  'строго типизированные tool calls. Рискованные действия (отправка, удаление, ' +
  'платежи, shell) приложение подтвердит у пользователя — не бойся их предлагать, ' +
  'но не выдумывай адресатов. Отвечай кратко по-русски.';

const TOOL_SCHEMAS = [
  fn('open_app', 'Открыть/активировать приложение macOS.', { app: { type: 'string' } }, ['app']),
  fn('navigate_url', 'Открыть URL в браузере.', { url: { type: 'string' } }, ['url']),
  fn('search', 'Найти что-то в браузере.', { query: { type: 'string' } }, ['query']),
  fn('type_text', 'Ввести текст в активное поле.', { text: { type: 'string' }, app: { type: 'string' } }, ['text']),
  fn('click_element', 'Кликнуть по элементу UI по тексту.', { text: { type: 'string' }, app: { type: 'string' } }, ['text']),
  fn('send_message', 'Отправить сообщение в мессенджер.', { text: { type: 'string' }, target: { type: 'string' }, app: { type: 'string' } }, ['text', 'target']),
  fn('delete_file', 'Удалить файл (необратимо).', { target: { type: 'string' } }, ['target']),
  fn('run_shell', 'Выполнить shell-команду.', { command: { type: 'string' } }, ['command']),
  fn('read_screen', 'Прочитать активное окно через Accessibility.', {}, []),
];

function fn(name, description, properties, required) {
  return {
    type: 'function',
    function: {
      name, description, strict: true,
      parameters: { type: 'object', additionalProperties: false, properties, required },
    },
  };
}

// ── Public API ──────────────────────────────────────────────
async function plan(text) {
  if (process.env.OPENAI_API_KEY) {
    try {
      return await openaiPlan(text);
    } catch (e) {
      console.error('[orchestrator] OpenAI failed, falling back to mock:', e.message);
    }
  }
  return mockPlan(text);
}

module.exports = { plan, mockPlan, TOOL_SCHEMAS };
