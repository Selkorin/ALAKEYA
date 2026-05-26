export type AIProvider = 'claude' | 'openai' | 'gemini' | 'local';

export interface IAIMessage {
  role: 'user' | 'assistant';
  content: string;
}

export interface IContentItem {
  id: string;
  title: string;
  caption: string;
  imagePrompt?: string;
  imageUrl?: string;
  hashtags: string[];
  contentType: 'post' | 'story' | 'reel' | 'short' | 'carousel';
  publishAt: Date;
  status: 'draft' | 'needs_review' | 'approved' | 'scheduled' | 'published' | 'failed';
  platform: 'instagram' | 'telegram' | 'vk' | 'youtube' | 'tiktok';
}

export interface IContentPlan {
  id: string;
  title: string;
  items: IContentItem[];
  periodStart: Date;
  periodEnd: Date;
  status: 'draft' | 'active' | 'completed';
}

export interface IBrandKnowledge {
  businessDescription: string;
  targetAudience: string;
  tone: string;
  style: string;
  mainOffers: string[];
  pastPosts: string[];
  references: string[];
}

export interface IWebhookPayload {
  type: 'create_content_plan' | 'generate_content' | 'publish' | 'analyze';
  socialAccountId: string;
  projectId: string;
  userMessage: string;
  files?: string[];
  references?: string[];
}

export interface IPublishingJob {
  id: string;
  contentItemId: string;
  platform: string;
  status: 'pending' | 'publishing' | 'published' | 'failed';
  platformPostId?: string;
  error?: string;
}
