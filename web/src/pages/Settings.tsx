import { useState, useEffect } from 'react';
import { Settings as SettingsIcon, Key, Link, Save } from 'lucide-react';
import { socialAccounts } from '../services/api';

interface SocialAccount {
  id: string;
  platform: string;
  accountName: string;
  status: string;
}

export default function Settings() {
  const [accounts, setAccounts] = useState<SocialAccount[]>([]);
  const [loading, setLoading] = useState(true);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    loadAccounts();
  }, []);

  const loadAccounts = async () => {
    try {
      setLoading(true);
      const res = await socialAccounts.list();
      setAccounts(res.data.accounts);
    } catch (error) {
      console.error('Error loading accounts:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = () => {
    setSaved(true);
    setTimeout(() => setSaved(false), 3000);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Settings</h1>
        <p className="text-gray-500 mt-2">Manage your accounts and preferences</p>
      </div>

      {/* Social Accounts */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-6 flex items-center gap-2">
          <Link size={20} className="text-blue-600" />
          Connected Social Accounts
        </h2>

        {loading ? (
          <p className="text-gray-500">Loading accounts...</p>
        ) : accounts.length === 0 ? (
          <p className="text-gray-500">No social accounts connected</p>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {accounts.map((account) => (
              <div
                key={account.id}
                className="p-4 border border-gray-200 rounded-lg hover:shadow-md transition-shadow"
              >
                <div className="flex items-center justify-between mb-3">
                  <div>
                    <p className="font-medium text-gray-900 capitalize">{account.platform}</p>
                    <p className="text-sm text-gray-600">{account.accountName}</p>
                  </div>
                  <span className="px-3 py-1 bg-green-100 text-green-800 rounded-full text-xs font-medium">
                    {account.status}
                  </span>
                </div>
                <div className="flex gap-2">
                  <button className="flex-1 px-3 py-2 bg-gray-100 hover:bg-gray-200 rounded-lg text-sm font-medium transition-colors">
                    Edit
                  </button>
                  <button className="flex-1 px-3 py-2 bg-red-100 hover:bg-red-200 text-red-700 rounded-lg text-sm font-medium transition-colors">
                    Disconnect
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}

        <div className="mt-6 pt-6 border-t border-gray-200">
          <button className="btn-primary flex items-center gap-2">
            <Key size={18} />
            Add Account
          </button>
        </div>
      </div>

      {/* Preferences */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-6 flex items-center gap-2">
          <SettingsIcon size={20} className="text-purple-600" />
          Preferences
        </h2>

        <div className="space-y-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Content Language
            </label>
            <select className="input max-w-md">
              <option>English</option>
              <option>Russian</option>
              <option>Spanish</option>
              <option>French</option>
              <option>German</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Timezone
            </label>
            <select className="input max-w-md">
              <option>UTC</option>
              <option>UTC-5 (EST)</option>
              <option>UTC+0 (GMT)</option>
              <option>UTC+1 (CET)</option>
              <option>UTC+3 (MSK)</option>
            </select>
          </div>

          <div>
            <label className="flex items-center gap-3 cursor-pointer">
              <input type="checkbox" defaultChecked className="w-4 h-4" />
              <span className="text-sm text-gray-700">
                Send email notifications for scheduled posts
              </span>
            </label>
          </div>

          <div>
            <label className="flex items-center gap-3 cursor-pointer">
              <input type="checkbox" defaultChecked className="w-4 h-4" />
              <span className="text-sm text-gray-700">
                Notify me when comments exceed threshold
              </span>
            </label>
          </div>

          <div>
            <label className="flex items-center gap-3 cursor-pointer">
              <input type="checkbox" className="w-4 h-4" />
              <span className="text-sm text-gray-700">Allow AI to auto-respond to comments</span>
            </label>
          </div>
        </div>
      </div>

      {/* AI Agent Settings */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-6">AI Agent Configuration</h2>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              AI Provider
            </label>
            <select className="input max-w-md">
              <option>Claude (Recommended)</option>
              <option>OpenAI GPT-4</option>
              <option>Google Gemini</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Content Tone
            </label>
            <input
              type="text"
              placeholder="e.g., engaging, professional, casual"
              className="input max-w-md"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Brand Values
            </label>
            <textarea
              placeholder="Describe your brand values and guidelines..."
              className="input max-w-md h-32"
            />
          </div>
        </div>
      </div>

      {/* Save Button */}
      <div className="flex gap-4">
        <button onClick={handleSave} className="btn-primary flex items-center gap-2">
          <Save size={18} />
          Save Settings
        </button>

        {saved && (
          <div className="flex items-center gap-2 text-green-700 bg-green-50 px-4 py-2 rounded-lg">
            <span>✓</span>
            <span className="text-sm font-medium">Settings saved successfully</span>
          </div>
        )}
      </div>
    </div>
  );
}
