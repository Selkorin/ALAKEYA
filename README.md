# WAI Social Brain — AI SMM Agent for Social Networks

Intelligent social media management system that creates content plans, generates posts, manages assets, and automates publication across multiple social networks.

## 🎯 Features

- **Multi-platform support**: Instagram, Telegram, VK, YouTube, TikTok
- **AI-powered agent**: Understands your brand and creates contextual content
- **Multiple AI providers**: Claude, OpenAI, Gemini (extensible)
- **Content planning**: Automatic 7-14 day plans
- **Knowledge base**: Upload files, references, brand guidelines
- **Approval workflow**: Manual review before publishing
- **Webhook integration**: Integrate with your own server at `85.239.51.246`
- **Publishing scheduler**: Automatic post scheduling

## 📋 Architecture

```
┌─────────────────────────────────────────┐
│  WAI Admin Panel                        │
│  (Frontend - React + TypeScript)        │
└──────────────┬──────────────────────────┘
               │ (HTTP)
┌──────────────▼──────────────────────────┐
│  WAI Backend API                        │
│  (Node.js + Express)                    │
│                                          │
│  • Social Account Management             │
│  • Webhook Receiver                      │
│  • Database Operations                   │
└──────────────┬──────────────────────────┘
               │ (Webhook)
┌──────────────▼──────────────────────────┐
│  Your Server (85.239.51.246)            │
│                                          │
│  ┌─────────────────────────────────┐    │
│  │ Webhook Handler                 │    │
│  │ (Receives tasks from WAI)       │    │
│  └────────────┬────────────────────┘    │
│               │                         │
│  ┌────────────▼────────────────────┐    │
│  │ SMM Agent Service               │    │
│  │ • Content Planning              │    │
│  │ • Text Generation               │    │
│  │ • Image Prompt Generation       │    │
│  │ • Brand Knowledge Analysis      │    │
│  └────────────┬────────────────────┘    │
│               │                         │
│  ┌────────────▼────────────────────┐    │
│  │ AI Provider Factory             │    │
│  │ • Claude Provider               │    │
│  │ • OpenAI Provider (TODO)        │    │
│  │ • Gemini Provider (TODO)        │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

## 🗄️ Database Schema

### `social_accounts`
Stores connected social media accounts
- `id`: UUID
- `platform`: 'instagram' | 'telegram' | 'vk' | 'youtube' | 'tiktok'
- `accountName`: Display name
- `accessTokenEncrypted`: Encrypted API token
- `status`: 'connected' | 'disconnected' | 'error'

### `social_agents`
AI agents configured per social account
- `id`: UUID
- `agentName`: "WAI SMM"
- `toneOfVoice`: "professional, engaging"
- `brandRules`: JSON with style, offers, audience
- `aiProvider`: 'claude' | 'openai' | 'gemini'
- `autoPublishEnabled`: boolean
- `approvalRequired`: boolean

### `knowledge_files`
Brand knowledge documents
- `id`: UUID
- `fileName`: "branding_guide.pdf"
- `fileType`: 'pdf' | 'docx' | 'txt' | 'image' | 'audio' | 'link'
- `parsedText`: Extracted text content
- `embeddingId`: Vector embedding ID

### `content_plans`
7-14 day content plans
- `id`: UUID
- `title`: "Weekly Plan"
- `periodStart` / `periodEnd`: Date range
- `status`: 'draft' | 'active' | 'completed'

### `content_items`
Individual posts/stories/reels
- `id`: UUID
- `caption`: Post text
- `imagePrompt`: For image generation
- `imageUrl` / `videoUrl`: Generated or uploaded media
- `hashtags`: Array of tags
- `publishAt`: Scheduled time
- `status`: 'draft' | 'needs_review' | 'approved' | 'scheduled' | 'published'
- `approvalStatus`: 'pending' | 'approved' | 'rejected'

## 🚀 Getting Started

### Installation

```bash
npm install
```

### Configuration

1. Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

2. Fill in your API keys:
```
ANTHROPIC_API_KEY=sk-ant-...
DB_HOST=localhost
DB_PORT=5432
DB_NAME=wai_social_agent
```

### Database Setup

```bash
# Create PostgreSQL database
createdb wai_social_agent

# Run migrations (auto-sync with NODE_ENV=development)
npm run build
npm start
```

### Development

```bash
npm run dev
```

Server will start on `http://localhost:3000`

Health check: `GET /health`

## 🔗 Webhook Integration

### Receive Tasks from WAI

**Endpoint:** `POST /webhook/task`

**Payload:**
```json
{
  "type": "create_content_plan",
  "socialAccountId": "uuid",
  "projectId": "uuid",
  "userMessage": "Create a 7-day plan for Instagram",
  "files": ["url1", "url2"],
  "references": ["reference1", "reference2"]
}
```

**Types:**
- `create_content_plan`: Generate a content plan
- `generate_content`: Generate specific content
- `publish`: Publish approved content
- `analyze`: Analyze brand/content

**Response:**
```json
{
  "success": true,
  "result": { /* varies by type */ },
  "taskId": 1234567890
}
```

### Send Commands to WAI

From your server to WAI:

```bash
curl -X POST http://wai-api/social-agents/task \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_WAI_TOKEN" \
  -d '{
    "type": "publish",
    "contentItemId": "uuid",
    "platform": "instagram"
  }'
```

## 🤖 AI Agent Usage

### Initialize Agent

```typescript
const smmService = new SmmAgentService();
await smmService.initialize(agentId, socialAccountId, projectId);
```

### Create Content Plan

```typescript
const plan = await smmService.createContentPlan(
  "Weekly Plan",
  new Date(),
  new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
  "Create posts for a marketing agency"
);
```

### Generate Content

```typescript
const items = await smmService.generateContentItems(
  contentPlanId,
  7, // number of posts
  'instagram'
);
```

### Approve & Publish

```typescript
await smmService.approveContent(contentItemId);
await smmService.publishContent(contentItemId);
```

## 🔐 Security

- ✅ Encrypted token storage
- ✅ Webhook signature verification (TODO)
- ✅ JWT authentication (TODO)
- ✅ Rate limiting (TODO)
- ✅ Content safety checks (TODO)

## 📦 Deployment

### Docker

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY dist ./dist

CMD ["node", "dist/index.ts"]
```

### Your Server (85.239.51.246)

1. Clone the repo
2. Install dependencies: `npm install`
3. Build: `npm run build`
4. Set up `.env` with your API keys
5. Run: `npm start`

## 🗺️ Roadmap

### Phase 1 ✅
- [x] Project scaffold
- [x] Database schema
- [x] Claude AI provider
- [x] Webhook receiver
- [x] Basic content planning

### Phase 2 🔄
- [ ] OpenAI provider
- [ ] Gemini provider
- [ ] Instagram OAuth & publishing
- [ ] Telegram bot API integration
- [ ] File upload & parsing
- [ ] Content calendar UI

### Phase 3 📋
- [ ] VK API integration
- [ ] YouTube API integration
- [ ] Image generation (Midjourney/Stable Diffusion)
- [ ] Analytics & reporting
- [ ] A/B testing

## 📞 API Reference

### Content Planning
- `POST /webhook/task` - Create content plan

### Content Management
- `GET /content-plans/{id}` - Get plan details
- `POST /content-items/{id}/approve` - Approve content
- `POST /content-items/{id}/publish` - Publish content
- `PUT /content-items/{id}` - Edit content

### Social Accounts
- `POST /social-accounts` - Connect account
- `GET /social-accounts` - List accounts
- `DELETE /social-accounts/{id}` - Disconnect account

### AI Agents
- `POST /agents` - Create agent
- `PUT /agents/{id}` - Update agent settings
- `POST /agents/{id}/ask` - Chat with agent

## 🤝 Contributing

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Commit: `git commit -am 'Add feature'`
3. Push: `git push origin feature/your-feature`
4. Open PR

## 📄 License

MIT

## 💬 Support

- Docs: https://docs.wai.system
- Email: support@wai.system
- Telegram: @wai_support

---

Built with ❤️ for SMM teams
