# UI Template

A production-ready React template with AWS serverless backend, authentication, and one-command deployment.

![Web App Template](images/web-app.png)

## Features

<div class="grid cards" markdown>

-   :material-react:{ .lg .middle } **Modern Frontend**

    ---

    React 19 + TypeScript + Vite + Tailwind CSS with Redux Toolkit state management

-   :material-aws:{ .lg .middle } **AWS Serverless**

    ---

    Lambda, Cognito, S3, CloudFront - fully managed, auto-scaling infrastructure

-   :material-lock:{ .lg .middle } **Authentication**

    ---

    AWS Cognito with Amplify SDK - secure sign up, sign in, and session management

-   :material-rocket-launch:{ .lg .middle } **One-Command Deploy**

    ---

    SST v3 infrastructure as code with `npm run setup` deployment

</div>

## Quick Start

```bash
# Clone and install
git clone <repository-url>
cd ui-template
npm install

# Configure AWS
aws configure  # or: aws sso login --profile your-profile

# Deploy
npm run setup
```

**That's it!** Your application is now live on AWS.

[:octicons-arrow-right-24: Quick Start Guide](quick-start-guide.md)

## Architecture

![AWS Architecture](images/aws-architecture.png)

| Resource | Purpose | Details |
|----------|---------|---------|
| **CloudFront** | Global CDN | HTTPS termination, edge caching, SPA routing |
| **S3** | Static hosting | React app build artifacts |
| **Lambda** | API backend | Function URL (no API Gateway needed) |
| **Cognito** | Authentication | User pool with JWT tokens |
| **CloudWatch** | Monitoring | Logs and metrics |

[:octicons-arrow-right-24: AWS Infrastructure Details](aws-infrastructure.md)

## Documentation

<div class="grid cards" markdown>

-   :material-school:{ .lg .middle } **Tutorial**

    ---

    Complete guide from setup to production deployment

    [:octicons-arrow-right-24: Start Tutorial](tutorial.md)

-   :material-play-circle:{ .lg .middle } **Quick Start**

    ---

    Get running in 10 minutes

    [:octicons-arrow-right-24: Quick Start](quick-start-guide.md)

-   :material-code-braces:{ .lg .middle } **Developer Guide**

    ---

    Architecture, logging, auth, state management

    [:octicons-arrow-right-24: Developer Guide](developer-guide.md)

-   :material-cloud-upload:{ .lg .middle } **Deployment Guide**

    ---

    Detailed AWS deployment instructions

    [:octicons-arrow-right-24: Deployment Guide](deployment-guide.md)

</div>

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

This project is licensed under the MIT License.
