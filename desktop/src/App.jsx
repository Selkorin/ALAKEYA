// ============================================================
// App.jsx — the ALAKEYA overlay (wai-agent-integration.md §3.1).
// Wires the design-system components to the main process over window.api.
// Falls back to a local mock when run in a plain browser (design preview).
// ============================================================
import React, { useState, useEffect, useCallback } from 'react';
import Orb from './components/alakeya/Orb';
import AssistantPanel from './components/alakeya/AssistantPanel';
import PermissionCard from './components/alakeya/PermissionCard';
import ErrorToast from './components/alakeya/ErrorToast';
import ActivityLog from './components/alakeya/ActivityLog';
import SettingsWindow, { SETTINGS_DEFAULTS } from './components/alakeya/SettingsWindow';
import OnboardingFlow from './components/alakeya/OnboardingFlow';
import { WAI_STATUS_TO_ORB_STATE } from './components/alakeya/orbMachine';
import { getApi } from './mockApi';

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

export default function App() {
  const [status, setStatus] = useState('Готов');
  const [panelOpen, setPanelOpen] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [task, setTask] = useState(null);
  const [pendingAction, setPendingAction] = useState(null);
  const [errorMsg, setErrorMsg] = useState(null);
  const [activity, setActivity] = useState([]);
  const [showActivity, setShowActivity] = useState(false);
  const [settings, setSettings] = useState(SETTINGS_DEFAULTS);
  const [showSettings, setShowSettings] = useState(false);
  const [settingsTab, setSettingsTab] = useState('appearance');
  const [onboarded, setOnboarded] = useState(
    () => localStorage.getItem('alakeya.onboarded') === '1'
  );

  // Subscribe to main-process events.
  useEffect(() => {
    const offs = [
      api.onStatus(setStatus),
      api.onTranscript(({ text }) => setTranscript(text)),
      api.onTask(setTask),
      api.onApproval(setPendingAction),
      api.onError(({ message, blocked }) => setErrorMsg({ message, blocked })),
      api.onActivity((row) => setActivity((a) => [...a, row])),
      api.onOpenSettings((tab) => { setSettingsTab(tab || 'permissions'); setShowSettings(true); }),
    ];
    api.getActivity?.().then((rows) => rows && setActivity(rows));
    return () => offs.forEach((off) => off && off());
  }, []);

  // Apply the chosen accent live (token override).
  useEffect(() => {
    const accent = settings.appearance.accent;
    document.documentElement.style.setProperty('--wai-accent', accent);
  }, [settings.appearance.accent]);

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
    if (collected?.accent) changeSetting('appearance.accent', collected.accent);
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
          <Orb state={orbState} size={72} onClick={() => setPanelOpen(true)} />
        </div>
      )}

      <AssistantPanel
        open={panelOpen}
        orbState={orbState}
        transcript={transcript}
        currentTask={task}
        onClose={() => setPanelOpen(false)}
        onSubmit={submit}
        onVoiceStart={() => api.startListening()}
        onVoiceStop={() => api.stopListening()}
        onQuickAction={onQuickAction}
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
