// ============================================================
// orbMachine.js — finite state machine for the assistant orb
//
// Use with XState (recommended) OR as a plain reducer.
//
// STATES
//   idle         baseline · breathing · always returns here when "free"
//   listening    mic open · 3-dot wave + pulse rings
//   thinking     LLM call in flight · sphere rotates
//   speaking     TTS playing · mouth animates with audio
//   acting       executing computer-control action · holo beam
//   permission   awaiting user approval · amber tint
//   error        action blocked / failed · friendly amber/red
//
// EVENTS
//   WAKE_WORD / CLICK / PUSH_TO_TALK   →  listening
//   STOP_LISTENING                     →  thinking | idle
//   LLM_DONE                           →  speaking | acting | idle
//   TTS_DONE                           →  idle | acting
//   ACTION_REQUIRES_APPROVAL           →  permission
//   APPROVE                            →  acting
//   DENY                               →  idle
//   ACTION_DONE                        →  idle | speaking
//   ACTION_BLOCKED                     →  error
//   ERROR                              →  error
//   DISMISS_ERROR                      →  idle
// ============================================================

// ── XState v5 config (recommended) ──────────────────────────
export const orbMachineConfig = {
  id: 'orb',
  initial: 'idle',
  states: {
    idle: {
      on: {
        WAKE_WORD: 'listening',
        CLICK_MIC: 'listening',
        PUSH_TO_TALK: 'listening',
        TEXT_SUBMITTED: 'thinking',
        ACTION_REQUIRES_APPROVAL: 'permission',
        ERROR: 'error',
      },
    },
    listening: {
      on: {
        STOP_LISTENING: 'thinking',
        CANCEL: 'idle',
        ERROR: 'error',
      },
    },
    thinking: {
      on: {
        LLM_NEEDS_SPEECH: 'speaking',
        LLM_NEEDS_ACTION: 'acting',
        LLM_NEEDS_APPROVAL: 'permission',
        LLM_DONE: 'idle',
        ERROR: 'error',
      },
    },
    speaking: {
      on: {
        TTS_DONE: 'idle',
        TTS_DONE_THEN_ACT: 'acting',
        CANCEL: 'idle',
      },
    },
    acting: {
      on: {
        ACTION_REQUIRES_APPROVAL: 'permission',
        ACTION_DONE: 'idle',
        ACTION_DONE_THEN_SPEAK: 'speaking',
        ACTION_BLOCKED: 'error',
        ERROR: 'error',
        CANCEL: 'idle',
      },
    },
    permission: {
      on: {
        APPROVE: 'acting',
        APPROVE_AND_REMEMBER: 'acting',
        DENY: 'idle',
        ERROR: 'error',
      },
    },
    error: {
      on: {
        DISMISS_ERROR: 'idle',
        RETRY: 'thinking',
      },
    },
  },
};

// ── Plain reducer (if you're not using XState) ──────────────
//
//   const [state, dispatch] = useReducer(orbReducer, 'idle');
//   dispatch({ type: 'WAKE_WORD' });
//
// ────────────────────────────────────────────────────────────
const TRANSITIONS = {
  idle: {
    WAKE_WORD: 'listening', CLICK_MIC: 'listening', PUSH_TO_TALK: 'listening',
    TEXT_SUBMITTED: 'thinking', ACTION_REQUIRES_APPROVAL: 'permission', ERROR: 'error',
  },
  listening: { STOP_LISTENING: 'thinking', CANCEL: 'idle', ERROR: 'error' },
  thinking: {
    LLM_NEEDS_SPEECH: 'speaking', LLM_NEEDS_ACTION: 'acting',
    LLM_NEEDS_APPROVAL: 'permission', LLM_DONE: 'idle', ERROR: 'error',
  },
  speaking: { TTS_DONE: 'idle', TTS_DONE_THEN_ACT: 'acting', CANCEL: 'idle' },
  acting: {
    ACTION_REQUIRES_APPROVAL: 'permission', ACTION_DONE: 'idle',
    ACTION_DONE_THEN_SPEAK: 'speaking', ACTION_BLOCKED: 'error',
    ERROR: 'error', CANCEL: 'idle',
  },
  permission: { APPROVE: 'acting', APPROVE_AND_REMEMBER: 'acting', DENY: 'idle', ERROR: 'error' },
  error: { DISMISS_ERROR: 'idle', RETRY: 'thinking' },
};

export function orbReducer(state, event) {
  const next = TRANSITIONS[state]?.[event.type];
  return next ?? state;   // unknown event → stay
}

// ── Map your existing WAI Agent statuses to orb states ──────
//
// Your widget already exposes: Готов, Думаю, Слушаю, Говорю.
// Add three more: Действую, Жду подтверждения, Ошибка.
//
export const WAI_STATUS_TO_ORB_STATE = {
  'Готов':                'idle',
  'Слушаю':               'listening',
  'Думаю':                'thinking',
  'Говорю':               'speaking',
  'Действую':             'acting',
  'Жду подтверждения':    'permission',
  'Ошибка':               'error',
};

export const ORB_STATE_TO_WAI_STATUS = Object.fromEntries(
  Object.entries(WAI_STATUS_TO_ORB_STATE).map(([k, v]) => [v, k])
);
