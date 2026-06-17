// ============================================================
// toolRunner.js — permission gate + executor + journaling, and the
// task loop that drives the 7 statuses (wai-agent-integration §2.2, §4).
// ============================================================
const { agentStatus, STATUS } = require('./status');
const { EXECUTORS } = require('./executors');
const { actionFromToolCall } = require('./actionFromToolCall');
const orchestrator = require('./orchestrator');
const ctx = require('../context');
const {
  classifyRisk, shouldAutoConfirm, rememberedRules, saveRules, askUser,
} = require('../permissions');

function humanize(e) {
  if (/not found|не найден/i.test(e.message)) return 'Не нашёл нужный элемент или приложение.';
  return e.message || 'Что-то пошло не так.';
}
function isBlocked(e) { return /denied|blocked|permission/i.test(e.message || ''); }

/** Gate one action through policy, then execute it. */
async function runTool(action) {
  const risk = classifyRisk(action);
  const auto = shouldAutoConfirm(risk, ctx.getMode(), rememberedRules, action);

  if (!auto) {
    agentStatus.set(STATUS.AWAITING);
    ctx.addLog({ kind: action.type, title: action.title, subtitle: action.scope, status: 'awaiting' });
    const wc = ctx.windows.orb?.webContents;
    const decision = await askUser(wc, action);

    if (decision === 'deny') {
      ctx.addLog({ kind: action.type, title: action.title, subtitle: 'Отклонено', status: 'denied' });
      agentStatus.set(STATUS.READY);
      return { ok: false, denied: true };
    }
    if (decision === 'always') {
      rememberedRules.add(`${action.type}:${action.target}`);
      saveRules();
    }
  }

  agentStatus.set(STATUS.ACTING);
  try {
    const exec = EXECUTORS[action.type];
    if (!exec) throw new Error(`Нет исполнителя для «${action.type}»`);
    const result = await exec(action);
    ctx.addLog({ kind: action.type, title: action.title, subtitle: result.summary, status: 'ok' });
    return { ok: true, result };
  } catch (e) {
    agentStatus.set(STATUS.ERROR);
    ctx.addLog({ kind: action.type, title: action.title, subtitle: humanize(e), status: 'blocked' });
    ctx.send('agent:error', { message: humanize(e), blocked: isBlocked(e) });
    setTimeout(() => agentStatus.set(STATUS.READY), 4000);
    return { ok: false, error: e.message };
  }
}

/** Full task: plan → (gate → execute)* → speak → idle. */
async function runTask(text) {
  agentStatus.set(STATUS.THINKING);
  let planned;
  try {
    planned = await orchestrator.plan(text);
  } catch (e) {
    agentStatus.set(STATUS.ERROR);
    ctx.send('agent:error', { message: humanize(e), blocked: false });
    setTimeout(() => agentStatus.set(STATUS.READY), 4000);
    return;
  }

  // Push task progress to the panel.
  const steps = planned.steps.map((s) => ({ ...s, status: 'pending' }));
  const taskTitle = text.length > 48 ? text.slice(0, 48) + '…' : text;
  const pushTask = () => ctx.send('agent:task-update', { title: taskTitle, steps });
  pushTask();

  for (let i = 0; i < planned.toolCalls.length; i++) {
    steps[i].status = 'active';
    pushTask();
    const action = actionFromToolCall(planned.toolCalls[i]);
    const r = await runTool(action);
    if (!r.ok) {
      steps[i].status = r.denied ? 'pending' : 'blocked';
      pushTask();
      return; // stop the chain on deny/error
    }
    steps[i].status = 'done';
    pushTask();
  }

  if (planned.reply) {
    agentStatus.set(STATUS.SPEAKING);
    ctx.send('agent:transcript', { text: planned.reply, partial: false, role: 'assistant' });
    await new Promise((r) => setTimeout(r, Math.min(2200, 600 + planned.reply.length * 35)));
  }
  agentStatus.set(STATUS.READY);
}

module.exports = { runTool, runTask };
