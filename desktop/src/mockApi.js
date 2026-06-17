// ============================================================
// mockApi.js — returns window.api inside Electron, or a self-contained
// browser simulation for design preview / `vite preview` without Electron.
// The mock mirrors the documented agent flow end-to-end.
// ============================================================

export function getApi() {
  if (typeof window !== 'undefined' && window.api) return window.api;
  return createMock();
}

function createMock() {
  const listeners = {};
  const emit = (ch, payload) => (listeners[ch] || []).forEach((cb) => cb(payload));
  const on = (ch) => (cb) => {
    (listeners[ch] ||= []).push(cb);
    return () => { listeners[ch] = (listeners[ch] || []).filter((x) => x !== cb); };
  };
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));
  const activity = [];
  let pendingResolve = null;

  const log = (row) => {
    const full = { id: `m${Date.now()}${Math.random()}`, time: Date.now(), ...row };
    activity.push(full);
    emit('agent:activity', full);
  };

  async function gate(action) {
    emit('agent:status', 'Жду подтверждения');
    log({ kind: action.type, title: action.title, subtitle: action.scope, status: 'awaiting' });
    const decision = await new Promise((res) => {
      pendingResolve = res;
      emit('agent:action-requires-approval', { id: 'mock', ...action });
    });
    pendingResolve = null;
    if (decision === 'deny') { log({ kind: action.type, title: action.title, subtitle: 'Отклонено', status: 'denied' }); return false; }
    return true;
  }

  async function runTask(text) {
    emit('agent:status', 'Думаю');
    await wait(700);
    const low = text.toLowerCase();
    const app = /телеграм|telegram|тг/.test(low) ? 'Telegram'
      : /сафари|safari|браузер|найди/.test(low) ? 'Safari'
      : /почт|mail/.test(low) ? 'Mail' : 'Notes';
    const isSend = /напиши|отправь|send|сообщ/.test(low);

    const steps = isSend
      ? [{ label: `Открыть ${app}` }, { label: 'Ввести сообщение' }, { label: 'Отправить сообщение' }]
      : [{ label: `Открыть ${app}` }, { label: 'Готово' }];
    steps.forEach((s) => (s.status = 'pending'));
    const title = text.length > 48 ? text.slice(0, 48) + '…' : text;
    const pushTask = () => emit('agent:task-update', { title, steps });
    pushTask();

    // step 1 — open (medium, auto in mock)
    steps[0].status = 'active'; pushTask();
    emit('agent:status', 'Действую'); await wait(700);
    log({ kind: 'open_app', title: `Открыть ${app}`, subtitle: app, status: 'ok' });
    steps[0].status = 'done'; pushTask();

    if (isSend) {
      steps[1].status = 'active'; pushTask(); await wait(600);
      log({ kind: 'type_text', title: 'Ввести сообщение', subtitle: app, status: 'ok' });
      steps[1].status = 'done';
      steps[2].status = 'active'; pushTask();
      const ok = await gate({
        type: 'send_message', title: 'Отправить сообщение',
        description: `Отправить «${text.slice(0, 60)}» в ${app}.`,
        target: app, scope: app, risk: 'high', reversible: false,
      });
      if (!ok) { steps[2].status = 'pending'; pushTask(); emit('agent:status', 'Готов'); return; }
      emit('agent:status', 'Действую'); await wait(700);
      log({ kind: 'send_message', title: 'Отправить сообщение', subtitle: `Отправлено в ${app}`, status: 'ok' });
      steps[2].status = 'done'; pushTask();
    } else {
      steps[1].status = 'done'; pushTask();
    }

    emit('agent:status', 'Говорю');
    emit('agent:transcript', { text: 'Готово.', role: 'assistant' });
    await wait(1400);
    emit('agent:status', 'Готов');
  }

  return {
    onStatus: on('agent:status'),
    onTranscript: on('agent:transcript'),
    onTask: on('agent:task-update'),
    onApproval: on('agent:action-requires-approval'),
    onError: on('agent:error'),
    onActivity: on('agent:activity'),
    onOpenSettings: on('agent:open-settings'),
    runTask,
    startListening: () => { emit('agent:status', 'Слушаю'); },
    stopListening: () => { emit('agent:status', 'Готов'); },
    cancel: () => emit('agent:status', 'Готов'),
    approveAction: (_id, decision) => pendingResolve && pendingResolve(decision),
    denyAction: () => pendingResolve && pendingResolve('deny'),
    setMode: () => {},
    setConfig: () => {},
    setCorner: () => {},
    setAsleep: () => {},
    tts: async () => null,          // no API key in plain-browser preview
    stt: async () => ({ ok: false, error: 'STT недоступен в браузере' }),
    openSettings: (tab) => emit('agent:open-settings', tab),
    getStatus: async () => 'Готов',
    getActivity: async () => activity,
  };
}
