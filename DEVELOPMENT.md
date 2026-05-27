# 🛠️ Development Guide - WAI Social Brain

Полное руководство для разработчиков - архитектура, структура, и как добавлять новые фичи.

---

## 📚 Архитектура системы

```
┌──────────────────────────────────────────────┐
│           React Frontend (web/)               │
│  - Dashboard, Content, Analytics, Settings   │
│  - Tailwind CSS, React Router, Axios        │
└──────────────┬───────────────────────────────┘
               │ HTTP Requests (REST API)
               ↓
┌──────────────────────────────────────────────┐
│         Express Backend (src/)                │
│  - REST API, Services, Controllers           │
│  - TypeORM, SQLite/PostgreSQL, JWT auth      │
└──────────────┬───────────────────────────────┘
               │
               ├─→ Database (SQLite/PostgreSQL)
               ├─→ AI Providers (Claude, OpenAI)
               ├─→ Social Platforms (Instagram, Telegram, etc)
               └─→ Google Drive API (optional)
```

---

## 🏗️ Backend Architecture

### Слои приложения

```
src/
├── index.ts                 # Entry point, route registration
├── config/                  # Configuration
│   ├── database.ts         # DB connection (SQLite/PostgreSQL)
│   └── env.ts             # Environment variables
├── controllers/            # HTTP endpoint handlers
│   ├── DashboardController    # Stats, analytics
│   ├── APIController          # Content CRUD
│   ├── PublishingController   # Publishing operations
│   └── ...
├── services/              # Business logic
│   ├── ContentGenerationService    # AI content generation
│   ├── SchedulerService            # Auto-publishing
│   ├── PublishingService           # Publishing workflow
│   ├── CompetitorAnalysisService   # AI analysis
│   ├── SeedDataService             # Demo data
│   └── ...
├── entities/              # TypeORM models (database schema)
│   ├── ContentItem.ts
│   ├── SocialAccount.ts
│   ├── CompetitorAnalysis.ts
│   └── ...
├── adapters/              # Platform-specific implementations
│   ├── IPublishingAdapter.ts  # Interface
│   ├── InstagramAdapter.ts
│   ├── TelegramAdapter.ts
│   └── ...
├── utils/                 # Utilities
│   ├── encryption.ts      # Token encryption
│   └── ...
├── migrations/            # Database migrations (future)
└── scripts/               # CLI scripts
    └── seed.ts           # Initialize database
```

### Паттерны

**Repository Pattern**: `AppDataSource.getRepository(Entity)`
```typescript
const userRepo = AppDataSource.getRepository(ContentItem);
const posts = await userRepo.find({ where: { status: 'published' } });
```

**Service Layer**: Business logic отделена от HTTP
```typescript
// ContentGenerationService handles all generation logic
const service = new ContentGenerationService();
const content = await service.generateForPlan(planId);
```

**Factory Pattern**: Выбор провайдера в runtime
```typescript
const aiProvider = AIProviderFactory.getProvider('claude');
const text = await aiProvider.generateText(prompt);
```

**Adapter Pattern**: Поддержка разных платформ
```typescript
const adapter = PublishingService.getAdapter('instagram');
const result = await adapter.publishPost(content);
```

---

## 💻 Frontend Architecture

### React компоненты

```
web/src/
├── pages/                  # Full pages (routes)
│   ├── Dashboard.tsx      # Main dashboard
│   ├── ContentManagement.tsx
│   ├── CompetitorAnalysis.tsx
│   ├── Analytics.tsx
│   ├── Settings.tsx
│   └── NotFound.tsx
├── components/
│   ├── layout/            # Layout components
│   │   ├── Layout.tsx    # Main layout wrapper
│   │   ├── Sidebar.tsx   # Navigation sidebar
│   │   └── Header.tsx    # Top header
│   ├── dashboard/         # Dashboard components
│   │   ├── StatCard.tsx
│   │   ├── ContentCalendar.tsx
│   │   └── RecentActivity.tsx
│   └── common/            # Reusable components
├── services/              # API client
│   └── api.ts            # Axios instance, API methods
├── App.tsx               # Router setup
├── main.tsx              # React entry point
└── index.css             # Global styles (Tailwind)
```

### State Management

Используется **React Hooks** с **local state** для простоты:
```typescript
const [stats, setStats] = useState(null);
const [loading, setLoading] = useState(false);

useEffect(() => {
  loadData();
}, []);
```

Для более сложных состояний можно добавить **TanStack Query** или **Redux**.

---

## 🔌 API Endpoints

### Dashboard
```
GET /api/dashboard/stats       → { stats: { totalContent, ... } }
GET /api/dashboard/activity    → { activity: { recentContent, ... } }
GET /api/dashboard/calendar    → { calendar: { date: [...] } }
GET /api/dashboard/analytics   → { timeline: [...], byPlatform: [...] }
```

### Content CRUD
```
GET    /api/content?status=approved&page=1
POST   /api/content
GET    /api/content/:id
PUT    /api/content/:id
DELETE /api/content/:id
```

### Social Accounts
```
GET /api/socials
GET /api/socials/:id
```

### Competitor Analysis
```
POST /analyze/competitor
GET  /analysis/:id
POST /analysis/:id/send-to-agents
```

Полный список: [API.md](./API.md)

---

## 🔄 Data Flow

### Создание поста (пример)

```
┌─ Frontend ────────────────────────────────────┐
│ User fills form and clicks "Create"           │
│ →POST /api/content {title, caption, ...}      │
└────────────────┬────────────────────────────────┘
                 │
┌─ Backend ─────────────────────────────────────┐
│ APIController.createContent()                 │
│ → ContentItem entity created                  │
│ → Save to database                            │
│ → Return saved item                           │
└────────────────┬────────────────────────────────┘
                 │
┌─ Frontend ────────────────────────────────────┐
│ Display success message                       │
│ Reload content list                           │
│ Navigate to /content                          │
└──────────────────────────────────────────────┘
```

### Публикация поста (пример)

```
┌─ SchedulerService (runs every 60 seconds) ──┐
│ Check: publishAt <= now AND status=approved  │
│ For each post: PublishingService.publish()   │
└────────────┬─────────────────────────────────┘
             │
┌─ PublishingService ─────────────────────────┐
│ 1. Fetch token from SocialAccount            │
│ 2. Get platform adapter (Instagram, TG, etc) │
│ 3. Call adapter.publish(content)             │
│ 4. Save result to PublishingHistory          │
│ 5. Update ContentItem.status = 'published'   │
└────────────┬─────────────────────────────────┘
             │
┌─ InstagramAdapter (or other) ──────────────┐
│ 1. Decrypt token                            │
│ 2. Call Instagram API                       │
│ 3. Return { postId, url, metrics }          │
└─────────────────────────────────────────────┘
```

---

## 📝 Добавление новой фичи

### Пример: Добавить фичу "Content Drafts"

#### Шаг 1: Backend

**1.1 Entity** (если нужна новая таблица):
```typescript
// src/entities/ContentDraft.ts
@Entity('content_drafts')
export class ContentDraft {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  contentItemId: string;

  @Column('text')
  draftContent: string;

  @CreateDateColumn()
  createdAt: Date;
}
```

**1.2 Service**:
```typescript
// src/services/ContentDraftService.ts
export class ContentDraftService {
  async saveDraft(contentId: string, draft: string) {
    const repo = AppDataSource.getRepository(ContentDraft);
    return await repo.save({
      contentItemId: contentId,
      draftContent: draft,
    });
  }

  async getDraft(contentId: string) {
    const repo = AppDataSource.getRepository(ContentDraft);
    return await repo.findOneBy({ contentItemId: contentId });
  }
}
```

**1.3 Controller** (в APIController):
```typescript
async saveDraft(req: Request, res: Response) {
  const { contentId, draft } = req.body;
  const service = new ContentDraftService();
  const saved = await service.saveDraft(contentId, draft);
  res.json({ success: true, draft: saved });
}
```

**1.4 Route** (в index.ts):
```typescript
app.post('/api/content/:id/draft', (req, res) =>
  apiController.saveDraft(req, res)
);
```

#### Шаг 2: Frontend

**2.1 API Service** (в web/src/services/api.ts):
```typescript
export const contentDrafts = {
  save: (contentId: string, draft: string) =>
    apiClient.post(`/content/${contentId}/draft`, { draft }),
  get: (contentId: string) =>
    apiClient.get(`/content/${contentId}/draft`),
};
```

**2.2 Component**:
```typescript
// web/src/components/ContentDraftSaver.tsx
import { contentDrafts } from '../services/api';

export default function ContentDraftSaver({ contentId }: { contentId: string }) {
  const [draft, setDraft] = useState('');

  const handleSave = async () => {
    await contentDrafts.save(contentId, draft);
    alert('Draft saved!');
  };

  return (
    <div>
      <textarea
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        placeholder="Save your draft..."
      />
      <button onClick={handleSave}>Save Draft</button>
    </div>
  );
}
```

**2.3 Интегрировать в Page**:
```typescript
// web/src/pages/ContentManagement.tsx
import ContentDraftSaver from '../components/ContentDraftSaver';

// В render:
<ContentDraftSaver contentId={selectedId} />
```

---

## 🧪 Тестирование

### Backend тестирование

```bash
# Проверить types
npm run typecheck

# Стартовать dev сервер
npm run dev

# Тестировать API (curl или Postman)
curl http://localhost:3000/api/content
```

### Frontend тестирование

```bash
cd web

# Dev сервер с hot reload
npm run dev

# Build для production
npm run build

# Preview production build
npm run preview
```

---

## 🔑 Ключевые файлы для изменения

| Файл | Когда менять | Пример |
|------|------------|----------|
| `src/entities/*.ts` | Добавить новую таблицу | New entity class |
| `src/services/*.ts` | Добавить логику | New business method |
| `src/controllers/*.ts` | Добавить endpoint | New API handler |
| `src/index.ts` | Регистрировать роут | `app.post('/api/...', ...)` |
| `web/src/pages/*.tsx` | Новая страница | New page component |
| `web/src/components/**/*.tsx` | Новый компонент | Reusable component |
| `web/src/services/api.ts` | Новый API call | New apiClient method |

---

## 📦 Зависимости

### Backend
- `express` - HTTP сервер
- `typeorm` - ORM для БД
- `pg` / `sqlite3` - драйверы БД
- `anthropic` - Claude API
- `axios` - HTTP клиент
- `jsonwebtoken` - JWT токены
- `multer` - File uploads
- `csv-parse` - CSV parsing

### Frontend
- `react` - UI framework
- `react-router-dom` - Routing
- `axios` - HTTP клиент
- `tailwindcss` - CSS framework
- `lucide-react` - Icons
- `recharts` - Charts (опционально)

---

## 🚀 Deployment

### Локальный
```bash
docker-compose up
```

### Production (Railway)
```bash
# Коммит и push
git push origin main

# Railway автоматически:
# 1. Clones repo
# 2. Installs dependencies
# 3. Runs build
# 4. Starts server
```

### Production (собственный сервер)
```bash
docker build -t wai-social-brain .
docker run -p 3000:3000 -e NODE_ENV=production wai-social-brain
```

---

## 📖 Дальнейшее развитие

### High Priority
- [ ] Добавить Google Drive интеграцию
- [ ] Интегрировать нейросетевые API (Claude, OpenAI)
- [ ] Реальное time live publishing
- [ ] Analytics dashboard с графиками

### Medium Priority
- [ ] Unit тесты
- [ ] Integration тесты
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Performance optimization

### Low Priority
- [ ] GraphQL API
- [ ] WebSocket real-time updates
- [ ] Mobile app (React Native)
- [ ] Advanced caching

---

## 💡 Best Practices

1. **Типизация**: Всегда используй TypeScript типы
2. **Error handling**: Try-catch в Services, proper HTTP codes в Controllers
3. **Logging**: console.log в development, proper logger в production
4. **Validation**: Validate input на Backend, перед сохранением
5. **Security**: Encrypt sensitive tokens, use HTTPS в production
6. **Comments**: Документируй non-obvious логику
7. **Tests**: Write tests для critical paths
8. **Database**: Use migrations для schema changes

---

**Готово!** Теперь ты можешь расширять систему по любому направлению 🚀
