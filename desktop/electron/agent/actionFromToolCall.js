// ============================================================
// actionFromToolCall.js — turn a raw tool call into a UI-ready
// action object for the PermissionCard (wai-agent-integration §3.2).
// ============================================================

function actionFromToolCall(tc) {
  const base = { id: tc.id, type: tc.name };
  const a = tc.arguments || {};

  switch (tc.name) {
    case 'open_app':
      return { ...base,
        title: `Открыть ${a.app}`,
        description: `Запустить приложение ${a.app}.`,
        target: a.app, scope: a.app, app: a.app, reversible: true };

    case 'navigate_url':
      return { ...base,
        title: 'Открыть ссылку',
        description: `Перейти на ${a.url}.`,
        url: a.url, target: 'Safari', scope: 'Браузер', reversible: true };

    case 'search':
      return { ...base,
        title: 'Поиск',
        description: `Найти: «${a.query || a.text || ''}».`,
        query: a.query || a.text, target: 'Браузер', scope: 'Браузер', reversible: true };

    case 'type_text':
      return { ...base,
        title: 'Ввести текст',
        description: `Напечатать: «${String(a.text || '').slice(0, 80)}».`,
        text: a.text, target: a.target || 'активное поле', scope: a.app || '—', reversible: true };

    case 'click_element':
      return { ...base,
        title: 'Нажать элемент',
        description: `Кликнуть «${a.text || a.target}».`,
        text: a.text, target: a.target || a.text, scope: a.app || '—', reversible: true };

    case 'send_message':
      return { ...base,
        title: 'Отправить сообщение',
        description: `Отправить «${String(a.text || '').slice(0, 80)}» — ${a.target}.`,
        text: a.text, target: a.target, scope: a.app || 'Мессенджер', reversible: false };

    case 'send_email':
      return { ...base,
        title: 'Отправить письмо',
        description: `Отправить письмо: ${a.target}.`,
        target: a.target, scope: 'Mail', reversible: false };

    case 'delete_file':
      return { ...base,
        title: 'Удалить файл',
        description: `Удалить ${a.target}. Действие необратимо.`,
        target: a.target, scope: 'Finder', reversible: false };

    case 'run_shell':
      return { ...base,
        title: 'Выполнить shell-команду',
        description: 'Команда показана ниже. Проверь перед запуском.',
        code: a.command, target: 'Terminal', scope: 'Система', reversible: false };

    case 'make_payment':
      return { ...base,
        title: 'Совершить платёж',
        description: `Оплата: ${a.target}.`,
        target: a.target, scope: 'Платежи', reversible: false };

    default:
      return { ...base,
        title: tc.name,
        description: a.description || 'Действие агента.',
        target: a.target || '—', scope: a.scope || '—', reversible: true };
  }
}

module.exports = { actionFromToolCall };
