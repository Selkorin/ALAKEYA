#!/usr/bin/env node
// ============================================================
// finetune.mjs — validate the collected dataset and (optionally)
// launch an OpenAI fine-tuning job for gpt-4o-mini.
//
//   node scripts/finetune.mjs [file.jsonl]          # validate only
//   node scripts/finetune.mjs [file.jsonl] --run    # validate + upload + train
//
// The dataset is produced by Alakeya: Settings → Developer → "Скачать .jsonl",
// or directly from   ~/Library/Application Support/Alakeya/alakeya-training.jsonl
// (run scripts/prepare from there). Requires OPENAI_API_KEY for --run.
// ============================================================
import fs from 'node:fs';

const args = process.argv.slice(2);
const run = args.includes('--run');
const file = args.find((a) => !a.startsWith('--')) || 'alakeya-finetune.jsonl';
const BASE_MODEL = process.env.ALAKEYA_FT_BASE || 'gpt-4o-mini-2024-07-18';
const MIN_EXAMPLES = 10;

if (!fs.existsSync(file)) {
  console.error(`✗ Не найден файл датасета: ${file}`);
  console.error('  Экспортируй его из приложения (Настройки → Разработчик → Скачать .jsonl)');
  process.exit(1);
}

const lines = fs.readFileSync(file, 'utf-8').split('\n').filter(Boolean);
let ok = 0;
const errors = [];
for (const [i, line] of lines.entries()) {
  try {
    const ex = JSON.parse(line);
    if (!Array.isArray(ex.messages) || ex.messages.length < 2) {
      throw new Error('нужно ≥2 сообщения (system+user[+assistant])');
    }
    const roles = ex.messages.map((m) => m.role);
    if (!roles.includes('user') || !roles.includes('assistant')) {
      throw new Error('нет user или assistant сообщения');
    }
    ok++;
  } catch (e) {
    errors.push(`  строка ${i + 1}: ${e.message}`);
  }
}

console.log(`Датасет: ${file}`);
console.log(`Валидных примеров: ${ok} / ${lines.length}`);
if (errors.length) {
  console.log('Проблемы:');
  console.log(errors.slice(0, 20).join('\n'));
}
if (ok < MIN_EXAMPLES) {
  console.log(`\n⚠ Для дообучения нужно минимум ${MIN_EXAMPLES} примеров. Поработай с ассистентом ещё.`);
}

if (!run) {
  console.log('\nДля запуска обучения добавь флаг --run (нужен OPENAI_API_KEY).');
  process.exit(0);
}

const key = process.env.OPENAI_API_KEY;
if (!key) { console.error('✗ Нет OPENAI_API_KEY'); process.exit(1); }
if (ok < MIN_EXAMPLES) { console.error('✗ Слишком мало примеров для обучения.'); process.exit(1); }

console.log(`\n↑ Загружаю датасет в OpenAI…`);
const form = new FormData();
form.append('file', new Blob([fs.readFileSync(file)], { type: 'application/jsonl' }), 'alakeya.jsonl');
form.append('purpose', 'fine-tune');

const up = await fetch('https://api.openai.com/v1/files', {
  method: 'POST', headers: { Authorization: `Bearer ${key}` }, body: form,
});
if (!up.ok) { console.error('✗ Загрузка не удалась:', await up.text()); process.exit(1); }
const fileObj = await up.json();
console.log(`  file id: ${fileObj.id}`);

console.log(`▶ Создаю fine-tune job (база: ${BASE_MODEL})…`);
const job = await fetch('https://api.openai.com/v1/fine_tuning/jobs', {
  method: 'POST',
  headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ training_file: fileObj.id, model: BASE_MODEL }),
});
if (!job.ok) { console.error('✗ Не удалось создать job:', await job.text()); process.exit(1); }
const jobObj = await job.json();
console.log(`✓ Job создан: ${jobObj.id}`);
console.log(`  Статус: ${jobObj.status}`);
console.log(`\nКогда обучение завершится, в письме/консоли OpenAI будет имя модели вида`);
console.log(`  ft:gpt-4o-mini-...:alakeya. Впиши его в Настройки → Разработчик → Модель.`);
