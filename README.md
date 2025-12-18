# UI Template

A production-ready React template with AWS serverless backend, authentication, and one-command deployment.

![Technology Overview](./docs-content/images/ui-template-tech-overview.png)

The UI template offers a frame for any kind of app development with an AWS backend.

![Web App Template](./docs-content/images/web-app.png)

## Features

- **Frontend**: React 19 + TypeScript + Vite + Tailwind CSS
- **State Management**: Redux Toolkit with typed hooks
- **UI Components**: Headless UI + Lucide icons
- **Authentication**: AWS Cognito with Amplify SDK
- **Backend**: AWS Lambda with API Gateway HTTP API
- **CDN**: CloudFront distribution with S3 static hosting
- **Infrastructure**: SST v3 (Pulumi/Terraform-based)
- **Theming**: Light/Dark/System mode support
- **Logging**: Configurable browser console logging with categories

## Quick Start (3 Steps)

### 1. Install

```bash
git clone <repository-url>
cd ui-template
npm install
```

### 2. Configure AWS

```bash
# For personal AWS accounts
aws configure

# For corporate SSO
aws sso login --profile your-profile
export AWS_PROFILE=your-profile
```

### 3. Deploy

```bash
npm run setup
```

**That's it!** Your application is now live on AWS.

For detailed instructions, see **[Getting Started](./docs-content/getting-started.md)**.

## Architecture Overview

![AWS Architecture](./docs-content/images/aws-architecture.png)

| Resource | Purpose | Details |
|----------|---------|---------|
| **CloudFront** | Global CDN | HTTPS termination, edge caching, SPA routing |
| **S3** | Static hosting | React app build artifacts |
| **API Gateway** | HTTP API | Routes requests to Lambda |
| **Lambda** | API backend | Serverless compute (30s timeout, 256MB) |
| **Cognito** | Authentication | User pool with JWT tokens |
| **CloudWatch** | Monitoring | Logs and metrics |

For detailed architecture documentation including data flow diagrams, see **[Reference](./docs-content/reference.md)**.

## Development

### Local Development with AWS

```bash
npm run dev
```

Starts Vite with SST, connecting to real AWS resources with live reload.

### Local-Only Development

```bash
npm run dev:local    # Frontend only
npm run start        # Frontend + local API server
```

Open [http://localhost:5173](http://localhost:5173) in your browser.

## Deployment

### Local Deployment

| Command | Description |
|---------|-------------|
| `npm run setup` | Interactive setup and deploy |
| `npm run deploy` | Deploy to personal stage |
| `npm run deploy:dev` | Deploy to dev environment |
| `npm run deploy:prod` | Deploy to production |
| `npm run remove` | Remove your deployment |

### CI/CD (GitHub Actions)

| Action | Deploys To | Approval |
|--------|------------|----------|
| `git push origin <any-branch>` | dev | Auto |
| `git push origin main` | int | Auto |
| `git tag v1.0.0 && git push --tags` | prod | Required |

See **[Getting Started](./docs-content/getting-started.md)** for environment protection setup.

## Project Structure

```
ui-template/
├── src/                      # React frontend
│   ├── components/           # React components
│   ├── context/              # React contexts
│   ├── hooks/                # Custom hooks
│   ├── services/             # API client, auth
│   ├── store/                # Redux store
│   └── utils/                # Utilities (Logger)
├── lambda/                   # AWS Lambda functions
│   └── api/                  # API handler
├── scripts/
│   └── setup.sh              # Setup & deploy script
├── sst.config.ts             # SST infrastructure config
└── docs-content/             # Documentation (MkDocs)
```

## Available Scripts

| Script | Description |
|--------|-------------|
| `npm run dev` | Start development with SST |
| `npm run dev:local` | Start Vite only (no AWS) |
| `npm run build` | Build for production |
| `npm run lint` | Run ESLint |
| `npm run typecheck` | TypeScript type checking |
| `npm run deploy` | Deploy to AWS |
| `npm run remove` | Remove deployment |

## Environment Badges

The status bar shows the current environment:

| Environment | Badge | Description |
|-------------|-------|-------------|
| LOCAL | Gray | Local development |
| DEV | Blue | Development stage |
| INT | Amber | Integration/staging |
| PROD | Red | Production |

## Documentation

| Guide | Description |
|-------|-------------|
| **[Getting Started](./docs-content/getting-started.md)** | Setup, deploy, develop, CI/CD pipelines |
| **[Frontend Architecture](./docs-content/frontend-architecture.md)** | MVI pattern, Redux, authentication, logging |
| **[Reference](./docs-content/reference.md)** | SST config, API patterns, environment setup |

**Published docs**: [fwornle.github.io/ui-template](https://fwornle.github.io/ui-template)

## Tech Stack

### Frontend
- [React 19](https://react.dev/) - UI framework
- [TypeScript](https://www.typescriptlang.org/) - Type safety
- [Vite](https://vite.dev/) - Build tool
- [Tailwind CSS](https://tailwindcss.com/) - Styling
- [Redux Toolkit](https://redux-toolkit.js.org/) - State management
- [AWS Amplify](https://docs.amplify.aws/) - Auth SDK

### Infrastructure
- [SST v3](https://sst.dev/) - Infrastructure as code
- [AWS Lambda](https://aws.amazon.com/lambda/) - Serverless compute
- [Amazon Cognito](https://aws.amazon.com/cognito/) - Authentication
- [Amazon S3](https://aws.amazon.com/s3/) - Static hosting
- [Amazon CloudFront](https://aws.amazon.com/cloudfront/) - CDN

## License

This project is licensed under the [MIT License](./LICENSE).
