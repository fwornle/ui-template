import type { APIGatewayProxyEvent, APIGatewayProxyResult, Context } from 'aws-lambda';

interface RouteHandler {
  (event: APIGatewayProxyEvent, context: Context): Promise<APIGatewayProxyResult>;
}

interface Routes {
  [path: string]: {
    [method: string]: RouteHandler;
  };
}

// Get environment variables
const CORS_ORIGIN = process.env.CORS_ORIGIN || '*';
const ENVIRONMENT = process.env.NODE_ENV || 'dev';
const LOG_LEVEL = process.env.LOG_LEVEL || 'info';

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': CORS_ORIGIN,
  'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
  'Access-Control-Allow-Credentials': 'true',
};

// Helper to create response
function response(statusCode: number, body: object): APIGatewayProxyResult {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders,
    },
    body: JSON.stringify(body),
  };
}

// Helper for logging
function log(level: string, message: string, data?: object): void {
  const levels = ['error', 'warn', 'info', 'debug'];
  const configLevel = levels.indexOf(LOG_LEVEL);
  const messageLevel = levels.indexOf(level);

  if (messageLevel <= configLevel) {
    console.log(JSON.stringify({
      level,
      message,
      timestamp: new Date().toISOString(),
      environment: ENVIRONMENT,
      ...data,
    }));
  }
}

// Route handlers
const routes: Routes = {
  '/api/health': {
    GET: async () => {
      log('info', 'Health check requested');
      return response(200, {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        environment: ENVIRONMENT,
      });
    },
  },

  '/api/version': {
    GET: async () => {
      log('info', 'Version requested');
      return response(200, {
        version: process.env.APP_VERSION || '1.0.0',
        environment: ENVIRONMENT,
        buildDate: process.env.BUILD_DATE || new Date().toISOString(),
      });
    },
  },

  '/api/config': {
    GET: async () => {
      log('info', 'Client config requested');
      return response(200, {
        cognito: {
          userPoolId: process.env.USER_POOL_ID,
          userPoolClientId: process.env.USER_POOL_CLIENT_ID,
          region: process.env.REGION || 'eu-central-1',
        },
        environment: ENVIRONMENT,
        features: {
          authentication: true,
          darkMode: true,
          logging: true,
        },
      });
    },
  },

  '/api/user/profile': {
    GET: async (event) => {
      // This route requires authentication (handled by API Gateway Cognito Authorizer)
      const claims = event.requestContext.authorizer?.claims;

      if (!claims) {
        return response(401, { error: 'Unauthorized' });
      }

      log('info', 'User profile requested', { userId: claims.sub });

      return response(200, {
        userId: claims.sub,
        email: claims.email,
        emailVerified: claims.email_verified === 'true',
        firstName: claims.given_name || '',
        lastName: claims.family_name || '',
      });
    },

    PUT: async (event) => {
      const claims = event.requestContext.authorizer?.claims;

      if (!claims) {
        return response(401, { error: 'Unauthorized' });
      }

      try {
        const body = JSON.parse(event.body || '{}');
        log('info', 'User profile update requested', { userId: claims.sub });

        // In a real application, this would update the user profile in a database
        return response(200, {
          message: 'Profile updated successfully',
          userId: claims.sub,
          ...body,
        });
      } catch (error) {
        log('error', 'Failed to update user profile', { error: String(error) });
        return response(400, { error: 'Invalid request body' });
      }
    },
  },
};

// Main handler
export async function handler(
  event: APIGatewayProxyEvent,
  context: Context
): Promise<APIGatewayProxyResult> {
  log('debug', 'Request received', {
    path: event.path,
    method: event.httpMethod,
    requestId: context.awsRequestId,
  });

  // Handle OPTIONS requests for CORS
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: '',
    };
  }

  // Find matching route
  const path = event.path;
  const method = event.httpMethod;

  // Check for exact match
  if (routes[path] && routes[path][method]) {
    try {
      return await routes[path][method](event, context);
    } catch (error) {
      log('error', 'Route handler error', { error: String(error), path, method });
      return response(500, { error: 'Internal server error' });
    }
  }

  // Check for path parameter routes (e.g., /api/users/:id)
  for (const routePath of Object.keys(routes)) {
    if (routePath.includes('{') && routes[routePath][method]) {
      const pattern = routePath.replace(/\{[^}]+\}/g, '([^/]+)');
      const regex = new RegExp(`^${pattern}$`);
      if (regex.test(path)) {
        try {
          return await routes[routePath][method](event, context);
        } catch (error) {
          log('error', 'Route handler error', { error: String(error), path, method });
          return response(500, { error: 'Internal server error' });
        }
      }
    }
  }

  // Route not found
  log('warn', 'Route not found', { path, method });
  return response(404, { error: 'Not found', path, method });
}
