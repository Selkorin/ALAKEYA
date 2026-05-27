import { Activity } from 'lucide-react';

interface RecentActivityProps {
  activity: any;
}

export default function RecentActivity({ activity }: RecentActivityProps) {
  if (!activity) {
    return (
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <div className="flex items-center gap-2 mb-4">
          <Activity size={20} className="text-purple-600" />
          <h2 className="text-lg font-semibold text-gray-900">Recent Activity</h2>
        </div>
        <p className="text-gray-500">Loading activity...</p>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <div className="flex items-center gap-2 mb-6">
        <Activity size={20} className="text-purple-600" />
        <h2 className="text-lg font-semibold text-gray-900">Recent Activity</h2>
      </div>

      <div className="space-y-4">
        {/* Recent Content */}
        <div>
          <p className="text-xs font-semibold text-gray-600 uppercase mb-3">Content Updates</p>
          <div className="space-y-2">
            {activity?.recentContent?.slice(0, 3).map((item: any) => (
              <div key={item.id} className="text-sm text-gray-700 p-2 hover:bg-gray-50 rounded">
                <p className="font-medium">{item.title}</p>
                <p className="text-xs text-gray-500">{item.platform} • {item.status}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Upcoming Posts */}
        <div className="pt-4 border-t border-gray-200">
          <p className="text-xs font-semibold text-gray-600 uppercase mb-3">Upcoming</p>
          <div className="space-y-2">
            {activity?.upcoming?.slice(0, 3).map((item: any) => (
              <div
                key={item.id}
                className="text-sm text-gray-700 p-2 hover:bg-gray-50 rounded"
              >
                <p className="font-medium">{item.title}</p>
                <p className="text-xs text-gray-500">{item.platform}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
