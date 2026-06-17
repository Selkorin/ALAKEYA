# Мост к существующему WAI Agent

Конкретный код для подключения визуального слоя ALAKEYA к твоей текущей реализации.

---

## 1. Что у тебя уже есть (контекст)

Из твоего описания:

- **Main process** — Electron, OpenAI API (gpt-4o-mini), Whisper, TTS, AppleScript, Accessibility tree.
- **Computer control** — `open_app`, нажатие клавиш, clipboard+Cmd+V, клики по координатам, скролл, drag, shell, скриншоты, поиск UI-элемента по тексту.
- **Risk classifier** — low/medium/high уже есть.
- **Manual / Auto mode** — уже есть.
- **Skills** — browser-page-parser, marketing-smm-seo, programming-agent, connectors-roadmap.

---

## 2. Изменения в main process

### 2.1. Добавь новые статусы

У тебя сейчас 4 статуса: `Готов / Думаю / Слушаю / Говорю`. Нужно ещё три:

```js
// main/agent/status.js
export const STATUS = {
  READY:      'Готов',
  LISTENING:  'Слушаю',
  THINKING:   'Думаю',
  SPEAKING:   'Говорю',
  ACTING:     'Действую',          // ← новый
  AWAITING:   'Жду подтверждения', // ← новый
  ERROR:      'Ошибка',            // ← новый
};

class StatusEmitter extends EventEmitter {
  constructor() {
    super();
    this.current = STATUS.READY;
  }
  set(next) {
    if (next === this.current) return;
    this.current = next;
    this.emit('change', next);
  }
  wrap(status, fn) {
    const prev = this.current;
    this.set(status);
    return Promise.resolve(fn()).finally(() => this.set(prev));
  }
}
export const agentStatus = new StatusEmitter();
```

Прокидываешь в renderer:

```js
// main/ipc.js
agentStatus.on('change', (s) => {
  windows.orb?.webContents.send('agent:status', s);
});
```

### 2.2. Обнови tool-runner — вставь permission gate

У тебя tool-runner сейчас вызывает `open_app`, `click`, etc. напрямую. Поставь перед ним gate:

```js
// main/agent/toolRunner.js
import { classifyRisk, shouldAutoConfirm, askUser } from '../permissions';
import { agentStatus, STATUS } from './status';

export async function runTool(action) {
  const risk = classifyRisk(action);
  const auto = shouldAutoConfirm(risk, getMode(), rememberedRules, action);

  if (!auto) {
    agentStatus.set(STATUS.AWAITING);
    const decision = await askUser(action);   // ← Promise resolves on user click
    if (decision === 'deny') {
      logAction({ ...action, result: 'denied' });
      agentStatus.set(STATUS.READY);
      return { ok: false, denied: true };
    }
    if (decision === 'always') {
      rememberedRules.add(`${action.type}:${action.target}`);
      saveRules();
    }
  }

  agentStatus.set(STATUS.ACTING);
  try {
    const result = await EXECUTORS[action.type](action);    // твоя существующая логика
    logAction({ ...action, result: 'ok' });
    return { ok: true, result };
  } catch (e) {
    agentStatus.set(STATUS.ERROR);
    windows.orb?.webContents.send('agent:error', {
      message: humanize(e),
      blocked: isBlocked(e),
    });
    setTimeout(() => agentStatus.set(STATUS.READY), 4000);
    return { ok: false, error: e.message };
  }
}
```

### 2.3. `askUser` — ожидает решение пользователя

```js
// main/permissions.js
const pending = new Map();   // id → resolve fn

export function askUser(action) {
  return new Promise((resolve) => {
    const id = `act_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
    pending.set(id, resolve);
    windows.orb?.webContents.send('agent:action-requires-approval', {
      id,
      type: action.type,
      title: actionTitle(action),       // "Открыть Safari"
      description: actionDescription(action), // "Найти 'best CRM…'"
      target: action.app || action.target,
      risk: classifyRisk(action),
      reversible: isReversible(action),
      scope: actionScope(action),       // "Только браузер"
      code: action.shell || null,       // для shell-команд показать код
    });
  });
}

// renderer присылает решение
ipcMain.on('agent:approve-action', (_, { id, decision }) => {
  const resolve = pending.get(id);
  if (!resolve) return;
  pending.delete(id);
  resolve(decision);     // 'once' | 'always' | 'deny'
});
```

### 2.4. Telegram-сценарий — пример с гейтом

Раньше у тебя цепочка:

```
открыть Telegram → поиск → найти контакт → клик → вставить текст
```

Теперь каждый шаг проходит через `runTool` и спрашивает разрешение (если risk ≥ medium и нет remembered rule):

```js
async function sendTelegramMessage({ contact, text }) {
  await runTool({ type: 'open_app',     app: 'Telegram' });
  await runTool({ type: 'apple_script', script: 'open search', target: 'Telegram' });
  await runTool({ type: 'type_text',    text: contact });
  await runTool({ type: 'click_element', text: contact });
  await runTool({ type: 'type_text',    text });
  // последний шаг — отправка — всегда спрашивает
  await runTool({ type: 'send_message', target: `Telegram·${contact}`, text });
}
```

Пользователь увидит permission card на «send_message» (high risk) и опционально на остальных (medium, если не сохранено).

---

## 3. Изменения в renderer

### 3.1. Главный компонент App

```jsx
// renderer/src/App.jsx
import { useState, useEffect } from 'react';
import Orb from './components/alakeya/Orb';
import AssistantPanel from './components/alakeya/AssistantPanel';
import PermissionCard from './components/alakeya/PermissionCard';
import { WAI_STATUS_TO_ORB_STATE } from './components/alakeya/orbMachine';

export default function App() {
  const [status, setStatus] = useState('Готов');
  const [panelOpen, setPanelOpen] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [task, setTask] = useState(null);
  const [pendingAction, setPendingAction] = useState(null);
  const [errorMsg, setErrorMsg] = useState(null);

  useEffect(() => {
    window.api.onStatus(setStatus);
    window.api.onTranscript(({ text }) => setTranscript(text));
    window.api.onTask(setTask);
    window.api.onApproval(setPendingAction);
    window.api.onError(({ message, blocked }) => {
      setErrorMsg({ message, blocked });
      setTimeout(() => setErrorMsg(null), 6000);
    });
  }, []);

  const orbState = WAI_STATUS_TO_ORB_STATE[status] || 'idle';

  const approve = (decision) => {
    window.api.approveAction(pendingAction.id, decision);
    setPendingAction(null);
  };

  return (
    <div className="wai-root">
      <Orb
        state={orbState}
        onClick={() => setPanelOpen(o => !o)}
      />

      <AssistantPanel
        open={panelOpen}
        orbState={orbState}
        transcript={transcript}
        currentTask={task}
        onClose={() => setPanelOpen(false)}
        onSubmit={(text) => {
          window.api.runTask(text);
          setText('');
        }}
        onVoiceStart={() => window.api.startListening()}
        onVoiceStop={() => window.api.stopListening()}
        onQuickAction={(id) => window.api.runTask(QUICK_PROMPTS[id])}
      />

      {pendingAction && (
        <div className="wai-overlay">
          <PermissionCard
            action={pendingAction}
            onAllowOnce={() => approve('once')}
            onAlwaysAllow={() => approve('always')}
            onCancel={() => approve('deny')}
          />
        </div>
      )}

      {errorMsg && <ErrorToast {...errorMsg} />}
    </div>
  );
}

const QUICK_PROMPTS = {
  open:      'Открой ',
  search:    'Найди в браузере: ',
  summarize: 'Что на этом экране?',
  write:     'Напиши ',
  organize:  'Покажи папку Загрузки',
  image:     'Сгенерируй картинку: ',
  translate: 'Переведи на английский: ',
  settings:  '__open_settings__',
};
```

### 3.2. Маппинг твоих действий → action object

`AssistantPanel.onSubmit(text)` шлёт сырой текст. Main process прогоняет через LLM, тот возвращает tool calls. Каждый tool call оборачиваешь в action object для permission card:

```js
// main/agent/actionFromToolCall.js
export function actionFromToolCall(tc) {
  const base = { id: tc.id, type: tc.function.name };
  const args = JSON.parse(tc.function.arguments);

  switch (tc.function.name) {
    case 'open_app':
      return { ...base,
        title: `Открыть ${args.app}`,
        description: `Запустить ${args.app}.`,
        target: args.app, scope: args.app,
        reversible: true,
      };
    case 'send_message':
      return { ...base,
        title: `Отправить сообщение`,
        description: `Отправить "${args.text.slice(0, 80)}…" в ${args.target}.`,
        target: args.target, scope: args.app,
        reversible: false,
      };
    case 'run_shell':
      return { ...base,
        title: 'Выполнить shell-команду',
        description: 'Команда покажется ниже. Проверь перед запуском.',
        code: args.command,
        target: 'Terminal', scope: 'Система',
        reversible: false,
      };
    // ... и т.д. для каждого tool
  }
}
```

---

## 4. Voice flow с правильными статусами

```js
// main/agent/voiceFlow.js
async function handleVoice() {
  agentStatus.set(STATUS.LISTENING);
  const audio = await whisper.recordUntilSilence();

  agentStatus.set(STATUS.THINKING);
  const text = await whisper.transcribe(audio);
  windows.orb?.webContents.send('agent:transcript', { text, partial: false });

  const llmResponse = await openai.chat.completions.create({...});

  // Если LLM вернул tool calls → ACTING (через permission gate)
  if (llmResponse.tool_calls?.length) {
    for (const tc of llmResponse.tool_calls) {
      await runTool(actionFromToolCall(tc));
    }
  }

  // Если есть текст для озвучки → SPEAKING
  if (llmResponse.content) {
    agentStatus.set(STATUS.SPEAKING);
    await tts.speak(llmResponse.content);
  }

  agentStatus.set(STATUS.READY);
}
```

---

## 5. Что трогать НЕ нужно

✓ OpenAI API-вызовы
✓ Whisper-распознавание
✓ TTS-озвучка
✓ Все исполнители tool calls (open_app, AppleScript, …)
✓ Парсер активного окна
✓ Skills (browser-page-parser, …)
✓ Алиасы Telegram/Chrome/Cursor/etc.

Эти части продолжают жить в main process как есть.

---

## 6. Тестовый сценарий после интеграции

1. Запусти приложение → видишь орб в bottom-right с breathing glow.
2. Скажи "Hey Alakeya, открой Telegram и напиши Солнышку привет".
3. Орб → `listening` (3 точки, кольца).
4. Замолчал → `thinking` (вращается).
5. LLM вернул план → `acting` (открывает Telegram).
6. Дошло до `send_message` → `permission` (янтарный).
7. Появилась `PermissionCard` с превью текста и кнопками.
8. Жмёшь "Разрешить один раз" → `acting` → действие выполнено.
9. LLM отвечает голосом "Готово" → `speaking`.
10. Орб → `idle`.

Если на любом шаге ошибка (например, контакт не найден) → орб в `error`, показывается toast с понятным сообщением.

---

## 7. Что обновить в существующем UI

Твоё текущее окно:
- ~~3D-голова/аватар~~ → `<Orb>` (можно оставить 3D как `face-style: futuristic` опцию в настройках)
- ~~Статусы: Готов, Думаю, Слушаю, Говорю~~ → 7 статусов, маппинг готов
- ~~Badge модели: GPT / Local / Offline~~ → оставить, добавить в шапку панели рядом с именем
- ~~Manual / Auto переключатель~~ → оставить, добавить в шапку панели или Settings
- ~~Поле текстового ввода~~ → `<AssistantPanel>` уже даёт это
- ~~Кнопка голосового ввода~~ → 3-dot mic внутри panel
- ~~Диалог подтверждения~~ → `<PermissionCard>`

---

## 8. Дальнейшие фичи (после MVP)

- **Визуальное распознавание по скриншоту** → новый action type `analyze_screenshot`, low risk.
- **Google Drive/Docs** → connectors, добавляются как новые tools, классификация risk зависит от операции.
- **n8n webhooks** → новый tool `trigger_webhook`, medium risk (требует подтверждения).
- **Telegram Mini Apps** → отдельное окно, через тот же permission flow.

Все они вписываются в схему без изменений в UI-слое.
