import express from 'express';
import dotenv from 'dotenv';
import { AppDataSource } from './config/database';
import { WebhookController } from './controllers/WebhookController';
import { DemoController } from './controllers/DemoController';
import { AuthController } from './controllers/AuthController';
import { PublishingController } from './controllers/PublishingController';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Initialize database
AppDataSource.initialize()
  .then(() => {
    console.log('✅ Database connection established');
  })
  .catch(error => console.log('⚠️ Database initialization warning:', error.message));

// Controllers
const webhookController = new WebhookController();
const demoController = new DemoController();
const authController = new AuthController();
const publishingController = new PublishingController();

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
  console.log(`   Status: GET /content/:contentItemId/status\n`);
});
