import { Request, Response } from 'express';
import { PublishingService } from '../services/PublishingService';
import { AppDataSource } from '../config/database';
import { ContentItem } from '../entities/ContentItem';

export class PublishingController {
  private publishingService = new PublishingService();

  async publishNow(req: Request, res: Response) {
    try {
      const { contentItemId } = req.params;

      const result = await this.publishingService.publishContentItem(contentItemId);

      res.json({
        success: true,
        postId: result.postId,
        url: result.url,
        message: 'Content published successfully',
      });
    } catch (error: any) {
      console.error('Publishing error:', error);
      res.status(500).json({
        success: false,
        error: error.message,
      });
    }
  }

  async approveContent(req: Request, res: Response) {
    try {
      const { contentItemId } = req.params;
      const { approved } = req.body;

      const contentItemRepo = AppDataSource.getRepository(ContentItem);
      const item = await contentItemRepo.findOneBy({ id: contentItemId });

      if (!item) {
        return res.status(404).json({ error: 'Content not found' });
      }

      if (approved) {
        item.approvalStatus = 'approved';
        item.status = 'approved';
      } else {
        item.approvalStatus = 'rejected';
        item.status = 'draft';
      }

      await contentItemRepo.save(item);

      res.json({
        success: true,
        item,
        message: approved ? 'Content approved' : 'Content rejected',
      });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }

  async scheduleContent(req: Request, res: Response) {
    try {
      const { contentItemId, publishAt } = req.body;

      const contentItemRepo = AppDataSource.getRepository(ContentItem);
      const item = await contentItemRepo.findOneBy({ id: contentItemId });

      if (!item) {
        return res.status(404).json({ error: 'Content not found' });
      }

      item.publishAt = new Date(publishAt);
      item.status = 'scheduled';

      await contentItemRepo.save(item);

      res.json({
        success: true,
        item,
        message: `Content scheduled for ${publishAt}`,
      });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }

  async getContentStatus(req: Request, res: Response) {
    try {
      const { contentItemId } = req.params;

      const contentItemRepo = AppDataSource.getRepository(ContentItem);
      const item = await contentItemRepo.findOneBy({ id: contentItemId });

      if (!item) {
        return res.status(404).json({ error: 'Content not found' });
      }

      res.json({
        id: item.id,
        title: item.title,
        status: item.status,
        approvalStatus: item.approvalStatus,
        platformPostId: item.platformPostId,
        errorMessage: item.errorMessage,
        publishAt: item.publishAt,
      });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }
}
