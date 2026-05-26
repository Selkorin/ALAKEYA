import { Request, Response } from 'express';
import { IWebhookPayload } from '../types';
import { SmmAgentService } from '../services/SmmAgentService';
import { AppDataSource } from '../config/database';
import { SocialAgent } from '../entities/SocialAgent';

export class WebhookController {
  async handleTask(req: Request, res: Response) {
    try {
      const payload = req.body as IWebhookPayload;

      const agentRepo = AppDataSource.getRepository(SocialAgent);
      const agents = await agentRepo.findBy({ socialAccountId: payload.socialAccountId });

      if (!agents.length) {
        return res.status(404).json({ error: 'Agent not found' });
      }

      const agent = agents[0];
      const smmService = new SmmAgentService();
      await smmService.initialize(agent.id, payload.socialAccountId, payload.projectId);

      let result: any;

      switch (payload.type) {
        case 'create_content_plan':
          result = await smmService.createContentPlan(
            `Plan from ${new Date().toLocaleDateString()}`,
            new Date(),
            new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
            payload.userMessage,
          );
          break;

        case 'generate_content':
          // TODO: Implement content generation
          result = { message: 'Content generation task queued' };
          break;

        case 'publish':
          // TODO: Implement publishing
          result = { message: 'Publishing task queued' };
          break;

        case 'analyze':
          // TODO: Implement analysis
          result = { message: 'Analysis task queued' };
          break;

        default:
          return res.status(400).json({ error: 'Unknown task type' });
      }

      res.json({
        success: true,
        result,
        taskId: Date.now(),
      });
    } catch (error: any) {
      console.error('Webhook error:', error);
      res.status(500).json({
        success: false,
        error: error.message,
      });
    }
  }

  async getStatus(req: Request, res: Response) {
    res.json({ status: 'ok', timestamp: new Date() });
  }
}
