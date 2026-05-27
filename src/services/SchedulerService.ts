import { AppDataSource } from '../config/database';
import { ContentItem } from '../entities/ContentItem';
import { PublishingService } from './PublishingService';

export class SchedulerService {
  private publishingService = new PublishingService();
  private isRunning = false;
  private checkInterval = 60000; // Check every minute

  start() {
    if (this.isRunning) {
      console.log('⚠️ Scheduler already running');
      return;
    }

    this.isRunning = true;
    console.log('✅ Scheduler started - checking every minute');

    this.checkAndPublish();
    setInterval(() => this.checkAndPublish(), this.checkInterval);
  }

  stop() {
    this.isRunning = false;
    console.log('⏹️ Scheduler stopped');
  }

  private async checkAndPublish() {
    try {
      const contentItemRepo = AppDataSource.getRepository(ContentItem);

      // Find all scheduled items that are ready to publish
      const now = new Date();
      const scheduledItems = await contentItemRepo.find({
        where: [
          {
            status: 'scheduled',
            approvalStatus: 'approved',
          },
        ],
      });

      const readyItems = scheduledItems.filter(item => item.publishAt <= now);

      if (readyItems.length === 0) return;

      console.log(`📤 Found ${readyItems.length} items ready to publish`);

      for (const item of readyItems) {
        try {
          await this.publishingService.publishContentItem(item.id);
          console.log(`✅ Published: ${item.title}`);
        } catch (error: any) {
          console.error(`❌ Failed to publish ${item.title}:`, error.message);
        }
      }
    } catch (error) {
      console.error('Scheduler error:', error);
    }
  }

  // Get next scheduled items
  async getNextScheduled(limit: number = 10) {
    const contentItemRepo = AppDataSource.getRepository(ContentItem);

    return contentItemRepo.find({
      where: {
        status: 'scheduled',
        approvalStatus: 'approved',
      },
      order: {
        publishAt: 'ASC',
      },
      take: limit,
    });
  }

  // Get publishing statistics
  async getStats(days: number = 7) {
    const contentItemRepo = AppDataSource.getRepository(ContentItem);

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const items = await contentItemRepo.find({
      where: {
        publishAt: {
          $gte: startDate,
        } as any,
      },
    });

    const stats = {
      total: items.length,
      published: items.filter(i => i.status === 'published').length,
      scheduled: items.filter(i => i.status === 'scheduled').length,
      failed: items.filter(i => i.status === 'failed').length,
      draft: items.filter(i => i.status === 'draft').length,
      successRate: 0,
    };

    if (stats.total > 0) {
      stats.successRate = Math.round((stats.published / stats.total) * 100);
    }

    return stats;
  }
}
