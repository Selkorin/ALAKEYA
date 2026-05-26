import express from 'express';
import dotenv from 'dotenv';
import { AppDataSource } from './config/database';
import { WebhookController } from './controllers/WebhookController';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Initialize database
AppDataSource.initialize()
  .then(() => {
    console.log('Database connection established');
  })
  .catch(error => console.log('Error initializing database:', error));

// Routes
const webhookController = new WebhookController();

app.post('/webhook/task', (req, res) => webhookController.handleTask(req, res));
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'WAI Social Agent', version: '0.1.0' });
});

app.get('/webhook/status', (req, res) => webhookController.getStatus(req, res));

app.listen(PORT, () => {
  console.log(`WAI Social Agent running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`Webhook endpoint: http://localhost:${PORT}/webhook/task`);
});
