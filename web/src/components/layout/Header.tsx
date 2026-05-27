import { useState, useEffect } from 'react';
import { Bell, User, Search, Menu } from 'lucide-react';
import { health } from '../../services/api';

export default function Header() {
  const [isHealthy, setIsHealthy] = useState(false);

  useEffect(() => {
    health()
      .then(() => setIsHealthy(true))
      .catch(() => setIsHealthy(false));
  }, []);

  return (
    <header className="bg-white border-b border-gray-200 h-16 flex items-center justify-between px-6">
      <div className="flex items-center gap-4 flex-1">
        <button className="p-2 hover:bg-gray-100 rounded-lg lg:hidden">
          <Menu size={20} />
        </button>

        <div className="hidden md:flex items-center bg-gray-100 rounded-lg px-4 py-2 flex-1 max-w-md">
          <Search size={18} className="text-gray-400" />
          <input
            type="text"
            placeholder="Search content, accounts..."
            className="bg-transparent ml-2 outline-none flex-1 text-sm"
          />
        </div>
      </div>

      <div className="flex items-center gap-4">
        {/* Status indicator */}
        <div className="flex items-center gap-2">
          <div
            className={`w-2 h-2 rounded-full ${
              isHealthy ? 'bg-green-500' : 'bg-red-500'
            }`}
          ></div>
          <span className="text-xs text-gray-500">
            {isHealthy ? 'Connected' : 'Offline'}
          </span>
        </div>

        {/* Notifications */}
        <button className="relative p-2 hover:bg-gray-100 rounded-lg">
          <Bell size={20} className="text-gray-600" />
          <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full"></span>
        </button>

        {/* User menu */}
        <button className="flex items-center gap-2 p-2 hover:bg-gray-100 rounded-lg">
          <div className="w-8 h-8 bg-blue-600 rounded-full flex items-center justify-center text-white text-xs font-bold">
            D
          </div>
          <span className="text-sm text-gray-700">Demo</span>
        </button>
      </div>
    </header>
  );
}
