# Developer Guide

This guide provides detailed documentation for developers working on the UI Template application.

![Application Overview](./images/web-app.png)

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Logging System](#logging-system)
- [Authentication](#authentication)
- [State Management](#state-management)
- [Theming](#theming)
- [API Client](#api-client)
- [Component Structure](#component-structure)

## Architecture Overview

The application follows a modern React architecture with:

- **React 19** - UI framework with concurrent features
- **TypeScript** - Type safety throughout the codebase
- **Redux Toolkit** - Centralized state management
- **Vite** - Fast build tooling with HMR
- **Tailwind CSS** - Utility-first styling

### Directory Structure

```
src/
├── components/           # React components
│   ├── auth/             # Authentication UI (LoginModal)
│   ├── layout/           # Layout components (TopBar, BottomBar)
│   ├── settings/         # Settings modal
│   └── ui/               # Reusable UI components
├── context/              # React contexts (ThemeProvider)
├── hooks/                # Custom hooks (useAuth, useAppDispatch)
├── services/             # External service integrations
│   ├── auth/             # Cognito authentication
│   └── apiClient.ts      # HTTP client
├── store/                # Redux store
│   └── slices/           # Redux slices (auth, preferences, logging)
├── utils/                # Utilities
│   └── logging/          # Logging system
├── pages/                # Page components
├── routes/               # React Router configuration
└── config/               # Application configuration
```

## Logging System

The application includes a comprehensive browser-based logging system with colored output, level filtering, and category organization.

![Logging Configuration](./images/logging.png)

### Quick Start

```typescript
import { Logger } from '@/utils/logging';

// Log at different levels
Logger.error(Logger.Categories.AUTH, 'Authentication failed:', error);
Logger.warn(Logger.Categories.API, 'Request retry:', attempt);
Logger.info(Logger.Categories.APP, 'Application started');
Logger.debug(Logger.Categories.STORE, 'State updated:', newState);
Logger.trace(Logger.Categories.UI, 'Component rendered');
```

### Log Levels

| Level | Use Case | Console Method |
|-------|----------|----------------|
| ERROR | Critical failures, exceptions | `console.error` |
| WARN | Potential issues, deprecations | `console.warn` |
| INFO | Important events, state changes | `console.info` |
| DEBUG | Detailed debugging information | `console.debug` |
| TRACE | Very detailed execution flow | `console.log` |

### Categories

Categories help organize logs by functional area:

| Category | Color | Use Case |
|----------|-------|----------|
| APP | Gray | General application-level logs |
| AUTH | Pink | Authentication (Cognito sign in/out) |
| API | Indigo | HTTP requests and responses |
| STORE | Teal | Redux state management |
| UI | Blue | UI components and interactions |
| THEME | Green | Theme switching operations |
| STORAGE | Cyan | localStorage operations |

### Runtime Configuration

Users can configure logging at runtime via the Settings modal:

1. Click the **Settings** icon in the top bar
2. Navigate to the **Logging** section
3. Toggle individual levels or categories
4. Settings persist in localStorage

### Programmatic Control

```typescript
// Enable/disable categories
Logger.enableCategory('API');
Logger.disableCategory('TRACE');

// Get current state
const activeLevels = Logger.getActiveLevels();
const activeCategories = Logger.getActiveCategories();

// Set multiple at once
Logger.setActiveLevels(new Set(['ERROR', 'WARN', 'INFO']));
Logger.setActiveCategories(new Set(['AUTH', 'API']));
```

### Output Format

Log messages appear in the browser console with colored prefixes:

```
[ERROR][AUTH] Authentication failed: Invalid credentials
[DEBUG][API] GET https://api.example.com/user
[TRACE][THEME] System prefers dark: true
```

### Configuration Files

- `src/utils/logging/config/loggingConfig.ts` - Level and category definitions
- `src/utils/logging/config/loggingColors.ts` - Color palette
- `src/utils/logging/Logger.ts` - Main Logger class

## Authentication

Authentication is handled via AWS Cognito with the Amplify SDK.

![Login Modal](./images/auth.png)

### Components

- **cognitoService** (`src/services/auth/cognitoService.ts`) - Low-level Cognito operations
- **authSlice** (`src/store/slices/authSlice.ts`) - Redux state and async thunks
- **useAuth** (`src/hooks/useAuth.ts`) - React hook for components
- **LoginModal** (`src/components/auth/LoginModal.tsx`) - UI component

### Usage

```typescript
import { useAuth } from '@/hooks/useAuth';

function MyComponent() {
  const { user, isAuthenticated, login, signOut, isLoading, error } = useAuth();

  const handleLogin = async () => {
    await login({ username: email, password });
  };

  if (isAuthenticated) {
    return <div>Welcome, {user.name}</div>;
  }

  return <button onClick={handleLogin}>Sign In</button>;
}
```

### Auth Flow

1. User enters credentials in LoginModal
2. `loginUser` async thunk dispatches to cognitoService
3. Cognito validates and returns tokens
4. Tokens stored in Redux state and localStorage
5. TopBar updates to show user menu

### Token Management

- Access tokens auto-refresh before expiration (5-minute buffer)
- Refresh handled transparently by apiClient
- Session persists across page reloads via localStorage

## State Management

Redux Toolkit manages application state with typed hooks.

### Store Structure

```typescript
{
  auth: {
    user: User | null,
    tokens: AuthTokens | null,
    isAuthenticated: boolean,
    isLoading: boolean,
    error: string | null,
  },
  preferences: {
    theme: 'light' | 'dark' | 'system',
    sidebarOpen: boolean,
  },
  logging: {
    activeLevels: string[],
    activeCategories: string[],
  },
  counter: {
    value: number,
  }
}
```

### Typed Hooks

Always use typed hooks instead of plain `useDispatch`/`useSelector`:

```typescript
import { useAppDispatch, useAppSelector } from '@/store';

function MyComponent() {
  const dispatch = useAppDispatch();
  const theme = useAppSelector(state => state.preferences.theme);

  dispatch(setTheme('dark'));
}
```

### Adding New Slices

1. Create slice in `src/store/slices/mySlice.ts`
2. Export reducer and actions
3. Add to `src/store/index.ts` combineReducers
4. Update RootState type automatically inferred

## Theming

The application supports Light, Dark, and System (auto-detect) themes.

![Settings - Theme Selection](./images/settings.png)

### Theme Provider

The `ThemeProvider` component in `src/context/ThemeProvider.tsx`:

- Reads theme preference from Redux store
- Applies CSS classes to `<html>` and `<body>`
- Listens for system preference changes when in System mode

### CSS Variables

Theme colors are defined as CSS variables in `src/index.css`:

```css
:root {
  --background: 0 0% 100%;
  --foreground: 222.2 84% 4.9%;
  --primary: 222.2 47.4% 11.2%;
  /* ... */
}

.dark {
  --background: 222.2 84% 4.9%;
  --foreground: 210 40% 98%;
  /* ... */
}
```

### Using Theme Colors

```tsx
// Tailwind classes automatically use CSS variables
<div className="bg-background text-foreground">
  <button className="bg-primary text-primary-foreground">
    Click me
  </button>
</div>
```

### Changing Theme

```typescript
import { setTheme } from '@/store/slices/preferencesSlice';

dispatch(setTheme('dark'));  // 'light' | 'dark' | 'system'
```

## API Client

The `apiClient` provides a typed HTTP client with automatic token management.

### Basic Usage

```typescript
import { api } from '@/services/apiClient';

// Public endpoints (no auth required)
const health = await api.public.health();
const version = await api.public.version();

// Protected endpoints (auto-attaches token)
const profile = await api.user.getProfile();
await api.user.updateProfile({ firstName: 'John' });

// Generic requests
const data = await api.get<MyType>('/api/custom');
await api.post('/api/data', { key: 'value' });
```

### Error Handling

```typescript
import { ApiError } from '@/services/apiClient';

try {
  await api.get('/api/protected');
} catch (error) {
  if (error instanceof ApiError) {
    console.log(error.status);  // HTTP status code
    console.log(error.message); // Error message
    console.log(error.data);    // Response body
  }
}
```

### Skip Authentication

```typescript
// For endpoints that don't require auth
await apiClient.get('/api/public', { skipAuth: true });
```

## Component Structure

### Layout Components

**TopBar** (`src/components/layout/TopBar.tsx`)
- Application logo and title
- Navigation links
- Theme toggle
- User menu / Login button
- Settings access

**BottomBar** (`src/components/layout/BottomBar.tsx`)
- Status indicator (Ready/Loading/Error)
- Environment badge (LOCAL/DEV/INT/PROD)
- Current time
- Application version

**Layout** (`src/components/Layout.tsx`)
- Wraps TopBar + main content + BottomBar
- Provides version and environment to BottomBar
- Uses React Router's `<Outlet />` for page content

### Adding New Pages

1. Create component in `src/pages/MyPage.tsx`
2. Export from `src/pages/index.ts`
3. Add route in `src/routes/index.tsx`:

```typescript
{
  path: 'my-page',
  element: <MyPage />,
}
```

### Reusable Components

Place reusable components in `src/components/ui/`:

- Use TypeScript interfaces for props
- Support className prop for style customization
- Use Tailwind CSS for styling
- Export from `src/components/ui/index.ts`

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VITE_ENVIRONMENT` | Environment name | `local` |
| `VITE_API_URL` | Backend API URL | `http://localhost:3030` |
| `VITE_COGNITO_USER_POOL_ID` | Cognito User Pool ID | - |
| `VITE_COGNITO_USER_POOL_CLIENT_ID` | Cognito Client ID | - |
| `VITE_COGNITO_REGION` | AWS Region | `eu-central-1` |

## Build-Time Injected Variables

These are injected by Vite at build time (see `vite.config.ts`):

| Variable | Description |
|----------|-------------|
| `__APP_VERSION__` | Version from package.json |
| `__APP_BUILD_TIME__` | ISO timestamp of build |

Access in code:

```typescript
const version = __APP_VERSION__;  // "1.0.0"
const buildTime = __APP_BUILD_TIME__;  // "2024-01-15T10:30:00.000Z"
```

## Development Workflow

### Starting Development

```bash
npm install
npm run dev          # Frontend only
npm run start        # Frontend + local API server
```

### Code Quality

```bash
npm run typecheck    # TypeScript validation
npm run lint         # ESLint
npm run build        # Production build
```

### Deploying

```bash
npm run sam:deploy:dev   # Deploy to dev (auto-bumps version)
npm run sam:deploy:int   # Deploy to int
npm run sam:deploy:prod  # Deploy to prod
```

See the [Deployment Guide](./deployment-guide.md) for complete deployment instructions.
