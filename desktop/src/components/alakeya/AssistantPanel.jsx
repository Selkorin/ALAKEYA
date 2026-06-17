// ============================================================
// AssistantPanel.jsx — the 360 × 480 glass panel
//
// PROPS
//   open               boolean
//   orbState           same as Orb state
//   transcript         string (live STT output, empty when not listening)
//   currentTask        { title, steps: [{ label, status }] } | null
//   onClose            () => void
//   onSubmit           (text) => void
//   onVoiceStart       () => void
//   onVoiceStop        () => void
//   onQuickAction      (actionId) => void
//
// Render below the panel:
//   - <Orb state={orbState} size={52} />
//   - voice transcript (live)
//   - task progress with checkmarks
//   - quick actions grid
// ============================================================

import React, { useState, useRef, useEffect } from 'react';
import Orb from './Orb';
import {
  IconOpen, IconSearch, IconSummarize, IconWrite,
  IconFiles, IconImage, IconTranslate, IconSettings,
  IconHistory, IconMinus, IconClose,
} from './Icons';

const QUICK_ACTIONS = [
  { id: 'open',       label: 'Открыть',     Icon: IconOpen },
  { id: 'search',     label: 'Найти',       Icon: IconSearch },
  { id: 'summarize',  label: 'Резюме',      Icon: IconSummarize },
  { id: 'write',      label: 'Написать',    Icon: IconWrite },
  { id: 'organize',   label: 'Файлы',       Icon: IconFiles },
  { id: 'image',      label: 'Картинка',    Icon: IconImage },
  { id: 'translate',  label: 'Перевести',   Icon: IconTranslate },
  { id: 'settings',   label: 'Настройки',   Icon: IconSettings },
];

const STATUS_LABEL = {
  idle:       'Готов',
  listening:  'Слушаю…',
  thinking:   'Думаю…',
  speaking:   'Говорю…',
  acting:     'Действую…',
  permission: 'Жду подтверждения',
  error:      'Ошибка',
};

export default function AssistantPanel({
  open,
  orbState = 'idle',
  appearance = {},
  transcript = '',
  currentTask = null,
  onClose,
  onSubmit,
  onVoiceStart,
  onVoiceStop,
  onQuickAction,
  onShowActivity,
}) {
  const [text, setText] = useState('');
  const inputRef = useRef(null);

  useEffect(() => {
    if (open && inputRef.current) inputRef.current.focus();
  }, [open]);

  if (!open) return null;

  const isListening = orbState === 'listening';

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!text.trim()) return;
    onSubmit?.(text.trim());
    setText('');
  };

  return (
    <div className="wai-panel" role="dialog" aria-label="Alakeya assistant">
      {/* Header ─────────────────────────────────────────── */}
      <header className="wai-panel-header">
        <Orb
          state={orbState}
          size={52}
          accent={appearance.accent}
          glow={appearance.glow}
          particles={appearance.particles}
          faceStyle={appearance.faceStyle}
          onClick={onClose}
        />
        <div className="wai-panel-meta">
          <div className="wai-panel-name">Alakeya</div>
          <div className="wai-panel-status">
            <span className={`wai-status-dot wai-status-${orbState}`} />
            {STATUS_LABEL[orbState]}
          </div>
        </div>
        <button className="wai-icon-btn" onClick={onShowActivity} aria-label="Журнал действий" title="Журнал действий"><IconHistory /></button>
        <button className="wai-icon-btn" onClick={onClose} aria-label="Свернуть"><IconMinus /></button>
        <button className="wai-icon-btn" onClick={onClose} aria-label="Закрыть"><IconClose /></button>
      </header>

      {/* Live transcript (only while listening) ─────────── */}
      {isListening && transcript && (
        <div className="wai-transcript">
          {transcript}<span className="wai-caret" />
        </div>
      )}

      {/* Current task ───────────────────────────────────── */}
      {currentTask && (
        <section className="wai-task">
          <div className="wai-task-title">{currentTask.title}</div>
          <ol className="wai-task-steps">
            {currentTask.steps.map((step, i) => (
              <li key={i} className={`wai-step wai-step-${step.status}`}>
                <span className="wai-step-dot" />{step.label}
              </li>
            ))}
          </ol>
        </section>
      )}

      {/* Input + 3-dot mic ──────────────────────────────── */}
      <form className="wai-input-row" onSubmit={handleSubmit}>
        <input
          ref={inputRef}
          type="text"
          className="wai-input"
          placeholder="Скажи или напиши задачу…"
          value={text}
          onChange={(e) => setText(e.target.value)}
        />
        <button
          type="button"
          className={`wai-mic ${isListening ? 'wai-mic-active' : ''}`}
          onClick={isListening ? onVoiceStop : onVoiceStart}
          aria-label={isListening ? 'Stop listening' : 'Start listening'}
        >
          <span /><span /><span />
        </button>
      </form>

      {/* Quick actions grid ─────────────────────────────── */}
      <div className="wai-quick-caption">Быстрые действия</div>
      <div className="wai-quick-grid">
        {QUICK_ACTIONS.map(({ id, label, Icon }) => (
          <button
            key={id}
            className="wai-quick-cell"
            onClick={() => onQuickAction?.(id)}
          >
            <span className="wai-quick-icon"><Icon /></span>
            <span className="wai-quick-label">{label}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

/* Required CSS — drop in your stylesheet ────────────────────

.wai-panel {
  position: fixed; bottom: 24px; right: 24px;
  width: 360px; padding: 24px;
  background: var(--wai-surface);
  backdrop-filter: var(--wai-blur-lg);
  border: 1px solid var(--wai-line-strong);
  border-radius: var(--wai-r-2xl);
  box-shadow: var(--wai-shadow-panel);
  color: var(--wai-text);
  font-family: var(--wai-font-sans);
  z-index: var(--wai-z-panel);
  transform-origin: bottom right;
  animation: wai-panel-in var(--wai-dur-morph) var(--wai-ease-out);
}
@keyframes wai-panel-in {
  from { transform: scale(0.6) translateY(20px); opacity: 0; }
  to   { transform: scale(1) translateY(0);     opacity: 1; }
}
.wai-panel-header  { display: flex; align-items: center; gap: 14px; margin-bottom: 22px; }
.wai-panel-meta    { flex: 1; }
.wai-panel-name    { font-size: 15px; font-weight: 600; }
.wai-panel-status  { font-size: 12px; color: var(--wai-accent-bright);
                     display: flex; align-items: center; gap: 6px; margin-top: 2px; }
.wai-status-dot    { width: 6px; height: 6px; border-radius: 50%;
                     background: var(--wai-accent-bright);
                     box-shadow: 0 0 8px var(--wai-accent-bright); }
.wai-status-error  { background: var(--wai-warning-soft); box-shadow: 0 0 8px var(--wai-warning-soft); }
.wai-icon-btn      { width: 28px; height: 28px; border-radius: 50%;
                     background: rgba(255,255,255,0.06);
                     border: 1px solid var(--wai-line);
                     color: var(--wai-text-dim); cursor: pointer; font-size: 14px; }
.wai-transcript    { padding: 14px 16px; margin-bottom: 14px;
                     background: var(--wai-accent-soft);
                     border: 1px solid var(--wai-line-accent);
                     border-radius: var(--wai-r-lg);
                     font-size: 14px; line-height: 1.5; }
.wai-caret         { display: inline-block; width: 2px; height: 14px;
                     background: var(--wai-accent-bright); margin-left: 3px;
                     vertical-align: middle;
                     animation: wai-caret-blink 0.9s infinite; }
.wai-task          { margin-bottom: 16px; padding: 14px;
                     background: rgba(255,255,255,0.03);
                     border: 1px solid var(--wai-line);
                     border-radius: var(--wai-r-lg); }
.wai-task-title    { font-size: 12px; color: var(--wai-text-dim);
                     margin-bottom: 10px; }
.wai-task-steps    { list-style: none; padding: 0; margin: 0;
                     display: flex; flex-direction: column; gap: 8px; }
.wai-step          { display: flex; align-items: center; gap: 10px;
                     font-size: 13px; color: var(--wai-text-muted); }
.wai-step-dot      { width: 16px; height: 16px; border-radius: 50%;
                     border: 1px solid var(--wai-line-strong); flex-shrink: 0; }
.wai-step-done .wai-step-dot     { background: var(--wai-accent-soft);
                                   border-color: var(--wai-accent);
                                   position: relative; }
.wai-step-done .wai-step-dot::after { content:'✓'; position:absolute;
                                      inset:0; display:flex;
                                      align-items:center; justify-content:center;
                                      color: var(--wai-accent-bright); font-size:10px; }
.wai-step-active                 { color: var(--wai-text); font-weight: 500; }
.wai-step-active .wai-step-dot   { border-color: var(--wai-accent-bright);
                                   box-shadow: 0 0 8px var(--wai-accent-bright); }
.wai-input-row     { display: flex; align-items: center; gap: 10px;
                     padding: 14px 16px; margin-bottom: 16px;
                     background: var(--wai-surface-inset);
                     border: 1px solid var(--wai-line-strong);
                     border-radius: var(--wai-r-lg); }
.wai-input         { flex: 1; background: none; border: none;
                     color: var(--wai-text); font-size: 13px;
                     font-family: inherit; outline: none; }
.wai-input::placeholder { color: var(--wai-text-muted); font-weight: 300; }
.wai-mic           { display: flex; gap: 5px; align-items: center;
                     padding: 6px 10px;
                     background: var(--wai-accent-soft);
                     border: 1px solid var(--wai-line-accent);
                     border-radius: var(--wai-r-pill);
                     cursor: pointer; }
.wai-mic span      { width: 5px; height: 5px; border-radius: 50%;
                     background: var(--wai-accent-bright);
                     box-shadow: 0 0 6px var(--wai-accent-bright); }
.wai-mic-active span { animation: wai-dot-wave 0.7s infinite; }
.wai-mic-active span:nth-child(2) { animation-delay: 0.1s; }
.wai-mic-active span:nth-child(3) { animation-delay: 0.2s; }
.wai-quick-caption { font-family: var(--wai-font-mono);
                     font-size: var(--wai-fs-micro);
                     letter-spacing: var(--wai-tracking-caption);
                     text-transform: uppercase;
                     color: var(--wai-text-muted);
                     margin-bottom: 12px; }
.wai-quick-grid    { display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; }
.wai-quick-cell    { display: flex; flex-direction: column;
                     align-items: center; justify-content: center; gap: 6px;
                     aspect-ratio: 1; padding: 8px;
                     background: var(--wai-surface-inset);
                     border: 1px solid var(--wai-line);
                     border-radius: var(--wai-r-lg);
                     color: var(--wai-text); cursor: pointer;
                     transition: all var(--wai-dur-fast) var(--wai-ease-out); }
.wai-quick-cell:hover { background: rgba(255,255,255,0.07);
                        border-color: var(--wai-line-accent); }
.wai-quick-icon    { font-size: 18px; color: var(--wai-accent-bright); }
.wai-quick-label   { font-size: 9px; color: var(--wai-text-dim); }

──────────────────────────────────────────────────────────── */
