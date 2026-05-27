import axios from 'axios';
import { IPublishingAdapter } from './IPublishingAdapter';

export class TelegramAdapter implements IPublishingAdapter {
  name = 'telegram';
  private botToken: string;
  private chatId: string;
  private apiUrl = 'https://api.telegram.org';

  constructor(botToken: string, chatId: string) {
    this.botToken = botToken;
    this.chatId = chatId;
  }

  async validateToken(): Promise<boolean> {
    try {
      const response = await axios.get(
        `${this.apiUrl}/bot${this.botToken}/getMe`
      );
      return !!response.data.result;
    } catch (error) {
      console.error('Telegram token validation failed:', error);
      return false;
    }
  }

  async publishPost(content: {
    caption: string;
    imageUrl?: string;
    videoUrl?: string;
    hashtags?: string[];
  }): Promise<{ postId: string; url: string }> {
    const text = this.formatCaption(content.caption, content.hashtags);

    try {
      let response;

      if (content.imageUrl) {
        response = await axios.post(
          `${this.apiUrl}/bot${this.botToken}/sendPhoto`,
          {
            chat_id: this.chatId,
            photo: content.imageUrl,
            caption: text,
            parse_mode: 'HTML',
          }
        );
      } else if (content.videoUrl) {
        response = await axios.post(
          `${this.apiUrl}/bot${this.botToken}/sendVideo`,
          {
            chat_id: this.chatId,
            video: content.videoUrl,
            caption: text,
            parse_mode: 'HTML',
          }
        );
      } else {
        response = await axios.post(
          `${this.apiUrl}/bot${this.botToken}/sendMessage`,
          {
            chat_id: this.chatId,
            text: text,
            parse_mode: 'HTML',
          }
        );
      }

      const messageId = response.data.result.message_id;
      return {
        postId: messageId.toString(),
        url: `https://t.me/c/${this.chatId.replace('-100', '')}/${messageId}`,
      };
    } catch (error: any) {
      throw new Error(`Failed to publish to Telegram: ${error.message}`);
    }
  }

  async getAccountInfo(): Promise<{ id: string; name: string }> {
    try {
      const response = await axios.get(
        `${this.apiUrl}/bot${this.botToken}/getMe`
      );
      const bot = response.data.result;
      return {
        id: bot.id.toString(),
        name: bot.username || bot.first_name,
      };
    } catch (error) {
      throw new Error('Failed to get Telegram bot info');
    }
  }

  private formatCaption(caption: string, hashtags?: string[]): string {
    let text = `<b>${caption}</b>`;
    if (hashtags && hashtags.length > 0) {
      text += `\n\n${hashtags.map(h => h.startsWith('#') ? h : `#${h}`).join(' ')}`;
    }
    return text;
  }
}
