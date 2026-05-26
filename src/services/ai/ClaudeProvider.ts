import { Anthropic } from '@anthropic-ai/sdk';
import { IAIProvider } from './IAIProvider';
import { IAIMessage } from '../../types';

export class ClaudeProvider implements IAIProvider {
  private client: Anthropic;
  private model: string = 'claude-opus-4-1';

  constructor() {
    this.client = new Anthropic({
      apiKey: process.env.ANTHROPIC_API_KEY,
    });
  }

  async generateText(prompt: string, context?: IAIMessage[]): Promise<string> {
    const messages = context?.map(msg => ({
      role: msg.role as 'user' | 'assistant',
      content: msg.content,
    })) || [];

    messages.push({
      role: 'user',
      content: prompt,
    });

    const response = await this.client.messages.create({
      model: this.model,
      max_tokens: 2048,
      messages: messages as any,
    });

    const content = response.content[0];
    if (content.type === 'text') {
      return content.text;
    }

    throw new Error('Unexpected response type from Claude');
  }

  async generateContentPlan(briefing: string, references: string[]): Promise<any> {
    const prompt = `
You are an expert SMM strategist. Create a content plan based on:

Briefing:
${briefing}

References and examples:
${references.join('\n')}

Return a JSON object with:
{
  "themes": ["theme1", "theme2", ...],
  "contentTypes": ["post", "story", "reel", ...],
  "postsPerDay": 2,
  "strategy": "description",
  "recommendations": ["rec1", "rec2", ...]
}
    `;

    const result = await this.generateText(prompt);
    try {
      return JSON.parse(result);
    } catch {
      return { raw: result };
    }
  }

  async generateCaption(topic: string, style: string, context: string): Promise<string> {
    const prompt = `
Create a social media caption for:
Topic: ${topic}
Style: ${style}
Context: ${context}

Make it engaging, clear, and suitable for the platform.
    `;

    return this.generateText(prompt);
  }

  async generateImagePrompt(topic: string, style: string): Promise<string> {
    const prompt = `
Create a detailed image prompt for:
Topic: ${topic}
Style: ${style}

The prompt should be suitable for image generation tools like Midjourney or DALL-E.
    `;

    return this.generateText(prompt);
  }

  async analyzeContent(content: string): Promise<any> {
    const prompt = `
Analyze this content for social media:
${content}

Return a JSON object with:
{
  "tone": "detected tone",
  "keyMessages": ["msg1", "msg2"],
  "targetAudience": "description",
  "improvements": ["improvement1", "improvement2"]
}
    `;

    const result = await this.generateText(prompt);
    try {
      return JSON.parse(result);
    } catch {
      return { raw: result };
    }
  }
}
