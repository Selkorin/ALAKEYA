import { useState, useEffect } from 'react';
import { Plus, Filter } from 'lucide-react';
import { content, contentPlans } from '../services/api';

interface ContentItem {
  id: string;
  title: string;
  caption: string;
  platform: string;
  status: string;
  publishAt: string;
}

export default function ContentManagement() {
  const [items, setItems] = useState<ContentItem[]>([]);
  const [plans, setPlans] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedPlan, setSelectedPlan] = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      const [contentRes, plansRes] = await Promise.all([
        content.list(statusFilter || undefined, undefined, selectedPlan || undefined),
        contentPlans.list(),
      ]);

      setItems(contentRes.data.items);
      setPlans(plansRes.data.plans);
    } catch (error) {
      console.error('Error loading data:', error);
    } finally {
      setLoading(false);
    }
  };

  const statusColors: Record<string, string> = {
    draft: 'bg-gray-100 text-gray-800',
    approved: 'bg-green-100 text-green-800',
    scheduled: 'bg-blue-100 text-blue-800',
    published: 'bg-purple-100 text-purple-800',
    failed: 'bg-red-100 text-red-800',
  };

  const platformColors: Record<string, string> = {
    instagram: 'text-pink-600',
    telegram: 'text-blue-600',
    tiktok: 'text-black',
    twitter: 'text-sky-600',
    youtube: 'text-red-600',
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Content Management</h1>
          <p className="text-gray-500 mt-2">Create, edit, and schedule your posts</p>
        </div>
        <button className="btn-primary flex items-center gap-2">
          <Plus size={20} />
          New Post
        </button>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4 flex flex-wrap gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Plan</label>
          <select
            value={selectedPlan}
            onChange={(e) => {
              setSelectedPlan(e.target.value);
            }}
            className="input"
          >
            <option value="">All Plans</option>
            {plans.map((plan) => (
              <option key={plan.id} value={plan.id}>
                {plan.title}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Status</label>
          <select
            value={statusFilter}
            onChange={(e) => {
              setStatusFilter(e.target.value);
            }}
            className="input"
          >
            <option value="">All Statuses</option>
            <option value="draft">Draft</option>
            <option value="approved">Approved</option>
            <option value="scheduled">Scheduled</option>
            <option value="published">Published</option>
            <option value="failed">Failed</option>
          </select>
        </div>
        <div className="flex items-end">
          <button
            onClick={loadData}
            className="btn-secondary flex items-center gap-2"
          >
            <Filter size={18} />
            Apply Filters
          </button>
        </div>
      </div>

      {/* Content Table */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="p-6 text-center text-gray-500">Loading content...</div>
        ) : items.length === 0 ? (
          <div className="p-6 text-center text-gray-500">No content found</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-200 bg-gray-50">
                  <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">
                    Title
                  </th>
                  <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">
                    Platform
                  </th>
                  <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">
                    Publish Date
                  </th>
                  <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody>
                {items.map((item) => (
                  <tr key={item.id} className="border-b border-gray-200 hover:bg-gray-50">
                    <td className="px-6 py-4 text-sm font-medium text-gray-900">
                      {item.title}
                    </td>
                    <td className="px-6 py-4 text-sm">
                      <span className={`font-medium ${platformColors[item.platform] || ''}`}>
                        {item.platform}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-sm">
                      <span
                        className={`inline-block px-3 py-1 rounded-full text-xs font-medium ${
                          statusColors[item.status] || 'bg-gray-100 text-gray-800'
                        }`}
                      >
                        {item.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-600">
                      {new Date(item.publishAt).toLocaleDateString()}
                    </td>
                    <td className="px-6 py-4 text-sm">
                      <button className="text-blue-600 hover:text-blue-700 font-medium">
                        Edit
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
