import { useState, useEffect } from 'react';
import { BarChart3, Clock, Eye, MessageSquare, TrendingUp } from 'lucide-react';
import { dashboard } from '../services/api';
import StatCard from '../components/dashboard/StatCard';
import RecentActivity from '../components/dashboard/RecentActivity';
import ContentCalendar from '../components/dashboard/ContentCalendar';

interface Stats {
  totalContent: number;
  approvedContent: number;
  publishedContent: number;
  connectedAccounts: number;
  engagement: {
    likes: number;
    comments: number;
    reach: number;
  };
}

export default function Dashboard() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [activity, setActivity] = useState(null);
  const [calendar, setCalendar] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      const [statsRes, activityRes, calendarRes] = await Promise.all([
        dashboard.getStats(),
        dashboard.getActivity(),
        dashboard.getCalendar(),
      ]);

      setStats(statsRes.data.stats);
      setActivity(activityRes.data.activity);
      setCalendar(calendarRes.data.calendar);
    } catch (error) {
      console.error('Error loading dashboard:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="text-center py-12">Loading dashboard...</div>;
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-gray-500 mt-2">Welcome back! Here's your content overview.</p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
        <StatCard
          title="Total Content"
          value={stats?.totalContent || 0}
          icon={<Eye size={24} className="text-blue-600" />}
          trend="+12%"
        />
        <StatCard
          title="Approved"
          value={stats?.approvedContent || 0}
          icon={<TrendingUp size={24} className="text-green-600" />}
          trend="Ready to publish"
        />
        <StatCard
          title="Published"
          value={stats?.publishedContent || 0}
          icon={<MessageSquare size={24} className="text-purple-600" />}
          trend="This week"
        />
        <StatCard
          title="Accounts"
          value={stats?.connectedAccounts || 0}
          icon={<BarChart3 size={24} className="text-orange-600" />}
          trend="Connected"
        />
        <StatCard
          title="Engagement"
          value={stats?.engagement.likes || 0}
          icon={<Clock size={24} className="text-red-600" />}
          trend={`${stats?.engagement.comments || 0} comments`}
        />
      </div>

      {/* Main Content */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          <ContentCalendar calendar={calendar} />
        </div>
        <div className="lg:col-span-1">
          <RecentActivity activity={activity} />
        </div>
      </div>

      {/* Quick Actions */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h2>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <button className="p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors text-center">
            <p className="text-sm font-medium text-gray-700">📝 Create Post</p>
          </button>
          <button className="p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors text-center">
            <p className="text-sm font-medium text-gray-700">📅 View Calendar</p>
          </button>
          <button className="p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors text-center">
            <p className="text-sm font-medium text-gray-700">📊 Analyze</p>
          </button>
          <button className="p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors text-center">
            <p className="text-sm font-medium text-gray-700">⚙️ Settings</p>
          </button>
        </div>
      </div>
    </div>
  );
}
