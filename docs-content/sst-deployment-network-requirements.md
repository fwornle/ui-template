# SST v3 Deployment: Network Requirements & Deployment Modes

This document details the external network dependencies required during SST v3 deployment and strategies for deploying in different network environments.

## Architecture Overview

![SST Deployment Network Flow](images/sst-deployment-network-flow.png)

## Network Modes

The setup script automatically detects and configures for three network modes:

| Mode | Detection | Network Access | Configuration |
|------|-----------|----------------|---------------|
| **EXTERNAL** | contenthub.bmwgroup.net unreachable | Full internet | Normal deployment |
| **CN_PROXY** | contenthub reachable + proxy env vars | Via corporate proxy | Auto-configures npm proxy |
| **CN_AIRGAP** | contenthub reachable + no npm access | None (AWS only) | Requires deployment cache |

### Detection Flow

The network detection follows this logic:

1. **Check corporate network** - Test if `contenthub.bmwgroup.net` responds (5s timeout)
2. **If in corporate network:**
   - Check if `HTTP_PROXY` or `HTTPS_PROXY` environment variables are set
   - If proxy is set: **CN_PROXY** mode (deploy via proxy)
   - If no proxy: Test if `registry.npmjs.org` is accessible
     - If npm accessible: **CN_PROXY** mode (direct access works)
     - If npm blocked: **CN_AIRGAP** mode (requires deployment cache)
   - SST telemetry is always disabled in corporate network
3. **If outside corporate network:** **EXTERNAL** mode (full internet access)

## External Endpoints Required

### 1. SST Services (Optional - Auto-disabled in CN)

| Endpoint | Purpose | Required? | Can Disable? |
|----------|---------|-----------|--------------|
| `telemetry.ion.sst.dev` | Anonymous usage analytics | No | Yes: `SST_TELEMETRY_DISABLED=1` |
| `console.sst.dev` | Live debugging WebSocket | No | Yes: Don't use `sst dev` |
| `sst.dev/install` | CLI binary download | First install only | Pre-install binary |

### 2. Package Registries (Critical for EXTERNAL/CN_PROXY)

| Endpoint | Purpose | Required? | Alternative |
|----------|---------|-----------|-------------|
| `registry.npmjs.org` | npm packages (@pulumi/*, @smithy/*, etc.) | Yes | Internal npm mirror or cache |

**Packages downloaded during deployment:**
- `@pulumi/pulumi` - Core Pulumi SDK
- `@pulumi/aws` - AWS provider bindings
- `@smithy/*` - AWS SDK components
- `esbuild` - Build tooling
- Various SST internal dependencies

### 3. Pulumi Provider Sources (Critical for EXTERNAL/CN_PROXY)

| Endpoint | Purpose | Required? | Alternative |
|----------|---------|-----------|-------------|
| `api.github.com` | Release metadata lookup | Yes | Override with env var |
| `github.com/pulumi/*` | Provider binary downloads | Yes | Override with env var |
| `get.pulumi.com` | Fallback mirror | Fallback | Override with env var |

**Provider binaries downloaded:**
- `pulumi-resource-aws` (~200MB) - AWS provider
- Other providers as needed (cloudflare, etc.)

### 4. AWS Endpoints (Required in all modes)

| Endpoint | Purpose | Required? |
|----------|---------|-----------|
| AWS regional endpoints | CloudFormation, S3, Lambda, IAM, etc. | Yes |

## Deployment by Network Mode

### Mode 1: EXTERNAL (Outside Corporate Network)

**Detection:** `contenthub.bmwgroup.net` unreachable

**Command:**
```bash
./scripts/setup.sh --stage dev
```

**What happens:**
- Full internet access to npm, GitHub, SST services
- SST telemetry enabled (optional)
- Normal deployment flow

### Mode 2: CN_PROXY (Corporate Network with Proxy)

**Detection:** `contenthub.bmwgroup.net` reachable AND (`HTTP_PROXY` set OR npm registry accessible)

**Command:**
```bash
# Option A: Set proxy environment variables
HTTP_PROXY=http://proxy.company.com:8080 \
HTTPS_PROXY=http://proxy.company.com:8080 \
./scripts/setup.sh --stage dev

# Option B: Export before running
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
./scripts/setup.sh --stage dev
```

**What happens:**
- SST telemetry auto-disabled
- npm configured to use proxy
- NO_PROXY auto-configured for AWS endpoints
- Deployment proceeds via proxy

**Proxy Configuration (automatic):**
```bash
# These are set automatically by setup.sh:
npm config set proxy $HTTP_PROXY
npm config set https-proxy $HTTPS_PROXY
NO_PROXY=.amazonaws.com,.aws.amazon.com,169.254.169.254,localhost,127.0.0.1
```

### Mode 3: CN_AIRGAP (Corporate Network, No External Access)

**Detection:** `contenthub.bmwgroup.net` reachable AND no proxy AND npm registry unreachable

**Prerequisites:** Deployment cache with node_modules

**Setup (run once from EXTERNAL network):**
```bash
# 1. Deploy successfully to populate caches
./scripts/setup.sh --stage dev

# 2. Create deployment cache with node_modules
./scripts/create-deployment-cache.sh --include-node-modules

# 3. Transfer to air-gapped machine (choose one):
# Option A: Commit to repository
git add .deployment-cache
git commit -m 'Add deployment cache for offline use'
git push

# Option B: Create tarball
tar -czf deployment-cache.tar.gz .deployment-cache
# Transfer file to restricted machine
# On restricted machine: tar -xzf deployment-cache.tar.gz
```

**Command (in air-gapped environment):**
```bash
./scripts/setup.sh --stage dev
```

**What happens:**
- Script detects air-gapped mode
- Restores node_modules from cache
- Restores Pulumi plugins from cache
- Skips npm install
- Deploys using cached assets

## Local Cache Locations

SST and Pulumi cache downloaded assets locally:

| Location | Contents |
|----------|----------|
| `~/.pulumi/plugins/` | Pulumi provider binaries |
| `~/.bun/install/cache/` | Bun/npm package cache |
| `~/Library/Application Support/sst/` | SST binaries and plugins (macOS) |

The SST directory contains:
- `bin/pulumi` - Pulumi CLI
- `bin/bun` - Bun package manager
- `plugins/resource-aws-v*` - AWS provider

## Deployment Cache Structure

Created by `./scripts/create-deployment-cache.sh --include-node-modules`:

| Path | Contents |
|------|----------|
| `.deployment-cache/manifest.json` | Cache metadata |
| `.deployment-cache/pulumi-plugins/` | Pulumi provider binaries (~200MB) |
| `.deployment-cache/sst-binaries/` | SST/Pulumi/Bun binaries |
| `.deployment-cache/node_modules/` | npm packages (if --include-node-modules) |

## Environment Variables Reference

| Variable | Purpose | Example |
|----------|---------|---------|
| `SST_TELEMETRY_DISABLED=1` | Disable telemetry calls | Auto-set in CN |
| `PULUMI_SKIP_UPDATE_CHECK=true` | Skip version check | Auto-set with cache |
| `DO_NOT_TRACK=1` | Standard DNT signal | Auto-set in CN |
| `HTTP_PROXY` | HTTP proxy URL | `http://proxy:8080` |
| `HTTPS_PROXY` | HTTPS proxy URL | `http://proxy:8080` |
| `NO_PROXY` | Bypass proxy for these domains | Auto-configured for AWS |

## Quick Reference: Which Mode Am I In?

Run setup.sh and look for the network mode message:

```bash
./scripts/setup.sh --check

# Output examples:
# Network mode: EXTERNAL (full internet access)
# Network mode: CN_PROXY (corporate with proxy)
# Network mode: CN_AIRGAP (no external network)
```

## Troubleshooting

### Error: "Air-gapped mode requires .deployment-cache/"
- **Cause:** No proxy, no npm access, and no cache
- **Solution:** Create cache from unrestricted network:
  ```bash
  ./scripts/create-deployment-cache.sh --include-node-modules
  ```

### Error: "provider aws not found"
- **Cause:** Pulumi can't download AWS provider binary
- **Solution:**
  - CN_PROXY: Check proxy settings
  - CN_AIRGAP: Ensure cache includes Pulumi plugins

### Error: 502 from registry.npmjs.org
- **Cause:** Corporate proxy blocking/failing npm requests
- **Solution:**
  - CN_PROXY: Verify HTTP_PROXY is correct
  - CN_AIRGAP: Use deployment cache with node_modules

### Error: Timeout connecting to telemetry.ion.sst.dev
- **Cause:** SST telemetry endpoint unreachable
- **Solution:** Should auto-disable in CN; if not, use `--no-telemetry`

### Proxy not being used
- **Cause:** Environment variables not exported
- **Solution:** Use `export` or pass inline:
  ```bash
  export HTTP_PROXY=http://proxy:8080
  export HTTPS_PROXY=http://proxy:8080
  ./scripts/setup.sh --stage dev
  ```

## Complete Deployment Scenarios

### Scenario 1: Home Office (Full Internet)
```bash
cd ui-template
./scripts/setup.sh --stage dev
# Deploys normally with full internet access
```

### Scenario 2: Corporate Office (With Proxy)
```bash
cd ui-template
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
./scripts/setup.sh --stage dev
# Deploys via proxy, telemetry auto-disabled
```

### Scenario 3: Corporate Office (Air-Gapped)
```bash
# First time: Create cache at home
./scripts/create-deployment-cache.sh --include-node-modules
git add .deployment-cache && git commit -m "Add cache" && git push

# At office: Pull and deploy
git pull
./scripts/setup.sh --stage dev
# Uses cached assets, no external network needed
```

### Scenario 4: AWS CodeBuild (Cloud-Based)
```bash
# Uses buildspec.yml, has unrestricted internet
# SST_TELEMETRY_DISABLED=1 is set in buildspec.yml
```
