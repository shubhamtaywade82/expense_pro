// frontend/src/components/notifications/NotificationCard.tsx
import React from 'react';
import type { Notification } from '@/types';
import { formatDistanceToNow } from 'date-fns';

interface NotificationCardProps {
  notification: Notification;
  onMarkAsRead: (id: number) => void;
  onArchive: (id: number) => void;
  onClick: (notification: Notification) => void;
}

export const NotificationCard: React.FC<NotificationCardProps> = ({
  notification,
  onMarkAsRead,
  onArchive,
  onClick,
}) => {
  const getCategoryIcon = (category: string) => {
    switch (category) {
      case 'tax':
        return (
          <svg className="w-5 h-5 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
        );
      case 'cash_flow':
        return (
          <svg className="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        );
      case 'investment':
        return (
          <svg className="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
          </svg>
        );
      case 'document':
        return (
          <svg className="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
        );
      default:
        return (
          <svg className="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        );
    }
  };

  const getPriorityColor = (priority?: number) => {
    if (!priority || priority >= 4) return 'border-l-4 border-gray-300';
    if (priority === 3) return 'border-l-4 border-yellow-400';
    if (priority === 2) return 'border-l-4 border-orange-500';
    return 'border-l-4 border-red-600'; // priority 1
  };

  const handleClick = () => {
    if (!notification.read) {
      onMarkAsRead(notification.id);
    }
    onClick(notification);
  };

  return (
    <div
      className={`p-4 hover:bg-gray-50 cursor-pointer transition-colors ${getPriorityColor(notification.payload.priority)} ${!notification.read ? 'bg-white' : 'bg-gray-50'}`}
      onClick={handleClick}
    >
      <div className="flex items-start gap-3">
        <div className="flex-shrink-0 mt-1">
          {getCategoryIcon(notification.category)}
        </div>
        
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between gap-2">
            <h4 className={`font-medium text-sm ${!notification.read ? 'text-gray-900' : 'text-gray-600'}`}>
              {notification.subject}
            </h4>
            {!notification.read && (
              <span className="flex-shrink-0 w-2 h-2 bg-blue-500 rounded-full mt-1"></span>
            )}
          </div>
          
          <p className="mt-1 text-sm text-gray-600 line-clamp-2">
            {notification.message}
          </p>
          
          <div className="mt-2 flex items-center justify-between">
            <span className="text-xs text-gray-500">
              {formatDistanceToNow(new Date(notification.createdAt), { addSuffix: true })}
            </span>
            
            <div className="flex items-center gap-2">
              {notification.payload.action_label && (
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    onClick(notification);
                  }}
                  className="text-xs font-medium text-blue-600 hover:text-blue-800 px-2 py-1 bg-blue-50 rounded hover:bg-blue-100 transition-colors"
                >
                  {notification.payload.action_label}
                </button>
              )}
              
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onArchive(notification.id);
                }}
                className="text-xs text-gray-500 hover:text-gray-700 px-2 py-1 hover:bg-gray-200 rounded transition-colors"
                title="Archive"
              >
                Archive
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
