import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import { api } from '@/services/apiClient';
import type { RootState } from '@/store';
import { Logger } from '@/utils/logging';

// Types
interface HealthResponse {
  status: string;
  timestamp: string;
  environment: string;
}

interface VersionResponse {
  version: string;
  environment: string;
  buildDate: string;
}

interface ConfigResponse {
  cognito: {
    userPoolId: string;
    userPoolClientId: string;
    region: string;
  };
  environment: string;
  features: {
    authentication: boolean;
    darkMode: boolean;
    logging: boolean;
  };
}

interface ApiStatusState {
  health: HealthResponse | null;
  version: VersionResponse | null;
  config: ConfigResponse | null;
  loading: boolean;
  error: string | null;
  lastFetched: number | null;
}

// Initial state
const initialState: ApiStatusState = {
  health: null,
  version: null,
  config: null,
  loading: false,
  error: null,
  lastFetched: null,
};

// Async thunks
export const fetchHealth = createAsyncThunk(
  'apiStatus/fetchHealth',
  async (_, { rejectWithValue }) => {
    try {
      Logger.debug(Logger.Categories.API, 'Fetching /api/health');
      const response = await api.public.health();
      Logger.info(Logger.Categories.API, 'Health response:', response.data);
      return response.data as HealthResponse;
    } catch (error) {
      Logger.error(Logger.Categories.API, 'Health fetch failed:', error);
      return rejectWithValue(error instanceof Error ? error.message : 'Failed to fetch health');
    }
  }
);

export const fetchVersion = createAsyncThunk(
  'apiStatus/fetchVersion',
  async (_, { rejectWithValue }) => {
    try {
      Logger.debug(Logger.Categories.API, 'Fetching /api/version');
      const response = await api.public.version();
      Logger.info(Logger.Categories.API, 'Version response:', response.data);
      return response.data as VersionResponse;
    } catch (error) {
      Logger.error(Logger.Categories.API, 'Version fetch failed:', error);
      return rejectWithValue(error instanceof Error ? error.message : 'Failed to fetch version');
    }
  }
);

export const fetchConfig = createAsyncThunk(
  'apiStatus/fetchConfig',
  async (_, { rejectWithValue }) => {
    try {
      Logger.debug(Logger.Categories.API, 'Fetching /api/config');
      const response = await api.public.config();
      Logger.info(Logger.Categories.API, 'Config response:', response.data);
      return response.data as ConfigResponse;
    } catch (error) {
      Logger.error(Logger.Categories.API, 'Config fetch failed:', error);
      return rejectWithValue(error instanceof Error ? error.message : 'Failed to fetch config');
    }
  }
);

export const fetchAllStatus = createAsyncThunk(
  'apiStatus/fetchAll',
  async (_, { dispatch }) => {
    Logger.info(Logger.Categories.STORE, 'Dispatching fetchAllStatus');
    await Promise.all([
      dispatch(fetchHealth()),
      dispatch(fetchVersion()),
      dispatch(fetchConfig()),
    ]);
    Logger.info(Logger.Categories.STORE, 'All API status fetched');
  }
);

// Slice
const apiStatusSlice = createSlice({
  name: 'apiStatus',
  initialState,
  reducers: {
    clearStatus: (state) => {
      state.health = null;
      state.version = null;
      state.config = null;
      state.error = null;
      state.lastFetched = null;
    },
  },
  extraReducers: (builder) => {
    // Health
    builder
      .addCase(fetchHealth.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(fetchHealth.fulfilled, (state, action) => {
        state.health = action.payload;
        state.loading = false;
        state.lastFetched = Date.now();
      })
      .addCase(fetchHealth.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload as string;
      });

    // Version
    builder
      .addCase(fetchVersion.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(fetchVersion.fulfilled, (state, action) => {
        state.version = action.payload;
        state.loading = false;
        state.lastFetched = Date.now();
      })
      .addCase(fetchVersion.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload as string;
      });

    // Config
    builder
      .addCase(fetchConfig.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(fetchConfig.fulfilled, (state, action) => {
        state.config = action.payload;
        state.loading = false;
        state.lastFetched = Date.now();
      })
      .addCase(fetchConfig.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload as string;
      });

    // Fetch All
    builder
      .addCase(fetchAllStatus.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(fetchAllStatus.fulfilled, (state) => {
        state.loading = false;
      })
      .addCase(fetchAllStatus.rejected, (state, action) => {
        state.loading = false;
        state.error = action.error.message || 'Failed to fetch status';
      });
  },
});

// Actions
export const { clearStatus } = apiStatusSlice.actions;

// Selectors
export const selectApiStatus = (state: RootState) => state.apiStatus;
export const selectHealth = (state: RootState) => state.apiStatus.health;
export const selectVersion = (state: RootState) => state.apiStatus.version;
export const selectConfig = (state: RootState) => state.apiStatus.config;
export const selectLoading = (state: RootState) => state.apiStatus.loading;
export const selectError = (state: RootState) => state.apiStatus.error;

export default apiStatusSlice.reducer;
