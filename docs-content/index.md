# UI Template

Production-ready React + AWS serverless template with one-command deployment.

![Web App](images/web-app.png)

## Features

| Feature | Stack |
|---------|-------|
| **Frontend** | React 19, TypeScript, Vite, Tailwind, Redux Toolkit |
| **Backend** | AWS Lambda with Function URL |
| **Auth** | AWS Cognito with Amplify SDK |
| **Infrastructure** | SST v3 (Infrastructure as Code) |
| **CI/CD** | GitHub Actions (dev → int → prod) |

## Quick Start

```bash
git clone <repository-url>
cd ui-template
npm install
aws configure
npm run setup
```

**Done.** Your app is live on AWS.

## Architecture

![AWS Architecture](images/aws-architecture.png)

| Component | Service |
|-----------|---------|
| CDN | CloudFront |
| Static Hosting | S3 |
| API | Lambda Function URL |
| Auth | Cognito User Pool |

## Documentation

| Guide | Description |
|-------|-------------|
| **[Getting Started](getting-started.md)** | Setup, deploy, develop, CI/CD |
| **[Reference](reference.md)** | Architecture, SST config, API patterns |

## Commands

| Command | Purpose |
|---------|---------|
| `npm run dev` | Local dev with AWS |
| `npm run dev:local` | Local dev without AWS |
| `npm run deploy` | Deploy to personal stage |
| `npm run deploy:prod` | Deploy to production |

## License

MIT
