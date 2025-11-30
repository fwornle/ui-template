/// <reference path="./.sst/platform/config.d.ts" />

/**
 * SST v3 Configuration for UI Template
 *
 * This configuration deploys:
 * - Cognito User Pool for authentication
 * - Lambda API with public and protected routes
 * - S3 bucket for static assets
 * - CloudFront CDN distribution
 * - Vite React frontend
 */
export default $config({
  app(input) {
    return {
      name: "ui-template",
      removal: input?.stage === "prod" ? "retain" : "remove",
      protect: input?.stage === "prod",
      home: "aws",
      providers: {
        aws: {
          region: "eu-central-1",
        },
      },
    };
  },
  async run() {
    // =========================================================
    // Cognito User Pool for Authentication
    // =========================================================
    const userPool = new sst.aws.CognitoUserPool("Auth", {
      usernames: ["email"],
      transform: {
        userPool: {
          passwordPolicy: {
            minimumLength: 8,
            requireLowercase: true,
            requireUppercase: true,
            requireNumbers: true,
            requireSymbols: false,
          },
          autoVerifiedAttributes: ["email"],
          schemas: [
            { name: "email", attributeDataType: "String", required: true },
            { name: "given_name", attributeDataType: "String", required: false },
            { name: "family_name", attributeDataType: "String", required: false },
          ],
        },
      },
    });

    const userPoolClient = userPool.addClient("WebClient", {
      transform: {
        client: {
          explicitAuthFlows: [
            "ALLOW_USER_SRP_AUTH",
            "ALLOW_REFRESH_TOKEN_AUTH",
            "ALLOW_USER_PASSWORD_AUTH",
          ],
          accessTokenValidity: 1,
          idTokenValidity: 1,
          refreshTokenValidity: 30,
          tokenValidityUnits: {
            accessToken: "hours",
            idToken: "hours",
            refreshToken: "days",
          },
          preventUserExistenceErrors: "ENABLED",
        },
      },
    });

    // =========================================================
    // Lambda API Function
    // =========================================================
    const api = new sst.aws.Function("Api", {
      handler: "lambda/api/index.handler",
      timeout: "30 seconds",
      memory: "256 MB",
      environment: {
        NODE_ENV: $app.stage,
        LOG_LEVEL: $app.stage === "prod" ? "warn" : "debug",
        USER_POOL_ID: userPool.id,
        USER_POOL_CLIENT_ID: userPoolClient.id,
        CORS_ORIGIN: "*",
        REGION: "eu-central-1",
      },
      url: {
        cors: {
          allowOrigins: ["*"],
          allowMethods: ["*"],
          allowHeaders: ["*"],
          allowCredentials: false,
        },
      },
    });

    // =========================================================
    // Static Website (Vite React)
    // =========================================================
    const web = new sst.aws.StaticSite("Web", {
      build: {
        command: "npm run build",
        output: "dist",
      },
      environment: {
        VITE_API_URL: api.url,
        VITE_COGNITO_USER_POOL_ID: userPool.id,
        VITE_COGNITO_USER_POOL_CLIENT_ID: userPoolClient.id,
        VITE_COGNITO_REGION: "eu-central-1",
        VITE_ENVIRONMENT: $app.stage,
      },
    });

    // =========================================================
    // Outputs
    // =========================================================
    return {
      apiUrl: api.url,
      webUrl: web.url,
      userPoolId: userPool.id,
      userPoolClientId: userPoolClient.id,
      stage: $app.stage,
    };
  },
});
