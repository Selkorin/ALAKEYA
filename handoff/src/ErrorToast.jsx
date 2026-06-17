// ============================================================
// ErrorToast.jsx — мягкий janтарный/красный тост для ошибок
//
// PROPS
//   message   string
//   blocked   boolean   — true если действие было заблокировано
//   onDismiss () => void
//   autoHideMs number   — default 6000
//
// Привязан к 'agent:error' IPC.
// ============================================================

import React, { useEffect } from 'react';

export default function ErrorToast({
  message,
  blocked = false,
  onDismiss,
  autoHideMs = 6000,
}) {
  useEffect(() => {
    if (!autoHideMs) return;
    const t = setTimeout(() => onDismiss?.(), autoHideMs);
    return () => clearTimeout(t);
  }, [autoHideMs, onDismiss]);

  return (
    <div
      className="wai-toast"
      role="alert"
      style={{
        '--toast-accent': blocked ? '#FBBF24' : '#F87171',
      }}
    >
      <div className="wai-toast-caption">
        {blocked ? 'Действие заблокировано' : 'Ошибка'}
      </div>
      <p className="wai-toast-msg">{message}</p>
      <div className="wai-toast-actions">
        <button className="wai-btn wai-btn-ghost" onClick={onDismiss}>
          Закрыть
        </button>
        {blocked && (
          <button
            className="wai-btn wai-btn-secondary"
            onClick={() => window.api?.openSettings?.('permissions')}
          >
            Открыть настройки
          </button>
        )}
      </div>
      {/* timer bar */}
      <div className="wai-toast-timer">
        <div style={{ animation: `wai-toast-timer ${autoHideMs}ms linear` }} />
      </div>
    </div>
  );
}

/* CSS ──────────────────────────────────────────────────────

.wai-toast {
  position: fixed; bottom: 120px; right: 24px;
  width: 280px; padding: 14px 16px;
  background: rgba(20, 12, 4, 0.85);
  backdrop-filter: var(--wai-blur-md);
  border: 1px solid var(--toast-accent);
  border-radius: var(--wai-r-lg);
  color: var(--wai-text);
  font-family: var(--wai-font-sans);
  box-shadow: var(--wai-shadow-card);
  z-index: var(--wai-z-toast);
  animation: wai-toast-in var(--wai-dur-medium) var(--wai-ease-out);
}
@keyframes wai-toast-in {
  from { transform: translateY(20px); opacity: 0; }
  to   { transform: translateY(0);    opacity: 1; }
}
@keyframes wai-toast-timer {
  from { width: 100%; }
  to   { width: 0%; }
}
.wai-toast-caption {
  font-family: var(--wai-font-mono);
  font-size: var(--wai-fs-caption);
  letter-spacing: var(--wai-tracking-caption);
  text-transform: uppercase;
  color: var(--toast-accent);
  margin-bottom: 6px;
}
.wai-toast-msg {
  font-size: var(--wai-fs-body);
  line-height: 1.45;
  margin: 0 0 10px;
  color: var(--wai-text);
}
.wai-toast-actions { display: flex; gap: 6px; }
.wai-toast-timer {
  position: absolute; bottom: 0; left: 0; right: 0; height: 2px;
  background: rgba(255,255,255,0.08);
  border-radius: 0 0 var(--wai-r-lg) var(--wai-r-lg);
  overflow: hidden;
}
.wai-toast-timer > div {
  height: 100%;
  background: linear-gradient(90deg, var(--toast-accent), var(--wai-accent-bright));
}

────────────────────────────────────────────────────────── */
