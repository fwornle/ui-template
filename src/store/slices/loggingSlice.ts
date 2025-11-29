import { createSlice } from '@reduxjs/toolkit';
import type { PayloadAction } from '@reduxjs/toolkit';

export type LogLevel = 'error' | 'warn' | 'info' | 'debug' | 'trace';
export type LogCategory = 'default' | 'lifecycle' | 'config' | 'ui' | 'data' | 'api' | 'cache' | 'server' | 'auth' | 'performance' | 'router' | 'store';

interface LoggingState {
  activeLevels: LogLevel[];
  activeCategories: LogCategory[];
  isLoggingEnabled: boolean;
}

const initialState: LoggingState = {
  activeLevels: ['error', 'warn', 'info'],
  activeCategories: ['default', 'lifecycle', 'config', 'ui', 'data', 'api', 'cache', 'server', 'auth', 'performance', 'router', 'store'],
  isLoggingEnabled: true,
};

const loggingSlice = createSlice({
  name: 'logging',
  initialState,
  reducers: {
    setActiveLevels: (state, action: PayloadAction<LogLevel[]>) => {
      state.activeLevels = action.payload;
    },
    setActiveCategories: (state, action: PayloadAction<LogCategory[]>) => {
      state.activeCategories = action.payload;
    },
    toggleLogLevel: (state, action: PayloadAction<LogLevel>) => {
      const level = action.payload;
      if (state.activeLevels.includes(level)) {
        state.activeLevels = state.activeLevels.filter(l => l !== level);
      } else {
        state.activeLevels.push(level);
      }
    },
    toggleLogCategory: (state, action: PayloadAction<LogCategory>) => {
      const category = action.payload;
      if (state.activeCategories.includes(category)) {
        state.activeCategories = state.activeCategories.filter(c => c !== category);
      } else {
        state.activeCategories.push(category);
      }
    },
    setIsLoggingEnabled: (state, action: PayloadAction<boolean>) => {
      state.isLoggingEnabled = action.payload;
    },
    resetLogging: (state) => {
      state.activeLevels = ['error', 'warn', 'info'];
      state.activeCategories = ['default', 'lifecycle', 'config', 'ui', 'data', 'api', 'cache', 'server', 'auth', 'performance', 'router', 'store'];
      state.isLoggingEnabled = true;
    },
  },
});

export const {
  setActiveLevels,
  setActiveCategories,
  toggleLogLevel,
  toggleLogCategory,
  setIsLoggingEnabled,
  resetLogging,
} = loggingSlice.actions;

export default loggingSlice.reducer;
