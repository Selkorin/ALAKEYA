import axios from 'axios';
import { IPublishingAdapter } from './IPublishingAdapter';

export class InstagramAdapter implements IPublishingAdapter {
  name = 'instagram';
  private accessToken: string;
  private igUserId: string;
  private apiUrl = 'https://graph.instagram.com';

  constructor(accessToken: string, igUserId: string) {
    this.accessToken = accessToken;
    this.igUserId = igUserId;
  }

  async validateToken(): Promise<boolean> {
    try {
      const response = await axios.get(
        `${this.apiUrl}/me?fields=id,username&access_token=${this.accessToken}`
      );
      return !!response.data.id;
    } catch (error) {
      console.error('Instagram token validation failed:', error);
      return false;
    }
  }

  async publishPost(content: {
    caption: string;
    imageUrl?: string;
    videoUrl?: string;
    hashtags?: string[];
  }): Promise<{ postId: string; url: string }> {
    try {
      const caption = this.formatCaption(content.caption, content.hashtags);

      if (content.imageUrl) {
        return await this.publishImage(caption, content.imageUrl);
      } else if (content.videoUrl) {
        return await this.publishVideo(caption, content.videoUrl);
      } else {
        throw new Error('Instagram requires image or video');
      }
    } catch (error: any) {
      throw new Error(`Failed to publish to Instagram: ${error.message}`);
    }
  }

  private async publishImage(
    caption: string,
    imageUrl: string
  ): Promise<{ postId: string; url: string }> {
    // Step 1: Create media container
    const containerResponse = await axios.post(
      `${this.apiUrl}/${this.igUserId}/media`,
      {
        image_url: imageUrl,
        caption: caption,
        access_token: this.accessToken,
      }
    );

    const containerId = containerResponse.data.id;

    // Step 2: Publish container
    const publishResponse = await axios.post(
      `${this.apiUrl}/${this.igUserId}/media_publish`,
      {
        creation_id: containerId,
        access_token: this.accessToken,
      }
    );

    const postId = publishResponse.data.id;

    return {
      postId,
      url: `https://instagram.com/p/${postId}`,
    };
  }

  private async publishVideo(
    caption: string,
    videoUrl: string
  ): Promise<{ postId: string; url: string }> {
    // Step 1: Create video container (Reels)
    const containerResponse = await axios.post(
      `${this.apiUrl}/${this.igUserId}/media`,
      {
        media_type: 'REELS',
        video_url: videoUrl,
        caption: caption,
        access_token: this.accessToken,
      }
    );

    const containerId = containerResponse.data.id;

    // Step 2: Publish container
    const publishResponse = await axios.post(
      `${this.apiUrl}/${this.igUserId}/media_publish`,
      {
        creation_id: containerId,
        access_token: this.accessToken,
      }
    );

    const postId = publishResponse.data.id;

    return {
      postId,
      url: `https://instagram.com/p/${postId}`,
    };
  }

  async getAccountInfo(): Promise<{
    id: string;
    name: string;
    followers?: number;
  }> {
    try {
      const response = await axios.get(
        `${this.apiUrl}/me?fields=id,username,name,followers_count&access_token=${this.accessToken}`
      );

      return {
        id: response.data.id,
        name: response.data.username || response.data.name,
        followers: response.data.followers_count,
      };
    } catch (error) {
      throw new Error('Failed to get Instagram account info');
    }
  }

  private formatCaption(caption: string, hashtags?: string[]): string {
    let text = caption;
    if (hashtags && hashtags.length > 0) {
      text += `\n\n${hashtags.map(h => h.startsWith('#') ? h : `#${h}`).join(' ')}`;
    }
    return text;
  }
}
