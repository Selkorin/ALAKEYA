import { AppDataSource } from '../config/database';
import { ContentItem } from '../entities/ContentItem';
import { ContentPlan } from '../entities/ContentPlan';
import * as csv from 'csv-parse/sync';

export interface ImportedContent {
  title: string;
  caption: string;
  platform: 'instagram' | 'telegram' | 'vk' | 'youtube' | 'tiktok';
  contentType: 'post' | 'story' | 'reel' | 'short' | 'carousel';
  publishAt: Date;
  imageUrl?: string;
  videoUrl?: string;
  hashtags?: string[];
  notes?: string;
}

export class ContentImportService {
  // Parse CSV file
  parseCSV(fileContent: string): ImportedContent[] {
    try {
      const records = csv.parse(fileContent, {
        columns: true,
        skip_empty_lines: true,
      });

      return records.map((record: any) => this.validateAndTransform(record));
    } catch (error: any) {
      throw new Error(`CSV parsing error: ${error.message}`);
    }
  }

  // Parse JSON file
  parseJSON(fileContent: string): ImportedContent[] {
    try {
      const data = JSON.parse(fileContent);
      const records = Array.isArray(data) ? data : [data];

      return records.map((record: any) => this.validateAndTransform(record));
    } catch (error: any) {
      throw new Error(`JSON parsing error: ${error.message}`);
    }
  }

  // Import content items
  async importContent(
    contentPlanId: string,
    importedItems: ImportedContent[]
  ): Promise<ContentItem[]> {
    const contentPlanRepo = AppDataSource.getRepository(ContentPlan);
    const contentItemRepo = AppDataSource.getRepository(ContentItem);

    const plan = await contentPlanRepo.findOneBy({ id: contentPlanId });
    if (!plan) {
      throw new Error('Content plan not found');
    }

    const savedItems: ContentItem[] = [];

    for (const item of importedItems) {
      // Validate publish date is within plan period
      if (item.publishAt < plan.periodStart || item.publishAt > plan.periodEnd) {
        console.warn(
          `Skipping "${item.title}" - publish date outside plan period`
        );
        continue;
      }

      const contentItem = contentItemRepo.create({
        contentPlanId,
        platform: item.platform,
        contentType: item.contentType,
        title: item.title,
        caption: item.caption,
        imageUrl: item.imageUrl,
        videoUrl: item.videoUrl,
        hashtags: item.hashtags || [],
        publishAt: item.publishAt,
        status: 'draft',
        approvalStatus: 'pending',
      });

      const saved = await contentItemRepo.save(contentItem);
      savedItems.push(saved);
    }

    return savedItems;
  }

  // Bulk schedule update
  async updateSchedules(
    updates: Array<{ contentItemId: string; publishAt: Date }>
  ): Promise<ContentItem[]> {
    const contentItemRepo = AppDataSource.getRepository(ContentItem);
    const updated: ContentItem[] = [];

    for (const update of updates) {
      const item = await contentItemRepo.findOneBy({ id: update.contentItemId });
      if (!item) continue;

      item.publishAt = update.publishAt;
      const saved = await contentItemRepo.save(item);
      updated.push(saved);
    }

    return updated;
  }

  // Export content items to CSV
  async exportToCSV(contentPlanId: string): Promise<string> {
    const contentItemRepo = AppDataSource.getRepository(ContentItem);
    const items = await contentItemRepo.findBy({ contentPlanId });

    if (items.length === 0) {
      return '';
    }

    const headers = [
      'title',
      'caption',
      'platform',
      'contentType',
      'publishAt',
      'imageUrl',
      'videoUrl',
      'hashtags',
      'status',
    ];

    const rows = items.map(item => [
      `"${item.title}"`,
      `"${item.caption.replace(/"/g, '""')}"`,
      item.platform,
      item.contentType,
      item.publishAt.toISOString(),
      item.imageUrl || '',
      item.videoUrl || '',
      item.hashtags?.join(',') || '',
      item.status,
    ]);

    const csv = [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
    return csv;
  }

  // Export to JSON
  async exportToJSON(contentPlanId: string): Promise<string> {
    const contentItemRepo = AppDataSource.getRepository(ContentItem);
    const items = await contentItemRepo.findBy({ contentPlanId });

    return JSON.stringify(
      items.map(item => ({
        title: item.title,
        caption: item.caption,
        platform: item.platform,
        contentType: item.contentType,
        publishAt: item.publishAt.toISOString(),
        imageUrl: item.imageUrl,
        videoUrl: item.videoUrl,
        hashtags: item.hashtags,
        status: item.status,
      })),
      null,
      2
    );
  }

  // Get import template
  getCSVTemplate(): string {
    const headers = [
      'title',
      'caption',
      'platform',
      'contentType',
      'publishAt',
      'imageUrl',
      'videoUrl',
      'hashtags',
    ];

    const example = [
      '"First Post"',
      '"Check out our new product!"',
      'instagram',
      'post',
      '2024-12-25T12:00:00Z',
      'https://example.com/image1.jpg',
      '',
      '#marketing,#product',
    ];

    return [headers.join(','), example.join(',')].join('\n');
  }

  private validateAndTransform(record: any): ImportedContent {
    // Validate required fields
    if (!record.title) throw new Error('Missing required field: title');
    if (!record.caption) throw new Error('Missing required field: caption');
    if (!record.platform) throw new Error('Missing required field: platform');
    if (!record.contentType) throw new Error('Missing required field: contentType');
    if (!record.publishAt) throw new Error('Missing required field: publishAt');

    // Validate platform
    const validPlatforms = ['instagram', 'telegram', 'vk', 'youtube', 'tiktok'];
    if (!validPlatforms.includes(record.platform)) {
      throw new Error(`Invalid platform: ${record.platform}`);
    }

    // Validate content type
    const validTypes = ['post', 'story', 'reel', 'short', 'carousel'];
    if (!validTypes.includes(record.contentType)) {
      throw new Error(`Invalid contentType: ${record.contentType}`);
    }

    // Parse date
    const publishAt = new Date(record.publishAt);
    if (isNaN(publishAt.getTime())) {
      throw new Error(`Invalid date: ${record.publishAt}`);
    }

    // Parse hashtags
    let hashtags: string[] = [];
    if (record.hashtags) {
      if (typeof record.hashtags === 'string') {
        hashtags = record.hashtags
          .split(',')
          .map((tag: string) => tag.trim())
          .filter((tag: string) => tag.length > 0);
      } else if (Array.isArray(record.hashtags)) {
        hashtags = record.hashtags;
      }
    }

    return {
      title: record.title.trim(),
      caption: record.caption.trim(),
      platform: record.platform,
      contentType: record.contentType,
      publishAt,
      imageUrl: record.imageUrl || undefined,
      videoUrl: record.videoUrl || undefined,
      hashtags,
      notes: record.notes || undefined,
    };
  }
}
