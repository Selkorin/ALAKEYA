import { Calendar } from 'lucide-react';

interface ContentCalendarProps {
  calendar: Record<string, any> | null;
}

export default function ContentCalendar({ calendar }: ContentCalendarProps) {
  if (!calendar) {
    return (
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <div className="flex items-center gap-2 mb-4">
          <Calendar size={20} className="text-blue-600" />
          <h2 className="text-lg font-semibold text-gray-900">Content Calendar</h2>
        </div>
        <p className="text-gray-500">Loading calendar...</p>
      </div>
    );
  }

  const calendarData = calendar as Record<string, any>;
  const entries = Object.entries(calendarData).slice(0, 10);

  return (
    <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-2">
          <Calendar size={20} className="text-blue-600" />
          <h2 className="text-lg font-semibold text-gray-900">Content Calendar</h2>
        </div>
        <button className="text-sm text-blue-600 hover:text-blue-700">View Full</button>
      </div>

      <div className="space-y-3">
        {entries.length > 0 ? (
          entries.map(([date, items]: [string, any]) => (
            <div key={date} className="border-l-4 border-blue-600 pl-4 py-2">
              <p className="text-sm font-medium text-gray-900">{date}</p>
              <div className="mt-1 space-y-1">
                {items.map((item: any, idx: number) => (
                  <div
                    key={idx}
                    className="text-xs text-gray-600 bg-gray-50 px-2 py-1 rounded"
                  >
                    <span className="font-medium">{item.title}</span>
                    <span className="mx-1">•</span>
                    <span className="text-gray-500">{item.platform}</span>
                  </div>
                ))}
              </div>
            </div>
          ))
        ) : (
          <p className="text-gray-500 text-sm">No content scheduled</p>
        )}
      </div>
    </div>
  );
}
