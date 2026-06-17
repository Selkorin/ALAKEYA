// ============================================================
// status.js — central status emitter for the assistant.
//
// The 7 documented statuses (HANDOFF.md §4.2 / wai-agent-integration §2.1).
// Renderer maps these to orb visual states via WAI_STATUS_TO_ORB_STATE.
// ============================================================
const { EventEmitter } = require('events');

const STATUS = {
  READY: 'Готов',
  LISTENING: 'Слушаю',
  THINKING: 'Думаю',
  SPEAKING: 'Говорю',
  ACTING: 'Действую',
  AWAITING: 'Жду подтверждения',
  ERROR: 'Ошибка',
};

class StatusEmitter extends EventEmitter {
  constructor() {
    super();
    this.current = STATUS.READY;
  }

  set(next) {
    if (next === this.current) return;
    this.current = next;
    this.emit('change', next);
  }

  /** Run `fn` while showing `status`, then restore previous status. */
  wrap(status, fn) {
    const prev = this.current;
    this.set(status);
    return Promise.resolve()
      .then(fn)
      .finally(() => this.set(prev));
  }
}

const agentStatus = new StatusEmitter();

module.exports = { STATUS, agentStatus };
