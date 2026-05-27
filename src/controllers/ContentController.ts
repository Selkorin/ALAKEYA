import { Request, Response } from 'express';
import { AppDataSource } from '../config/database';
import { ContentItem } from '../entities/ContentItem';
import { ContentPlan } from '../entities/ContentPlan';
import { PublishingHistory } from '../entities/PublishingHistory';
import { ContentGenerationService } from '../services/ContentGenerationService';
import { SchedulerService } from '../services/SchedulerService';

export class ContentController {
  private contentGenerationService = new ContentGenerationService();
  private schedulerService = new SchedulerService();

  // Get content calendar
  async getCalendar(req: Request, res: Response) {
    try {
      const { socialAccountId, month } = req.query;
      const contentItemRepo = AppDataSource.getRepository(ContentItem);

      let query = contentItemRepo.createQueryBuilder('content');

      if (socialAccountId) {
        query = query.where('content.socialAccountId = :socialAccountId', {
          socialAccountId,
        });
      }

      if (month) {
        const [year, monthNum] = (month as string).split('-');
        const startDate = new Date(parseInt(year), parseInt(monthNum) - 1, 1);
        const endDate = new Date(parseInt(year), parseInt(monthNum), 0);

        query = query.andWhere('content.publishAt BETWEEN :start AND :end', {
          start: startDate,
          end: endDate,
        });
      }

      const items = await query.orderBy('content.publishAt', 'ASC').getMany();

      // Group by date
      const calendar = items.reduce(
        (acc, item) => {
          const date = item.publishAt.toISOString().split('T')[0];
          if (!acc[date]) acc[date] = [];
          acc[date].push(item);
          return acc;
        },
        {} as Record<string, ContentItem[]>
      );

      res.json(calendar);
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }

  // Generate content for plan
  async generateForPlan(req: Request, res: Response) {
    try {
      const { contentPlanId, agentId, platforms } = req.body;

      if (!contentPlanId || !agentId) {
        return res.status(400).json({
          error: 'contentPlanId and agentId are required',
        });
      }

      const platformList = platforms || [
        'instagram',
        'telegram',
        'vk',
      ];

      const results = await this.contentGenerationService.batchGenerateContent(
        contentPlanId,
        agentId,
        platformList
      );

      res.json({
        success: true,
        generatedCount: Object.values(results).reduce(
          (sum, items) => sum + items.length,
          0
        ),
        results,
      });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }

  // Generate single post
  async generateSingle(req: Request, res: Response) {
    try {
      const {
        socialAccountId,
        agentId,
        platform,
        topic,
        style,
      } = req.body;

      if (!socialAccountId || !agentId || !platform || !topic) {
        return res.status(400).json({
          error: 'socialAccountId, agentId, platform, and topic are required',
        });
      }

      const item = await this.contentGenerationService.generateSinglePost(
        socialAccountId,
        agentId,
        platform,
        topic,
        style
      );

      res.json({
        success: true,
        item,
      });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }

  // Regenerate content
  async regenerate(req: Request, res: Response) {
    try {
      const { contentItemId } = req.params;

      const item = await this.contentGenerationService.regenerateContent(
        contentItemId
      );

      res.json({
        success: true,
        item,
      });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }

  // Get publishing history
  async getHistory(req: Request, res: Response) {
    try {
      const { socialAccountId, limit = 50 } = req.query;
      const historyRepo = AppDataSource.getRepository(PublishingHistory);

      let query = historyRepo.createQueryBuilder('history')
        .orderBy('history.publishedAt', 'DESC');

      if (socialAccountId) {
        query = query.where('history.socialAccountId = :socialAccountId', {
          socialAccountId,
        });
      }

      const items = await query.take(parseInt(limit as string)).getMany();

      res.json(items);
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }

  // Get analytics/statistics
  async getAnalytics(req: Request, res: Response) {
    try {
      const { socialAccountId, days = 7 } = req.query;
      const historyRepo = AppDataSource.getRepository(PublishingHistory);

      const startDate = new Date();
      startDate.setDate(startDate.getDate() - parseInt(days as string));

      let query = historyRepo.createQueryBuilder('history')
        .where('history.publishedAt >= :startDate', { startDate });

      if (socialAccountId) {
        query = query.andWhere('history.socialAccountId = :socialAccountId', {
          socialAccountId,
        });
      }

      const items = await query.getMany();

      const stats = {
        period: `Last ${days} days`,
        totalPublished: items.filter(i => i.status === 'success').length,
        totalFailed: items.filter(i => i.status === 'failed').length,
        successRate: 0,
        byPlatform: {} as Record<string, { success: number; failed: number }>,
      };

      // Calculate success rate
      const total = items.length;
      if (total > 0) {
        stats.successRate = Math.round(
          (stats.totalPublished / total) * 100
        );
      }

      // Group by platform
      items.forEach(item => {
        if (!stats.byPlatform[item.platform]) {
          stats.byPlatform[item.platform] = { success: 0, failed: 0 };
        }
        if (item.status === 'success') {
          stats.byPlatform[item.platform].success++;
        } else {
          stats.byPlatform[item.platform].failed++;
        }
      });

      res.json(stats);
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }

  // Get upcoming scheduled posts
  async getScheduled(req: Request, res: Response) {
    try {
      const scheduled = await this.schedulerService.getNextScheduled(10);
      res.json(scheduled);
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }
}
