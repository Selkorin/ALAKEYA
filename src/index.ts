import express from 'express';
import dotenv from 'dotenv';
import multer from 'multer';
import { AppDataSource } from './config/database';
import { WebhookController } from './controllers/WebhookController';
import { DemoController } from './controllers/DemoController';
import { AuthController } from './controllers/AuthController';
import { PublishingController } from './controllers/PublishingController';
import { ContentController } from './controllers/ContentController';
import { ImportController } from './controllers/ImportController';
import { SchedulerService } from './services/SchedulerService';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Multer setup for file uploads
const upload = multer({ storage: multer.memoryStorage() });

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Services
const schedulerService = new SchedulerService();

// Initialize database
AppDataSource.initialize()
  .then(() => {
    console.log('✅ Database connection established');
    // Start scheduler
    schedulerService.start();
  })
  .catch(error => console.log('⚠️ Database initialization warning:', error.message));

// Controllers
const webhookController = new WebhookController();
const demoController = new DemoController();
const authController = new AuthController();
const publishingController = new PublishingController();
const contentController = new ContentController();
const importController = new ImportController();

// Health & Demo
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'WAI Social Agent', version: '0.1.0' });
});

app.get('/demo', (req, res) => demoController.getDashboard(req, res));
app.get('/', (req, res) => res.redirect('/demo'));

// Webhook
app.post('/webhook/task', (req, res) => webhookController.handleTask(req, res));
app.get('/webhook/status', (req, res) => webhookController.getStatus(req, res));

// OAuth Authentication Routes
app.get('/auth/instagram/url', (req, res) => authController.getInstagramOAuthUrl(req, res));
app.get('/auth/instagram/callback', (req, res) => authController.instagramCallback(req, res));

app.get('/auth/vk/url', (req, res) => authController.getVkOAuthUrl(req, res));
app.get('/auth/vk/callback', (req, res) => authController.vkCallback(req, res));

app.post('/auth/telegram/connect', (req, res) => authController.telegramConnect(req, res));

// Publishing Routes
app.post('/publish/:contentItemId', (req, res) =>
  publishingController.publishNow(req, res)
);

app.post('/content/:contentItemId/approve', (req, res) =>
  publishingController.approveContent(req, res)
);

app.post('/content/:contentItemId/schedule', (req, res) =>
  publishingController.scheduleContent(req, res)
);

app.get('/content/:contentItemId/status', (req, res) =>
  publishingController.getContentStatus(req, res)
);

// Content Generation Routes
app.post('/content/generate/plan', (req, res) =>
  contentController.generateForPlan(req, res)
);

app.post('/content/generate/single', (req, res) =>
  contentController.generateSingle(req, res)
);

app.post('/content/:contentItemId/regenerate', (req, res) =>
  contentController.regenerate(req, res)
);

// Calendar & Analytics Routes
app.get('/calendar', (req, res) =>
  contentController.getCalendar(req, res)
);

app.get('/history', (req, res) =>
  contentController.getHistory(req, res)
);

app.get('/analytics', (req, res) =>
  contentController.getAnalytics(req, res)
);

app.get('/scheduled', (req, res) =>
  contentController.getScheduled(req, res)
);

// Import/Export Routes
app.post('/import/:contentPlanId/csv', upload.single('file'), (req, res) =>
  importController.importCSV(req, res)
);

app.post('/import/:contentPlanId/json', upload.single('file'), (req, res) =>
  importController.importJSON(req, res)
);

app.post('/schedules/bulk-update', (req, res) =>
  importController.updateSchedules(req, res)
);

app.get('/export/:contentPlanId/csv', (req, res) =>
  importController.exportCSV(req, res)
);

app.get('/export/:contentPlanId/json', (req, res) =>
  importController.exportJSON(req, res)
);

app.get('/import/template/csv', (req, res) =>
  importController.getCSVTemplate(req, res)
);

app.get('/import/template/json', (req, res) =>
  importController.getJSONTemplate(req, res)
);

app.listen(PORT, () => {
  console.log(`\n✅ WAI Social Agent running on port ${PORT}\n`);
  console.log(`🌐 Dashboard: http://localhost:${PORT}/demo`);
  console.log(`💚 Health check: http://localhost:${PORT}/health`);
  console.log(`🔗 Webhook endpoint: http://localhost:${PORT}/webhook/task`);

  console.log(`\n🔐 OAuth Endpoints:`);
  console.log(`   Instagram: GET /auth/instagram/url`);
  console.log(`   VK: GET /auth/vk/url`);
  console.log(`   Telegram: POST /auth/telegram/connect`);

  console.log(`\n📤 Publishing Endpoints:`);
  console.log(`   Publish: POST /publish/:contentItemId`);
  console.log(`   Approve: POST /content/:contentItemId/approve`);
  console.log(`   Schedule: POST /content/:contentItemId/schedule`);
  console.log(`   Status: GET /content/:contentItemId/status`);

  console.log(`\n🤖 Content Generation Endpoints:`);
  console.log(`   Generate Plan: POST /content/generate/plan`);
  console.log(`   Generate Single: POST /content/generate/single`);
  console.log(`   Regenerate: POST /content/:contentItemId/regenerate`);

  console.log(`\n📅 Calendar & Analytics Endpoints:`);
  console.log(`   Calendar: GET /calendar?socialAccountId=uuid&month=2024-12`);
  console.log(`   History: GET /history?socialAccountId=uuid&limit=50`);
  console.log(`   Analytics: GET /analytics?days=7&socialAccountId=uuid`);
  console.log(`   Scheduled: GET /scheduled`);

  console.log(`\n⏱️ Scheduler: Auto-publishes content at scheduled times (every minute)`);

  console.log(`\n📥 Import/Export Endpoints:`);
  console.log(`   Import CSV: POST /import/:contentPlanId/csv (with file)`);
  console.log(`   Import JSON: POST /import/:contentPlanId/json (with file)`);
  console.log(`   Export CSV: GET /export/:contentPlanId/csv`);
  console.log(`   Export JSON: GET /export/:contentPlanId/json`);
  console.log(`   CSV Template: GET /import/template/csv`);
  console.log(`   JSON Template: GET /import/template/json`);
  console.log(`   Bulk Update Schedules: POST /schedules/bulk-update\n`);
});
