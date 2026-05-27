# 📅 Bulk Scheduling Guide - WAI Social Brain

Полная система для массовой загрузки и планирования постов на месяцы вперед.

---

## 🚀 Быстрый старт

### 1️⃣ Загрузить посты из CSV

```bash
# Скачать шаблон
curl http://localhost:3000/import/template/csv -o template.csv

# Открыть и заполнить template.csv

# Загрузить
curl -X POST http://localhost:3000/import/{contentPlanId}/csv \
  -F "file=@posts.csv"

# Response:
{
  "success": true,
  "imported": 42,
  "items": [ /* ContentItem array */ ],
  "message": "Successfully imported 42 items"
}
```

### 2️⃣ Загрузить посты из JSON

```bash
# Скачать шаблон
curl http://localhost:3000/import/template/json -o template.json

# Заполнить и загрузить
curl -X POST http://localhost:3000/import/{contentPlanId}/json \
  -H "Content-Type: multipart/form-data" \
  -F "file=@posts.json"
```

### 3️⃣ Просмотреть календарь

```bash
GET /calendar?month=2024-12
# Видишь все загруженные посты по датам
```

### 4️⃣ Система автоматически публикует!

Scheduler проверяет каждую минуту и публикует одобренные посты в расписанное время.

---

## 📋 CSV Format

### Скачай шаблон:
```bash
curl http://localhost:3000/import/template/csv
```

### Пример content.csv:

```csv
title,caption,platform,contentType,publishAt,imageUrl,videoUrl,hashtags
"Day 1 Post 1","Excited to announce...",instagram,post,2024-12-25T09:00:00Z,https://example.com/img1.jpg,,#excited,#announcement
"Day 1 Post 2","Check out our story!",instagram,story,2024-12-25T12:00:00Z,https://example.com/img2.jpg,,#story,#instagram
"Day 2 Telegram","Новое видео готово!",telegram,post,2024-12-26T10:00:00Z,,https://example.com/video.mp4,#видео,#новое
"Day 3 Reel","Watch this amazing transformation",instagram,reel,2024-12-27T15:00:00Z,,https://example.com/reel.mp4,#transformation,#amazing
```

### Поля:

| Поле | Обязательное | Тип | Пример |
|------|------------|------|--------|
| **title** | ✅ | string | "My Post" |
| **caption** | ✅ | string | "Great content!" |
| **platform** | ✅ | enum | instagram, telegram, vk, youtube, tiktok |
| **contentType** | ✅ | enum | post, story, reel, short, carousel |
| **publishAt** | ✅ | ISO date | 2024-12-25T12:00:00Z |
| **imageUrl** | ❌ | URL | https://example.com/image.jpg |
| **videoUrl** | ❌ | URL | https://example.com/video.mp4 |
| **hashtags** | ❌ | comma-separated | #tag1,#tag2,#tag3 |

---

## 📄 JSON Format

### Скачай шаблон:
```bash
curl http://localhost:3000/import/template/json > template.json
```

### Пример posts.json:

```json
[
  {
    "title": "First Post",
    "caption": "Check out our new product!",
    "platform": "instagram",
    "contentType": "post",
    "publishAt": "2024-12-25T09:00:00Z",
    "imageUrl": "https://example.com/image1.jpg",
    "videoUrl": null,
    "hashtags": ["#marketing", "#product"]
  },
  {
    "title": "Video Tutorial",
    "caption": "How to use our service in 60 seconds",
    "platform": "instagram",
    "contentType": "reel",
    "publishAt": "2024-12-25T15:00:00Z",
    "imageUrl": null,
    "videoUrl": "https://example.com/tutorial.mp4",
    "hashtags": ["#tutorial", "#howto"]
  },
  {
    "title": "Telegram Announcement",
    "caption": "Новое событие! 🎉",
    "platform": "telegram",
    "contentType": "post",
    "publishAt": "2024-12-26T10:00:00Z",
    "imageUrl": "https://example.com/event.jpg",
    "videoUrl": null,
    "hashtags": ["#событие", "#новое"]
  }
]
```

---

## 🔄 Bulk Update Schedules

Если нужно сдвинуть даты публикации:

```bash
POST /schedules/bulk-update
Content-Type: application/json

{
  "updates": [
    {
      "contentItemId": "uuid-1",
      "publishAt": "2024-12-26T12:00:00Z"
    },
    {
      "contentItemId": "uuid-2",
      "publishAt": "2024-12-26T15:00:00Z"
    },
    {
      "contentItemId": "uuid-3",
      "publishAt": "2024-12-27T09:00:00Z"
    }
  ]
}

# Response:
{
  "success": true,
  "updated": 3,
  "items": [ /* updated ContentItems */ ]
}
```

---

## 📥 Complete Workflow

### День 1: Подготовка
```bash
# 1. Создать план на месяц
POST /webhook/task
{
  "type": "create_content_plan",
  "userMessage": "Plan for December 2024"
}
# → planId: plan-123

# 2. Скачать шаблон
curl http://localhost:3000/import/template/csv > posts.csv

# 3. Заполнить 30-40 постов в Excel/Google Sheets
# Структура CSV: title, caption, platform, contentType, publishAt, imageUrl, hashtags
```

### День 2: Загрузка
```bash
# 4. Загрузить все посты
curl -X POST http://localhost:3000/import/plan-123/csv \
  -F "file=@posts.csv"
# → imported: 42 items

# 5. Проверить календарь
curl http://localhost:3000/calendar?month=2024-12
# Видишь все 42 поста по датам
```

### День 3+: Автопубликация
```bash
# 6. Одобрить посты (опционально)
curl -X POST http://localhost:3000/content/{id}/approve \
  -d '{"approved": true}'

# 7. Scheduler автоматически публикует!
# Каждую минуту проверяет:
# - Есть ли посты с publishAt <= now?
# - Одобрены ли они?
# - Если да → публикует через платформу
```

### Мониторинг
```bash
# Видеть что публикуется
GET /scheduled

# История всех публикаций
GET /history?limit=50

# Статистика
GET /analytics?days=7
```

---

## 📊 Пример большого плана на месяц

```csv
title,caption,platform,contentType,publishAt,imageUrl,videoUrl,hashtags
"Mon Dec 1 - Post 1","Monday motivation!",instagram,post,2024-12-01T09:00:00Z,https://cdn.example.com/mon1.jpg,,#monday,#motivation
"Mon Dec 1 - Story","Morning routine",instagram,story,2024-12-01T07:00:00Z,https://cdn.example.com/mon_story.jpg,,#morning,#routine
"Tue Dec 2 - Reel","5 tips for...",instagram,reel,2024-12-02T15:00:00Z,,https://cdn.example.com/tips.mp4,#tips,#tutorial
"Telegram Daily","Обновления дня",telegram,post,2024-12-02T10:00:00Z,https://cdn.example.com/update.jpg,,#новости,#обновления
"Wed Dec 3 - Post","Behind the scenes",instagram,post,2024-12-03T12:00:00Z,https://cdn.example.com/bts.jpg,,#behindthescenes,#studio
... (добавить еще 25+ строк)
```

**Как заполнять:**
1. Используй Excel/Google Sheets для удобства
2. Копируй и пасти одну строку, меняя дату
3. Дата автоматически сдвигается на +1 день
4. Время: утро 9:00, день 12:00, вечер 18:00
5. Картинки: сохрани URL на CDN или облако
6. Хэштеги: разделяй запятыми (без пробелов)

---

## 🎯 Smart Scheduling (Pro Tips)

### Паттерн публикаций:
```
Понедельник: Мотивация + Tips (2 поста)
Вторник: Reels + Telegram (2 разные платформы)
Среда: Behind-the-scenes + Stories
Четверг: Обучение + Видео
Пятница: Lifestyle + Мероприятия
Выходные: Stories + Casual content
```

### Временные слоты по платформам:
```
Instagram:
  - Утро: 9:00 (профессиональный контент)
  - День: 12:00-13:00 (основной контент)
  - Вечер: 18:00-19:00 (мотивация)
  - Ночь: 21:00 (развлекательный контент)

Telegram:
  - Рабочие часы: 10:00, 14:00, 18:00
  - Вечер: 20:00

VK:
  - Полдень: 12:00
  - Вечер: 20:00
```

---

## 🔐 Валидация при импорте

Система проверяет:
- ✅ Все обязательные поля заполнены
- ✅ Даты в правильном формате (ISO 8601)
- ✅ Platform из доступного списка
- ✅ ContentType из доступного списка
- ✅ Даты публикации в рамках плана
- ✅ URLs доступны (если указаны)

Если ошибка:
```json
{
  "error": "Invalid platform: tiktoks (did you mean 'tiktok'?)"
}
```

---

## 📤 Export & Backup

Экспортировать текущие посты:

```bash
# В CSV
curl http://localhost:3000/export/{contentPlanId}/csv -o backup.csv

# В JSON
curl http://localhost:3000/export/{contentPlanId}/json -o backup.json
```

Используй для:
- Резервной копии
- Обновления/редактирования
- Анализа
- Передачи другому человеку

---

## 🚨 Troubleshooting

### "Import failed: Invalid date format"
**Решение:** Используй ISO 8601: `2024-12-25T12:00:00Z`

### "Publish date outside plan period"
**Решение:** Убедись, что дата между `periodStart` и `periodEnd` плана

### "Platform not found"
**Решение:** Проверь написание (instagram, telegram, vk, youtube, tiktok)

### "No file provided"
**Решение:** Убедись, что файл загружается как multipart/form-data

---

## 💡 Best Practices

1. **Планируй за месяц вперед** - создавай булк план на целый месяц
2. **Используй одинаковые временные слоты** - привычка подписчиков
3. **Чередуй контент** - не все посты одного типа
4. **Разные платформы** - один контент, разные форматы
5. **Одобрение批ей** - одобри все перед автопубликацией
6. **Backup регулярно** - экспортируй план каждую неделю
7. **Мониторь аналитику** - смотри что работает

---

Готово! Теперь ты можешь планировать контент на месяцы вперед 🎉
