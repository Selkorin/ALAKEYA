import { useState, useEffect } from 'react';
import { BarChart3, TrendingUp, MessageCircle, Eye } from 'lucide-react';
import { dashboard } from '../services/api';

interface AnalyticsData {
  period: string;
  timeline: Array<{
    date: string;
    posts: number;
    likes: number;
    comments: number;
    reach: number;
  }>;
  byPlatform: Array<{
    platform: string;
    posts: number;
    engagement: number;
  }>;
  summary: {
    totalPosts: number;
    totalLikes: number;
    totalComments: number;
    totalReach: number;
    avgEngagement: number;
  };
}

export default function Analytics() {
  const [analytics, setAnalytics] = useState<AnalyticsData | null>(null);
  const [days, setDays] = useState(7);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadAnalytics();
  }, [days]);

  const loadAnalytics = async () => {
    try {
      setLoading(true);
      const res = await dashboard.getAnalytics(days);
      setAnalytics(res.data);
    } catch (error) {
      console.error('Error loading analytics:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="text-center py-12">Loading analytics...</div>;
  }

  if (!analytics) {
    return <div className="text-center py-12 text-gray-500">No analytics data available</div>;
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Analytics</h1>
          <p className="text-gray-500 mt-2">{analytics.period}</p>
        </div>
        <div className="flex gap-2">
          {[7, 14, 30].map((d) => (
            <button
              key={d}
              onClick={() => setDays(d)}
              className={`px-4 py-2 rounded-lg transition-colors ${
                days === d
                  ? 'bg-blue-600 text-white'
                  : 'bg-white text-gray-700 border border-gray-200 hover:bg-gray-50'
              }`}
            >
              {d}d
            </button>
          ))}
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <p className="text-sm text-gray-600 mb-2">Total Posts</p>
          <p className="text-3xl font-bold text-gray-900">{analytics.summary.totalPosts}</p>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <p className="text-sm text-gray-600 mb-2 flex items-center gap-1">
            <TrendingUp size={16} /> Likes
          </p>
          <p className="text-3xl font-bold text-gray-900">
            {analytics.summary.totalLikes.toLocaleString()}
          </p>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <p className="text-sm text-gray-600 mb-2 flex items-center gap-1">
            <MessageCircle size={16} /> Comments
          </p>
          <p className="text-3xl font-bold text-gray-900">
            {analytics.summary.totalComments.toLocaleString()}
          </p>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <p className="text-sm text-gray-600 mb-2 flex items-center gap-1">
            <Eye size={16} /> Reach
          </p>
          <p className="text-3xl font-bold text-gray-900">
            {(analytics.summary.totalReach / 1000).toFixed(1)}k
          </p>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <p className="text-sm text-gray-600 mb-2">Avg Engagement</p>
          <p className="text-3xl font-bold text-gray-900">{analytics.summary.avgEngagement}</p>
        </div>
      </div>

      {/* Charts Section */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Timeline Chart */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-6">Posts Over Time</h2>
          <div className="space-y-4">
            {analytics.timeline.slice(0, 7).map((day) => (
              <div key={day.date}>
                <div className="flex items-center justify-between mb-1">
                  <p className="text-sm text-gray-600">{day.date}</p>
                  <p className="text-sm font-medium text-gray-900">{day.posts} posts</p>
                </div>
                <div className="w-full bg-gray-200 rounded-full h-2">
                  <div
                    className="bg-blue-600 h-2 rounded-full"
                    style={{ width: `${Math.min(day.posts * 10, 100)}%` }}
                  ></div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Platform Performance */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-6">Performance by Platform</h2>
          <div className="space-y-6">
            {analytics.byPlatform.map((platform) => (
              <div key={platform.platform}>
                <div className="flex items-center justify-between mb-2">
                  <p className="font-medium text-gray-900 capitalize">{platform.platform}</p>
                  <p className="text-sm text-gray-600">{platform.engagement} engagements</p>
                </div>
                <div className="flex items-center gap-4">
                  <div className="flex-1 bg-gray-200 rounded-full h-2">
                    <div
                      className="bg-green-600 h-2 rounded-full"
                      style={{
                        width: `${(platform.engagement / Math.max(...analytics.byPlatform.map((p) => p.engagement))) * 100}%`,
                      }}
                    ></div>
                  </div>
                  <p className="text-sm text-gray-600 min-w-fit">{platform.posts} posts</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
