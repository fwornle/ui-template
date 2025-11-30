import { store } from '@/store';
import { refreshToken, logoutLocal } from '@/store/slices/authSlice';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3030';

interface RequestOptions extends RequestInit {
  skipAuth?: boolean;
}

interface ApiResponse<T = unknown> {
  data: T;
  status: number;
  ok: boolean;
}

class ApiClient {
  private baseUrl: string;
  private refreshPromise: Promise<void> | null = null;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl.replace(/\/$/, ''); // Remove trailing slash
  }

  private getAuthHeaders(): Record<string, string> {
    const state = store.getState();
    const tokens = state.auth.tokens;

    if (tokens?.accessToken) {
      return {
        Authorization: `Bearer ${tokens.accessToken}`,
      };
    }

    return {};
  }

  private isTokenExpired(): boolean {
    const state = store.getState();
    const tokens = state.auth.tokens;

    if (!tokens?.expiresAt) {
      return true;
    }

    // Consider token expired if less than 5 minutes remaining
    const bufferMs = 5 * 60 * 1000;
    return Date.now() > tokens.expiresAt - bufferMs;
  }

  private async ensureValidToken(): Promise<void> {
    const state = store.getState();

    if (!state.auth.isAuthenticated) {
      return;
    }

    if (!this.isTokenExpired()) {
      return;
    }

    // If already refreshing, wait for that to complete
    if (this.refreshPromise) {
      await this.refreshPromise;
      return;
    }

    // Refresh token
    this.refreshPromise = store
      .dispatch(refreshToken())
      .unwrap()
      .then(() => {
        this.refreshPromise = null;
      })
      .catch(() => {
        this.refreshPromise = null;
        // Token refresh failed, log out
        store.dispatch(logoutLocal());
        throw new Error('Session expired. Please sign in again.');
      });

    await this.refreshPromise;
  }

  async request<T = unknown>(endpoint: string, options: RequestOptions = {}): Promise<ApiResponse<T>> {
    const { skipAuth = false, headers = {}, ...fetchOptions } = options;

    // Ensure we have a valid token if authenticated
    if (!skipAuth) {
      await this.ensureValidToken();
    }

    const url = `${this.baseUrl}${endpoint.startsWith('/') ? endpoint : `/${endpoint}`}`;

    const requestHeaders: Record<string, string> = {
      'Content-Type': 'application/json',
      ...(!skipAuth ? this.getAuthHeaders() : {}),
      ...(headers as Record<string, string>),
    };

    try {
      const response = await fetch(url, {
        ...fetchOptions,
        headers: requestHeaders,
      });

      let data: T;
      const contentType = response.headers.get('content-type');

      if (contentType?.includes('application/json')) {
        data = await response.json();
      } else {
        data = (await response.text()) as unknown as T;
      }

      if (!response.ok) {
        throw new ApiError(
          (data as { error?: string })?.error || `Request failed with status ${response.status}`,
          response.status,
          data
        );
      }

      return {
        data,
        status: response.status,
        ok: true,
      };
    } catch (error) {
      if (error instanceof ApiError) {
        throw error;
      }
      throw new ApiError(
        error instanceof Error ? error.message : 'Network error',
        0,
        null
      );
    }
  }

  async get<T = unknown>(endpoint: string, options: RequestOptions = {}): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, { ...options, method: 'GET' });
  }

  async post<T = unknown>(endpoint: string, body?: unknown, options: RequestOptions = {}): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, {
      ...options,
      method: 'POST',
      body: body ? JSON.stringify(body) : undefined,
    });
  }

  async put<T = unknown>(endpoint: string, body?: unknown, options: RequestOptions = {}): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, {
      ...options,
      method: 'PUT',
      body: body ? JSON.stringify(body) : undefined,
    });
  }

  async patch<T = unknown>(endpoint: string, body?: unknown, options: RequestOptions = {}): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, {
      ...options,
      method: 'PATCH',
      body: body ? JSON.stringify(body) : undefined,
    });
  }

  async delete<T = unknown>(endpoint: string, options: RequestOptions = {}): Promise<ApiResponse<T>> {
    return this.request<T>(endpoint, { ...options, method: 'DELETE' });
  }
}

export class ApiError extends Error {
  status: number;
  data: unknown;

  constructor(message: string, status: number, data: unknown) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.data = data;
  }
}

// Export singleton instance
export const apiClient = new ApiClient(API_BASE_URL);

// Export convenience methods
export const api = {
  get: apiClient.get.bind(apiClient),
  post: apiClient.post.bind(apiClient),
  put: apiClient.put.bind(apiClient),
  patch: apiClient.patch.bind(apiClient),
  delete: apiClient.delete.bind(apiClient),

  // Public endpoints (no auth required)
  public: {
    health: () => apiClient.get('/api/health', { skipAuth: true }),
    version: () => apiClient.get('/api/version', { skipAuth: true }),
    config: () => apiClient.get('/api/config', { skipAuth: true }),
  },

  // Protected endpoints
  user: {
    getProfile: () => apiClient.get('/api/user/profile'),
    updateProfile: (data: { firstName?: string; lastName?: string }) =>
      apiClient.put('/api/user/profile', data),
  },
};

export default apiClient;
