import { Request, Response } from 'express';
import { CompetitorAnalysisService } from '../services/CompetitorAnalysisService';
import { CompetitorData } from '../services/CompetitorAnalysisService';

export class CompetitorAnalysisController {
  private analysisService = new CompetitorAnalysisService();

  // Analyze a competitor
  async analyzeCompetitor(req: Request, res: Response) {
    try {
      const { projectId, socialAccountId, competitorData } = req.body;

      if (!projectId || !socialAccountId || !competitorData) {
        return res.status(400).json({
          error: 'Missing required fields: projectId, socialAccountId, competitorData',
        });
      }

      if (!competitorData.platform || !competitorData.handle) {
        return res.status(400).json({
          error: 'Competitor data must include platform and handle',
        });
      }

      const analysis = await this.analysisService.analyzeCompetitor(
        projectId,
        socialAccountId,
        competitorData as CompetitorData
      );

      res.json({
        success: true,
        analysisId: analysis.id,
        status: analysis.status,
        analysis,
      });
    } catch (error: any) {
      console.error('Competitor analysis error:', error);
      res.status(500).json({ error: error.message });
    }
  }

  // Get analysis by ID
  async getAnalysis(req: Request, res: Response) {
    try {
      const { analysisId } = req.params;

      const analysis = await this.analysisService.getAnalysis(analysisId);

      if (!analysis) {
        return res.status(404).json({ error: 'Analysis not found' });
      }

      res.json({
        success: true,
        analysis,
      });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }

  // Get all analyses for a project
  async getAnalysesByProject(req: Request, res: Response) {
    try {
      const { projectId } = req.query;

      if (!projectId) {
        return res.status(400).json({ error: 'projectId query parameter required' });
      }

      const analyses = await this.analysisService.getAnalysesByProject(projectId as string);

      res.json({
        success: true,
        count: analyses.length,
        analyses,
      });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }

  // Send recommendations to content agents
  async sendRecommendationsToAgents(req: Request, res: Response) {
    try {
      const { analysisId } = req.params;
      const { agentIds } = req.body;

      if (!analysisId) {
        return res.status(400).json({ error: 'analysisId required' });
      }

      if (!Array.isArray(agentIds) || agentIds.length === 0) {
        return res.status(400).json({ error: 'agentIds must be a non-empty array' });
      }

      const result = await this.analysisService.sendRecommendationsToAgents(
        analysisId,
        agentIds
      );

      res.json({
        success: result.success,
        message: result.message,
      });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }
}
