import { useState, useEffect } from 'react';
import { Eye, TrendingUp, MessageCircle } from 'lucide-react';
import { competitorAnalysis } from '../services/api';

interface Analysis {
  id: string;
  competitorHandle: string;
  platform: string;
  status: string;
  metrics: {
    totalFollowers: number;
    avgLikes: number;
    avgComments: number;
    engagementRate: number;
  };
  recommendations: Array<{
    title: string;
    description: string;
    priority: string;
  }>;
}

export default function CompetitorAnalysis() {
  const [analyses, setAnalyses] = useState<Analysis[]>([]);
  const [loading, setLoading] = useState(true);
  const [handle, setHandle] = useState('');
  const [platform, setPlatform] = useState('instagram');

  useEffect(() => {
    loadAnalyses();
  }, []);

  const loadAnalyses = async () => {
    try {
      setLoading(true);
      // In a real implementation, we'd fetch from the API
      // For now, showing empty list for demo
    } catch (error) {
      console.error('Error loading analyses:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleAnalyze = async () => {
    if (!handle) return;

    try {
      setLoading(true);
      const res = await competitorAnalysis.analyze({
        projectId: 'demo',
        socialAccountId: 'account-instagram-demo',
        competitorData: {
          platform,
          handle,
          url: `https://${platform}.com/${handle}`,
          posts: [],
        },
      });

      // Reload analyses
      await loadAnalyses();
    } catch (error) {
      console.error('Error analyzing competitor:', error);
    } finally {
      setLoading(false);
    }
  };

  const priorityColors: Record<string, string> = {
    high: 'bg-red-100 text-red-800',
    medium: 'bg-yellow-100 text-yellow-800',
    low: 'bg-green-100 text-green-800',
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Competitor Analysis</h1>
        <p className="text-gray-500 mt-2">
          Analyze competitors and get AI-powered recommendations
        </p>
      </div>

      {/* Analysis Form */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Analyze a Competitor</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Platform</label>
            <select
              value={platform}
              onChange={(e) => setPlatform(e.target.value)}
              className="input"
            >
              <option>instagram</option>
              <option>tiktok</option>
              <option>twitter</option>
              <option>youtube</option>
              <option>telegram</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Handle or Username
            </label>
            <input
              type="text"
              placeholder="@username"
              value={handle}
              onChange={(e) => setHandle(e.target.value)}
              className="input"
            />
          </div>
          <div className="flex items-end">
            <button onClick={handleAnalyze} className="btn-primary w-full">
              Analyze
            </button>
          </div>
        </div>
      </div>

      {/* Analyses List */}
      <div className="space-y-4">
        {loading ? (
          <div className="text-center py-12 text-gray-500">Loading analyses...</div>
        ) : analyses.length === 0 ? (
          <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-12 text-center">
            <Eye size={48} className="mx-auto text-gray-300 mb-4" />
            <p className="text-gray-500">No analyses yet. Start by analyzing a competitor!</p>
          </div>
        ) : (
          analyses.map((analysis) => (
            <div
              key={analysis.id}
              className="bg-white rounded-lg shadow-sm border border-gray-200 p-6"
            >
              <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
                <div>
                  <p className="text-sm text-gray-600 mb-1">Competitor</p>
                  <p className="text-lg font-semibold text-gray-900">
                    {analysis.competitorHandle}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-gray-600 mb-1 flex items-center gap-1">
                    <TrendingUp size={16} /> Followers
                  </p>
                  <p className="text-lg font-semibold text-gray-900">
                    {analysis.metrics.totalFollowers.toLocaleString()}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-gray-600 mb-1">Avg Likes</p>
                  <p className="text-lg font-semibold text-gray-900">
                    {analysis.metrics.avgLikes}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-gray-600 mb-1 flex items-center gap-1">
                    <MessageCircle size={16} /> Engagement
                  </p>
                  <p className="text-lg font-semibold text-gray-900">
                    {analysis.metrics.engagementRate}%
                  </p>
                </div>
              </div>

              <div>
                <p className="text-sm font-semibold text-gray-900 mb-3">
                  AI Recommendations
                </p>
                <div className="space-y-3">
                  {analysis.recommendations?.map((rec, idx) => (
                    <div key={idx} className="p-3 bg-gray-50 rounded-lg">
                      <div className="flex items-start justify-between">
                        <div>
                          <p className="font-medium text-gray-900">{rec.title}</p>
                          <p className="text-sm text-gray-600 mt-1">{rec.description}</p>
                        </div>
                        <span
                          className={`px-3 py-1 rounded-full text-xs font-medium ${
                            priorityColors[rec.priority] || 'bg-gray-100'
                          }`}
                        >
                          {rec.priority}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
