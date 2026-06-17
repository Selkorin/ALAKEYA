// ============================================================
// SettingsWindow.jsx — полное окно настроек с 6 вкладками
//
// PROPS
//   settings      — текущие значения (см. defaults ниже)
//   permissions   — { screen, mic, mouse, keyboard, files, apps }
//   onChange      (path, value) => void
//                  path: 'appearance.size' | 'voice.activation' | …
//   onClose       () => void
//   onForgetMemory () => void
//
// Подвести к твоему electron-store: на onChange сохрани в store
// и эмить main процессу.
// ============================================================

import React, { useState } from 'react';
import Orb from './Orb';

const SIZE_PX = { small: 64, medium: 80, large: 96 };

const TABS = [
  { id: 'appearance',  label: 'Внешний вид',  group: 'general' },
  { id: 'voice',       label: 'Голос',        group: 'general' },
  { id: 'permissions', label: 'Разрешения',   group: 'general' },
  { id: 'automation',  label: 'Автоматизация',group: 'general' },
  { id: 'memory',      label: 'Память',       group: 'general' },
  { id: 'developer',   label: 'Разработчик',  group: 'advanced' },
  { id: 'about',       label: 'О программе',  group: 'advanced' },
];

export const SETTINGS_DEFAULTS = {
  appearance: {
    size: 'medium',           // 'small' | 'medium' | 'large'
    corner: 'bottom-right',
    theme: 'system',
    glow: 0.68,
    particles: 0.5,
    faceStyle: 'friendly',
    accent: '#06B6D4',
  },
  voice: {
    activation: 'push',       // 'click' | 'wake' | 'push'
    wakeWord: 'Hey Alakeya',
    micDeviceId: 'default',
    ttsEnabled: true,
    ttsVoice: 'onyx',         // onyx = глубокий, бархатный, взрослый
    speed: 1.0,
    personality: 'calm',
    sounds: true,             // приятные звуковые сигналы (появление и т.д.)
  },
  automation: {
    askEvery: true,
    autoSafe: false,
    neverSend: true,
    neverDelete: true,
    neverPay: true,
    allowedApps: ['Safari', 'Chrome', 'Notes', 'Mail'],
  },
  memory: {
    rememberPrefs: true,
    rememberTasks: true,
  },
  developer: {
    apiKey: '',
    model: 'gpt-4o',
    localFallback: 'llama3:8b',
    sttModel: 'whisper-1',
    ttsVoice: 'onyx',
    dailyLimit: 5.0,
    usageToday: 0.0,
  },
};

export default function SettingsWindow({
  settings = SETTINGS_DEFAULTS,
  permissions = {},
  onChange,
  onClose,
  onForgetMemory,
  initialTab = 'appearance',
}) {
  const [tab, setTab] = useState(initialTab);
  const set = (path, val) => onChange?.(path, val);

  return (
    <div className="wai-settings">
      {/* Title bar */}
      <header className="wai-settings-title">
        <div className="wai-traffic">
          <span className="wai-traffic-dot" style={{ background: '#ff5f57' }} onClick={onClose} />
          <span className="wai-traffic-dot" style={{ background: '#febc2e' }} />
          <span className="wai-traffic-dot" style={{ background: '#28c840' }} />
        </div>
        <span className="wai-settings-name">Alakeya — Настройки</span>
        <span style={{ width: 60 }} />
      </header>

      <div className="wai-settings-body">
        {/* Side nav */}
        <nav className="wai-settings-nav">
          <div className="wai-settings-group">Основное</div>
          {TABS.filter(t => t.group === 'general').map(t => (
            <button
              key={t.id}
              className={`wai-settings-tab ${tab === t.id ? 'wai-settings-tab-active' : ''}`}
              onClick={() => setTab(t.id)}
            >
              {t.label}
            </button>
          ))}
          <div className="wai-settings-group" style={{ marginTop: 14, paddingTop: 14, borderTop: '1px solid rgba(255,255,255,0.05)' }}>Расширенное</div>
          {TABS.filter(t => t.group === 'advanced').map(t => (
            <button
              key={t.id}
              className={`wai-settings-tab ${tab === t.id ? 'wai-settings-tab-active' : ''}`}
              onClick={() => setTab(t.id)}
            >
              {t.label}
            </button>
          ))}
        </nav>

        {/* Content */}
        <div className="wai-settings-content">
          {tab === 'appearance' && (
            <AppearanceTab settings={settings.appearance} set={(k, v) => set(`appearance.${k}`, v)} />
          )}
          {tab === 'voice' && (
            <VoiceTab settings={settings.voice} set={(k, v) => set(`voice.${k}`, v)} />
          )}
          {tab === 'permissions' && (
            <PermissionsTab perms={permissions} set={(k, v) => set(`permissions.${k}`, v)} />
          )}
          {tab === 'automation' && (
            <AutomationTab settings={settings.automation} set={(k, v) => set(`automation.${k}`, v)} />
          )}
          {tab === 'memory' && (
            <MemoryTab settings={settings.memory} set={(k, v) => set(`memory.${k}`, v)} onForget={onForgetMemory} />
          )}
          {tab === 'developer' && (
            <DeveloperTab settings={settings.developer} set={(k, v) => set(`developer.${k}`, v)} />
          )}
          {tab === 'about' && <AboutTab />}
        </div>
      </div>
    </div>
  );
}

/* ── Individual tabs ───────────────────────────────────── */

function AppearanceTab({ settings, set }) {
  return (
    <>
      <h3 className="wai-settings-h">Внешний вид</h3>
      <p className="wai-settings-p">Как Alakeya выглядит и где живёт на экране.</p>

      <div style={{
        display: 'flex', justifyContent: 'center', alignItems: 'center',
        height: 120, marginBottom: 24,
        background: 'rgba(0,0,0,0.2)', borderRadius: 'var(--wai-r-lg)',
        border: '1px solid var(--wai-line)',
      }}>
        <Orb
          state="idle"
          size={SIZE_PX[settings.size] || 80}
          accent={settings.accent}
          glow={settings.glow}
          particles={settings.particles}
          faceStyle={settings.faceStyle}
        />
      </div>

      <Field label="Размер" value={`${settings.size === 'small' ? '64' : settings.size === 'large' ? '96' : '80'} px`}>
        <SegmentedControl
          value={settings.size}
          onChange={(v) => set('size', v)}
          options={[
            { value: 'small', label: 'Маленький' },
            { value: 'medium', label: 'Средний' },
            { value: 'large', label: 'Большой' },
          ]}
        />
      </Field>

      <Field label="Угол экрана" value={cornerLabel(settings.corner)}>
        <CornerPicker value={settings.corner} onChange={(v) => set('corner', v)} />
      </Field>

      <Field label="Стиль лица" value={faceLabel(settings.faceStyle)}>
        <SegmentedControl
          value={settings.faceStyle}
          onChange={(v) => set('faceStyle', v)}
          options={[
            { value: 'minimal',    label: 'Минимальный' },
            { value: 'friendly',   label: 'Дружелюбный' },
            { value: 'futuristic', label: 'Футуристичный' },
          ]}
        />
      </Field>

      <Field label="Интенсивность свечения" value={`${Math.round(settings.glow * 100)}%`}>
        <Slider value={settings.glow} onChange={(v) => set('glow', v)} />
      </Field>

      <Field label="Частицы" value={`${Math.round(settings.particles * 100)}%`}>
        <Slider value={settings.particles} onChange={(v) => set('particles', v)} />
      </Field>

      <Field label="Акцентный цвет">
        <ColorPicker value={settings.accent} onChange={(v) => set('accent', v)} />
      </Field>
    </>
  );
}

function faceLabel(f) {
  return { minimal: 'Минимальный', friendly: 'Дружелюбный', futuristic: 'Футуристичный' }[f] || '';
}

function VoiceTab({ settings, set }) {
  return (
    <>
      <h3 className="wai-settings-h">Голос</h3>
      <p className="wai-settings-p">Как Alakeya слышит и отвечает.</p>

      <Field label="Активация">
        <SegmentedControl
          value={settings.activation}
          onChange={(v) => set('activation', v)}
          options={[
            { value: 'click', label: 'Клик' },
            { value: 'wake',  label: 'Wake-слово' },
            { value: 'push',  label: 'Push-to-talk' },
          ]}
        />
      </Field>

      {settings.activation === 'wake' && (
        <Field label="Wake-слово">
          <input
            type="text" className="wai-settings-input"
            value={settings.wakeWord}
            onChange={(e) => set('wakeWord', e.target.value)}
          />
        </Field>
      )}

      <Field label="Микрофон">
        <select className="wai-settings-input" value={settings.micDeviceId} onChange={(e) => set('micDeviceId', e.target.value)}>
          <option value="default">По умолчанию</option>
          <option value="builtin">MacBook Pro Microphone</option>
        </select>
      </Field>

      <Toggle
        label="Озвучивать ответы"
        desc="Alakeya говорит вслух (OpenAI TTS)"
        value={settings.ttsEnabled}
        onChange={(v) => set('ttsEnabled', v)}
      />

      <Toggle
        label="Звуковые сигналы"
        desc="Мягкий звук при появлении, прослушивании, готовности"
        value={settings.sounds !== false}
        onChange={(v) => set('sounds', v)}
      />

      <Field label="Голос" value={voiceLabel(settings.ttsVoice)}>
        <select className="wai-settings-input" value={settings.ttsVoice} onChange={(e) => set('ttsVoice', e.target.value)}>
          <option value="onyx">Onyx — глубокий, бархатный (муж.)</option>
          <option value="echo">Echo — спокойный, взрослый (муж.)</option>
          <option value="ash">Ash — мягкий, тёплый</option>
          <option value="alloy">Alloy — нейтральный</option>
          <option value="nova">Nova — лёгкий (жен.)</option>
          <option value="shimmer">Shimmer — мягкий (жен.)</option>
        </select>
      </Field>

      <Field label="Скорость речи" value={`${settings.speed.toFixed(2)}×`}>
        <Slider value={(settings.speed - 0.5) / 1.5} onChange={(v) => set('speed', +(0.5 + v * 1.5).toFixed(2))} />
      </Field>
    </>
  );
}

function voiceLabel(v) {
  return {
    onyx: 'Onyx', echo: 'Echo', ash: 'Ash',
    alloy: 'Alloy', nova: 'Nova', shimmer: 'Shimmer',
  }[v] || v;
}

function PermissionsTab({ perms, set }) {
  const rows = [
    { key: 'screen',   label: 'Чтение экрана', desc: 'Нужно для понимания контекста' },
    { key: 'mic',      label: 'Микрофон',      desc: 'Для голосовых команд' },
    { key: 'mouse',    label: 'Мышь',          desc: 'Клики и скролл' },
    { key: 'keyboard', label: 'Клавиатура',    desc: 'Ввод текста' },
    { key: 'files',    label: 'Файлы',         desc: 'Только папка Documents' },
    { key: 'apps',     label: 'Управление приложениями', desc: 'Открывать и переключать' },
  ];
  return (
    <>
      <h3 className="wai-settings-h">Разрешения</h3>
      <p className="wai-settings-p">Что Alakeya может видеть и делать.</p>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {rows.map(r => (
          <div key={r.key} className="wai-perm-row">
            <div>
              <div className="wai-perm-label">{r.label}</div>
              <div className="wai-perm-desc">{r.desc}</div>
            </div>
            <PermissionBadge value={perms[r.key] || 'off'} onClick={() => set(r.key, nextPerm(perms[r.key]))} />
          </div>
        ))}
      </div>
    </>
  );
}

function AutomationTab({ settings, set }) {
  return (
    <>
      <h3 className="wai-settings-h">Автоматизация</h3>
      <p className="wai-settings-p">Жёсткие лимиты, которые Alakeya никогда не нарушит.</p>

      <Toggle label="Спрашивать перед каждым действием" value={settings.askEvery} onChange={(v) => set('askEvery', v)} />
      <Toggle label="Авто-подтверждение безопасных" value={settings.autoSafe} onChange={(v) => set('autoSafe', v)} />
      <Toggle label="Никогда не отправлять сообщения" desc="Email, чат, SMS" value={settings.neverSend} onChange={(v) => set('neverSend', v)} />
      <Toggle label="Никогда не удалять файлы" desc="Корзина тоже отключена" value={settings.neverDelete} onChange={(v) => set('neverDelete', v)} />
      <Toggle label="Никогда не платить" value={settings.neverPay} onChange={(v) => set('neverPay', v)} />

      <Field label="Разрешённые приложения">
        <div className="wai-chips">
          {settings.allowedApps.map(app => (
            <span key={app} className="wai-chip">{app}<span className="wai-chip-x">×</span></span>
          ))}
          <span className="wai-chip wai-chip-add">+ Добавить</span>
        </div>
      </Field>
    </>
  );
}

function MemoryTab({ settings, set, onForget }) {
  return (
    <>
      <h3 className="wai-settings-h">Память</h3>
      <p className="wai-settings-p">Что Alakeya помнит о тебе.</p>

      <Toggle label="Запоминать предпочтения" value={settings.rememberPrefs} onChange={(v) => set('rememberPrefs', v)} />
      <Toggle label="Запоминать частые задачи" value={settings.rememberTasks} onChange={(v) => set('rememberTasks', v)} />

      <Field label="Сохранённая память · 12 записей">
        <div className="wai-memory-list">
          <div>Использует Chrome как браузер по умолчанию</div>
          <div>Предпочитает короткие резюме (3 пункта)</div>
          <div>Живёт в Москве (таймзона)</div>
          <div>Отправляет письма с anna@studio.io</div>
          <div>Работает над Q3 маркетингом</div>
        </div>
      </Field>

      <div style={{ display: 'flex', gap: 6, marginTop: 14 }}>
        <button className="wai-btn wai-btn-ghost" style={{ flex: 1 }}>Показать все</button>
        <button className="wai-btn wai-btn-danger" style={{ flex: 1 }} onClick={onForget}>Забыть всё</button>
      </div>
    </>
  );
}

function DeveloperTab({ settings, set }) {
  return (
    <>
      <h3 className="wai-settings-h">Разработчик</h3>
      <p className="wai-settings-p">Свои ключи и модели.</p>

      <Field label="API-ключ">
        <input
          type="password" className="wai-settings-input mono"
          value={settings.apiKey}
          placeholder="sk-..."
          onChange={(e) => set('apiKey', e.target.value)}
        />
      </Field>

      <Field label="Модель">
        <select className="wai-settings-input" value={settings.model} onChange={(e) => set('model', e.target.value)}>
          <option value="gpt-4o-mini">GPT-4o mini</option>
          <option value="gpt-4o">GPT-4o</option>
          <option value="claude-sonnet-4-5">Claude Sonnet 4.5</option>
        </select>
      </Field>

      <Field label="Локальный fallback">
        <select className="wai-settings-input" value={settings.localFallback} onChange={(e) => set('localFallback', e.target.value)}>
          <option value="llama3:8b">Llama 3 · 8B</option>
          <option value="llama3:70b">Llama 3 · 70B</option>
          <option value="none">Отключён</option>
        </select>
      </Field>

      <div className="wai-usage">
        <div className="wai-usage-head">
          <span className="mono" style={{ fontSize: 24, fontWeight: 600 }}>${settings.usageToday.toFixed(2)}</span>
          <span style={{ fontSize: 11, color: 'var(--wai-text-muted)' }}>из ${settings.dailyLimit.toFixed(2)} лимита</span>
        </div>
        <div className="wai-usage-bar">
          <div style={{ width: `${(settings.usageToday / settings.dailyLimit) * 100}%` }} />
        </div>
      </div>
    </>
  );
}

function AboutTab() {
  return (
    <>
      <h3 className="wai-settings-h">О программе</h3>
      <p className="wai-settings-p">Alakeya · WAI Agent</p>
      <div style={{ fontFamily: 'var(--wai-font-mono)', fontSize: 12, lineHeight: 2, color: 'var(--wai-text-dim)', marginTop: 20 }}>
        <div>Версия &nbsp;&nbsp; 0.1.0</div>
        <div>Сборка &nbsp;&nbsp; 2026.06.17</div>
        <div>Electron &nbsp; 30.x</div>
        <div>Node &nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 20.x</div>
      </div>
    </>
  );
}

/* ── Atom components ───────────────────────────────────── */

function Field({ label, value, children }) {
  return (
    <div className="wai-field">
      <div className="wai-field-head">
        <span className="wai-field-label">{label}</span>
        {value && <span className="wai-field-value mono">{value}</span>}
      </div>
      {children}
    </div>
  );
}

function SegmentedControl({ value, onChange, options }) {
  return (
    <div className="wai-segmented">
      {options.map(o => (
        <button
          key={o.value}
          className={`wai-seg ${value === o.value ? 'wai-seg-active' : ''}`}
          onClick={() => onChange(o.value)}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

function CornerPicker({ value, onChange }) {
  const corners = ['top-left', 'top-right', 'bottom-left', 'bottom-right'];
  return (
    <div className="wai-corners">
      {corners.map(c => (
        <button
          key={c}
          className={`wai-corner ${value === c ? 'wai-corner-active' : ''}`}
          onClick={() => onChange(c)}
          data-corner={c}
        >
          <span className="wai-corner-dot" />
        </button>
      ))}
    </div>
  );
}

function Slider({ value, onChange }) {
  return (
    <div className="wai-slider">
      <input
        type="range" min="0" max="1" step="0.01"
        value={value}
        onChange={(e) => onChange(parseFloat(e.target.value))}
      />
    </div>
  );
}

function ColorPicker({ value, onChange }) {
  const colors = ['#3B82F6', '#06B6D4', '#8B5CF6', '#EC4899', '#4ADE80'];
  return (
    <div className="wai-colors">
      {colors.map(c => (
        <button
          key={c}
          className={`wai-color ${value === c ? 'wai-color-active' : ''}`}
          style={{ background: c }}
          onClick={() => onChange(c)}
        />
      ))}
    </div>
  );
}

function Toggle({ label, desc, value, onChange }) {
  return (
    <div className="wai-toggle-row">
      <div>
        <div className="wai-toggle-label">{label}</div>
        {desc && <div className="wai-toggle-desc">{desc}</div>}
      </div>
      <button
        className={`wai-toggle ${value ? 'wai-toggle-on' : ''}`}
        onClick={() => onChange(!value)}
        aria-pressed={value}
      >
        <span />
      </button>
    </div>
  );
}

function PermissionBadge({ value, onClick }) {
  const map = {
    granted: { color: '#4ADE80', label: 'РАЗРЕШЕНО' },
    scoped:  { color: '#4ADE80', label: 'ОГРАНИЧЕНО' },
    ask:     { color: '#FBBF24', label: 'СПРАШИВАТЬ' },
    off:     { color: '#999',    label: 'ВЫКЛ' },
  };
  const m = map[value] || map.off;
  return (
    <button
      className="wai-perm-badge"
      style={{ color: m.color, borderColor: `${m.color}55`, background: `${m.color}15` }}
      onClick={onClick}
    >
      {m.label}
    </button>
  );
}

function cornerLabel(c) {
  return {
    'bottom-right': 'Снизу-справа',
    'bottom-left':  'Снизу-слева',
    'top-right':    'Сверху-справа',
    'top-left':     'Сверху-слева',
  }[c];
}

function nextPerm(curr) {
  return { granted: 'ask', ask: 'off', off: 'granted', scoped: 'granted' }[curr] || 'granted';
}

/* CSS ──────────────────────────────────────────────────────

.wai-settings {
  width: 100%; max-width: 760px;
  background: var(--wai-surface-strong);
  backdrop-filter: var(--wai-blur-lg);
  border: 1px solid var(--wai-line-strong);
  border-radius: 18px;
  overflow: hidden;
  box-shadow: var(--wai-shadow-panel);
  color: var(--wai-text);
  font-family: var(--wai-font-sans);
}
.wai-settings-title {
  display: flex; align-items: center; padding: 14px 16px;
  border-bottom: 1px solid var(--wai-line); gap: 12px;
}
.wai-traffic { display: flex; gap: 7px; }
.wai-traffic-dot { width: 12px; height: 12px; border-radius: 50%; cursor: pointer; border: none; }
.wai-settings-name { flex: 1; text-align: center; font-size: 12px; color: var(--wai-text-dim); }

.wai-settings-body { display: grid; grid-template-columns: 200px 1fr; min-height: 460px; }
.wai-settings-nav {
  padding: 16px 12px;
  border-right: 1px solid var(--wai-line);
  background: rgba(0,0,0,0.2);
}
.wai-settings-group {
  font-family: var(--wai-font-mono); font-size: 9px;
  letter-spacing: var(--wai-tracking-caption);
  text-transform: uppercase;
  color: var(--wai-text-muted);
  padding: 8px 10px;
}
.wai-settings-tab {
  display: block; width: 100%; text-align: left;
  padding: 9px 10px; background: transparent; border: none;
  border-radius: 9px;
  font-size: 13px; color: var(--wai-text-dim);
  font-family: inherit; cursor: pointer;
  margin-bottom: 2px;
}
.wai-settings-tab-active {
  background: var(--wai-accent-soft);
  border: 1px solid var(--wai-line-accent);
  color: var(--wai-text);
}
.wai-settings-content { padding: 28px 32px; overflow: auto; }
.wai-settings-h { font-size: 22px; font-weight: 600; margin: 0 0 4px; }
.wai-settings-p { font-size: 13px; color: var(--wai-text-dim); margin: 0 0 26px; }

.wai-field { margin-bottom: 22px; }
.wai-field-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
.wai-field-label { font-size: 13px; color: var(--wai-text); }
.wai-field-value { font-size: 11px; color: var(--wai-text-muted); }
.wai-settings-input {
  width: 100%; padding: 9px 12px;
  background: var(--wai-surface-inset);
  border: 1px solid var(--wai-line-strong);
  border-radius: var(--wai-r-md);
  color: var(--wai-text); font-size: 13px;
  font-family: inherit;
}

.wai-segmented {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(0, 1fr));
  gap: 6px;
}
.wai-seg {
  padding: 9px 0; background: transparent;
  color: var(--wai-text-dim); border: 1px solid var(--wai-line-strong);
  border-radius: 9px; font-size: 12px; font-family: inherit;
  cursor: pointer;
}
.wai-seg-active {
  background: var(--wai-accent-soft);
  color: var(--wai-text);
  border-color: var(--wai-line-accent);
}

.wai-corners {
  display: grid; grid-template-columns: repeat(2, 1fr); gap: 6px;
  aspect-ratio: 4/1.4; max-width: 240px;
}
.wai-corner {
  background: var(--wai-surface-inset);
  border: 1px solid var(--wai-line-strong);
  border-radius: 9px;
  cursor: pointer; position: relative;
}
.wai-corner-active { background: var(--wai-accent-soft); border-color: var(--wai-line-accent); }
.wai-corner-dot {
  position: absolute; width: 7px; height: 7px; border-radius: 50%;
  background: var(--wai-text-muted);
}
.wai-corner[data-corner="top-left"]     .wai-corner-dot { top: 6px;    left: 6px; }
.wai-corner[data-corner="top-right"]    .wai-corner-dot { top: 6px;    right: 6px; }
.wai-corner[data-corner="bottom-left"]  .wai-corner-dot { bottom: 6px; left: 6px; }
.wai-corner[data-corner="bottom-right"] .wai-corner-dot { bottom: 6px; right: 6px; }
.wai-corner-active .wai-corner-dot {
  background: var(--wai-accent-bright);
  box-shadow: 0 0 6px var(--wai-accent-bright);
}

.wai-slider input[type="range"] {
  width: 100%; appearance: none; background: transparent;
}
.wai-slider input[type="range"]::-webkit-slider-runnable-track {
  height: 6px; background: rgba(255,255,255,0.08); border-radius: 3px;
}
.wai-slider input[type="range"]::-webkit-slider-thumb {
  appearance: none; width: 16px; height: 16px; border-radius: 50%;
  background: #fff; margin-top: -5px; cursor: pointer;
  box-shadow: 0 0 12px var(--wai-accent-glow);
}

.wai-colors { display: flex; gap: 8px; }
.wai-color {
  width: 32px; height: 32px; border-radius: 50%;
  border: 2px solid transparent; cursor: pointer;
}
.wai-color-active { border-color: #fff; box-shadow: 0 0 12px var(--wai-accent-glow); }

.wai-toggle-row { display: flex; justify-content: space-between; align-items: center; padding: 10px 4px; border-bottom: 1px solid rgba(255,255,255,0.05); }
.wai-toggle-label { font-size: 12px; }
.wai-toggle-desc { font-size: 10px; color: var(--wai-text-muted); margin-top: 1px; }
.wai-toggle {
  width: 32px; height: 18px; border-radius: 999px; border: none;
  background: rgba(255,255,255,0.1); position: relative; cursor: pointer;
  transition: background var(--wai-dur-fast) var(--wai-ease-out);
}
.wai-toggle span {
  position: absolute; top: 2px; left: 2px; width: 14px; height: 14px;
  background: rgba(255,255,255,0.7); border-radius: 50%;
  transition: all var(--wai-dur-fast) var(--wai-ease-out);
}
.wai-toggle-on {
  background: linear-gradient(90deg, var(--wai-accent), var(--wai-accent-deep));
  box-shadow: 0 0 8px var(--wai-accent-glow);
}
.wai-toggle-on span { left: auto; right: 2px; background: #fff; }

.wai-chips { display: flex; flex-wrap: wrap; gap: 6px; }
.wai-chip {
  padding: 4px 10px;
  background: var(--wai-accent-soft);
  border: 1px solid var(--wai-line-accent);
  border-radius: var(--wai-r-pill);
  font-size: 11px;
}
.wai-chip-x { margin-left: 6px; opacity: 0.5; cursor: pointer; }
.wai-chip-add {
  background: transparent;
  border: 1px dashed rgba(255,255,255,0.2);
  color: var(--wai-text-muted); cursor: pointer;
}

.wai-perm-row {
  display: flex; align-items: center; justify-content: space-between;
  padding: 12px;
  background: var(--wai-surface-inset);
  border: 1px solid var(--wai-line);
  border-radius: var(--wai-r-md);
}
.wai-perm-label { font-size: 12px; font-weight: 500; }
.wai-perm-desc { font-size: 10px; color: var(--wai-text-muted); margin-top: 2px; }
.wai-perm-badge {
  font-size: 10px; padding: 3px 8px; border-radius: var(--wai-r-pill);
  border-width: 1px; border-style: solid;
  font-family: inherit; font-weight: 500; cursor: pointer;
}

.wai-memory-list {
  background: rgba(0,0,0,0.25);
  border: 1px solid var(--wai-line);
  border-radius: var(--wai-r-md);
  max-height: 130px; overflow: hidden;
  position: relative;
}
.wai-memory-list > div {
  padding: 8px 12px; font-size: 11px; color: var(--wai-text-dim);
  border-bottom: 1px solid rgba(255,255,255,0.04);
}
.wai-memory-list > div:last-child { border-bottom: none; }

.wai-btn-danger {
  background: rgba(248,113,113,0.08);
  color: #F87171;
  border: 1px solid rgba(248,113,113,0.3);
  padding: 9px 0; border-radius: var(--wai-r-md);
  font-family: inherit; font-size: 12px; cursor: pointer;
}

.wai-usage {
  padding: 12px;
  background: rgba(0,0,0,0.3);
  border: 1px solid var(--wai-line);
  border-radius: var(--wai-r-md);
}
.wai-usage-head { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 8px; }
.wai-usage-bar { height: 4px; background: rgba(255,255,255,0.08); border-radius: 2px; overflow: hidden; }
.wai-usage-bar > div {
  height: 100%;
  background: linear-gradient(90deg, var(--wai-accent), var(--wai-accent-bright));
}

────────────────────────────────────────────────────────── */
