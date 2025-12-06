import { useCallback, useEffect, useState } from 'react';
import { X, Check } from 'lucide-react';
import { useAppSelector, useAppDispatch } from '@/store';
import { updatePreferences } from '@/store/slices/preferencesSlice';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({ isOpen, onClose }) => {
  const dispatch = useAppDispatch();
  const preferences = useAppSelector(state => state.preferences);
  const [success, setSuccess] = useState(false);

  // Derive current values directly from preferences when rendering
  // This ensures we always show the latest values without needing useEffect
  const currentTheme = preferences.theme || 'system';
  const currentAnimationSpeed = preferences.animationSpeed || 1;

  // Local state for edits (starts matching preferences)
  const [localTheme, setLocalTheme] = useState(currentTheme);
  const [localAnimationSpeed, setLocalAnimationSpeed] = useState(currentAnimationSpeed);

  // When modal becomes visible, sync local state to match preferences (handles re-opening)
  useEffect(() => {
    if (isOpen) {
      setLocalTheme(currentTheme);
      setLocalAnimationSpeed(currentAnimationSpeed);
      setSuccess(false);
    }
  }, [isOpen, currentTheme, currentAnimationSpeed]);

  const handleSave = useCallback(() => {
    dispatch(updatePreferences({
      theme: localTheme,
      animationSpeed: localAnimationSpeed,
    }));
    setSuccess(true);
    setTimeout(() => {
      setSuccess(false);
      onClose();
    }, 1000);
  }, [dispatch, localTheme, localAnimationSpeed, onClose]);

  // Handle keyboard shortcuts
  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        onClose();
      } else if (e.key === 'Enter' && !e.shiftKey) {
        const target = e.target as HTMLElement;
        if (target.tagName !== 'TEXTAREA') {
          e.preventDefault();
          handleSave();
        }
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose, handleSave]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
      <div className="bg-white dark:bg-primary-800 rounded-lg shadow-lg w-full max-w-md max-h-[85vh] overflow-y-auto">
        {/* Header */}
        <div className="flex justify-between items-center p-4 border-b border-gray-200 dark:border-primary-700 sticky top-0 bg-white dark:bg-primary-800">
          <h2 className="text-lg font-semibold text-primary-900 dark:text-white">Settings</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 dark:hover:text-white transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="p-4 space-y-4">
          {/* Theme Selection */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Theme
            </label>
            <div className="grid grid-cols-3 gap-2">
              {(['light', 'dark', 'system'] as const).map((themeOption) => (
                <button
                  key={themeOption}
                  onClick={() => setLocalTheme(themeOption)}
                  className={`px-3 py-2 rounded-lg text-sm font-medium transition-all ${
                    localTheme === themeOption
                      ? 'bg-accent-600 text-white'
                      : 'bg-gray-100 dark:bg-primary-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-primary-600'
                  }`}
                >
                  {themeOption.charAt(0).toUpperCase() + themeOption.slice(1)}
                </button>
              ))}
            </div>
            <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
              Choose how the app looks. System will match your device settings.
            </p>
          </div>

          {/* Animation Speed */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Animation Speed
            </label>
            <div className="flex items-center gap-3">
              <input
                type="range"
                min="0.5"
                max="2"
                step="0.1"
                value={localAnimationSpeed}
                onChange={(e) => setLocalAnimationSpeed(parseFloat(e.target.value))}
                className="flex-1 h-2 bg-gray-200 dark:bg-primary-700 rounded-lg appearance-none cursor-pointer accent-accent-600"
              />
              <span className="text-sm text-gray-600 dark:text-gray-400 w-12 text-right">
                {localAnimationSpeed}x
              </span>
            </div>
            <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
              Control the speed of UI animations.
            </p>
          </div>

          {/* Success Message */}
          {success && (
            <div className="flex items-center gap-2 p-2 bg-green-50 dark:bg-green-900/30 text-green-600 dark:text-green-400 rounded-lg">
              <Check className="w-4 h-4" />
              <span className="text-sm">Settings saved successfully!</span>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex justify-end gap-2 p-4 border-t border-gray-200 dark:border-primary-700 sticky bottom-0 bg-white dark:bg-primary-800">
          <button
            onClick={onClose}
            className="px-4 py-2 text-gray-700 dark:text-gray-300 bg-gray-100 dark:bg-primary-700 rounded-lg text-sm font-medium hover:bg-gray-200 dark:hover:bg-primary-600 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            className="px-4 py-2 text-white bg-accent-600 rounded-lg text-sm font-medium hover:bg-accent-700 transition-colors"
          >
            Save Changes
          </button>
        </div>
      </div>
    </div>
  );
};

export default SettingsModal;
