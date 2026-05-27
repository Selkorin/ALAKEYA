# 🔗 Google Drive Integration - WAI Social Brain

Полная интеграция с Google Drive для хранения и управления контентом.

---

## 🚀 Быстрый старт

### 1️⃣ Настроить Google Cloud Project

1. Перейди на [Google Cloud Console](https://console.cloud.google.com/)
2. Создай новый проект
3. Включи Google Drive API:
   - Перейди в "APIs & Services" → "Library"
   - Найди "Google Drive API"
   - Нажми "Enable"

4. Создай OAuth 2.0 credentials:
   - Перейди в "APIs & Services" → "Credentials"
   - Нажми "Create Credentials" → "OAuth client ID"
   - Выбери "Web application"
   - Добавь redirect URL: `http://localhost:3000/auth/google/callback`
   - Скачай JSON файл и сохрани credentials

### 2️⃣ Добавить environment variables

```bash
# .env
GOOGLE_CLIENT_ID=your_client_id
GOOGLE_CLIENT_SECRET=your_client_secret
GOOGLE_REDIRECT_URL=http://localhost:3000/auth/google/callback
```

### 3️⃣ Подключиться к Google Drive

```bash
# Получить URL для авторизации
curl http://localhost:3000/auth/google/url

# Response:
{
  "success": true,
  "authUrl": "https://accounts.google.com/o/oauth2/v2/auth?..."
}
```

Открой эту URL в браузере → авторизуйся → получи код

---

## 📤 API Endpoints

### Авторизация

```bash
# Получить URL для авторизации
GET /auth/google/url

# Callback (автоматический)
GET /auth/google/callback?code=AUTH_CODE
```

### Загрузка контента

```bash
# Загрузить один пост на Google Drive
POST /drive/upload
Content-Type: application/json

{
  "contentItemId": "uuid-1234",
  "accessToken": "ya29.a0AfH6SMBx..."
}

# Response:
{
  "success": true,
  "message": "Content uploaded to Google Drive",
  "file": {
    "id": "1a2b3c4d5e",
    "name": "content-uuid-1234.json",
    "mimeType": "application/json",
    "webViewLink": "https://docs.google.com/document/d/...",
    "createdTime": "2024-12-25T12:00:00Z",
    "modifiedTime": "2024-12-25T12:00:00Z"
  }
}
```

### Скачивание контента

```bash
# Скачать пост из Google Drive
POST /drive/download
Content-Type: application/json

{
  "contentItemId": "uuid-1234",
  "accessToken": "ya29.a0AfH6SMBx..."
}

# Response:
{
  "success": true,
  "data": {
    "id": "uuid-1234",
    "title": "Post Title",
    "caption": "Post caption...",
    // ... остальные поля ContentItem
  }
}
```

### Синхронизация плана

```bash
# Синхронизировать весь план контента на Google Drive
POST /drive/sync-plan
Content-Type: application/json

{
  "contentPlanId": "plan-uuid",
  "accessToken": "ya29.a0AfH6SMBx..."
}

# Response:
{
  "success": true,
  "message": "Synced 15 items to Google Drive",
  "count": 15,
  "files": [ /* array of uploaded files */ ]
}
```

### Просмотр файлов

```bash
# Получить список всех файлов контента на Google Drive
GET /drive/files?accessToken=ya29.a0AfH6SMBx...

# Response:
{
  "success": true,
  "count": 15,
  "files": [
    {
      "id": "1a2b3c4d5e",
      "name": "content-uuid-1234.json",
      "mimeType": "application/json",
      "webViewLink": "https://docs.google.com/document/d/...",
      "createdTime": "2024-12-25T12:00:00Z",
      "modifiedTime": "2024-12-25T12:00:00Z"
    },
    // ... остальные файлы
  ]
}
```

### Удаление контента

```bash
# Удалить пост из Google Drive
POST /drive/delete
Content-Type: application/json

{
  "contentItemId": "uuid-1234",
  "accessToken": "ya29.a0AfH6SMBx..."
}

# Response:
{
  "success": true,
  "message": "Content deleted from Google Drive"
}
```

### Общий доступ

```bash
# Поделиться контентом с другим пользователем
POST /drive/share
Content-Type: application/json

{
  "contentItemId": "uuid-1234",
  "email": "partner@example.com",
  "accessToken": "ya29.a0AfH6SMBx...",
  "role": "editor"  // или 'viewer', 'commenter'
}

# Response:
{
  "success": true,
  "message": "Content shared with partner@example.com"
}
```

---

## 🗂️ Структура Google Drive

Система автоматически создает такую структуру:

```
Google Drive Root/
├── WAI Social Content/
│   ├── content-uuid-1.json
│   ├── content-uuid-2.json
│   ├── content-uuid-3.json
│   └── Assets/
│       ├── image1.jpg
│       ├── image2.png
│       └── video1.mp4
```

---

## 💡 Примеры использования

### Сценарий 1: Загрузить контент план на Google Drive

```javascript
// 1. Получить accessToken
const authResponse = await fetch('http://localhost:3000/auth/google/url');
const { authUrl } = await authResponse.json();
// Пользователь открывает authUrl и авторизуется

// 2. Синхронизировать план
const syncResponse = await fetch('http://localhost:3000/drive/sync-plan', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    contentPlanId: 'plan-123',
    accessToken: userAccessToken
  })
});

const { count, files } = await syncResponse.json();
console.log(`Uploaded ${count} items to Google Drive`);
```

### Сценарий 2: Скачать обновленный контент из Google Drive

```javascript
// 1. Скачать пост
const downloadResponse = await fetch('http://localhost:3000/drive/download', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    contentItemId: 'content-uuid',
    accessToken: userAccessToken
  })
});

const { data } = await downloadResponse.json();
console.log('Updated content:', data);
```

### Сценарий 3: Поделиться контентом с командой

```javascript
// Поделиться с несколькими членами команды
const emails = ['team1@example.com', 'team2@example.com'];

for (const email of emails) {
  await fetch('http://localhost:3000/drive/share', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contentItemId: 'content-uuid',
      email,
      accessToken: userAccessToken,
      role: 'editor'
    })
  });
}
```

---

## 🔐 Безопасность токенов

- Access tokens хранятся на клиенте (не на сервере)
- Передавай accessToken в каждом запросе
- Используй HTTPS в production
- Access tokens имеют ограниченное время жизни (~1 час)
- Refresh token можно использовать для получения нового access token

---

## 📋 Структура JSON файла контента

Каждый файл в Google Drive содержит полный JSON контента:

```json
{
  "id": "uuid-1234",
  "contentPlanId": "plan-uuid",
  "platform": "instagram",
  "contentType": "post",
  "title": "Exciting Announcement",
  "caption": "Check out our new product!",
  "imageUrl": "https://example.com/image.jpg",
  "videoUrl": null,
  "hashtags": ["#exciting", "#announcement"],
  "publishAt": "2024-12-25T12:00:00Z",
  "status": "approved",
  "approvalStatus": "approved",
  "platformPostId": null,
  "googleDriveFileId": "1a2b3c4d5e",
  "createdAt": "2024-12-20T10:00:00Z",
  "updatedAt": "2024-12-25T11:00:00Z"
}
```

---

## 🚨 Troubleshooting

### "Invalid credentials"
**Решение:** Убедись, что:
- GOOGLE_CLIENT_ID и GOOGLE_CLIENT_SECRET в .env верны
- Redirect URL совпадает в Google Cloud Console и .env
- OAuth credentials созданы для Web application

### "Permission denied"
**Решение:** 
- Убедись, что Google Drive API включен в Google Cloud Console
- Пользователь авторизован (accessToken валиден)
- Файл не был удален вручную из Google Drive

### "Access token expired"
**Решение:**
- Получи новый accessToken через OAuth flow
- Или используй refresh token для получения нового access token

---

## 📚 API Reference

| Endpoint | Метод | Описание |
|----------|-------|----------|
| `/auth/google/url` | GET | Получить URL для авторизации |
| `/auth/google/callback` | GET | OAuth callback |
| `/drive/upload` | POST | Загрузить пост на Google Drive |
| `/drive/download` | POST | Скачать пост из Google Drive |
| `/drive/sync-plan` | POST | Синхронизировать весь план |
| `/drive/files` | GET | Список файлов на Google Drive |
| `/drive/delete` | POST | Удалить пост из Google Drive |
| `/drive/share` | POST | Поделиться контентом |

---

## ✨ Будущие улучшения

- [ ] Синхронизация в реальном времени (Google Drive Realtime API)
- [ ] Экспорт в Google Docs с форматированием
- [ ] Импорт контента из Google Sheets
- [ ] История версий контента
- [ ] Комментарии в Google Drive
- [ ] Автоматическое резервное копирование

---

Готово! Теперь контент безопасно хранится и управляется на Google Drive 🎉
