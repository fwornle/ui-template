const STORAGE_KEY = 'app_prefs';

// Export as a type for preferences
export type Preferences = {
  // UI preferences
  theme?: 'light' | 'dark' | 'system';

  // Animation settings (if applicable)
  animationSpeed?: number;

  // User info (if applicable)
  username?: string;

  // Any custom preferences can be added here
  [key: string]: unknown;
}

// Simple obfuscation (not real encryption)
function encode(str: string) {
  return btoa(encodeURIComponent(str));
}

function decode(str: string) {
  try {
    return decodeURIComponent(atob(str));
  } catch {
    return '';
  }
}

export function savePreferences(prefs: Preferences) {
  const data = encode(JSON.stringify(prefs));
  localStorage.setItem(STORAGE_KEY, data);
}

export function loadPreferences(): Preferences {
  const data = localStorage.getItem(STORAGE_KEY);
  if (!data) return {};
  try {
    return JSON.parse(decode(data));
  } catch {
    return {};
  }
}

export function clearPreferences() {
  localStorage.removeItem(STORAGE_KEY);
}

// Helper function to get a specific preference with default value
export function getPreference<T>(key: keyof Preferences, defaultValue: T): T {
  const prefs = loadPreferences();
  return (prefs[key] as T) ?? defaultValue;
}

// Helper function to set a specific preference
export function setPreference<K extends keyof Preferences>(key: K, value: Preferences[K]) {
  const prefs = loadPreferences();
  prefs[key] = value;
  savePreferences(prefs);
}
