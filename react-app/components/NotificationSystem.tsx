"use client";

import { useState, useEffect, useCallback } from "react";
import { X, AlertTriangle, Ghost, Crown, CheckCircle, Info, Bell } from "lucide-react";

export interface Notification {
  id: string;
  type: "critical" | "warning" | "success" | "info";
  title: string;
  message: string;
  timestamp: Date;
  icon?: React.ReactNode;
}

interface NotificationToastProps {
  notifications: Notification[];
  onDismiss: (id: string) => void;
}

const TYPE_STYLES = {
  critical: "bg-red-50 border-red-200 text-red-800",
  warning: "bg-amber-50 border-amber-200 text-amber-800",
  success: "bg-green-50 border-green-200 text-green-800",
  info: "bg-blue-50 border-blue-200 text-blue-800",
};

const TYPE_ICONS = {
  critical: <AlertTriangle className="h-5 w-5 text-red-500" />,
  warning: <AlertTriangle className="h-5 w-5 text-amber-500" />,
  success: <CheckCircle className="h-5 w-5 text-green-500" />,
  info: <Info className="h-5 w-5 text-blue-500" />,
};

export function NotificationToast({ notifications, onDismiss }: NotificationToastProps) {
  return (
    <div className="fixed bottom-4 right-4 z-50 space-y-2 max-w-sm">
      {notifications.map((notification) => (
        <div
          key={notification.id}
          className={`p-4 rounded-lg border shadow-lg animate-slide-in ${TYPE_STYLES[notification.type]}`}
        >
          <div className="flex items-start gap-3">
            {notification.icon || TYPE_ICONS[notification.type]}
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-sm">{notification.title}</p>
              <p className="text-xs mt-0.5 opacity-80">{notification.message}</p>
            </div>
            <button
              onClick={() => onDismiss(notification.id)}
              className="p-1 hover:bg-black/10 rounded transition"
            >
              <X className="h-4 w-4" />
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}

export function useNotifications() {
  const [notifications, setNotifications] = useState<Notification[]>([]);

  const addNotification = useCallback((notification: Omit<Notification, "id" | "timestamp">) => {
    const newNotification: Notification = {
      ...notification,
      id: Date.now().toString() + Math.random().toString(36).substr(2, 9),
      timestamp: new Date(),
    };
    setNotifications((prev) => [...prev, newNotification]);

    setTimeout(() => {
      setNotifications((prev) => prev.filter((n) => n.id !== newNotification.id));
    }, 8000);
  }, []);

  const dismissNotification = useCallback((id: string) => {
    setNotifications((prev) => prev.filter((n) => n.id !== id));
  }, []);

  return { notifications, addNotification, dismissNotification };
}

export function NotificationDemo({ onNotify }: { onNotify: (n: Omit<Notification, "id" | "timestamp">) => void }) {
  const demoNotifications = [
    {
      type: "critical" as const,
      title: "Ghost Flight Detected",
      message: "PH1847: Captain assigned at ORD but aircraft at ATL",
      icon: <Ghost className="h-5 w-5 text-red-500" />,
    },
    {
      type: "warning" as const,
      title: "New Disruption Alert",
      message: "Thunderstorm approaching ATL hub - 23 flights at risk",
      icon: <AlertTriangle className="h-5 w-5 text-amber-500" />,
    },
    {
      type: "info" as const,
      title: "Elite Passenger Rebooking",
      message: "DIAMOND member J. Smith needs rebooking on PH2341",
      icon: <Crown className="h-5 w-5 text-purple-500" />,
    },
    {
      type: "success" as const,
      title: "Crew Recovery Complete",
      message: "Captain Williams accepted PH1234 assignment",
      icon: <CheckCircle className="h-5 w-5 text-green-500" />,
    },
  ];

  return (
    <div className="bg-white rounded-xl shadow-sm border p-4">
      <div className="flex items-center gap-2 mb-4">
        <Bell className="h-5 w-5 text-phantom-primary" />
        <h3 className="font-semibold text-slate-800">Live Notifications Demo</h3>
      </div>
      <div className="grid grid-cols-2 gap-2">
        {demoNotifications.map((notification, idx) => (
          <button
            key={idx}
            onClick={() => onNotify(notification)}
            className={`p-3 rounded-lg border text-left text-sm transition hover:shadow-md ${TYPE_STYLES[notification.type]}`}
          >
            <div className="flex items-center gap-2">
              {notification.icon}
              <span className="font-medium">{notification.title}</span>
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}
