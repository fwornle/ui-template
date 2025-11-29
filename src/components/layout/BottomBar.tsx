import React from 'react';
import { Clock, CheckCircle, AlertCircle, Loader2 } from 'lucide-react';

export type StatusType = 'idle' | 'loading' | 'success' | 'error';

interface BottomBarProps {
  className?: string;
  status?: StatusType;
  statusMessage?: string;
  version?: string;
  showClock?: boolean;
}

export function BottomBar({
  className = '',
  status = 'idle',
  statusMessage = '',
  version = '1.0.0',
  showClock = true,
}: BottomBarProps) {
  const [currentTime, setCurrentTime] = React.useState(new Date());

  React.useEffect(() => {
    if (!showClock) return;

    const timer = setInterval(() => {
      setCurrentTime(new Date());
    }, 1000);

    return () => clearInterval(timer);
  }, [showClock]);

  const formatTime = (date: Date) => {
    return date.toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit',
      hour12: true,
    });
  };

  const getStatusIcon = () => {
    switch (status) {
      case 'loading':
        return <Loader2 className="w-4 h-4 animate-spin text-accent-400" />;
      case 'success':
        return <CheckCircle className="w-4 h-4 text-green-400" />;
      case 'error':
        return <AlertCircle className="w-4 h-4 text-red-400" />;
      default:
        return <CheckCircle className="w-4 h-4 text-gray-400" />;
    }
  };

  const getStatusColor = () => {
    switch (status) {
      case 'loading':
        return 'text-accent-300';
      case 'success':
        return 'text-green-300';
      case 'error':
        return 'text-red-300';
      default:
        return 'text-gray-400';
    }
  };

  return (
    <footer className={`bg-primary-800 dark:bg-primary-900 text-gray-300 border-t border-primary-700 shadow-md h-10 w-full ${className}`}>
      <div className="mx-auto max-w-7xl px-2 sm:px-6 lg:px-8 h-full flex items-center justify-between gap-2 overflow-hidden">
        {/* Left side - Status indicators */}
        <div className="flex items-center gap-3 flex-shrink-0">
          {/* Status */}
          <div className="flex items-center gap-1.5 px-2 py-1 rounded bg-primary-700/50">
            {getStatusIcon()}
            <span className={`text-xs ${getStatusColor()}`}>
              {statusMessage || (status === 'idle' ? 'Ready' : status.charAt(0).toUpperCase() + status.slice(1))}
            </span>
          </div>
        </div>

        {/* Center - Any additional info can go here */}
        <div className="flex-1" />

        {/* Right side - Clock and version */}
        <div className="flex items-center gap-3 flex-shrink-0">
          {showClock && (
            <div className="flex items-center gap-1.5 px-2 py-1 rounded">
              <Clock className="w-3.5 h-3.5 text-accent-400" />
              <span className="text-xs text-gray-300 whitespace-nowrap">
                {formatTime(currentTime)}
              </span>
            </div>
          )}

          {/* Version */}
          <div className="text-xs text-gray-500 hidden sm:block">
            v{version}
          </div>
        </div>
      </div>
    </footer>
  );
}

export default BottomBar;
