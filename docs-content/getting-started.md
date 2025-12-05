# Getting Started

From zero to production in three phases: **Setup** → **Deploy** → **Develop**.

## Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| Node.js | 18+ | `node -v` |
| AWS CLI | 2.x | `aws --version` |
| AWS Account | - | [Create free account](https://aws.amazon.com/free/) |

---

## Phase 1: Setup

```bash
git clone <repository-url>
cd ui-template
npm install
```

**Configure AWS** (choose one):

=== "Personal Account (IAM)"
    ```bash
    aws configure
    # Enter: Access Key ID, Secret Key, region (eu-central-1)
    ```

=== "Corporate SSO"
    ```bash
    aws configure sso           # One-time setup
    aws sso login --profile your-profile
    export AWS_PROFILE=your-profile
    ```

---

## Phase 2: Deploy

```bash
npm run setup
```

This deploys your full stack to AWS:

| Resource | Purpose |
|----------|---------|
| CloudFront | CDN + HTTPS |
| S3 | Static hosting |
| Lambda | API backend |
| Cognito | Authentication |

**Output:**
```
✓ Complete
   webUrl: https://d1234567890.cloudfront.net
   apiUrl: https://xxx.lambda-url.eu-central-1.on.aws
```

---

## Phase 3: Develop

### Local Development (with AWS)

```bash
npm run dev
```

- Vite at `http://localhost:5173` with hot reload
- Lambda changes deploy instantly via SST
- Connected to real AWS resources

### Local-Only (no AWS)

```bash
npm run dev:local    # Frontend
npm run server       # Mock API (separate terminal)
```

---

## CI/CD Pipeline

![CI/CD Flow](./images/cicd-flow.png)

| Trigger | Environment | Purpose |
|---------|-------------|---------|
| Push to any branch | `dev` | Development testing |
| Push to `main` | `int` | Integration/staging |
| Tag `v*` | `prod` | Production release |

![Deploy to Dev](./images/deploy-to-dev.png)
*Committing to any branch triggers automatic deployment to dev.*

### Deploy Commands

| Command | Stage |
|---------|-------|
| `npm run deploy` | Personal (your username) |
| `npm run deploy:dev` | Development |
| `npm run deploy:int` | Integration |
| `npm run deploy:prod` | Production |

### Release to Production

```bash
git checkout main
git tag v1.0.0
git push origin v1.0.0
```

---

## SST Console

Monitor deployments at [console.sst.dev](https://console.sst.dev):

1. Create account with work email
2. Add AWS account (deploy CloudFormation to **us-east-1**)
3. View real-time logs during `npm run dev`

---

## Troubleshooting

**AWS credentials not found:**
```bash
aws sts get-caller-identity  # Verify credentials
aws sso login --profile your-profile  # For SSO
```

**Deployment failed:**
```bash
npx sst unlock --stage dev   # Clear lock
npm run remove && npm run deploy  # Clean retry
```

**SST Console not showing app:**
Ensure CloudFormation stack is in **us-east-1** (required regardless of app region).

---

## Next Steps

- **[Reference Guide](reference.md)** - Architecture, SST config, API patterns
