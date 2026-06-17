# ALAKEYA → WAI Agent · Техническое задание

**Версия:** 0.1 · 2026
**Стек заказчика:** Electron + React + OpenAI/Whisper + macOS Accessibility
**Что встраиваем:** визуальный слой ALAKEYA поверх существующей агентной логики WAI Agent

---

## 0. Зачем этот документ

У тебя уже есть рабочий агент: голос, LLM, контроль компьютера, классификатор риска, Manual/Auto-режим. Не хватает **визуального слоя**, который сделает агента живым, премиальным и понятным для пользователя.

Этот пакет даёт:

1. **Дизайн-токены** — все цвета/шрифты/отступы как CSS-переменные.
2. **Готовые React-компоненты** — Orb, AssistantPanel, PermissionCard.
3. **State machine** для орба — связь между статусами агента и визуальными состояниями.
4. **Permission flow** — UX для подтверждения действий.
5. **Архитектуру** — куда что класть в твоём Electron-проекте.
6. **Мост к существующей логике** — см. `wai-agent-integration.md`.

---

## 1. Структура поставки

```
handoff/
├── HANDOFF.md                        ← этот файл (канонический спек)
├── wai-agent-integration.md          ← конкретный мост к твоему коду
├── index.html                        ← интерактивный просмотр + live-демо
└── src/
    ├── tokens.css                    ← CSS-переменные (импортируй один раз)
    ├── animations.css                ← @keyframes (импортируй один раз)
    ├── Orb.jsx                       ← <Orb state={...} />
    ├── Orb.module.css                ← стили орба
    ├── orbMachine.js                 ← state machine + WAI↔Orb mapping
    ├── AssistantPanel.jsx            ← главная панель
    ├── PermissionCard.jsx            ← карточка подтверждения
    ├── ActivityLog.jsx               ← журнал действий
    ├── SettingsWindow.jsx            ← полное окно настроек (6 вкладок)
    ├── OnboardingFlow.jsx            ← 6-шаговый онбординг
    └── ErrorToast.jsx                ← тост ошибки/блокировки
```

Все файлы — реальные, рабочие, без сторонних зависимостей кроме `react`.

---

## 2. Установка в твой проект

### 2.1. Скопируй файлы

```bash
# в твоём WAI Agent репозитории
cp -r handoff/src/* renderer/src/components/alakeya/
```

### 2.2. Импортируй стили один раз

В `renderer/src/main.jsx` (или там, где у тебя точка входа React):

```js
import './components/alakeya/tokens.css';
import './components/alakeya/animations.css';
```

### 2.3. Подключи шрифты в `index.html`

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
```

Для офлайна можно положить `.woff2` в `assets/fonts/` и заменить `<link>` на `@font-face`.

### 2.4. Базовое использование

```jsx
import Orb from './components/alakeya/Orb';
import AssistantPanel from './components/alakeya/AssistantPanel';
import PermissionCard from './components/alakeya/PermissionCard';

function App() {
  const [orbState, setOrbState] = useState('idle');
  const [panelOpen, setPanelOpen] = useState(false);
  const [pendingAction, setPendingAction] = useState(null);

  // подписка на статусы твоего агента — см. §6
  useAgentStatus((status) => setOrbState(WAI_STATUS_TO_ORB_STATE[status]));

  return (
    <>
      <Orb state={orbState} onClick={() => setPanelOpen(o => !o)} />
      <AssistantPanel
        open={panelOpen}
        orbState={orbState}
        onClose={() => setPanelOpen(false)}
        onSubmit={(text) => window.api.runTask(text)}
        onVoiceStart={() => window.api.startListening()}
        onVoiceStop={() => window.api.stopListening()}
      />
      {pendingAction && (
        <PermissionCard
          action={pendingAction}
          onAllowOnce={() => window.api.approveAction(pendingAction.id, 'once')}
          onAlwaysAllow={() => window.api.approveAction(pendingAction.id, 'always')}
          onCancel={() => window.api.denyAction(pendingAction.id)}
        />
      )}
    </>
  );
}
```

---

## 3. Дизайн-токены

Полный список — в `src/tokens.css`. Ниже — самое важное.

### 3.1. Цвета

| Token | Hex | Где |
|---|---|---|
| `--wai-bg` | `#07070d` | Фон окна |
| `--wai-surface` | `rgba(10,10,20,0.65)` | Стеклянная панель |
| `--wai-surface-strong` | `rgba(10,10,20,0.78)` | Модальное стекло |
| `--wai-text` | `rgba(255,255,255,0.92)` | Основной текст |
| `--wai-text-dim` | `rgba(255,255,255,0.65)` | Подзаголовки |
| `--wai-text-muted` | `rgba(255,255,255,0.45)` | Подписи |
| `--wai-accent` | `#06B6D4` | Основной cyan |
| `--wai-accent-bright` | `#67E8F9` | Свечение/hover |
| `--wai-accent-pale` | `#A8F2FF` | Блики |
| `--wai-success` | `#4ADE80` | Granted, completed |
| `--wai-warning` | `#FBBF24` | Awaiting approval |
| `--wai-warning-soft` | `#F59E0B` | Error orb glow |
| `--wai-danger` | `#F87171` | Blocked actions |

**Правила:**

- Никогда не используй чистый `#fff` для текста — только с opacity (`rgba(255,255,255,…)`).
- Cyan-акцент используется только для активных состояний, фокуса, основной CTA — не для декорации.
- Семантические цвета (success/warning/danger) — только для статусов, никогда для UI-элементов.

### 3.2. Типографика

```css
font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'SF Pro Display', system-ui, sans-serif;
font-family: 'JetBrains Mono', 'SF Mono', ui-monospace, monospace; /* цифры, технические лейблы */
```

| Класс | Размер | Вес | Применение |
|---|---|---|---|
| Display | 72 | 600 | Hero-цифры |
| H1 | 32 | 600 | Заголовки экранов |
| H2 | 22 | 600 | Заголовки секций |
| H3 | 17 | 600 | Заголовки карточек |
| Body | 14 | 400 | Основной |
| Small | 12 | 400 | Дополнительный |
| Caption | 11 | 500 | UPPERCASE, tracking 0.18em |
| Micro | 10 | 500 | Метаданные |

### 3.3. Отступы и радиусы

База — **8 px**. Все отступы кратны: 4, 8, 12, 16, 24, 32, 40, 56.

Радиусы:

- `--wai-r-sm` (6 px) — чипы, тоглы
- `--wai-r-md` (10 px) — кнопки, инпуты
- `--wai-r-lg` (14 px) — вложенные карточки
- `--wai-r-xl` (22 px) — панель ассистента
- `--wai-r-2xl` (28 px) — большие оверлеи
- `--wai-r-pill` (999 px) — таблетки, тоглы

### 3.4. Glass / blur

| Уровень | Значение | Применение |
|---|---|---|
| `--wai-blur-sm` | `blur(20px)` | menubar, дёшево |
| `--wai-blur-md` | `blur(30px) saturate(180%)` | панель |
| `--wai-blur-lg` | `blur(40px) saturate(180%)` | модал, главное стекло |

**Важно для Electron:** `backdrop-filter` работает в Chromium, но для нативного macOS vibrancy используй `BrowserWindow({ vibrancy: 'sidebar' })` плюс полупрозрачные фоны. См. §5.

### 3.5. Тайминги анимаций

| Token | Значение | Применение |
|---|---|---|
| `--wai-dur-instant` | 120 ms | Нажатие кнопки |
| `--wai-dur-fast` | 200 ms | Hover |
| `--wai-dur-morph` | 240 ms | Sphere ↔ Panel |
| `--wai-dur-medium` | 400 ms | Entry/exit |
| `--wai-dur-breath` | 4000 ms | Idle pulse |

Easing:

- `--wai-ease-out: cubic-bezier(0.16, 1, 0.3, 1)` — для морфов, появления
- `--wai-ease-in-out: cubic-bezier(0.65, 0, 0.35, 1)` — для всего остального

---

## 4. State machine орба

Орб всегда находится в одном из **7 состояний**. Файл: `src/orbMachine.js`.

```
                   ┌────────────────┐
                   │     idle       │ ← дефолт; breathing glow
                   └───┬────────┬───┘
        WAKE_WORD/CLICK│        │TEXT_SUBMITTED
                       ▼        ▼
              ┌─────────────┐  ┌─────────────┐
              │ listening   │  │  thinking   │
              │ 3-dot wave  │  │  rotating   │
              └──────┬──────┘  └──┬───┬───┬──┘
        STOP_LISTENING│            │   │   │
                      ▼            │   │   │
                  thinking ────────┘   │   │
                                       │   │
                LLM_NEEDS_SPEECH────────┘   │
                       ▼                    │
              ┌──────────────┐              │
              │   speaking   │              │
              │   TTS plays  │              │
              └──────┬───────┘              │
                     │TTS_DONE              │
                     ▼                      │
                    idle                    │
                                            │
                LLM_NEEDS_ACTION────────────┘
                       │
                       ▼
              ┌──────────────┐
              │   acting     │ ← holo beam to target
              └──┬────────┬──┘
   ACTION_REQUIRES_APPROVAL│
                  ▼        │
         ┌─────────────┐   │ACTION_DONE
         │ permission  │   │
         │ amber glow  │   │
         └──┬──────────┘   │
   APPROVE │  │DENY        │
           │  └──→ idle    │
           ▼               ▼
         acting          idle

         (любое состояние) ──ERROR──▶ error  ──DISMISS──▶ idle
```

### 4.1. Состояния и их визуал

| Состояние | Визуал | Когда |
|---|---|---|
| `idle` | Breathing glow · искры | Дефолт |
| `listening` | 3 точки вместо улыбки · пульсирующие кольца | Whisper открыт, recording |
| `thinking` | Сфера вращается · 2 орбиты частиц | LLM-запрос в полёте |
| `speaking` | Рот пульсирует под TTS | TTS играет |
| `acting` | Голограммный луч к цели · статус-лейбл | computer_control выполняется |
| `permission` | Янтарное свечение | Жду APPROVE/DENY |
| `error` | Мягкое amber-свечение · хмурая улыбка | Blocked / failed |

### 4.2. Маппинг к твоим текущим статусам

```js
export const WAI_STATUS_TO_ORB_STATE = {
  'Готов':             'idle',
  'Слушаю':            'listening',
  'Думаю':             'thinking',
  'Говорю':            'speaking',       // ← добавить
  'Действую':          'acting',         // ← добавить
  'Жду подтверждения': 'permission',     // ← добавить
  'Ошибка':            'error',          // ← добавить
};
```

### 4.3. Использование

**С XState (рекомендуется):**

```js
import { createMachine, createActor } from 'xstate';
import { orbMachineConfig } from './orbMachine';

const machine = createMachine(orbMachineConfig);
const actor = createActor(machine);
actor.start();

actor.subscribe((snapshot) => setOrbState(snapshot.value));
actor.send({ type: 'WAKE_WORD' });
```

**Без XState (минимальный reducer):**

```js
import { orbReducer } from './orbMachine';
const [state, dispatch] = useReducer(orbReducer, 'idle');
dispatch({ type: 'WAKE_WORD' });
```

---

## 5. Архитектура в Electron

### 5.1. Папки

```
wai-agent/
├── main/                          ← Node.js main process
│   ├── index.js
│   ├── agent/                     ← (есть) LLM, Whisper, tools
│   ├── permissions.js             ← ←(новый) risk classifier + storage
│   └── ipc.js                     ← IPC channels (см. §6)
├── renderer/
│   ├── index.html
│   └── src/
│       ├── main.jsx               ← React entry
│       ├── App.jsx
│       ├── components/
│       │   └── alakeya/           ← ← сюда положить файлы из handoff/src/
│       └── state/
│           ├── useAgentStatus.js  ← bridge к main (см. §6)
│           └── usePermissions.js
└── preload.js                     ← contextBridge: window.api
```

### 5.2. BrowserWindow для overlay

```js
// main/index.js
const orb = new BrowserWindow({
  width: 380, height: 520,
  x: screen.width - 400, y: screen.height - 540,
  frame: false,
  transparent: true,
  alwaysOnTop: true,
  resizable: false,
  hasShadow: false,
  vibrancy: 'sidebar',              // macOS native blur
  visualEffectState: 'active',
  webPreferences: {
    preload: path.join(__dirname, '../preload.js'),
    contextIsolation: true,
  },
});
orb.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
orb.setAlwaysOnTop(true, 'screen-saver');
```

**`transparent: true` + `frame: false`** — окно бесшовно сливается с десктопом.
**`vibrancy`** даёт нативный macOS blur, поверх него работают `backdrop-filter` и полупрозрачные цвета.

### 5.3. Drag — `-webkit-app-region`

В CSS у внешнего контейнера панели:

```css
.wai-panel { -webkit-app-region: drag; }
.wai-panel button,
.wai-panel input,
.wai-panel .wai-mic,
.wai-panel .wai-quick-cell { -webkit-app-region: no-drag; }
```

Тогда пользователь таскает панель за пустые места, но клики по кнопкам работают.

### 5.4. Magnetic snap — в main

```js
// main/snap.js
const SNAP_RADIUS = 80;
orb.on('moved', () => {
  const [x, y] = orb.getPosition();
  const { width: sw, height: sh } = screen.getPrimaryDisplay().workAreaSize;
  const corners = [
    [0, 0], [sw - 380, 0],
    [0, sh - 520], [sw - 380, sh - 520],
  ];
  const nearest = corners.reduce((best, [cx, cy]) => {
    const d = Math.hypot(x - cx, y - cy);
    return d < best.d ? { d, cx, cy } : best;
  }, { d: Infinity });
  if (nearest.d < SNAP_RADIUS) orb.setPosition(nearest.cx, nearest.cy, true);
});
```

---

## 6. Permission flow

### 6.1. Жизненный цикл действия

```
LLM возвращает tool call
        │
        ▼
classifyRisk(action) → 'low' | 'medium' | 'high'
        │
        ▼
shouldAutoConfirm(risk, mode)
        │
   ┌────┴────┐
   │ true    │ false
   ▼         ▼
 execute  emit('action-requires-approval', action)
                │
                ▼
        Renderer показывает <PermissionCard>
                │
   ┌────────────┼────────────┐
   ▼            ▼            ▼
 APPROVE   APPROVE_ALWAYS   DENY
   │            │            │
   │            └→ store rule │
   ▼                          ▼
 execute                    log + back to idle
```

### 6.2. Классификатор риска

```js
// main/permissions.js
const HIGH_RISK_ACTIONS = new Set([
  'send_email', 'send_message', 'delete_file',
  'run_shell', 'make_payment', 'submit_form',
]);
const MEDIUM_RISK_ACTIONS = new Set([
  'open_app', 'click_element', 'type_text', 'drag_drop',
  'apple_script', 'navigate_url',
]);
// всё остальное (read_screen, parse_page, search, screenshot) — low

export function classifyRisk(action) {
  if (HIGH_RISK_ACTIONS.has(action.type)) return 'high';
  if (MEDIUM_RISK_ACTIONS.has(action.type)) return 'medium';
  return 'low';
}
```

### 6.3. Manual vs Auto

```js
export function shouldAutoConfirm(risk, mode, rememberedRules, action) {
  // Hard limits — независимо от режима
  if (action.type === 'send_email')    return false;
  if (action.type === 'delete_file')   return false;
  if (action.type === 'make_payment')  return false;

  // Запомненные правила
  const key = `${action.type}:${action.target}`;
  if (rememberedRules.has(key)) return true;

  if (mode === 'manual') return false;
  if (mode === 'auto'  && risk === 'low')    return true;
  if (mode === 'auto'  && risk === 'medium') return false;  // в auto среднее всё равно спрашивает
  return false;
}
```

### 6.4. IPC-каналы

| Канал | Direction | Payload |
|---|---|---|
| `agent:status` | main → renderer | `'Готов' \| 'Думаю' \| …` |
| `agent:transcript` | main → renderer | `{ text, partial: bool }` |
| `agent:task-update` | main → renderer | `{ title, steps }` |
| `agent:action-requires-approval` | main → renderer | `{ id, type, title, description, risk, reversible, scope, target, code? }` |
| `agent:action-result` | main → renderer | `{ id, ok, error? }` |
| `agent:error` | main → renderer | `{ message, blocked: bool }` |
| `agent:approve-action` | renderer → main | `{ id, decision: 'once' \| 'always' \| 'deny' }` |
| `agent:run-task` | renderer → main | `{ text }` |
| `agent:start-listening` | renderer → main | `{}` |
| `agent:stop-listening` | renderer → main | `{}` |
| `agent:cancel` | renderer → main | `{}` |

`preload.js`:

```js
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  // listeners
  onStatus:    (cb) => ipcRenderer.on('agent:status', (_, s) => cb(s)),
  onApproval:  (cb) => ipcRenderer.on('agent:action-requires-approval', (_, a) => cb(a)),
  onTranscript:(cb) => ipcRenderer.on('agent:transcript', (_, t) => cb(t)),
  onTask:      (cb) => ipcRenderer.on('agent:task-update', (_, t) => cb(t)),
  onError:     (cb) => ipcRenderer.on('agent:error', (_, e) => cb(e)),

  // commands
  runTask:        (text) => ipcRenderer.send('agent:run-task', { text }),
  startListening: () => ipcRenderer.send('agent:start-listening'),
  stopListening:  () => ipcRenderer.send('agent:stop-listening'),
  cancel:         () => ipcRenderer.send('agent:cancel'),
  approveAction:  (id, decision) => ipcRenderer.send('agent:approve-action', { id, decision }),
  denyAction:     (id) => ipcRenderer.send('agent:approve-action', { id, decision: 'deny' }),
});
```

---

## 7. Onboarding (6 шагов)

```
Welcome → VoiceTest → Permissions → Safety → Personalize → Ready
```

Каждый шаг — отдельная подкомпонента внутри `<OnboardingFlow>`. Прогресс хранится в `electron-store` (`onboarding.completedStep`).

| Шаг | Что показать | Что сохранить |
|---|---|---|
| 1. Welcome | Большой орб, "Meet Alakeya" | `started: true` |
| 2. Voice setup | Live waveform от микрофона, dropdown устройств | `micDeviceId` |
| 3. Permissions | Toggle screen / mic / mouse / kbd | системный prompt macOS Accessibility |
| 4. Safety | Превью permission card, "вы всегда контролируете" | — |
| 5. Personalize | Выбор accent color + face style | `accentColor`, `faceStyle` |
| 6. Ready | Анимированный орб, "Open Alakeya" | `onboarded: true` |

Запрос macOS-доступов на шаге 3 — через `systemPreferences.askForMediaAccess('microphone')` и инструкции открыть System Settings → Privacy → Accessibility для контроля мыши/клавиатуры.

---

## 8. Чек-лист для разработчика

### Этап 1 — Слой стилей (1-2 дня)
- [ ] Скопировать `tokens.css`, `animations.css` в проект
- [ ] Подключить шрифты Inter + JetBrains Mono
- [ ] Применить `--wai-bg` к фону окна виджета
- [ ] Заменить старые цвета на токены

### Этап 2 — Orb (1-2 дня)
- [ ] Импортировать `<Orb>` и `Orb.module.css`
- [ ] Подписаться на текущий статус агента
- [ ] Прокинуть статус через `WAI_STATUS_TO_ORB_STATE`
- [ ] Добавить недостающие статусы: `speaking`, `acting`, `permission`, `error`

### Этап 3 — Panel (2-3 дня)
- [ ] Импортировать `<AssistantPanel>`
- [ ] Связать инпут с `agent:run-task`
- [ ] Связать mic с `agent:start-listening` / `stop-listening`
- [ ] Подписаться на `agent:transcript` и прокинуть в `transcript`-prop
- [ ] Реализовать `quick actions` (open / search / summarize / write / …)

### Этап 4 — Permissions (2-3 дня)
- [ ] Скопировать `<PermissionCard>` и стили
- [ ] Перенести классификатор риска в `main/permissions.js`
- [ ] Добавить storage запомненных правил (`electron-store`)
- [ ] Прокинуть `action-requires-approval` в renderer
- [ ] Реализовать `approveAction` / `denyAction` в main

### Этап 5 — Окно-overlay (1-2 дня)
- [ ] Переключить `BrowserWindow` на `transparent + frame: false + vibrancy`
- [ ] Реализовать magnetic snap на `moved`
- [ ] Применить `-webkit-app-region: drag` / `no-drag`
- [ ] Hover-brightening (mouse enter / leave)

### Этап 6 — Onboarding (3-4 дня)
- [ ] Создать `<OnboardingFlow>` с 6 шагами
- [ ] Live mic test на шаге 2
- [ ] Permission requests на шаге 3
- [ ] Сохранять прогресс

### Этап 7 — Polish (1-2 дня)
- [ ] Activity log (использовать существующие логи действий)
- [ ] Settings экран (6 категорий из дизайна)
- [ ] Animation timing fine-tune

**Итого:** ~3 недели одного разработчика.

---

## 9. Что НЕ входит в этот пакет

- Логика LLM, Whisper, TTS — у тебя уже есть.
- Computer-control (`open_app`, клики, AppleScript) — у тебя уже есть.
- Парсер страниц, скиллы — у тебя уже есть.
- Активити-лог в main — у тебя уже есть.

Этот пакет — **только** визуальный слой и UI-логика. Все backend-операции остаются в твоём main process.

---

## 10. Дальше

См. `wai-agent-integration.md` — там конкретный мост между твоим существующим main process и этими React-компонентами, с примерами кода под твою архитектуру.

См. `index.html` — открой в браузере, увидишь live-демо орба во всех 7 состояниях и сможешь покликать.

---

**Вопросы?** Возвращайся за уточнениями: state machine, permission flow, onboarding-логика, animation tuning — что угодно.
