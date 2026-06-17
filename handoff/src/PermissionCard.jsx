// ============================================================
// PermissionCard.jsx — confirmation dialog before risky actions
//
// PROPS
//   action            { title, description, target, risk, reversible, scope, code? }
//   onAllowOnce       () => void
//   onAlwaysAllow     () => void    (binds this action signature to app/scope)
//   onCancel          () => void
//
// RISK LEVELS (match your existing WAI Agent classifier)
//   'low'     green   — search, read, focus window
//   'medium'  cyan    — open app, click safe element, write text
//   'high'    amber   — send message, delete, run shell, payment
//
// Wire your `action_to_be_executed` event from main process here.
// ============================================================

import React, { useEffect } from 'react';

const RISK_META = {
  low:    { color: '#4ADE80', label: 'Низкий риск', icon: '●' },
  medium: { color: '#67E8F9', label: 'Средний риск', icon: '◆' },
  high:   { color: '#FBBF24', label: 'Высокий риск', icon: '▲' },
};

export default function PermissionCard({
  action,
  onAllowOnce,
  onAlwaysAllow,
  onCancel,
}) {
  // Keyboard shortcuts: ⌘. cancel, ⌘⏎ allow once
  useEffect(() => {
    const onKey = (e) => {
      if (e.key === 'Escape' || (e.metaKey && e.key === '.')) {
        e.preventDefault();
        onCancel?.();
      }
      if (e.metaKey && e.key === 'Enter') {
        e.preventDefault();
        onAllowOnce?.();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onCancel, onAllowOnce]);

  const risk = RISK_META[action.risk] || RISK_META.medium;

  return (
    <div className="wai-permission-card" role="alertdialog" aria-modal="true">
      {/* Header */}
      <div className="wai-pc-header">
        <div className="wai-pc-orb" aria-hidden="true" />
        <div>
          <div className="wai-pc-caption">Подтверждение действия</div>
          <h3 className="wai-pc-title">{action.title}</h3>
        </div>
      </div>

      {/* Action preview */}
      <div className="wai-pc-preview">
        <p>{action.description}</p>
        {action.code && (
          <pre className="wai-pc-code"><code>{action.code}</code></pre>
        )}
      </div>

      {/* Risk meta */}
      <div className="wai-pc-meta">
        <div className="wai-pc-meta-row">
          <span>Уровень риска</span>
          <span style={{ color: risk.color }}>{risk.icon} {risk.label}</span>
        </div>
        <div className="wai-pc-meta-row">
          <span>Обратимо</span>
          <span>{action.reversible ? 'Да' : 'Нет'}</span>
        </div>
        <div className="wai-pc-meta-row">
          <span>Затронет</span>
          <span>{action.scope || '—'}</span>
        </div>
      </div>

      {/* Actions */}
      <div className="wai-pc-actions">
        <button className="wai-btn wai-btn-ghost" onClick={onCancel}>
          Отмена
        </button>
        <button className="wai-btn wai-btn-secondary" onClick={onAllowOnce}>
          Разрешить один раз
        </button>
        <button className="wai-btn wai-btn-primary" onClick={onAlwaysAllow}>
          Всегда для&nbsp;{action.target}
        </button>
      </div>

      <p className="wai-pc-hint">
        <kbd>⌘ .</kbd> отмена&nbsp;·&nbsp;<kbd>⌘ ⏎</kbd> разрешить
      </p>
    </div>
  );
}

/* Required CSS — drop in your stylesheet ────────────────────

.wai-permission-card {
  width: 100%; max-width: 420px;
  padding: var(--wai-s-7);
  background: var(--wai-surface-strong);
  backdrop-filter: var(--wai-blur-lg);
  border: 1px solid var(--wai-line-strong);
  border-radius: var(--wai-r-2xl);
  box-shadow: var(--wai-shadow-panel);
  color: var(--wai-text);
}
.wai-pc-header   { display: flex; align-items: center; gap: 14px; margin-bottom: 22px; }
.wai-pc-orb      { width: 44px; height: 44px; border-radius: 50%;
                   background: var(--wai-orb-core);
                   box-shadow: 0 0 20px var(--wai-accent-glow); }
.wai-pc-caption  { font-family: var(--wai-font-mono);
                   font-size: var(--wai-fs-caption);
                   letter-spacing: var(--wai-tracking-caption);
                   text-transform: uppercase;
                   color: var(--wai-text-muted); margin-bottom: 4px; }
.wai-pc-title    { font-size: 18px; font-weight: 600; margin: 0; }
.wai-pc-preview  { padding: 16px; margin-bottom: 18px;
                   background: rgba(255, 255, 255, 0.03);
                   border: 1px solid var(--wai-line);
                   border-radius: var(--wai-r-lg); }
.wai-pc-preview p { margin: 0 0 12px; font-size: var(--wai-fs-body);
                    line-height: var(--wai-lh-body); color: var(--wai-text-dim); }
.wai-pc-code     { padding: 10px 14px;
                   background: var(--wai-accent-soft);
                   border: 1px solid var(--wai-line-accent);
                   border-radius: var(--wai-r-md);
                   font-family: var(--wai-font-mono); font-size: 13px;
                   color: var(--wai-text); margin: 0; }
.wai-pc-meta     { padding: 12px 14px; margin-bottom: 22px;
                   background: rgba(255, 255, 255, 0.02);
                   border: 1px solid rgba(255, 255, 255, 0.05);
                   border-radius: var(--wai-r-md); }
.wai-pc-meta-row { display: flex; justify-content: space-between;
                   font-size: var(--wai-fs-small); padding: 4px 0; }
.wai-pc-meta-row span:first-child { color: var(--wai-text-muted); }
.wai-pc-actions  { display: grid; grid-template-columns: 1fr 1fr 1.2fr; gap: 8px; }
.wai-pc-hint     { font-size: var(--wai-fs-caption);
                   color: var(--wai-text-muted);
                   margin: 12px 0 0; text-align: center; }
.wai-pc-hint kbd { font-family: var(--wai-font-mono);
                   padding: 2px 6px;
                   background: rgba(255,255,255,0.06);
                   border: 1px solid var(--wai-line);
                   border-radius: 4px; }
.wai-btn         { padding: 12px 0; border: none; border-radius: var(--wai-r-lg);
                   font-size: 13px; font-family: var(--wai-font-sans);
                   font-weight: 500; cursor: pointer;
                   transition: all var(--wai-dur-fast) var(--wai-ease-out); }
.wai-btn-ghost   { background: transparent; color: var(--wai-text-dim);
                   border: 1px solid var(--wai-line-strong); }
.wai-btn-secondary { background: rgba(255,255,255,0.06); color: var(--wai-text);
                     border: 1px solid var(--wai-line-strong); }
.wai-btn-primary { background: linear-gradient(180deg, var(--wai-accent), var(--wai-accent-deep));
                   color: #001018; font-weight: 600;
                   box-shadow: var(--wai-shadow-cta); }
.wai-btn-primary:hover { box-shadow: var(--wai-shadow-cta-hover); }
.wai-btn-ghost:hover,
.wai-btn-secondary:hover { background: rgba(255,255,255,0.10); }

──────────────────────────────────────────────────────────── */
