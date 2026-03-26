'use client';

import { useEffect, useState, useCallback } from 'react';
import { Radio, Loader2, Wifi, WifiOff, Clock, ArrowRight } from 'lucide-react';

interface FlightEvent {
  EVENT_ID: string;
  FLIGHT_ID: string;
  EVENT_TYPE: string;
  EVENT_TIMESTAMP: string;
  NEW_STATUS?: string;
  PREVIOUS_STATUS?: string;
  DELAY_MINUTES?: number;
  DELAY_CODE?: string;
  DELAY_REASON?: string;
  DEPARTURE_GATE?: string;
  FLIGHT_NUMBER?: string;
  ORIGIN?: string;
  DESTINATION?: string;
}

interface LiveEventFeedProps {
  maxEvents?: number;
  pollIntervalMs?: number;
  className?: string;
}

const EVENT_TYPE_COLORS: Record<string, { bg: string; text: string }> = {
  STATUS_CHANGE: { bg: 'bg-blue-500/20', text: 'text-blue-400' },
  DELAY_UPDATE: { bg: 'bg-yellow-500/20', text: 'text-yellow-400' },
  GATE_CHANGE: { bg: 'bg-green-500/20', text: 'text-green-400' },
  DEPARTURE: { bg: 'bg-purple-500/20', text: 'text-purple-400' },
  ARRIVAL: { bg: 'bg-teal-500/20', text: 'text-teal-400' },
};

export default function LiveEventFeed({ 
  maxEvents = 15, 
  pollIntervalMs = 3000,
  className = ''
}: LiveEventFeedProps) {
  const [events, setEvents] = useState<FlightEvent[]>([]);
  const [isConnected, setIsConnected] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [lastUpdate, setLastUpdate] = useState<Date | null>(null);
  const [error, setError] = useState<string | null>(null);

  const fetchEvents = useCallback(async () => {
    try {
      const res = await fetch(`/api/events?limit=${maxEvents}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      
      const data = await res.json();
      setEvents(data.events || []);
      setIsConnected(true);
      setLastUpdate(new Date());
      setError(null);
    } catch (err) {
      setIsConnected(false);
      setError(err instanceof Error ? err.message : 'Connection failed');
    } finally {
      setIsLoading(false);
    }
  }, [maxEvents]);

  useEffect(() => {
    fetchEvents();
    const interval = setInterval(fetchEvents, pollIntervalMs);
    return () => clearInterval(interval);
  }, [fetchEvents, pollIntervalMs]);

  const formatTime = (timestamp: string) => {
    const date = new Date(timestamp);
    return date.toLocaleTimeString('en-US', { 
      hour: '2-digit', 
      minute: '2-digit', 
      second: '2-digit',
      hour12: false 
    });
  };

  const getEventDetail = (event: FlightEvent): string => {
    switch (event.EVENT_TYPE) {
      case 'STATUS_CHANGE':
        return `${event.PREVIOUS_STATUS || '?'} → ${event.NEW_STATUS || '?'}`;
      case 'DELAY_UPDATE':
        return `+${event.DELAY_MINUTES}min (${event.DELAY_CODE || 'UNK'})`;
      case 'GATE_CHANGE':
        return `Gate ${event.DEPARTURE_GATE}`;
      default:
        return event.EVENT_TYPE;
    }
  };

  return (
    <div className={`bg-gray-800/50 backdrop-blur rounded-xl border border-gray-700/50 ${className}`}>
      <div className="flex items-center justify-between p-4 border-b border-gray-700/50">
        <div className="flex items-center gap-2">
          <Radio className="w-5 h-5 text-cyan-400" />
          <h3 className="font-semibold text-white">Live Flight Events</h3>
          <span className="px-2 py-0.5 text-xs bg-cyan-500/20 text-cyan-400 rounded-full">
            Snowpipe Streaming
          </span>
        </div>
        
        <div className="flex items-center gap-3">
          {lastUpdate && (
            <span className="text-xs text-gray-500 flex items-center gap-1">
              <Clock className="w-3 h-3" />
              {formatTime(lastUpdate.toISOString())}
            </span>
          )}
          {isConnected ? (
            <span className="flex items-center gap-1 text-xs text-green-400">
              <Wifi className="w-4 h-4" />
              Live
            </span>
          ) : (
            <span className="flex items-center gap-1 text-xs text-red-400">
              <WifiOff className="w-4 h-4" />
              Disconnected
            </span>
          )}
        </div>
      </div>

      <div className="p-4">
        {isLoading ? (
          <div className="flex items-center justify-center py-8">
            <Loader2 className="w-6 h-6 animate-spin text-cyan-400" />
            <span className="ml-2 text-gray-400">Connecting to event stream...</span>
          </div>
        ) : error ? (
          <div className="text-center py-8 text-gray-400">
            <p className="text-red-400">{error}</p>
            <p className="text-sm mt-2">Events API not available. Start the streaming pipeline to see live events.</p>
          </div>
        ) : events.length === 0 ? (
          <div className="text-center py-8 text-gray-400">
            <p>No events yet</p>
            <p className="text-sm mt-2">Start the flight simulator to generate events</p>
          </div>
        ) : (
          <div className="space-y-2 max-h-[400px] overflow-y-auto custom-scrollbar">
            {events.map((event, idx) => {
              const colors = EVENT_TYPE_COLORS[event.EVENT_TYPE] || { bg: 'bg-gray-500/20', text: 'text-gray-400' };
              
              return (
                <div 
                  key={event.EVENT_ID || idx}
                  className={`flex items-center gap-3 p-3 rounded-lg bg-gray-900/50 border border-gray-700/30 
                    ${idx === 0 ? 'animate-pulse-once ring-1 ring-cyan-500/50' : ''}`}
                >
                  <span className={`px-2 py-1 rounded text-xs font-medium ${colors.bg} ${colors.text}`}>
                    {event.EVENT_TYPE.replace('_', ' ')}
                  </span>
                  
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="font-mono text-sm text-white">
                        {event.FLIGHT_NUMBER || event.FLIGHT_ID?.slice(-8)}
                      </span>
                      {event.ORIGIN && event.DESTINATION && (
                        <span className="text-xs text-gray-500 flex items-center gap-1">
                          {event.ORIGIN} <ArrowRight className="w-3 h-3" /> {event.DESTINATION}
                        </span>
                      )}
                    </div>
                    <p className="text-sm text-gray-400 truncate">
                      {getEventDetail(event)}
                    </p>
                  </div>
                  
                  <span className="text-xs text-gray-500 whitespace-nowrap">
                    {formatTime(event.EVENT_TIMESTAMP)}
                  </span>
                </div>
              );
            })}
          </div>
        )}
      </div>

      <style jsx>{`
        .custom-scrollbar::-webkit-scrollbar {
          width: 6px;
        }
        .custom-scrollbar::-webkit-scrollbar-track {
          background: rgba(0, 0, 0, 0.2);
          border-radius: 3px;
        }
        .custom-scrollbar::-webkit-scrollbar-thumb {
          background: rgba(255, 255, 255, 0.1);
          border-radius: 3px;
        }
        .custom-scrollbar::-webkit-scrollbar-thumb:hover {
          background: rgba(255, 255, 255, 0.2);
        }
        @keyframes pulse-once {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.7; }
        }
        .animate-pulse-once {
          animation: pulse-once 0.5s ease-in-out;
        }
      `}</style>
    </div>
  );
}
