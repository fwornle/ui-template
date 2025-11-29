import React, { useState, useEffect } from 'react';
import { X } from 'lucide-react';

interface AuthDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (username: string, password: string) => void;
  isLoading?: boolean;
  error?: string | null;
  title?: string;
}

export const AuthDialog: React.FC<AuthDialogProps> = ({
  isOpen,
  onClose,
  onSubmit,
  isLoading = false,
  error = null,
  title = 'Sign In',
}) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  // Handle keyboard shortcuts
  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        onClose();
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(username, password);
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
      <div className="bg-white dark:bg-primary-800 rounded-lg shadow-lg p-5 w-full max-w-md">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-lg font-semibold text-primary-900 dark:text-white">{title}</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 dark:hover:text-white transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-3">
          {error && (
            <div className="bg-red-50 dark:bg-red-900/30 text-red-600 dark:text-red-400 p-2 rounded text-xs">
              {error}
            </div>
          )}

          <div>
            <label htmlFor="username" className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
              Username
            </label>
            <input
              id="username"
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="Enter your username"
              className="w-full px-3 py-1.5 border border-gray-300 dark:border-primary-600 rounded bg-white dark:bg-primary-700 text-primary-900 dark:text-white focus:outline-none focus:ring-1 focus:ring-accent-500 text-sm"
              required
              disabled={isLoading}
            />
          </div>

          <div>
            <label htmlFor="password" className="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">
              Password
            </label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Enter your password"
              className="w-full px-3 py-1.5 border border-gray-300 dark:border-primary-600 rounded bg-white dark:bg-primary-700 text-primary-900 dark:text-white focus:outline-none focus:ring-1 focus:ring-accent-500 text-sm"
              required
              disabled={isLoading}
            />
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="px-3 py-1.5 text-gray-700 dark:text-gray-300 bg-gray-100 dark:bg-primary-700 rounded text-xs hover:bg-gray-200 dark:hover:bg-primary-600 focus:outline-none transition-colors"
              disabled={isLoading}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-3 py-1.5 text-white bg-accent-600 rounded text-xs hover:bg-accent-700 focus:outline-none disabled:opacity-50 transition-colors"
              disabled={isLoading}
            >
              {isLoading ? 'Signing in...' : 'Sign In'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default AuthDialog;
