# WAI Social Brain - Complete API Reference

## 📚 Основные API Endpoints

### Health & Status
```bash
GET /health
# Response: { "status": "ok", "service": "WAI Social Agent", "version": "0.1.0" }
```

### Dashboard
```bash
GET /demo
# Interactive UI для управления контентом
```

---

## 🔐 Authentication (OAuth)

### Instagram OAuth
```bash
# 1. Получить OAuth URL
GET /auth/instagram/url
# Response: { "url": "https://api.instagram.com/oauth/authorize?..." }

# 2. Пользователь переходит по URL и подтверждает
# 3. Instagram редирект на /auth/instagram/callback с code
# 4. Система автоматически обменивает code на token
# 5. Аккаунт подключен!
```

### Telegram (Token-based)
```bash
POST /auth/telegram/connect
Content-Type: application/json

{
  "botToken": "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11",
  "chatId": "-1001234567890"
}

# Response:
{
  "success": true,
  "accountId": "550e8400-e29b-41d4-a716-446655440000",
  "accountName": "MyBot"
}
```

### VK OAuth
```bash
GET /auth/vk/url
# Similar to Instagram OAuth flow
```

---

## 📤 Publishing

### Одобрить контент
```bash
POST /content/{contentItemId}/approve
Content-Type: application/json

{
  "approved": true
}

# Response:
{
  "success": true,
  "item": { /* ContentItem */ },
  "message": "Content approved"
}
```

### Запланировать публикацию
```bash
POST /content/{contentItemId}/schedule
Content-Type: application/json

{
  "publishAt": "2024-12-25T12:00:00Z"
}

# Response:
{
  "success": true,
  "item": { /* ContentItem */ },
  "message": "Content scheduled for 2024-12-25T12:00:00Z"
}
```

### Опубликовать сразу
```bash
POST /publish/{contentItemId}

# Response:
{
  "success": true,
  "postId": "17998399999999999",
  "url": "https://instagram.com/p/ABC123...",
  "message": "Content published successfully"
}
```

### Получить статус публикации
```bash
GET /content/{contentItemId}/status

# Response:
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

## 🤖 AI Content Generation

### Сгенерировать контент для плана
```bash
POST /content/generate/plan
Content-Type: application/json

{
  "contentPlanId": "550e8400-e29b-41d4-a716-446655440000",
  "agentId": "550e8400-e29b-41d4-a716-446655440001",
  "platforms": ["instagram", "telegram", "vk"]
}

# Response:
{
  "success": true,
  "generatedCount": 21,
  "results": {
    "instagram": [ /* 7 posts */ ],
    "telegram": [ /* 7 posts */ ],
    "vk": [ /* 7 posts */ ]
  }
}
```

### Сгенерировать один пост
```bash
POST /content/generate/single
Content-Type: application/json

{
  "socialAccountId": "550e8400-e29b-41d4-a716-446655440000",
  "agentId": "550e8400-e29b-41d4-a716-446655440001",
  "platform": "instagram",
  "topic": "How to grow your Instagram",
  "style": "engaging"
}

# Response:
{
  "success": true,
  "item": {
    "id": "uuid",
    "title": "How to grow your Instagram",
    "caption": "Вот 5 способов увеличить охват...",
    "imagePrompt": "Modern Instagram growth strategy infographic...",
    "hashtags": ["#instagram", "#growth", "#marketing"],
    "status": "draft"
  }
}
```

### Переделать контент (regenerate)
```bash
POST /content/{contentItemId}/regenerate

# Response:
{
  "success": true,
  "item": { /* обновленный контент с новым caption и prompt */ }
}
```

---

## 📅 Calendar, History & Analytics

### Получить календарь контента
```bash
# За месяц
GET /calendar?month=2024-12

# Для конкретного аккаунта
GET /calendar?socialAccountId=uuid&month=2024-12

# Response:
{
  "2024-12-20": [
    { "id": "uuid1", "title": "Post 1", "status": "scheduled" },
    { "id": "uuid2", "title": "Post 2", "status": "scheduled" }
  ],
  "2024-12-21": [
    { "id": "uuid3", "title": "Post 3", "status": "approved" }
  ]
}
```

### История публикаций
```bash
# Последние 50 публикаций
GET /history?limit=50

# Для конкретного аккаунта
GET /history?socialAccountId=uuid&limit=20

# Response:
[
  {
    "id": "uuid",
    "platform": "instagram",
    "platformPostId": "17998399999999999",
    "postUrl": "https://instagram.com/p/ABC123...",
    "status": "success",
    "publishedAt": "2024-12-20T12:00:00Z",
    "contentSnapshot": {
      "title": "Post Title",
      "caption": "Post text...",
      "hashtags": ["#tag1", "#tag2"]
    },
    "metrics": {
      "likes": 150,
      "comments": 23,
      "shares": 5
    }
  }
]
```

### Аналитика и статистика
```bash
# За последние 7 дней (по умолчанию)
GET /analytics

# За конкретный период
GET /analytics?days=30

# Для конкретного аккаунта
GET /analytics?socialAccountId=uuid&days=7

# Response:
{
  "period": "Last 7 days",
  "totalPublished": 14,
  "totalFailed": 1,
  "successRate": 93,
  "byPlatform": {
    "instagram": {
      "success": 7,
      "failed": 0
    },
    "telegram": {
      "success": 7,
      "failed": 1
    }
  }
}
```

### Получить запланированные посты
```bash
GET /scheduled

# Response:
[
  {
    "id": "uuid1",
    "title": "Post 1",
    "platform": "instagram",
    "publishAt": "2024-12-21T12:00:00Z",
    "status": "scheduled"
  },
  {
    "id": "uuid2",
    "title": "Post 2",
    "platform": "telegram",
    "publishAt": "2024-12-21T14:00:00Z",
    "status": "scheduled"
  }
]
```

---

## ⏱️ Scheduler (Автоматическая публикация)

Scheduler автоматически запускается при старте приложения.

**Как это работает:**
1. Каждую минуту проверяет все scheduled посты
2. Если время публикации наступило (publishAt <= now)
3. И пост одобрен (approvalStatus == approved)
4. Автоматически публикует через нужный адаптер
5. Сохраняет результат в PublishingHistory
6. Обновляет статус контента

**Workflow:**
```
Draft → Approved → Scheduled (with publishAt time)
                     ↓ (scheduler checks every minute)
                   Published OR Failed
```

**Примеры:**

Запланировать на завтра в 12:00:
```bash
POST /content/uuid/schedule
{ "publishAt": "2024-12-21T12:00:00Z" }

# Scheduler автоматически опубликует в это время!
```

Получить следующие посты:
```bash
GET /scheduled
# Показывает все, что готовится к публикации
```

---

## 🔄 Webhook Integration

### Получить задачу из WAI админки
```bash
POST /webhook/task
Content-Type: application/json

{
  "type": "create_content_plan",
  "socialAccountId": "uuid",
  "projectId": "uuid",
  "userMessage": "Создай контент-план на неделю для Instagram",
  "files": [],
  "references": []
}

# Response:
{
  "success": true,
  "result": { /* ContentPlan */ },
  "taskId": 1234567890
}
```

---

## 📊 Data Structures

### ContentItem
```json
{
  "id": "uuid",
  "contentPlanId": "uuid",
  "platform": "instagram|telegram|vk|youtube|tiktok",
  "contentType": "post|story|reel|short|carousel",
  "title": "Post Title",
  "caption": "Post text content",
  "imagePrompt": "AI prompt for image generation",
  "imageUrl": "https://...",
  "videoUrl": "https://...",
  "hashtags": ["#tag1", "#tag2"],
  "publishAt": "2024-12-25T12:00:00Z",
  "status": "draft|needs_review|approved|scheduled|publishing|published|failed",
  "approvalStatus": "pending|approved|rejected",
  "platformPostId": "platform-specific-id",
  "errorMessage": null,
  "createdAt": "2024-12-20T10:00:00Z",
  "updatedAt": "2024-12-20T10:00:00Z"
}
```

### PublishingHistory
```json
{
  "id": "uuid",
  "contentItemId": "uuid",
  "socialAccountId": "uuid",
  "platform": "instagram|telegram|vk",
  "platformPostId": "platform-id",
  "postUrl": "https://...",
  "status": "success|failed",
  "errorMessage": null,
  "contentSnapshot": {
    "title": "...",
    "caption": "...",
    "hashtags": [],
    "imageUrl": "..."
  },
  "metrics": {
    "likes": 150,
    "comments": 23,
    "shares": 5,
    "views": 1200,
    "engagementRate": 12.5
  },
  "publishedAt": "2024-12-20T12:00:00Z",
  "metricsUpdatedAt": "2024-12-20T13:00:00Z"
}
```

---

## 🚀 Complete Workflow Example

```bash
# 1. Подключить Telegram
curl -X POST http://localhost:3000/auth/telegram/connect \
  -H "Content-Type: application/json" \
  -d '{
    "botToken": "YOUR_BOT_TOKEN",
    "chatId": "YOUR_CHAT_ID"
  }'
# → accountId: abc-123

# 2. Создать контент-план (webhook из WAI)
curl -X POST http://localhost:3000/webhook/task \
  -H "Content-Type: application/json" \
  -d '{
    "type": "create_content_plan",
    "socialAccountId": "abc-123",
    "projectId": "proj-456",
    "userMessage": "Создай план на 3 дня"
  }'
# → planId: plan-789

# 3. Сгенерировать контент
curl -X POST http://localhost:3000/content/generate/plan \
  -H "Content-Type: application/json" \
  -d '{
    "contentPlanId": "plan-789",
    "agentId": "agent-001",
    "platforms": ["telegram"]
  }'
# → 3 поста созданы в статусе draft

# 4. Одобрить контент
curl -X POST http://localhost:3000/content/uuid-1/approve \
  -H "Content-Type: application/json" \
  -d '{"approved": true}'

# 5. Запланировать публикацию
curl -X POST http://localhost:3000/content/uuid-1/schedule \
  -H "Content-Type: application/json" \
  -d '{"publishAt": "2024-12-21T12:00:00Z"}'

# 6. Получить календарь
curl http://localhost:3000/calendar?month=2024-12
# → Видишь все посты на месяц

# 7. Получить статистику
curl http://localhost:3000/analytics?days=7
# → Видишь успешность публикаций

# 8. Scheduler автоматически опубликует в 12:00!
# → Content будет в статусе "published"
# → История сохранится в PublishingHistory
```

---

## ✅ Status Codes

- `200` - Успех
- `400` - Bad Request (неправильные параметры)
- `404` - Not Found
- `500` - Server Error

---

Готово! Полная система для управления контентом 🎉
