// ============================================================
// ActivityLog.jsx — журнал действий агента
//
// PROPS
//   entries   Array<{ id, kind, title, subtitle, time, status }>
//             status: 'ok' | 'blocked' | 'awaiting' | 'denied'
//   filter    'today' | 'week' | 'all'
//   onFilter  (next) => void
//   onExport  () => void
//
// Привязан к main: главное — отдай реальный лог из своего store
// (у тебя уже есть logAction).
// ============================================================

import React from 'react';

const STATUS_COLOR = {
  ok:       '#4ADE80',
  awaiting: '#FBBF24',
  blocked:  '#F87171',
  denied:   '#999',
};

function formatTime(ts) {
  if (!ts) return '';
  const d = new Date(ts);
  const today = new Date();
  if (d.toDateString() === today.toDateString()) {
    return d.toLocaleTimeString('ru', { hour: '2-digit', minute: '2-digit' });
  }
  return d.toLocaleDateString('ru', { day: '2-digit', month: 'short' });
}

export default function ActivityLog({
  entries = [],
  filter = 'today',
  onFilter,
  onExport,
}) {
  const pending = entries.filter(e => e.status === 'awaiting');
  const done = entries.filter(e => e.status !== 'awaiting');

  return (
    <div className="wai-log">
      {/* Header */}
      <div className="wai-log-head">
        <div>
          <div className="wai-log-caption">Activity</div>
          <h2 className="wai-log-title">Журнал действий</h2>
        </div>
        <div className="wai-tabs">
          {['today', 'week', 'all'].map(f => (
            <button
              key={f}
              className={`wai-tab ${filter === f ? 'wai-tab-active' : ''}`}
              onClick={() => onFilter?.(f)}
            >
              {f === 'today' ? 'Сегодня' : f === 'week' ? 'Неделя' : 'Всё'}
            </button>
          ))}
        </div>
      </div>

      {/* Pending */}
      {pending.map(entry => (
        <div key={entry.id} className="wai-log-row wai-log-pending">
          <span
            className="wai-log-dot"
            style={{ background: STATUS_COLOR.awaiting, boxShadow: `0 0 8px ${STATUS_COLOR.awaiting}` }}
          />
          <div>
            <div className="wai-log-row-title">{entry.title}</div>
            <div className="wai-log-row-sub">{entry.subtitle}</div>
          </div>
          <div className="wai-log-time mono">now</div>
        </div>
      ))}

      {/* Done */}
      <div className="wai-log-list">
        {done.map((entry, i) => (
          <React.Fragment key={entry.id}>
            <div className="wai-log-row">
              <span
                className="wai-log-dot"
                style={{ background: STATUS_COLOR[entry.status] || STATUS_COLOR.ok }}
              />
              <div>
                <div className="wai-log-row-title">{entry.title}</div>
                <div className="wai-log-row-sub">{entry.subtitle}</div>
              </div>
              <div className="wai-log-time mono">{formatTime(entry.time)}</div>
            </div>
            {i < done.length - 1 && <div className="wai-log-divider" />}
          </React.Fragment>
        ))}
      </div>

      {entries.length === 0 && (
        <div className="wai-log-empty">
          Пока пусто.<br />
          Действия агента появятся здесь.
        </div>
      )}

      <button className="wai-btn wai-btn-ghost wai-log-export" onClick={onExport}>
        Экспортировать · CSV
      </button>
    </div>
  );
}

/* CSS ──────────────────────────────────────────────────────

.wai-log {
  width: 100%; max-width: 420px; padding: 24px;
  background: var(--wai-surface-strong);
  backdrop-filter: var(--wai-blur-lg);
  border: 1px solid var(--wai-line-strong);
  border-radius: var(--wai-r-2xl);
  box-shadow: var(--wai-shadow-panel);
  color: var(--wai-text);
  font-family: var(--wai-font-sans);
}
.wai-log-head     { display: flex; align-items: center; justify-content: space-between; margin-bottom: 18px; }
.wai-log-caption  { font-family: var(--wai-font-mono);
                    font-size: var(--wai-fs-caption);
                    letter-spacing: var(--wai-tracking-caption);
                    text-transform: uppercase;
                    color: var(--wai-text-muted);
                    margin-bottom: 4px; }
.wai-log-title    { font-size: 17px; font-weight: 600; margin: 0; }
.wai-tabs         { display: flex; gap: 4px; padding: 3px;
                    background: rgba(255,255,255,0.04);
                    border: 1px solid var(--wai-line);
                    border-radius: var(--wai-r-sm); }
.wai-tab          { padding: 5px 10px; background: transparent;
                    color: var(--wai-text-muted); border: none;
                    border-radius: var(--wai-r-sm); font-size: 11px;
                    font-family: inherit; cursor: pointer; }
.wai-tab-active   { background: rgba(255,255,255,0.08); color: var(--wai-text); }

.wai-log-row      { display: grid; grid-template-columns: 14px 1fr auto;
                    gap: 12px; align-items: center; padding: 10px 8px; }
.wai-log-pending  { background: rgba(251,191,36,0.05);
                    border: 1px solid rgba(251,191,36,0.25);
                    border-radius: var(--wai-r-md);
                    padding: 12px 8px; margin-bottom: 6px; }
.wai-log-dot      { width: 8px; height: 8px; border-radius: 50%; }
.wai-log-pending .wai-log-dot {
  animation: wai-breathe-halo 1.4s infinite;
}
.wai-log-row-title { font-size: 13px; color: var(--wai-text); }
.wai-log-row-sub   { font-size: 11px; color: var(--wai-text-muted); margin-top: 1px; }
.wai-log-time      { font-size: 10px; color: var(--wai-text-muted); }
.wai-log-divider   { height: 1px; background: rgba(255,255,255,0.04); margin: 0 8px; }

.wai-log-empty     { padding: 40px 12px; text-align: center;
                     color: var(--wai-text-muted); font-size: 13px;
                     line-height: 1.6; }
.wai-log-export    { width: 100%; margin-top: 14px; }

────────────────────────────────────────────────────────── */
