# Alakeya — macOS desktop AI assistant

Плавающий AI-компаньон для macOS: парящий орб в углу экрана + стеклянная
панель ассистента, голос, и управление компьютером с подтверждением
рискованных действий.

Это **референс-реализация на Electron + React**, собранная строго по
документации:

- `../handoff/HANDOFF.md` — канонический спек (токены, state machine,
  permission flow, конфиг окна-оверлея).
- `../handoff/wai-agent-integration.md` — мост main↔renderer (статусы,
  permission gate, IPC, voice flow).
- два производственных отчёта (`.docx`) — архитектура control-cascade,
  классы действий, модель разрешений, упаковка/нотаризация.

Весь визуальный слой — это компоненты **ALAKEYA Design System**
(`src/components/alakeya/`), подключённые как drop-in, как и предписывает
HANDOFF §2.

---

## Запуск

```bash
cd desktop
npm install
npm run dev      # vite (renderer) + electron вместе
```

> При первой установке Electron качает свой бинарник (~100 МБ). Если сеть
> ограничена и нужен только UI-превью без Electron:
>
> ```bash
> ELECTRON_SKIP_BINARY_DOWNLOAD=1 npm install
> npm run build && npm run preview   # откроется в браузере с mock-агентом
> ```

Сборка .app (Developer ID, hardened runtime — см. DOC1):

```bash
npm run dist:mac
```

---

## Архитектура

Двухслойная, как в документации: доверенный системный слой отдельно от
агентной логики.

```
electron/                     ← main process (Node)
├── main.js                   ← окно-оверлей: transparent · frameless ·
│                               alwaysOnTop · vibrancy (HANDOFF §5.2)
├── preload.js                ← contextBridge → window.api (HANDOFF §6.4)
├── ipc.js                    ← каналы agent:status / task / approval / …
├── snap.js                   ← магнитный snap к углам (HANDOFF §5.4)
├── permissions.js            ← classifyRisk + shouldAutoConfirm + askUser
├── context.js                ← общий runtime: окна, режим, журнал действий
└── agent/
    ├── status.js             ← 7 статусов (Готов…Ошибка)
    ├── orchestrator.js       ← задача → план (tool calls). mock | OpenAI
    ├── toolRunner.js         ← permission gate → executor → лог; task loop
    ├── actionFromToolCall.js ← tool call → объект для PermissionCard
    └── executors.js          ← actuator (AppleScript/AX/paste/CGEvent)*

src/                          ← renderer (React, Vite)
├── App.jsx                   ← сборка оверлея (wai-agent-integration §3.1)
├── mockApi.js                ← браузерный mock window.api для превью
├── components/alakeya/       ← ALAKEYA Design System (Orb, AssistantPanel,
│                               PermissionCard, ActivityLog, SettingsWindow,
│                               OnboardingFlow, ErrorToast, orbMachine, токены)
└── styles/                   ← app-shell layout + извлечённый component CSS
```

### Поток одной задачи (как в HANDOFF §4 / integration §6)

```
текст/голос → Думаю → план (orchestrator)
            → для каждого action: policy gate
                 low/auto → сразу Действую
                 risk≥medium / hard-limit → Жду подтверждения
                      → PermissionCard → once | always | deny
            → Действую (executor) → лог
            → Говорю (ответ) → Готов
любое исключение → Ошибка → ErrorToast → Готов
```

### Состояния орба
`idle · listening · thinking · speaking · acting · permission · error`
— маппинг статусов в `components/alakeya/orbMachine.js`.

### Классы риска (DOC1 §6 / DOC2)
- **low** (read_screen, search, screenshot) — без подтверждения;
- **medium** (open_app, type_text, click, apple_script) — auto спрашивает;
- **high** (send_message, delete_file, run_shell, make_payment) — всегда
  подтверждение; `send_email / delete_file / make_payment` — hard-limit,
  не авто-подтверждаются никогда.

---

## Что симулировано (и где включить «настоящее»)

`electron/agent/executors.js` сейчас **безопасно симулирует** действия,
чтобы весь UX (орб, permission flow, журнал) работал кросс-платформенно и в
CI. Для реального управления Mac:

- `ALAKEYA_REAL_CONTROL=1` включает реальные `open`/`osascript` ветки;
- порядок каскада уже заложен по докам: Apple Events → Accessibility
  (AXUIElement) → буфер + ⌘V → CGEvent;
- голос: в `ipc.js` точки для whisper.cpp (STT) и TTS;
- LLM: `orchestrator.js` использует OpenAI автоматически при наличии
  `OPENAI_API_KEY` (модель — `ALAKEYA_MODEL`, по умолчанию `gpt-4o-mini`),
  иначе — встроенный детерминированный планировщик.

---

## Production-путь (из отчётов)

Документы рекомендуют для финального продукта **нативный host на
Swift + SwiftUI/AppKit** (AXSwift, ScreenCaptureKit, AVSpeechSynthesizer) с
отдельным agent-core, и распространение **вне Mac App Store** (Developer ID +
hardened runtime + notarization), потому что App Sandbox ломает
cross-app accessibility. Эта Electron-версия — рабочая реализация дизайна и
всей UI/permission-логики; системный actuator можно вынести в нативный
helper, сохранив тот же IPC-контракт.
