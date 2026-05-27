# WAI Social Brain - Platform Integration Guide

## 📋 Быстрый старт

### 1️⃣ Telegram (Самый простой)

**Требуется:**
- Bot Token (от @BotFather)
- Chat ID (ID канала или группы)

**Как получить:**

1. Откройте Telegram и найдите @BotFather
2. Отправьте `/newbot`
3. Следуйте инструкциям, получите Bot Token
4. Добавьте бота в ваш канал/группу
5. Отправьте любое сообщение в канал
6. Откройте `https://api.telegram.org/bot<TOKEN>/getUpdates` в браузере
7. Найдите Chat ID (это число начинающееся с `-100`)

**API запрос:**

```bash
curl -X POST http://localhost:3000/auth/telegram/connect \
  -H "Content-Type: application/json" \
  -d '{
    "botToken": "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11",
    "chatId": "-1001234567890"
  }'
```

**Ответ:**
```json
{
  "success": true,
  "accountId": "uuid-here",
  "accountName": "MyBot"
}
```

---

### 2️⃣ Instagram (OAuth)

**Требуется:**
- App ID
- App Secret
- Redirect URI

**Как получить:**

1. Перейти на https://developers.facebook.com/
2. Создать новое приложение → Выбрать "Manage business integrations"
3. Добавить продукт "Instagram"
4. В settings установить:
   - App Domains: `localhost:3000`
   - Valid OAuth Redirect URIs: `http://localhost:3000/auth/instagram/callback`
5. В IG Basic Settings получить App ID и App Secret
6. Запустить OAuth flow

**OAuth Flow:**

```bash
# 1. Получить OAuth URL
curl http://localhost:3000/auth/instagram/url

# Ответ:
# {
#   "url": "https://api.instagram.com/oauth/authorize?client_id=..."
# }

# 2. Пользователь переходит по URL, подтверждает доступ
# 3. Instagram редирект на callback с code
# 4. Система обменивает code на access_token
# 5. Аккаунт подключен!
```

**Переменные окружения:**
```env
INSTAGRAM_APP_ID=your-app-id
INSTAGRAM_APP_SECRET=your-app-secret
APP_URL=http://localhost:3000
WAI_APP_URL=http://localhost:3001
```

---

### 3️⃣ VK (OAuth)

**Требуется:**
- App ID
- App Secret

**Как получить:**

1. Перейти на https://vk.com/dev
2. Создать новое приложение
3. Выбрать тип: "Standalone application"
4. В settings установить:
   - Authorized redirect URI: `http://localhost:3000/auth/vk/callback`
5. Получить App ID и Secure Key

**OAuth Flow:**

```bash
# 1. Получить OAuth URL
curl http://localhost:3000/auth/vk/url

# 2. Пользователь переходит по URL
# 3. VK редирект на callback
# 4. Система обменивает code на access_token
```

**Переменные окружения:**
```env
VK_APP_ID=your-app-id
VK_APP_SECRET=your-app-secret
```

---

## 📤 Публикация контента

### Одобрить контент перед публикацией

```bash
curl -X POST http://localhost:3000/content/{contentItemId}/approve \
  -H "Content-Type: application/json" \
  -d '{"approved": true}'
```

### Запланировать публикацию

```bash
curl -X POST http://localhost:3000/content/{contentItemId}/schedule \
  -H "Content-Type: application/json" \
  -d '{"publishAt": "2024-12-25T12:00:00Z"}'
```

### Опубликовать сразу

```bash
curl -X POST http://localhost:3000/publish/{contentItemId}
```

**Ответ:**
```json
{
  "success": true,
  "postId": "17998399999999999",
  "url": "https://instagram.com/p/ABC123..."
}
```

### Получить статус публикации

```bash
curl http://localhost:3000/content/{contentItemId}/status
```

**Ответ:**
```json
{
  "id": "uuid",
  "title": "Post Title",
  "status": "published",
  "approvalStatus": "approved",
  "platformPostId": "17998399999999999",
  "publishAt": "2024-12-25T12:00:00Z"
}
```

---

## 🔐 Безопасность токенов

Все токены хранятся **зашифрованными** в БД:

```typescript
// Шифрование при сохранении
const encrypted = TokenEncryption.encrypt(accessToken);

// Расшифровка при использовании
const decrypted = TokenEncryption.decrypt(encrypted);
```

**Переменная окружения:**
```env
ENCRYPTION_KEY=your-encryption-key-min-32-chars-long!
```

---

## 📊 Поддерживаемые форматы контента

### Telegram
- ✅ Текст (с HTML форматированием)
- ✅ Фото
- ✅ Видео
- ✅ Хэштеги
- ❌ Истории (нет в Telegram)

### Instagram
- ✅ Текст + фото (обычный пост)
- ✅ Видео (Reels)
- ✅ Карусели (нужно несколько фото)
- ✅ Истории (Stories)
- ✅ Хэштеги (до 30)

### VK
- ✅ Текст
- ✅ Фото
- ✅ Видео
- ✅ Альбомы (галереи)
- ✅ Хэштеги

---

## 🚀 Workflow: От контента к публикации

```
1. User creates content in WAI
   ↓
2. System stores in database
   ↓
3. AI Agent prepares caption, image, etc.
   ↓
4. Content in DRAFT status
   ↓
5. User reviews content
   ↓
6. POST /content/{id}/approve
   ↓
7. Content in APPROVED status
   ↓
8. POST /publish/{id} or scheduled time
   ↓
9. System calls Platform Adapter
   ↓
10. Platform Adapter sends to Instagram/Telegram/VK
    ↓
11. Platform returns postId
    ↓
12. Content marked as PUBLISHED
    ↓
13. User can see live URL
```

---

## 🐛 Troubleshooting

### "Token is invalid"
- Проверьте, что Bot Token/Access Token правильный
- Убедитесь, что бот добавлен в канал (Telegram)
- Проверьте expiration date токена
- Переподключите аккаунт

### "Failed to publish to Instagram"
- Instagram API очень чувствителен к содержимому
- Проверьте что изображение качественное
- Не более 30 хэштегов
- Длина caption: макс 2200 символов

### "Chat not found" (Telegram)
- Проверьте Chat ID
- Убедитесь, что бот админ в канале
- Попробуйте другой канал для теста

### "Database connection error"
- Проверьте `DATABASE_URL` или `DB_*` переменные
- Убедитесь, что PostgreSQL запущен
- Проверьте права доступа

---

## 📚 Расширение на новые платформы

Добавить YouTube, TikTok или другую платформу просто:

1. Создайте новый Adapter:
```typescript
// src/adapters/YouTubeAdapter.ts
export class YouTubeAdapter implements IPublishingAdapter {
  // Implement interface methods
}
```

2. Зарегистрируйте в PublishingService:
```typescript
case 'youtube':
  return new YouTubeAdapter(token);
```

3. Добавьте OAuth route в AuthController

4. Готово! ✅

---

## 🔄 Полный пример workflow'а

```bash
# 1. Подключить Telegram
curl -X POST http://localhost:3000/auth/telegram/connect \
  -H "Content-Type: application/json" \
  -d '{
    "botToken": "YOUR_BOT_TOKEN",
    "chatId": "YOUR_CHAT_ID"
  }'
# Response: { "accountId": "abc-123" }

# 2. Создать контент (через webhook)
curl -X POST http://localhost:3000/webhook/task \
  -H "Content-Type: application/json" \
  -d '{
    "type": "create_content_plan",
    "socialAccountId": "abc-123",
    "projectId": "project-456",
    "userMessage": "Create 3 posts for Telegram"
  }'
# Response: { "contentPlanId": "plan-789" }

# 3. Одобрить контент
curl -X POST http://localhost:3000/content/content-item-1/approve \
  -H "Content-Type: application/json" \
  -d '{"approved": true}'

# 4. Опубликовать
curl -X POST http://localhost:3000/publish/content-item-1
# Response: { "postId": "12345", "url": "https://t.me/..." }

# 5. Проверить статус
curl http://localhost:3000/content/content-item-1/status
# Response: { "status": "published", "platformPostId": "12345" }
```

---

Готово! Теперь у вас есть полная система авторизации и публикации! 🚀
