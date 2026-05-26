import { IAIProvider } from './IAIProvider';
import { ClaudeProvider } from './ClaudeProvider';
import { AIProvider } from '../../types';

export class AIProviderFactory {
  static getProvider(provider: AIProvider): IAIProvider {
    switch (provider) {
      case 'claude':
        return new ClaudeProvider();
      case 'openai':
        // return new OpenAIProvider();
        throw new Error('OpenAI provider not yet implemented');
      case 'gemini':
        // return new GeminiProvider();
        throw new Error('Gemini provider not yet implemented');
      case 'local':
        // return new LocalLLMProvider();
        throw new Error('Local LLM provider not yet implemented');
      default:
        return new ClaudeProvider();
    }
  }
}
