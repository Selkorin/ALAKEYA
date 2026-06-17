// ============================================================
// App.jsx — the ALAKEYA overlay (wai-agent-integration.md §3.1).
// Wires the design-system components to the main process over window.api.
// Falls back to a local mock when run in a plain browser (design preview).
// ============================================================
import React, { useState, useEffect, useCallback, useRef } from 'react';
import Orb from './components/alakeya/Orb';
import AssistantPanel from './components/alakeya/AssistantPanel';
import PermissionCard from './components/alakeya/PermissionCard';
import ErrorToast from './components/alakeya/ErrorToast';
import ActivityLog from './components/alakeya/ActivityLog';
import SettingsWindow, { SETTINGS_DEFAULTS } from './components/alakeya/SettingsWindow';
import OnboardingFlow from './components/alakeya/OnboardingFlow';
import { WAI_STATUS_TO_ORB_STATE } from './components/alakeya/orbMachine';
import { getApi } from './mockApi';
import { playAudio, stopAudio, createRecorder } from './voice';
import { sounds, setSoundEnabled } from './sounds';
import { createWakeWord } from './wakeword';

const SLEEP_AFTER_MS = 60_000; // go translucent + sleep after 1 min idle

const QUICK_PROMPTS = {
  open: 'Открой ',
  search: 'Найди в браузере: ',
  summarize: 'Что на этом экране?',
  write: 'Напиши ',
  organize: 'Открой Finder',
  image: 'Сгенерируй картинку: ',
  translate: 'Переведи на английский: ',
  settings: '__open_settings__',
};

const api = getApi();

const SIZE_PX = { small: 64, medium: 80, large: 96 };

// Deep-merge persisted settings over defaults so new keys always exist.
function loadSettings() {
  try {
    const saved = JSON.parse(localStorage.getItem('alakeya.settings') || '{}');
    const merged = { ...SETTINGS_DEFAULTS };
    for (const group of Object.keys(SETTINGS_DEFAULTS)) {
      merged[group] = { ...SETTINGS_DEFAULTS[group], ...(saved[group] || {}) };
    }
    return merged;
  } catch {
    return SETTINGS_DEFAULTS;
  }
}

export default function App() {
  const [status, setStatus] = useState('Готов');
  const [panelOpen, setPanelOpen] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [task, setTask] = useState(null);
  const [pendingAction, setPendingAction] = useState(null);
  const [errorMsg, setErrorMsg] = useState(null);
  const [activity, setActivity] = useState([]);
  const [showActivity, setShowActivity] = useState(false);
  const [settings, setSettings] = useState(loadSettings);
  const [showSettings, setShowSettings] = useState(false);
  const [settingsTab, setSettingsTab] = useState('appearance');
  const [onboarded, setOnboarded] = useState(
    () => localStorage.getItem('alakeya.onboarded') === '1'
  );

  const appearance = settings.appearance;
  const [asleep, setAsleep] = useState(false);
  const recorderRef = useRef(null);
  const sleepTimerRef = useRef(null);
  const wakeRef = useRef(null);
  const startVoiceRef = useRef(null);
  const prevStatusRef = useRef('Готов');
  const ttsEnabledRef = useRef(settings.voice.ttsEnabled);
  ttsEnabledRef.current = settings.voice.ttsEnabled;

  // Subscribe to main-process events.
  useEffect(() => {
    const offs = [
      api.onStatus(setStatus),
      api.onTranscript((p) => {
        const { text, role } = p || {};
        if (role === 'assistant') {
          // Speak the reply in the velvety voice (if enabled + key present).
          if (ttsEnabledRef.current) {
            api.tts?.(text).then((audio) => audio && playAudio(audio));
          }
        } else {
          setTranscript(text || '');
        }
      }),
      api.onTask(setTask),
      api.onApproval(setPendingAction),
      api.onError(({ message, blocked }) => setErrorMsg({ message, blocked })),
      api.onActivity((row) => setActivity((a) => [...a, row])),
      api.onOpenSettings((tab) => { setSettingsTab(tab || 'permissions'); setShowSettings(true); }),
    ];
    api.getActivity?.().then((rows) => rows && setActivity(rows));
    return () => offs.forEach((off) => off && off());
  }, []);

  // Persist settings whenever they change, and forward the model/voice
  // preferences to the main process so the orchestrator + TTS use them.
  useEffect(() => {
    localStorage.setItem('alakeya.settings', JSON.stringify(settings));
    api.setConfig?.({
      model: settings.developer.model,
      apiKey: settings.developer.apiKey || undefined,
      ttsEnabled: settings.voice.ttsEnabled,
      ttsVoice: settings.voice.ttsVoice,
      sttModel: settings.developer.sttModel,
      speed: settings.voice.speed,
    });
  }, [settings]);

  // Apply the chosen accent + glow live (global token overrides).
  useEffect(() => {
    const root = document.documentElement.style;
    root.setProperty('--wai-accent', appearance.accent);
    root.setProperty('--orb-glow', String(appearance.glow));
  }, [appearance.accent, appearance.glow]);

  // Tell the main process which screen corner to dock the window into.
  useEffect(() => {
    api.setCorner?.(appearance.corner);
  }, [appearance.corner]);

  // Keep the synth sound library in sync with the setting.
  useEffect(() => { setSoundEnabled(settings.voice.sounds !== false); }, [settings.voice.sounds]);

  // Wake Alakeya: restore from sleep, full opacity, pleasant chime.
  const wake = useCallback(() => {
    setAsleep((was) => {
      if (was) sounds.wake();
      return false;
    });
    api.setAsleep?.(false);
  }, []);

  // Put Alakeya to sleep: translucent window + faint sleep animation.
  const sleep = useCallback(() => {
    setAsleep(true);
    sounds.sleep();
    api.setAsleep?.(true);
  }, []);

  // Idle → sleep timer. Resets on any status change, panel open, or
  // pending approval. Only sleeps when truly idle ("Готов") and closed.
  useEffect(() => {
    clearTimeout(sleepTimerRef.current);
    const idle = status === 'Готов' && !panelOpen && !pendingAction && !showSettings && !showActivity;
    if (idle && !asleep) {
      sleepTimerRef.current = setTimeout(sleep, SLEEP_AFTER_MS);
    } else if (!idle && asleep) {
      wake();
    }
    return () => clearTimeout(sleepTimerRef.current);
  }, [status, panelOpen, pendingAction, showSettings, showActivity, asleep, sleep, wake]);

  // Always-on wake word ("Алакея") when activation = wake.
  useEffect(() => {
    if (settings.voice.activation !== 'wake') {
      wakeRef.current?.stop();
      wakeRef.current = null;
      return;
    }
    const ww = createWakeWord(() => {
      wake();
      setPanelOpen(true);
      startVoiceRef.current?.();
    });
    ww.start();
    wakeRef.current = ww;
    return () => ww.stop();
  }, [settings.voice.activation, wake]);

  // Event sounds on status transitions (send / success / error).
  useEffect(() => {
    const prev = prevStatusRef.current;
    if (status !== prev) {
      if (status === 'Ошибка') sounds.error();
      else if (prev === 'Говорю' && status === 'Готов') sounds.success();
      else if (prev === 'Готов' && status === 'Думаю') sounds.send();
      prevStatusRef.current = status;
    }
  }, [status]);

  const orbState = WAI_STATUS_TO_ORB_STATE[status] || 'idle';

  const submit = useCallback((text) => {
    if (text === '__open_settings__') { setShowSettings(true); return; }
    setTask(null);
    api.runTask(text);
  }, []);

  const onQuickAction = (id) => {
    if (id === 'settings') { setShowSettings(true); return; }
    const prompt = QUICK_PROMPTS[id];
    if (prompt) submit(prompt);
  };

  // Push-to-talk: record the mic, then transcribe with Whisper and run it.
  const startVoice = useCallback(async () => {
    stopAudio();
    wake();
    try {
      const rec = createRecorder();
      await rec.start();
      recorderRef.current = rec;
      sounds.listen();
      api.startListening();
    } catch (e) {
      setErrorMsg({ message: 'Нет доступа к микрофону.', blocked: true });
    }
  }, [wake]);
  startVoiceRef.current = startVoice;

  const stopVoice = useCallback(async () => {
    const rec = recorderRef.current;
    recorderRef.current = null;
    if (!rec) { api.stopListening(); return; }
    setStatus('Думаю');
    const captured = await rec.stop();
    api.stopListening();
    if (!captured) return;
    const res = await api.stt?.(captured.bytes, captured.mime);
    if (res?.ok && res.text) {
      setTranscript(res.text);
      submit(res.text);
    } else {
      setStatus('Готов');
      if (res?.error) setErrorMsg({ message: res.error, blocked: false });
    }
  }, [submit]);

  const approve = (decision) => {
    if (pendingAction) api.approveAction(pendingAction.id, decision);
    setPendingAction(null);
  };

  const changeSetting = (path, value) => {
    setSettings((prev) => {
      const [group, key] = path.split('.');
      const next = { ...prev, [group]: { ...prev[group], [key]: value } };
      if (path === 'automation.autoSafe') api.setMode(value ? 'auto' : 'manual');
      return next;
    });
  };

  const completeOnboarding = (collected) => {
    localStorage.setItem('alakeya.onboarded', '1');
    setSettings((prev) => ({
      ...prev,
      appearance: {
        ...prev.appearance,
        ...(collected?.accent ? { accent: collected.accent } : {}),
        ...(collected?.faceStyle ? { faceStyle: collected.faceStyle } : {}),
      },
    }));
    setOnboarded(true);
  };

  if (!onboarded) {
    return (
      <div className="wai-root wai-center">
        <OnboardingFlow onComplete={completeOnboarding} onSkip={completeOnboarding} />
      </div>
    );
  }

  return (
    <div className="wai-root">
      {!panelOpen && (
        <div className="wai-orb-dock">
          <Orb
            state={orbState}
            size={SIZE_PX[appearance.size] || 80}
            accent={appearance.accent}
            glow={appearance.glow}
            particles={appearance.particles}
            faceStyle={appearance.faceStyle}
            sleeping={asleep}
            onClick={() => { wake(); setPanelOpen(true); }}
          />
        </div>
      )}

      <AssistantPanel
        open={panelOpen}
        orbState={orbState}
        appearance={appearance}
        transcript={transcript}
        currentTask={task}
        onClose={() => setPanelOpen(false)}
        onSubmit={submit}
        onVoiceStart={startVoice}
        onVoiceStop={stopVoice}
        onQuickAction={onQuickAction}
        onShowActivity={() => setShowActivity(true)}
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

      {showActivity && (
        <div className="wai-overlay" onClick={() => setShowActivity(false)}>
          <div onClick={(e) => e.stopPropagation()}>
            <ActivityLog
              entries={[...activity].reverse()}
              onExport={() => exportCsv(activity)}
            />
          </div>
        </div>
      )}

      {showSettings && (
        <div className="wai-overlay" onClick={() => setShowSettings(false)}>
          <div onClick={(e) => e.stopPropagation()}>
            <SettingsWindow
              settings={settings}
              initialTab={settingsTab}
              permissions={{ screen: 'granted', mic: 'granted', mouse: 'off', keyboard: 'off' }}
              onChange={changeSetting}
              onClose={() => setShowSettings(false)}
              onForgetMemory={() => setActivity([])}
            />
          </div>
        </div>
      )}

      {errorMsg && (
        <ErrorToast
          message={errorMsg.message}
          blocked={errorMsg.blocked}
          onDismiss={() => setErrorMsg(null)}
        />
      )}
    </div>
  );
}

function exportCsv(rows) {
  const header = 'time,kind,title,subtitle,status\n';
  const body = rows
    .map((r) => [new Date(r.time).toISOString(), r.kind, r.title, r.subtitle, r.status]
      .map((v) => `"${String(v ?? '').replace(/"/g, '""')}"`).join(','))
    .join('\n');
  const blob = new Blob([header + body], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = 'alakeya-activity.csv'; a.click();
  URL.revokeObjectURL(url);
}
