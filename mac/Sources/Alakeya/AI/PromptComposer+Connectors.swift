import Foundation

// ============================================================
// PromptComposer+Connectors.swift
// Injects active connector context into the system prompt.
// ============================================================

extension PromptComposer {
    static func connectorsSystemBlock() -> String {
        let states = ConnectorAuthStore.shared.loadStates()
        let connected = states.values
            .filter { $0.status == .connected }
            .map { title(forConnectorID: $0.connectorID) }
            .sorted()
        guard !connected.isEmpty else { return "" }
        let names = connected.joined(separator: ", ")
        return """
        ## Активные коннекторы
        Подключено: \(names).
        Если пользователь просит написать, отправить, опубликовать или запланировать пост в подключенный сервис, используй соответствующий connector tool.
        Для Telegram используй telegram_create_post_draft для черновика и telegram_publish_post для отправки. Параметры: channel, text, parse_mode.
        Для Telegram-постов по умолчанию используй parse_mode="HTML" и HTML-разметку: <b>жирный заголовок</b>, <i>красивое описание</i>, <blockquote>цитата или важная мысль</blockquote>. Не используй Markdown-маркеры **, ###, ``` в публикуемом Telegram-тексте.
        Для длинных фактов, рецептов, характеристик, списков и плотных объяснений используй <blockquote expandable>...</blockquote>. Если пишешь “Факты:” / “Вот факты:” / “Ссылки:” / “Что важно знать:”, делай заголовок секции жирным, а пункты ниже помещай в quote block.
        Ссылки оформляй как <a href="https://...">текст ссылки</a>. Custom emoji используй только если известен custom_emoji_id: <tg-emoji emoji-id="...">🙂</tg-emoji>. Если известен только стикерпак/стиль группы, подбирай живые тематические эмодзи и соблюдай настроение.
        Если пользователь просит "напиши/создай пост и отправь", сначала напиши полноценный текст публикации в стиле площадки, а в telegram_publish_post передавай именно готовый текст поста, не исходную команду пользователя.
        Если закреплено несколько соцсетей или Telegram-целей, можно сделать отдельный текст под каждую цель и вызвать публикацию для каждой выбранной цели.
        Если пользователь пишет "отправь его", "публикуй это", "подтверждаю", отправляй последний готовый черновик/пост из диалога, а не текст команды подтверждения.
        Если в сообщении есть блок "Активные соцсети для публикации", считай эти цели уже выбранными. Не проси указать группу/канал повторно.
        Разделяй намерения: "напиши пост" = только подготовь пост; "напиши пост и отправь" = подготовь новый пост и опубликуй именно его; "опубликуй его/её/это" = опубликуй последний готовый пост ассистента.
        Не говори, что у тебя нет возможности отправлять в Telegram, если Telegram подключён.
        Для уже закрепленных соцсетей дополнительное подтверждение не нужно: пользователь выбрал цели внизу чата и явно дал команду отправить.
        """
    }

    private static func title(forConnectorID id: String) -> String {
        switch id {
        case "telegram": return "Telegram"
        case "vk": return "ВКонтакте"
        case "instagram": return "Instagram"
        case "gmail": return "Gmail"
        case "google_drive": return "Google Drive"
        case "google_docs": return "Google Docs"
        case "google_sheets": return "Google Sheets"
        case "google_calendar": return "Google Calendar"
        default: return id
        }
    }
}
