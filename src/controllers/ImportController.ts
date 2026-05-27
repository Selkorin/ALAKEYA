import { Request, Response } from 'express';
import { ContentImportService } from '../services/ContentImportService';

export class ImportController {
  private importService = new ContentImportService();

  // Upload and import CSV
  async importCSV(req: Request, res: Response) {
    try {
      const { contentPlanId } = req.params;
      const { file } = req;

      if (!file) {
        return res.status(400).json({ error: 'No file provided' });
      }

      const fileContent = file.buffer.toString('utf-8');
      const importedItems = this.importService.parseCSV(fileContent);

      if (importedItems.length === 0) {
        return res.status(400).json({ error: 'No items in file' });
      }

      const savedItems = await this.importService.importContent(
        contentPlanId,
        importedItems
      );

      res.json({
        success: true,
        imported: savedItems.length,
        items: savedItems,
        message: `Successfully imported ${savedItems.length} items`,
      });
    } catch (error: any) {
      console.error('CSV import error:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Upload and import JSON
  async importJSON(req: Request, res: Response) {
    try {
      const { contentPlanId } = req.params;
      const { file } = req;

      if (!file) {
        return res.status(400).json({ error: 'No file provided' });
      }

      const fileContent = file.buffer.toString('utf-8');
      const importedItems = this.importService.parseJSON(fileContent);

      if (importedItems.length === 0) {
        return res.status(400).json({ error: 'No items in file' });
      }

      const savedItems = await this.importService.importContent(
        contentPlanId,
        importedItems
      );

      res.json({
        success: true,
        imported: savedItems.length,
        items: savedItems,
        message: `Successfully imported ${savedItems.length} items`,
      });
    } catch (error: any) {
      console.error('JSON import error:', error);
      res.status(400).json({ error: error.message });
    }
  }

  // Bulk update schedules
  async updateSchedules(req: Request, res: Response) {
    try {
      const { updates } = req.body;

      if (!Array.isArray(updates)) {
        return res.status(400).json({
          error: 'Updates must be an array',
        });
      }

      // Validate structure
      for (const update of updates) {
        if (!update.contentItemId || !update.publishAt) {
          return res.status(400).json({
            error: 'Each update must have contentItemId and publishAt',
          });
        }
      }

      // Transform dates
      const transformedUpdates = updates.map(u => ({
        contentItemId: u.contentItemId,
        publishAt: new Date(u.publishAt),
      }));

      const updated = await this.importService.updateSchedules(transformedUpdates);

      res.json({
        success: true,
        updated: updated.length,
        items: updated,
      });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }

  // Export to CSV
  async exportCSV(req: Request, res: Response) {
    try {
      const { contentPlanId } = req.params;

      const csv = await this.importService.exportToCSV(contentPlanId);

      res.setHeader('Content-Type', 'text/csv');
      res.setHeader(
        'Content-Disposition',
        `attachment; filename="content-plan-${contentPlanId}.csv"`
      );
      res.send(csv);
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }

  // Export to JSON
  async exportJSON(req: Request, res: Response) {
    try {
      const { contentPlanId } = req.params;

      const json = await this.importService.exportToJSON(contentPlanId);

      res.setHeader('Content-Type', 'application/json');
      res.setHeader(
        'Content-Disposition',
        `attachment; filename="content-plan-${contentPlanId}.json"`
      );
      res.send(json);
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }

  // Get CSV template
  getCSVTemplate(req: Request, res: Response) {
    try {
      const template = this.importService.getCSVTemplate();

      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename="template.csv"');
      res.send(template);
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }

  // Get JSON template
  getJSONTemplate(req: Request, res: Response) {
    const template = [
      {
        title: 'First Post',
        caption: 'Check out our new product!',
        platform: 'instagram',
        contentType: 'post',
        publishAt: '2024-12-25T12:00:00Z',
        imageUrl: 'https://example.com/image1.jpg',
        videoUrl: null,
        hashtags: ['#marketing', '#product'],
      },
      {
        title: 'Video Reel',
        caption: 'How to use our service',
        platform: 'instagram',
        contentType: 'reel',
        publishAt: '2024-12-25T15:00:00Z',
        imageUrl: null,
        videoUrl: 'https://example.com/video.mp4',
        hashtags: ['#tutorial', '#howto'],
      },
    ];

    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Disposition', 'attachment; filename="template.json"');
    res.json(template);
  }
}
