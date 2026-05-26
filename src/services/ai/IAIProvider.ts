import { IAIMessage } from '../../types';

export interface IAIProvider {
  generateText(prompt: string, context?: IAIMessage[]): Promise<string>;
  generateContentPlan(briefing: string, references: string[]): Promise<any>;
  generateCaption(topic: string, style: string, context: string): Promise<string>;
  generateImagePrompt(topic: string, style: string): Promise<string>;
  analyzeContent(content: string): Promise<any>;
}
