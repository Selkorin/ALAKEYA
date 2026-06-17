// ============================================================
// OnboardingFlow.jsx — 6-шаговый онбординг
//
// PROPS
//   onComplete  (settings) => void   — собранные настройки в конце
//   onSkip      () => void
//
// Состояние и сохранение прогресса сделай в App (electron-store):
//   { step: 1..6, settings: {...} }
// ============================================================

import React, { useState, useEffect } from 'react';
import Orb from './Orb';

const STEPS = ['welcome', 'voice', 'permissions', 'safety', 'personalize', 'ready'];

export default function OnboardingFlow({ onComplete, onSkip }) {
  const [step, setStep] = useState(0);
  const [collected, setCollected] = useState({
    micDeviceId: 'default',
    permissions: { screen: 'granted', mic: 'granted', mouse: 'off', keyboard: 'off' },
    accent: '#06B6D4',
    faceStyle: 'friendly',
  });

  const next = () => {
    if (step < STEPS.length - 1) setStep(s => s + 1);
    else onComplete?.(collected);
  };
  const back = () => setStep(s => Math.max(0, s - 1));
  const update = (patch) => setCollected(c => ({ ...c, ...patch }));

  return (
    <div className="wai-onboard">
      <header className="wai-onboard-head">
        <span className="mono" style={{ fontSize: 10, color: 'var(--wai-text-muted)' }}>
          {String(step + 1).padStart(2, '0')} / {String(STEPS.length).padStart(2, '0')}
        </span>
        <ProgressBar step={step} total={STEPS.length} />
        <button className="wai-icon-btn" onClick={onSkip} aria-label="Skip">×</button>
      </header>

      <div className="wai-onboard-body">
        {step === 0 && <Welcome />}
        {step === 1 && <VoiceTest deviceId={collected.micDeviceId} onChange={(id) => update({ micDeviceId: id })} />}
        {step === 2 && <Permissions perms={collected.permissions} onToggle={(k, v) => update({ permissions: { ...collected.permissions, [k]: v } })} />}
        {step === 3 && <Safety />}
        {step === 4 && <Personalize accent={collected.accent} face={collected.faceStyle} onChange={update} />}
        {step === 5 && <Ready accent={collected.accent} face={collected.faceStyle} />}
      </div>

      <footer className="wai-onboard-foot">
        {step > 0 && step < STEPS.length - 1 && (
          <button className="wai-btn wai-btn-ghost" onClick={back}>Назад</button>
        )}
        <button
          className="wai-btn wai-btn-primary"
          onClick={next}
          style={{ minWidth: 200 }}
        >
          {step === 0 ? 'Начать →' :
           step === STEPS.length - 1 ? 'Открыть Alakeya →' :
           'Продолжить →'}
        </button>
      </footer>
    </div>
  );
}

/* ── Steps ──────────────────────────────────────────────── */

function Welcome() {
  return (
    <div className="wai-onboard-center">
      <Orb state="idle" size={96} />
      <h2 className="wai-onboard-h">Знакомься, Alakeya<span style={{ color: 'var(--wai-accent)' }}>.</span></h2>
      <p className="wai-onboard-p">
        Твой AI-компаньон для рабочего стола.<br />
        Голосом, контекстом, всегда в углу.
      </p>
    </div>
  );
}

function VoiceTest({ deviceId, onChange }) {
  const [level, setLevel] = useState(0);

  // фейковая «амплитуда» — в проде подключи MediaRecorder + AnalyserNode
  useEffect(() => {
    const id = setInterval(() => setLevel(0.2 + Math.random() * 0.8), 80);
    return () => clearInterval(id);
  }, []);

  return (
    <div className="wai-onboard-center">
      <div className="wai-mic-test">
        {Array.from({ length: 11 }).map((_, i) => (
          <span
            key={i}
            style={{
              height: `${(Math.sin(Date.now() / 200 + i) * 0.5 + 0.5) * level * 50 + 10}px`,
              background: i === 5 ? 'var(--wai-accent-bright)' : 'var(--wai-accent)',
              animation: `wai-dot-wave 0.7s infinite ${i * 0.05}s`,
            }}
          />
        ))}
      </div>
      <div style={{ fontSize: 11, color: 'var(--wai-accent-bright)', marginBottom: 18, display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--wai-accent-bright)' }} />
        Слушаю · MacBook Pro Mic
      </div>
      <select
        className="wai-settings-input"
        style={{ maxWidth: 260 }}
        value={deviceId}
        onChange={(e) => onChange(e.target.value)}
      >
        <option value="default">По умолчанию</option>
        <option value="builtin">MacBook Pro Microphone</option>
      </select>
      <h2 className="wai-onboard-h" style={{ marginTop: 22 }}>Скажи что-нибудь</h2>
      <p className="wai-onboard-p">Проверим, что Alakeya тебя слышит.</p>
    </div>
  );
}

function Permissions({ perms, onToggle }) {
  const rows = [
    { key: 'screen',  label: 'Чтение экрана', desc: 'Чтобы понимать контекст' },
    { key: 'mic',     label: 'Микрофон',      desc: 'Для голосовых команд' },
    { key: 'mouse',   label: 'Мышь и клавиатура', desc: 'Выкл по умолчанию · включается по приложению' },
  ];
  return (
    <>
      <h2 className="wai-onboard-h" style={{ textAlign: 'center', marginBottom: 4 }}>Что Alakeya может</h2>
      <p className="wai-onboard-p" style={{ textAlign: 'center', marginBottom: 24 }}>Эти настройки можно менять в любое время.</p>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {rows.map(r => (
          <div key={r.key} className="wai-onboard-perm">
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13, fontWeight: 500 }}>{r.label}</div>
              <div style={{ fontSize: 11, color: 'var(--wai-text-muted)', marginTop: 2 }}>{r.desc}</div>
            </div>
            <button
              className={`wai-toggle ${perms[r.key] === 'granted' ? 'wai-toggle-on' : ''}`}
              onClick={() => onToggle(r.key, perms[r.key] === 'granted' ? 'off' : 'granted')}
            >
              <span />
            </button>
          </div>
        ))}
      </div>
    </>
  );
}

function Safety() {
  return (
    <div className="wai-onboard-center">
      <div style={{ position: 'relative', transform: 'rotate(-3deg)', boxShadow: 'var(--wai-shadow-card)' }}>
        <div style={{
          width: 220, padding: 16,
          background: 'rgba(255,255,255,0.04)',
          border: '1px solid var(--wai-line-accent)',
          borderRadius: 'var(--wai-r-lg)',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
            <Orb state="permission" size={28} />
            <span style={{ fontSize: 11, fontWeight: 500 }}>Подтверждение</span>
          </div>
          <p style={{ fontSize: 11, lineHeight: 1.45, color: 'var(--wai-text-dim)', margin: '0 0 12px' }}>
            Открыть Mail и отправить черновик Анне?
          </p>
          <div style={{ display: 'flex', gap: 6 }}>
            <button className="wai-btn wai-btn-ghost" style={{ flex: 1, padding: '6px 0', fontSize: 10 }}>Отмена</button>
            <button className="wai-btn wai-btn-primary" style={{ flex: 1, padding: '6px 0', fontSize: 10 }}>Разрешить</button>
          </div>
        </div>
      </div>
      <h2 className="wai-onboard-h" style={{ marginTop: 32 }}>Ты всегда контролируешь</h2>
      <p className="wai-onboard-p">
        Alakeya спрашивает перед отправкой,<br />
        удалением или оплатой. Всегда.
      </p>
    </div>
  );
}

function Personalize({ accent, face, onChange }) {
  const colors = ['#3B82F6', '#06B6D4', '#8B5CF6', '#EC4899', '#4ADE80'];
  const faces = [
    { value: 'minimal',    label: 'Минимальный' },
    { value: 'friendly',   label: 'Дружелюбный' },
    { value: 'futuristic', label: 'Футуристичный' },
  ];

  return (
    <>
      <h2 className="wai-onboard-h" style={{ textAlign: 'center', marginBottom: 4 }}>Сделай своим</h2>
      <p className="wai-onboard-p" style={{ textAlign: 'center', marginBottom: 20 }}>Выбери цвет и стиль лица.</p>
      <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 24 }}>
        <Orb state="idle" size={88} accent={accent} faceStyle={face} />
      </div>
      <div style={{ fontFamily: 'var(--wai-font-mono)', fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: 'var(--wai-text-muted)', marginBottom: 8 }}>Акцент</div>
      <div style={{ display: 'flex', justifyContent: 'center', gap: 8, marginBottom: 22 }}>
        {colors.map(c => (
          <button
            key={c}
            className="wai-color"
            style={{ background: c, width: 28, height: 28, border: c === accent ? '2px solid #fff' : '2px solid transparent', borderRadius: '50%', cursor: 'pointer', boxShadow: c === accent ? '0 0 10px rgba(6,182,212,0.6)' : 'none' }}
            onClick={() => onChange({ accent: c })}
          />
        ))}
      </div>
      <div style={{ fontFamily: 'var(--wai-font-mono)', fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase', color: 'var(--wai-text-muted)', marginBottom: 8 }}>Лицо</div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 6 }}>
        {faces.map(f => (
          <button
            key={f.value}
            className={`wai-seg ${face === f.value ? 'wai-seg-active' : ''}`}
            style={{ padding: '8px 0' }}
            onClick={() => onChange({ faceStyle: f.value })}
          >
            {f.label}
          </button>
        ))}
      </div>
    </>
  );
}

function Ready({ accent, face }) {
  return (
    <div className="wai-onboard-center">
      <Orb state="idle" size={104} accent={accent} faceStyle={face} />
      <h2 className="wai-onboard-h" style={{ marginTop: 32 }}>Всё готово.</h2>
      <p className="wai-onboard-p">
        Скажи «Hey Alakeya» в любое время,<br />
        или нажми на орб в углу.
      </p>
    </div>
  );
}

function ProgressBar({ step, total }) {
  return (
    <div style={{ display: 'flex', gap: 4, flex: 1, justifyContent: 'center' }}>
      {Array.from({ length: total }).map((_, i) => (
        <div
          key={i}
          style={{
            width: i === step ? 16 : 8,
            height: 3,
            background: i <= step ? 'var(--wai-accent)' : 'rgba(255,255,255,0.12)',
            borderRadius: 2,
            boxShadow: i === step ? '0 0 6px var(--wai-accent)' : 'none',
            transition: 'all var(--wai-dur-fast) var(--wai-ease-out)',
          }}
        />
      ))}
    </div>
  );
}

/* CSS ──────────────────────────────────────────────────────

.wai-onboard {
  width: 640px; min-height: 480px;
  padding: 24px;
  background: var(--wai-surface-strong);
  backdrop-filter: var(--wai-blur-lg);
  border: 1px solid var(--wai-line-strong);
  border-radius: 18px;
  box-shadow: var(--wai-shadow-panel);
  color: var(--wai-text);
  font-family: var(--wai-font-sans);
  display: flex; flex-direction: column;
}
.wai-onboard-head {
  display: flex; align-items: center; gap: 16px;
  margin-bottom: 24px;
}
.wai-onboard-body {
  flex: 1; display: flex; flex-direction: column; justify-content: center;
  padding: 24px 12px;
}
.wai-onboard-foot {
  display: flex; gap: 10px; justify-content: flex-end; align-items: center;
}
.wai-onboard-center {
  display: flex; flex-direction: column; align-items: center; gap: 4px;
  text-align: center;
}
.wai-onboard-h {
  font-size: 24px; font-weight: 600; letter-spacing: -0.6px;
  margin: 24px 0 6px;
}
.wai-onboard-p {
  font-size: 13px; color: var(--wai-text-dim);
  line-height: 1.55; margin: 0;
}
.wai-onboard-perm {
  display: flex; align-items: center; gap: 12px;
  padding: 14px;
  background: var(--wai-surface-inset);
  border: 1px solid var(--wai-line);
  border-radius: var(--wai-r-md);
}
.wai-mic-test {
  display: flex; align-items: flex-end; gap: 4px;
  height: 60px; margin-bottom: 16px;
}
.wai-mic-test span {
  width: 4px; border-radius: 2px;
  transform-origin: bottom;
}

────────────────────────────────────────────────────────── */
