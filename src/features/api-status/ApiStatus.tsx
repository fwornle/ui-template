import { useAppDispatch, useAppSelector } from '@/hooks';
import {
  fetchAllStatus,
  clearStatus,
  selectHealth,
  selectVersion,
  selectConfig,
  selectLoading,
  selectError,
} from './apiStatusSlice';
import { RefreshCw, Server, CheckCircle, XCircle, Loader2 } from 'lucide-react';
import { Logger } from '@/utils/logging';

export function ApiStatus() {
  const dispatch = useAppDispatch();
  const health = useAppSelector(selectHealth);
  const version = useAppSelector(selectVersion);
  const config = useAppSelector(selectConfig);
  const loading = useAppSelector(selectLoading);
  const error = useAppSelector(selectError);

  const handleFetch = () => {
    Logger.info(Logger.Categories.UI, 'Fetching API status...');
    dispatch(fetchAllStatus());
  };

  const handleClear = () => {
    Logger.debug(Logger.Categories.UI, 'Clearing API status');
    dispatch(clearStatus());
  };

  const hasData = health || version || config;

  return (
    <div className="flex flex-col gap-4 p-6 rounded-lg border bg-card w-full max-w-2xl">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Server className="w-5 h-5 text-primary" />
          <h2 className="text-xl font-bold">API Status</h2>
        </div>
        <div className="flex gap-2">
          <button
            onClick={handleFetch}
            disabled={loading}
            className="flex items-center gap-2 px-4 py-2 rounded-md bg-primary text-primary-foreground hover:bg-primary/80 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <RefreshCw className="w-4 h-4" />
            )}
            {loading ? 'Fetching...' : 'Fetch Status'}
          </button>
          {hasData && (
            <button
              onClick={handleClear}
              className="px-4 py-2 rounded-md bg-secondary text-secondary-foreground hover:bg-secondary/80"
            >
              Clear
            </button>
          )}
        </div>
      </div>

      {error && (
        <div className="flex items-center gap-2 p-3 rounded-md bg-destructive/10 text-destructive">
          <XCircle className="w-4 h-4" />
          <span>{error}</span>
        </div>
      )}

      {hasData && (
        <div className="grid gap-4 md:grid-cols-3">
          {/* Health Card */}
          <div className="p-4 rounded-lg border bg-background">
            <div className="flex items-center gap-2 mb-3">
              {health?.status === 'healthy' ? (
                <CheckCircle className="w-4 h-4 text-green-500" />
              ) : (
                <XCircle className="w-4 h-4 text-red-500" />
              )}
              <h3 className="font-semibold">Health</h3>
            </div>
            {health ? (
              <div className="space-y-1 text-sm">
                <p>
                  <span className="text-muted-foreground">Status:</span>{' '}
                  <span className={health.status === 'healthy' ? 'text-green-500' : 'text-red-500'}>
                    {health.status}
                  </span>
                </p>
                <p>
                  <span className="text-muted-foreground">Environment:</span>{' '}
                  {health.environment}
                </p>
                <p className="text-xs text-muted-foreground">
                  {new Date(health.timestamp).toLocaleString()}
                </p>
              </div>
            ) : (
              <p className="text-sm text-muted-foreground">Not loaded</p>
            )}
          </div>

          {/* Version Card */}
          <div className="p-4 rounded-lg border bg-background">
            <h3 className="font-semibold mb-3">Version</h3>
            {version ? (
              <div className="space-y-1 text-sm">
                <p>
                  <span className="text-muted-foreground">Version:</span>{' '}
                  <span className="font-mono">{version.version}</span>
                </p>
                <p>
                  <span className="text-muted-foreground">Environment:</span>{' '}
                  {version.environment}
                </p>
                <p className="text-xs text-muted-foreground">
                  Built: {new Date(version.buildDate).toLocaleDateString()}
                </p>
              </div>
            ) : (
              <p className="text-sm text-muted-foreground">Not loaded</p>
            )}
          </div>

          {/* Config Card */}
          <div className="p-4 rounded-lg border bg-background">
            <h3 className="font-semibold mb-3">Features</h3>
            {config ? (
              <div className="space-y-1 text-sm">
                {Object.entries(config.features).map(([key, enabled]) => (
                  <p key={key} className="flex items-center gap-2">
                    {enabled ? (
                      <CheckCircle className="w-3 h-3 text-green-500" />
                    ) : (
                      <XCircle className="w-3 h-3 text-red-500" />
                    )}
                    <span className="capitalize">{key}</span>
                  </p>
                ))}
              </div>
            ) : (
              <p className="text-sm text-muted-foreground">Not loaded</p>
            )}
          </div>
        </div>
      )}

      {!hasData && !loading && !error && (
        <p className="text-center text-muted-foreground py-4">
          Click "Fetch Status" to load data from the backend API
        </p>
      )}
    </div>
  );
}
