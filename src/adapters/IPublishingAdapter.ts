export interface IPublishingAdapter {
  name: string;
  validateToken(): Promise<boolean>;
  publishPost(content: {
    caption: string;
    imageUrl?: string;
    videoUrl?: string;
    hashtags?: string[];
  }): Promise<{ postId: string; url: string }>;
  publishStory?(content: {
    imageUrl?: string;
    videoUrl?: string;
  }): Promise<{ storyId: string }>;
  getAccountInfo(): Promise<{ id: string; name: string; followers?: number }>;
}
