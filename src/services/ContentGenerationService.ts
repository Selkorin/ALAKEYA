import { AppDataSource } from '../config/database';
import { ContentItem } from '../entities/ContentItem';
import { ContentPlan } from '../entities/ContentPlan';
import { SmmAgentService } from './SmmAgentService';
import { AIProviderFactory } from './ai/AIProviderFactory';

export class ContentGenerationService {
  async generateContentForPlan(
    contentPlanId: string,
    agentId: string,
    platform: 'instagram' | 'telegram' | 'vk' | 'youtube' | 'tiktok'
  ): Promise<ContentItem[]> {
    const contentPlanRepo = AppDataSource.getRepository(ContentPlan);
    const plan = await contentPlanRepo.findOneBy({ id: contentPlanId });

    if (!plan) {
      throw new Error('Content plan not found');
    }

    const smmService = new SmmAgentService();
    await smmService.initialize(agentId, plan.socialAccountId, '');

    // Calculate number of days and posts per day
    const daysInPlan = Math.ceil(
      (plan.periodEnd.getTime() - plan.periodStart.getTime()) / (1000 * 60 * 60 * 24)
    );
    const postsPerDay = platform === 'instagram' ? 2 : 1; // Instagram: 2 per day, others: 1
    const totalPosts = daysInPlan * postsPerDay;

    // Generate content
    return smmService.generateContentItems(contentPlanId, totalPosts, platform);
  }

  async generateSinglePost(
    socialAccountId: string,
    agentId: string,
    platform: 'instagram' | 'telegram' | 'vk' | 'youtube' | 'tiktok',
    topic: string,
    style?: string
  ): Promise<ContentItem> {
    const smmService = new SmmAgentService();
    await smmService.initialize(agentId, socialAccountId, '');

    const aiProvider = AIProviderFactory.getProvider('claude');

    // Generate caption
    const caption = await aiProvider.generateCaption(
      topic,
      style || 'professional',
      ''
    );

    // Generate image prompt
    const imagePrompt = await aiProvider.generateImagePrompt(
      topic,
      style || 'modern'
    );

    // Create content item
    const contentItemRepo = AppDataSource.getRepository(ContentItem);
    const item = contentItemRepo.create({
      contentPlanId: '', // Will be set manually
      platform,
      contentType: this.selectContentType(platform),
      title: topic,
      caption,
      imagePrompt,
      hashtags: this.generateHashtags(topic),
      publishAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // Tomorrow
      status: 'draft',
      approvalStatus: 'pending',
    });

    return contentItemRepo.save(item);
  }

  async regenerateContent(contentItemId: string): Promise<ContentItem> {
    const contentItemRepo = AppDataSource.getRepository(ContentItem);
    const item = await contentItemRepo.findOneBy({ id: contentItemId });

    if (!item) {
      throw new Error('Content item not found');
    }

    const aiProvider = AIProviderFactory.getProvider('claude');

    // Regenerate caption
    const newCaption = await aiProvider.generateCaption(
      item.title,
      'professional',
      ''
    );

    // Regenerate image prompt
    const newImagePrompt = await aiProvider.generateImagePrompt(
      item.title,
      'modern'
    );

    item.caption = newCaption;
    item.imagePrompt = newImagePrompt;
    item.status = 'draft';

    return contentItemRepo.save(item);
  }

  private selectContentType(
    platform: 'instagram' | 'telegram' | 'vk' | 'youtube' | 'tiktok'
  ): 'post' | 'story' | 'reel' | 'short' | 'carousel' {
    const types = {
      instagram: 'post' as const,
      telegram: 'post' as const,
      vk: 'post' as const,
      youtube: 'short' as const,
      tiktok: 'short' as const,
    };
    return types[platform];
  }

  private generateHashtags(topic: string): string[] {
    // Simple hashtag generation from topic
    const words = topic.toLowerCase().split(' ').slice(0, 5);
    return words
      .map(word => word.replace(/[^a-z0-9]/g, ''))
      .filter(word => word.length > 2)
      .map(word => `#${word}`);
  }

  async batchGenerateContent(
    contentPlanId: string,
    agentId: string,
    platforms: Array<'instagram' | 'telegram' | 'vk' | 'youtube' | 'tiktok'>
  ): Promise<Record<string, ContentItem[]>> {
    const results: Record<string, ContentItem[]> = {};

    for (const platform of platforms) {
      try {
        results[platform] = await this.generateContentForPlan(
          contentPlanId,
          agentId,
          platform
        );
      } catch (error: any) {
        console.error(`Failed to generate content for ${platform}:`, error.message);
        results[platform] = [];
      }
    }

    return results;
  }
}
