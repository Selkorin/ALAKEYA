# 🚀 WAI Social Brain - Complete Setup Guide

Полное руководство для запуска системы локально и в production.

---

## 📋 Системные требования

- **Node.js**: 20.x LTS или выше
- **npm** или **pnpm**: для управления зависимостями
- **Docker & Docker Compose**: для локального запуска (опционально, но рекомендуется)
- **Git**: для версионирования

---

## ⚡ Быстрый старт (5 минут)

### Вариант 1: Локальный запуск (без Docker)

```bash
# 1. Клонировать репозиторий
git clone <repo-url>
cd Selkorin

# 2. Установить зависимости
npm install

# 3. Создать .env файл (копировать из .env.development)
cp .env.development .env.local

# 4. Инициализировать БД с demo данными
npm run seed

# 5. Запустить backend
npm run dev

# 6. В другом терминале - запустить frontend
cd web
npm install
npm run dev
```

**Результат:**
- 🔗 Backend: http://localhost:3000
- 🎨 Frontend: http://localhost:3001

### Вариант 2: Docker Compose (рекомендуется)

```bash
# 1. Установить Docker и Docker Compose

# 2. Клонировать репозиторий
git clone <repo-url>
cd Selkorin

# 3. Запустить все сразу
docker-compose up

# 4. Дождаться инициализации (~30 секунд)
# Backend инициализирует БД автоматически
```

**Результат:**
- 🔗 Backend: http://localhost:3000
- 🎨 Frontend: http://localhost:3001
- 📊 Dashboard ready: http://localhost:3001

---

## 📁 Структура проекта

```
Selkorin/
├── src/                    # Backend (Node.js + Express)
│   ├── index.ts           # Главный файл приложения
│   ├── config/            # Конфигурация
│   │   ├── database.ts    # Выбор БД (SQLite или PostgreSQL)
│   │   └── database-sqlite.ts
│   ├── controllers/       # API endpoints
│   ├── services/          # Бизнес-логика
│   ├── entities/          # Модели БД (TypeORM)
│   └── scripts/           # CLI скрипты
│       └── seed.ts        # Заполнение demo данных
│
├── web/                    # Frontend (React + Tailwind)
│   ├── src/
│   │   ├── pages/         # Страницы приложения
│   │   ├── components/    # React компоненты
│   │   ├── services/      # API клиент
│   │   └── App.tsx        # Главный компонент
│   └── public/            # Статические файлы
│
├── data/                   # SQLite база (создается при запуске)
│   └── wai.db
│
├── docker-compose.yml      # Docker конфигурация
├── Dockerfile             # Backend контейнер
├── package.json           # Backend зависимости
├── .env.development       # Пример переменных окружения
└── SETUP.md              # Этот файл
```

---

## 🔧 Конфигурация

### Переменные окружения

Создай файл `.env.local` (для локальной разработки):

```bash
# Environment
NODE_ENV=development
PORT=3000

# Database (SQLite для разработки)
USE_SQLITE=true
DB_PATH=./data/wai.db

# AI API Keys (опционально для функций с ИИ)
ANTHROPIC_API_KEY=sk-ant-your-key
OPENAI_API_KEY=sk-your-key

# Frontend URL (для CORS)
CORS_ORIGIN=http://localhost:3001
```

### Переключение на PostgreSQL

Если хочешь использовать PostgreSQL вместо SQLite:

```bash
# Обновить .env
USE_SQLITE=false
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=wai_social_agent

# Запустить PostgreSQL контейнер
docker-compose --profile with-postgres up postgres
```

---

## 📊 Demo данные

При первом запуске система автоматически создает demo данные:

✅ **3 социальных аккаунта** (Instagram, Telegram, TikTok)
✅ **2 контентных плана** (текущая неделя + следующая)
✅ **7 постов** в разных статусах (draft, approved, published)
✅ **2 AI агента** для управления контентом
✅ **1 анализ конкурента** с полным отчетом

Все данные хранятся в SQLite (`./data/wai.db`)

### Сброс demo данных

```bash
# Очистить БД и создать новые demo данные
npm run seed:reset
```

---

## 🚀 Команды для разработки

### Backend

```bash
# Запуск в режиме разработки с hot-reload
npm run dev

# Создать production build
npm run build

# Запустить из build
npm start

# Проверить типы TypeScript
npm run typecheck

# Инициализировать БД demo данными
npm run seed

# Очистить БД и заново создать demo данные
npm run seed:reset
```

### Frontend

```bash
cd web

# Запуск dev сервера
npm run dev

# Production build
npm run build

# Preview production build локально
npm run preview

# Запуск linter
npm run lint
```

### Docker

```bash
# Запустить все сервисы
docker-compose up

# Запустить в фоне
docker-compose up -d

# Остановить все сервисы
docker-compose down

# Просмотреть логи
docker-compose logs -f

# Запустить с PostgreSQL
docker-compose --profile with-postgres up
```

---

## 📚 Основные API endpoints

### Dashboard
```
GET /api/dashboard/stats       - Статистика
GET /api/dashboard/activity    - Последняя активность
GET /api/dashboard/calendar    - Календарь постов
GET /api/dashboard/analytics   - Аналитика
```

### Content Management
```
GET    /api/content            - Список постов
POST   /api/content            - Создать пост
GET    /api/content/:id        - Получить пост
PUT    /api/content/:id        - Обновить пост
DELETE /api/content/:id        - Удалить пост
```

### Social Accounts
```
GET /api/socials               - Список аккаунтов
GET /api/socials/:id           - Детали аккаунта
```

### Content Plans
```
GET  /api/plans                - Список планов
POST /api/plans                - Создать план
GET  /api/plans/:id            - Детали плана
```

### Competitor Analysis
```
POST /analyze/competitor       - Анализировать конкурента
GET  /analysis/:id             - Получить анализ
POST /analysis/:id/send-to-agents - Отправить агентам
```

Полная документация: [API.md](./API.md)

---

## 🐛 Troubleshooting

### "Port 3000 already in use"

```bash
# Освободить порт
lsof -i :3000
kill -9 <PID>

# Или использовать другой порт
PORT=3001 npm run dev
```

### "Database is locked"

Если видишь ошибку "SQLITE_CANTOPEN":

```bash
# Удалить старую БД
rm -rf data/wai.db

# Пересоздать
npm run seed
```

### "Cannot find module 'sqlite3'"

```bash
# Переустановить зависимости
rm -rf node_modules package-lock.json
npm install
```

### "CORS error при запросах с фронтенда"

Убедись что в `.env`:
```
CORS_ORIGIN=http://localhost:3001
```

Если фронтенд на другом порту, обновить CORS_ORIGIN.

---

## 📦 Production Deploy

### Railway (рекомендуется)

1. Залить код на GitHub
2. Подключить репозиторий к Railway
3. Добавить переменные окружения:
   ```
   NODE_ENV=production
   USE_SQLITE=false
   DB_HOST=<railway-postgres-host>
   DB_PORT=5432
   DB_USER=postgres
   DB_PASSWORD=<strong-password>
   DB_NAME=wai_social_agent
   ANTHROPIC_API_KEY=...
   JWT_SECRET=<strong-secret>
   ```
4. Deploy на Railway

Подробнее: [DEPLOYMENT.md](./DEPLOYMENT.md)

### Docker на собственном сервере

```bash
# 1. Собрать образ
docker build -t wai-social-brain .

# 2. Запустить контейнер
docker run -d \
  -p 3000:3000 \
  -e NODE_ENV=production \
  -e USE_SQLITE=false \
  -e DB_HOST=postgres \
  -v wai-data:/app/data \
  wai-social-brain
```

---

## ✨ Что дальше?

После базовой настройки:

1. **Добавить Google Drive интеграцию**
   - Включить GOOGLE_DRIVE.md
   - Настроить Google Cloud credentials

2. **Интегрировать нейросетевые API**
   - Настроить Claude API для агентов
   - Добавить интеграции с другими LLM

3. **Настроить CI/CD**
   - Добавить GitHub Actions для тестирования
   - Автоматический deploy при push

4. **Кастомизировать**
   - Изменить стили (Tailwind конфиг)
   - Добавить логотип компании
   - Настроить брендовые цвета

---

## 📞 Помощь и поддержка

- 📖 Документация: [README.md](./README.md)
- 🔌 API Docs: [API.md](./API.md)
- 🚀 Deploy: [DEPLOYMENT.md](./DEPLOYMENT.md)
- 💾 Google Drive: [GOOGLE_DRIVE.md](./GOOGLE_DRIVE.md)
- 📅 Bulk Scheduling: [BULK_SCHEDULING.md](./BULK_SCHEDULING.md)

---

**Готово!** Система полностью готова к использованию 🎉

Начни с dashboard, добавь свои социальные аккаунты, создавай контент и смотри аналитику!
