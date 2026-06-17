// ============================================================
// training.js — collect (task → tool_calls) examples for fine-tuning.
//
// Every completed task is appended to userData/alakeya-training.jsonl
// in OpenAI's chat fine-tuning format (with tool calls). Only successful
// runs are marked `quality:"ok"`; denied/errored runs are still stored
// (marked) so they can be filtered out at export time.
//
// Later: `npm run finetune:prepare` filters this file into a clean
// training set, then upload it to OpenAI to fine-tune gpt-4o-mini.
// ============================================================
const path = require('path');
const fs = require('fs');
const { app } = require('electron');
const orchestrator = require('./orchestrator');

function filePath() {
  return path.join(app.getPath('userData'), 'alakeya-training.jsonl');
}

const SYSTEM_PROMPT =
  'Ты — Alakeya, локальный macOS-ассистент. Преобразуй задачу пользователя в ' +
  'строго типизированные tool calls. Отвечай кратко по-русски.';

/**
 * @param {string} task            the user's request
 * @param {Array}  toolCalls       [{ id, name, arguments }]
 * @param {string} reply           assistant's spoken reply
 * @param {'ok'|'denied'|'error'} quality
 */
function record({ task, toolCalls = [], reply = '', quality = 'ok' }) {
  if (!task || !task.trim()) return;
  try {
    const example = {
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: task },
        toolCalls.length
          ? {
              role: 'assistant',
              content: reply || null,
              tool_calls: toolCalls.map((t, i) => ({
                id: t.id || `call_${i}`,
                type: 'function',
                function: { name: t.name, arguments: JSON.stringify(t.arguments || {}) },
              })),
            }
          : { role: 'assistant', content: reply || 'Готово.' },
      ],
      tools: orchestrator.TOOL_SCHEMAS,
      parallel_tool_calls: false,
      // metadata (ignored by OpenAI fine-tune, used by our filter)
      _meta: { quality, ts: Date.now() },
    };
    fs.mkdirSync(path.dirname(filePath()), { recursive: true });
    fs.appendFileSync(filePath(), JSON.stringify(example) + '\n');
  } catch (e) {
    console.error('[training] failed to record example:', e.message);
  }
}

/** Read the raw collected dataset (all qualities). */
function readAll() {
  try {
    const text = fs.readFileSync(filePath(), 'utf-8');
    return text.split('\n').filter(Boolean).map((l) => JSON.parse(l));
  } catch {
    return [];
  }
}

/** Export the dataset as a clean OpenAI fine-tune JSONL string.
 *  By default keeps only successful examples and strips `_meta`. */
function exportJsonl({ onlyOk = true } = {}) {
  const rows = readAll().filter((r) => (onlyOk ? r._meta?.quality === 'ok' : true));
  const jsonl = rows
    .map(({ _meta, ...clean }) => JSON.stringify(clean))
    .join('\n');
  return { jsonl, count: rows.length, total: readAll().length, path: filePath() };
}

module.exports = { record, readAll, exportJsonl, filePath };
