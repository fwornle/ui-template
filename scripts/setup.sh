#!/bin/bash

#######################################################################
# UI Template - Setup & Deployment Script
#
# This script handles AWS authentication and SST deployment for both:
# - Personal AWS accounts (IAM user credentials)
# - Corporate SSO environments (AWS IAM Identity Center)
#
# Usage:
#   ./scripts/setup.sh              # Interactive setup and deploy
#   ./scripts/setup.sh --stage dev  # Deploy to specific stage
#   ./scripts/setup.sh --check      # Check AWS credentials only
#   ./scripts/setup.sh --unlock     # Unlock SST state (with telemetry disabled)
#   ./scripts/setup.sh --non-interactive  # Run without prompts (CI/CD mode)
#   ./scripts/setup.sh --help       # Show help
#
# Environment Variables:
#   SETUP_LOG_FILE    - Path to log file (default: logs/setup-$(date).log)
#   SETUP_TIMEOUT     - Default timeout for operations in seconds (default: 300)
#   AWS_PROFILE       - AWS profile to use
#   STAGE             - Deployment stage
#######################################################################

set -e
set -o pipefail  # Make pipelines return exit code of first failing command

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Default values
STAGE="${STAGE:-}"
CHECK_ONLY=false
UNLOCK_MODE=false
SKIP_INSTALL=false
PROFILE="${AWS_PROFILE:-}"
NON_INTERACTIVE=false
VERBOSE=false
IN_CORPORATE_NETWORK=false
FORCE_NO_TELEMETRY=false
USING_DEPLOYMENT_CACHE=false

# Network mode: EXTERNAL, CN_PROXY, CN_AIRGAP
NETWORK_MODE="EXTERNAL"

# Logging configuration
SCRIPT_START_TIME=$(date +%s)
LOG_DIR="logs"
LOG_FILE="${SETUP_LOG_FILE:-$LOG_DIR/setup-$(date +%Y%m%d-%H%M%S).log}"
DEFAULT_TIMEOUT="${SETUP_TIMEOUT:-300}"

#######################################################################
# Logging Functions
#######################################################################

ensure_log_dir() {
    mkdir -p "$LOG_DIR"
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local elapsed=$(($(date +%s) - SCRIPT_START_TIME))
    local log_line="[$timestamp] [+${elapsed}s] [$level] $message"

    # Always write to log file
    echo "$log_line" >> "$LOG_FILE"

    # Also print to stdout if verbose or if it's an error/warning
    if [ "$VERBOSE" = true ] || [ "$level" = "ERROR" ] || [ "$level" = "WARN" ]; then
        echo "$log_line" >&2
    fi
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_debug() { [ "$VERBOSE" = true ] && log "DEBUG" "$@" || true; }

log_step() {
    local step="$1"
    log_info "=== STEP: $step ==="
    print_step "$step"
}

log_command() {
    local cmd="$1"
    log_debug "Executing: $cmd"
}

# Detect if running in non-interactive environment
detect_interactive() {
    if [ -t 0 ]; then
        # stdin is a terminal
        NON_INTERACTIVE=false
        log_info "Running in interactive mode (TTY detected)"
    else
        # stdin is not a terminal (piped, redirected, or in container)
        NON_INTERACTIVE=true
        log_info "Running in non-interactive mode (no TTY)"
    fi
}

# Configure proxy for npm and other tools
configure_proxy() {
    log_info "Configuring proxy settings..."

    # Ensure both upper and lowercase are set (different tools check different vars)
    if [ -n "${HTTP_PROXY:-}" ]; then
        export http_proxy="$HTTP_PROXY"
        log_info "HTTP_PROXY: $HTTP_PROXY"
    fi
    if [ -n "${HTTPS_PROXY:-}" ]; then
        export https_proxy="$HTTPS_PROXY"
        log_info "HTTPS_PROXY: $HTTPS_PROXY"
    fi

    # Configure NO_PROXY for AWS endpoints (avoid proxying to AWS)
    local aws_no_proxy=".amazonaws.com,.aws.amazon.com,169.254.169.254,localhost,127.0.0.1"
    if [ -n "${NO_PROXY:-}" ]; then
        export NO_PROXY="${NO_PROXY},${aws_no_proxy}"
    else
        export NO_PROXY="$aws_no_proxy"
    fi
    export no_proxy="$NO_PROXY"
    log_info "NO_PROXY: $NO_PROXY"

    # Configure npm to use proxy
    if [ -n "${HTTP_PROXY:-}" ]; then
        npm config set proxy "$HTTP_PROXY" 2>/dev/null || true
        log_info "npm proxy configured"
    fi
    if [ -n "${HTTPS_PROXY:-}" ]; then
        npm config set https-proxy "$HTTPS_PROXY" 2>/dev/null || true
        log_info "npm https-proxy configured"
    fi

    print_success "Proxy configured"
}

# Require deployment cache for air-gapped mode
require_deployment_cache() {
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    local CACHE_DIR="$PROJECT_ROOT/.deployment-cache"

    if [ ! -d "$CACHE_DIR" ]; then
        echo ""
        print_error "Air-gapped mode requires .deployment-cache/"
        print_info "No network access detected and no deployment cache found."
        echo ""
        print_info "To create a deployment cache (run from unrestricted network):"
        echo "  ./scripts/create-deployment-cache.sh --include-node-modules"
        echo ""
        print_info "Then transfer the cache to this machine and try again."
        log_error "Air-gapped mode requires deployment cache which is missing"
        exit 1
    fi

    # Check for node_modules in cache
    if [ ! -d "$CACHE_DIR/node_modules" ] && [ ! -d "$PROJECT_ROOT/node_modules" ]; then
        echo ""
        print_error "Air-gapped mode requires node_modules in cache"
        print_info "Cache found but missing node_modules."
        echo ""
        print_info "Recreate cache with:"
        echo "  ./scripts/create-deployment-cache.sh --include-node-modules"
        echo ""
        log_error "Deployment cache missing node_modules"
        exit 1
    fi

    # Restore node_modules if not present locally
    if [ ! -d "$PROJECT_ROOT/node_modules" ] && [ -d "$CACHE_DIR/node_modules" ]; then
        log_info "Restoring node_modules from cache..."
        print_info "Restoring node_modules from cache (this may take a moment)..."
        cp -r "$CACHE_DIR/node_modules" "$PROJECT_ROOT/"
        print_success "Restored node_modules from cache"
    fi

    SKIP_INSTALL=true  # Don't try npm install in air-gapped mode
    USING_DEPLOYMENT_CACHE=true
    log_info "Air-gapped mode: using deployment cache, skipping npm install"
}

# Detect network environment and configure appropriately
# Determines: EXTERNAL (full internet), CN_PROXY (corporate with proxy), CN_AIRGAP (no network)
detect_network_environment() {
    log_step "Detecting network environment"

    # Check if telemetry was explicitly disabled via --no-telemetry flag
    if [ "$FORCE_NO_TELEMETRY" = true ]; then
        export SST_TELEMETRY_DISABLED=1
        export DO_NOT_TRACK=1
        log_info "SST telemetry disabled via --no-telemetry flag"
        print_info "SST telemetry disabled (--no-telemetry flag)"
    fi

    # Allow explicit override via environment variable
    if [ "${FORCE_EXTERNAL_NETWORK:-}" = "1" ] || [ "${FORCE_EXTERNAL_NETWORK:-}" = "true" ]; then
        IN_CORPORATE_NETWORK=false
        NETWORK_MODE="EXTERNAL"
        log_info "External network forced via FORCE_EXTERNAL_NETWORK env var"
        print_success "Network mode: EXTERNAL (forced via env var)"
        return 0
    fi

    # Test CN-only endpoint with 5 second timeout
    # This URL only responds with 200 inside the BMW corporate network
    # From outside, it returns 307 redirect to login page
    local CN_TEST_URL="https://contenthub.bmwgroup.net/web/start/"
    local CN_TIMEOUT=5

    # Check HTTP status code - only 200 indicates actual CN access
    # 307/302 redirects mean public access (outside CN)
    local http_code
    http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" --max-time "$CN_TIMEOUT" "$CN_TEST_URL" 2>/dev/null || echo "000")

    if [ "$http_code" = "200" ]; then
        IN_CORPORATE_NETWORK=true
        log_info "Corporate network detected (contenthub.bmwgroup.net returned 200)"
        print_info "Corporate network detected"

        # Always disable SST telemetry in corporate network
        export SST_TELEMETRY_DISABLED=1
        export DO_NOT_TRACK=1
        log_info "SST telemetry disabled (corporate firewall blocks telemetry endpoints)"

        # Check if proxy is configured
        if [ -n "${HTTP_PROXY:-}" ] || [ -n "${HTTPS_PROXY:-}" ]; then
            NETWORK_MODE="CN_PROXY"
            log_info "Proxy environment variables detected"
            print_info "Network mode: CN_PROXY (corporate with proxy)"
            configure_proxy
        else
            # No proxy configured - test if we can reach npm registry directly
            log_info "No proxy env vars, testing direct npm access..."
            if curl --silent --head --fail --max-time 5 "https://registry.npmjs.org" > /dev/null 2>&1; then
                NETWORK_MODE="CN_PROXY"  # Direct access works (internal mirror or exception)
                log_info "Direct npm registry access available"
                print_info "Network mode: CN_PROXY (direct npm access)"
            else
                NETWORK_MODE="CN_AIRGAP"
                log_info "No npm registry access - air-gapped mode"
                print_warning "Network mode: CN_AIRGAP (no external network)"
                require_deployment_cache  # Will fail if cache not present
            fi
        fi
    else
        IN_CORPORATE_NETWORK=false
        NETWORK_MODE="EXTERNAL"
        log_info "Outside corporate network (contenthub.bmwgroup.net returned $http_code, not 200)"
        print_success "Network mode: EXTERNAL (full internet access)"

        # In EXTERNAL mode, DON'T configure proxy - user's local proxy shouldn't affect deployment
        # Just warn if proxy vars are set
        if [ -n "${HTTP_PROXY:-}" ] || [ -n "${HTTPS_PROXY:-}" ]; then
            log_info "Note: Proxy env vars detected but ignoring in EXTERNAL mode"
            log_info "  HTTP_PROXY: ${HTTP_PROXY:-<not set>}"
            log_info "  HTTPS_PROXY: ${HTTPS_PROXY:-<not set>}"
            # Unset proxy vars to prevent interference with AWS CLI
            unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY 2>/dev/null || true
            log_info "Cleared proxy environment variables for clean AWS access"
        fi

        # Clear any npm proxy config from previous CN_PROXY runs
        # This prevents npm from using stale proxy settings
        if npm config get proxy 2>/dev/null | grep -qv "null"; then
            npm config delete proxy 2>/dev/null || true
            npm config delete https-proxy 2>/dev/null || true
            log_info "Cleared npm proxy configuration from previous runs"
        fi
    fi

    log_info "Final network mode: $NETWORK_MODE"
}

# Legacy function name for compatibility
detect_corporate_network() {
    detect_network_environment
}

#######################################################################
# Deployment Cache Functions (for offline/air-gapped deployment)
#######################################################################

# Check for and restore deployment cache
# This enables deployment in restricted networks without npm/github access
check_deployment_cache() {
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    local CACHE_DIR="$PROJECT_ROOT/.deployment-cache"
    local CACHE_SCRIPT="$SCRIPT_DIR/create-deployment-cache.sh"

    if [ ! -d "$CACHE_DIR" ]; then
        log_info "No deployment cache found at $CACHE_DIR"

        # Only offer to create cache in interactive mode and if cache script exists
        if [ "$NON_INTERACTIVE" = false ] && [ -f "$CACHE_SCRIPT" ]; then
            # Check if we have Pulumi plugins to cache (indicates previous successful deployment)
            local PULUMI_PLUGINS_DIR="$HOME/.pulumi/plugins"
            local HAS_AWS_PROVIDER=$(ls -d "$PULUMI_PLUGINS_DIR/resource-aws-"* 2>/dev/null | head -1)

            if [ -n "$HAS_AWS_PROVIDER" ]; then
                echo ""
                print_info "No deployment cache found, but you have cached Pulumi plugins."
                print_info "Creating a cache allows offline deployment in restricted networks."
                echo ""

                local CREATE_CACHE
                safe_read "Create deployment cache for offline use? [y/N]: " CREATE_CACHE "N" 30

                if [[ "$CREATE_CACHE" =~ ^[Yy]$ ]]; then
                    log_info "User requested cache creation"
                    if bash "$CACHE_SCRIPT"; then
                        log_info "Deployment cache created successfully"
                        print_success "Deployment cache created at .deployment-cache/"
                        print_info "Commit this directory or transfer it to restricted networks"
                    else
                        log_warn "Cache creation failed (continuing with deployment)"
                        print_warning "Cache creation failed (continuing anyway)"
                    fi
                else
                    log_info "User declined cache creation"
                fi
            fi
        fi
        return 0
    fi

    log_step "Using pre-cached deployment assets"
    USING_DEPLOYMENT_CACHE=true

    # Read manifest if available
    if [ -f "$CACHE_DIR/manifest.json" ]; then
        local cache_date=$(cat "$CACHE_DIR/manifest.json" | grep -o '"created": "[^"]*"' | cut -d'"' -f4)
        local aws_provider=$(cat "$CACHE_DIR/manifest.json" | grep -o '"aws_provider": "[^"]*"' | cut -d'"' -f4)
        log_info "Cache created: $cache_date"
        log_info "AWS provider: $aws_provider"
        print_info "Using cached assets (created: $cache_date)"
        print_info "Cached AWS provider: $aws_provider"
    fi

    # Restore Pulumi plugins if not already present
    local PULUMI_PLUGINS_DIR="$HOME/.pulumi/plugins"
    if [ -d "$CACHE_DIR/pulumi-plugins" ]; then
        # Check if AWS provider is cached but not in user's Pulumi plugins
        local CACHED_AWS=$(ls -d "$CACHE_DIR/pulumi-plugins/resource-aws-"* 2>/dev/null | head -1)
        local LOCAL_AWS=$(ls -d "$PULUMI_PLUGINS_DIR/resource-aws-"* 2>/dev/null | head -1)

        if [ -n "$CACHED_AWS" ] && [ -z "$LOCAL_AWS" ]; then
            log_info "Restoring Pulumi plugins from cache..."
            mkdir -p "$PULUMI_PLUGINS_DIR"
            cp -r "$CACHE_DIR/pulumi-plugins/"* "$PULUMI_PLUGINS_DIR/"
            print_success "Restored Pulumi plugins from cache"
        elif [ -n "$LOCAL_AWS" ]; then
            log_info "Pulumi plugins already present: $(basename $LOCAL_AWS)"
            print_info "Pulumi plugins already installed"
        fi
    fi

    # Restore SST binaries if not already present (macOS)
    local SST_APP_SUPPORT="$HOME/Library/Application Support/sst"
    if [ -d "$CACHE_DIR/sst-binaries" ] && [ ! -d "$SST_APP_SUPPORT/bin" ]; then
        log_info "Restoring SST binaries from cache..."
        mkdir -p "$SST_APP_SUPPORT"
        cp -r "$CACHE_DIR/sst-binaries/"* "$SST_APP_SUPPORT/" 2>/dev/null || true
        print_success "Restored SST binaries from cache"
    fi

    # Set environment variables to minimize network calls
    export PULUMI_SKIP_UPDATE_CHECK=true
    export SST_TELEMETRY_DISABLED=1
    export DO_NOT_TRACK=1

    log_info "Environment configured for offline deployment"
    print_success "Deployment cache loaded - offline mode enabled"
}

#######################################################################
# Helper Functions
#######################################################################

print_banner() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}           ${BOLD}UI Template - Setup & Deployment${NC}                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "\n${BLUE}▶${NC} ${BOLD}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

show_help() {
    echo "Usage: ./scripts/setup.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --stage <name>       Deploy to specific stage (dev, int, prod, or custom)"
    echo "  --profile <name>     Use specific AWS profile"
    echo "  --check              Check AWS credentials only (no deployment)"
    echo "  --unlock             Unlock SST state (with telemetry disabled for corporate networks)"
    echo "  --skip-install       Skip npm install check (faster when deps already installed)"
    echo "  --non-interactive    Run without prompts (for CI/CD, containers)"
    echo "  --no-telemetry       Disable SST telemetry (auto-detected in corporate network)"
    echo "  --verbose            Enable verbose logging"
    echo "  --timeout <seconds>  Set timeout for operations (default: 300)"
    echo "  --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./scripts/setup.sh                           # Interactive setup"
    echo "  ./scripts/setup.sh --stage dev               # Deploy to dev stage"
    echo "  ./scripts/setup.sh --profile tanfra          # Use tanfra AWS profile"
    echo "  ./scripts/setup.sh --check                   # Verify AWS credentials"
    echo "  ./scripts/setup.sh --unlock                  # Unlock SST state safely"
    echo "  ./scripts/setup.sh --non-interactive --stage dev  # CI/CD mode"
    echo ""
    echo "Environment Variables:"
    echo "  SETUP_LOG_FILE        Path to log file"
    echo "  SETUP_TIMEOUT         Default timeout in seconds"
    echo "  AWS_PROFILE           AWS profile to use"
    echo "  STAGE                 Deployment stage"
    echo "  SST_TELEMETRY_DISABLED  Set to 1 to disable SST telemetry"
    echo ""
    echo "For SSO authentication:"
    echo "  aws sso login --profile your-profile"
    echo "  ./scripts/setup.sh --profile your-profile"
    echo ""
    echo "Network Modes (auto-detected):"
    echo "  EXTERNAL   - Full internet access (outside corporate network)"
    echo "  CN_PROXY   - Corporate network with proxy (set HTTP_PROXY/HTTPS_PROXY)"
    echo "  CN_AIRGAP  - Corporate network, no proxy, requires deployment cache"
    echo ""
    echo "Corporate Network:"
    echo "  The script auto-detects corporate network by checking contenthub.bmwgroup.net"
    echo "  When in CN, SST telemetry is automatically disabled to avoid firewall timeouts"
    echo ""
    echo "Proxy Configuration:"
    echo "  HTTP_PROXY=http://proxy:8080 ./scripts/setup.sh --stage dev"
    echo "  HTTPS_PROXY=http://proxy:8080 ./scripts/setup.sh --stage dev"
    echo "  The script auto-configures npm and NO_PROXY for AWS endpoints"
    echo ""
    echo "Offline Deployment (air-gapped/restricted networks):"
    echo "  1. First deploy from unrestricted network to populate caches"
    echo "  2. Run: ./scripts/create-deployment-cache.sh --include-node-modules"
    echo "  3. Commit .deployment-cache/ to repository or transfer to restricted machine"
    echo "  4. In restricted network, setup.sh will auto-detect and use the cache"
    echo ""
    echo "  See docs-content/sst-deployment-network-requirements.md for details"
}

#######################################################################
# Timeout and Process Management
#######################################################################

# Run command with timeout
# Usage: run_with_timeout <timeout_seconds> <description> <command...>
run_with_timeout() {
    local timeout_secs="$1"
    local description="$2"
    shift 2

    log_info "Starting: $description (timeout: ${timeout_secs}s)"
    log_command "$*"

    local start_time=$(date +%s)
    local exit_code=0

    # Use timeout command if available, otherwise implement our own
    if command -v timeout &> /dev/null; then
        # Run with timeout, capture exit code properly with pipefail
        timeout "$timeout_secs" "$@" 2>&1 | tee -a "$LOG_FILE" || exit_code=$?
    else
        # Fallback: run without timeout but with logging
        "$@" 2>&1 | tee -a "$LOG_FILE" || exit_code=$?
    fi

    local elapsed=$(($(date +%s) - start_time))

    if [ $exit_code -eq 0 ]; then
        log_info "Completed: $description (took ${elapsed}s)"
        return 0
    elif [ $exit_code -eq 124 ]; then
        log_error "TIMEOUT: $description exceeded ${timeout_secs}s limit"
        return 124
    else
        log_error "FAILED: $description (exit code: $exit_code, took ${elapsed}s)"
        return $exit_code
    fi
}

# Safe read with timeout for interactive prompts
# Usage: safe_read <prompt> <variable_name> <default_value> <timeout_seconds>
safe_read() {
    local prompt="$1"
    local var_name="$2"
    local default_val="$3"
    local timeout_secs="${4:-30}"

    if [ "$NON_INTERACTIVE" = true ]; then
        log_info "Non-interactive mode: using default value '$default_val' for prompt: $prompt"
        eval "$var_name=\"$default_val\""
        return 0
    fi

    # Interactive mode with timeout
    if read -t "$timeout_secs" -p "$prompt" "$var_name" 2>/dev/null; then
        # User provided input
        local value
        eval "value=\$$var_name"
        if [ -z "$value" ]; then
            eval "$var_name=\"$default_val\""
        fi
        log_debug "User input for '$prompt': $(eval echo \$$var_name)"
    else
        # Timeout or error
        echo ""  # New line after timeout
        log_warn "Input timeout after ${timeout_secs}s, using default: $default_val"
        eval "$var_name=\"$default_val\""
    fi
}

# Safe read for sensitive input (no echo)
safe_read_secret() {
    local prompt="$1"
    local var_name="$2"
    local timeout_secs="${3:-60}"

    if [ "$NON_INTERACTIVE" = true ]; then
        log_error "Cannot read secret input in non-interactive mode"
        return 1
    fi

    if read -t "$timeout_secs" -s -p "$prompt" "$var_name" 2>/dev/null; then
        echo ""  # New line after hidden input
        log_debug "Secret input received for: $prompt"
        return 0
    else
        echo ""
        log_error "Timeout waiting for secret input"
        return 1
    fi
}

#######################################################################
# Parse Arguments
#######################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --stage)
            STAGE="$2"
            shift 2
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --unlock)
            UNLOCK_MODE=true
            shift
            ;;
        --skip-install)
            SKIP_INSTALL=true
            shift
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --no-telemetry)
            FORCE_NO_TELEMETRY=true
            shift
            ;;
        --timeout)
            DEFAULT_TIMEOUT="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

#######################################################################
# Check Prerequisites
#######################################################################

check_prerequisites() {
    log_step "Checking prerequisites"

    # Check Node.js
    log_info "Checking Node.js installation..."
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed"
        print_error "Node.js is not installed"
        echo "  Install from: https://nodejs.org/"
        exit 1
    fi
    NODE_VERSION=$(node -v)
    log_info "Node.js version: $NODE_VERSION"
    print_success "Node.js $NODE_VERSION"

    # Check npm
    log_info "Checking npm installation..."
    if ! command -v npm &> /dev/null; then
        log_error "npm is not installed"
        print_error "npm is not installed"
        exit 1
    fi
    NPM_VERSION=$(npm -v)
    log_info "npm version: $NPM_VERSION"
    print_success "npm $NPM_VERSION"

    # Check AWS CLI
    log_info "Checking AWS CLI installation..."
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        print_error "AWS CLI is not installed"
        echo ""
        echo "  Install instructions:"
        echo "  - macOS: brew install awscli"
        echo "  - Linux: curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'"
        echo "  - Windows: https://awscli.amazonaws.com/AWSCLIV2.msi"
        exit 1
    fi
    AWS_VERSION=$(aws --version | cut -d' ' -f1)
    log_info "AWS CLI version: $AWS_VERSION"
    print_success "AWS CLI $AWS_VERSION"

    # Check if package.json exists
    log_info "Checking project structure..."
    if [ ! -f "package.json" ]; then
        log_error "package.json not found - not running from project root"
        print_error "package.json not found. Run this script from the project root."
        exit 1
    fi
    log_info "Project structure verified"
    print_success "Project structure OK"
}

#######################################################################
# AWS Authentication
#######################################################################

# Check if a profile uses static credentials (not SSO)
# If so, clear any interfering SSO cache
ensure_clean_credentials() {
    local profile="${AWS_PROFILE:-${PROFILE:-default}}"
    local credentials_file="$HOME/.aws/credentials"
    local config_file="$HOME/.aws/config"

    # Check if this profile has static credentials (access key in credentials file)
    local has_static_creds=false
    if grep -q "^\[$profile\]" "$credentials_file" 2>/dev/null; then
        if grep -A3 "^\[$profile\]" "$credentials_file" 2>/dev/null | grep -q "aws_access_key_id"; then
            has_static_creds=true
        fi
    fi

    # Check if this profile uses SSO (sso_ entries in config)
    local uses_sso=false
    if grep -A10 "^\[profile $profile\]" "$config_file" 2>/dev/null | grep -q "sso_"; then
        uses_sso=true
    fi

    # If profile has static credentials and doesn't use SSO, clear ALL SSO caches
    # This prevents expired SSO tokens from interfering with static credential auth
    if [ "$has_static_creds" = true ] && [ "$uses_sso" = false ]; then
        local cleared=false

        # Clear CLI cache (credential cache)
        if [ -d "$HOME/.aws/cli/cache" ] && [ -n "$(ls -A $HOME/.aws/cli/cache 2>/dev/null)" ]; then
            rm -f "$HOME/.aws/cli/cache"/*.json 2>/dev/null || true
            cleared=true
        fi

        # Clear SSO cache (session tokens) - THIS IS CRITICAL
        if [ -d "$HOME/.aws/sso/cache" ] && [ -n "$(ls -A $HOME/.aws/sso/cache 2>/dev/null)" ]; then
            rm -f "$HOME/.aws/sso/cache"/*.json 2>/dev/null || true
            cleared=true
        fi

        if [ "$cleared" = true ]; then
            log_info "Profile '$profile' uses static credentials - cleared SSO caches to prevent interference"
        fi
    fi
}

detect_aws_auth() {
    log_step "Detecting AWS authentication"

    # If profile specified, set it
    if [ -n "$PROFILE" ]; then
        export AWS_PROFILE="$PROFILE"
        log_info "Using AWS profile: $PROFILE"
        print_info "Using AWS profile: $PROFILE"
    fi

    # CRITICAL: Clear any stale session tokens that override profile credentials
    # AWS_SESSION_TOKEN takes precedence over profile credentials and causes
    # "Credentials were refreshed, but the refreshed credentials are still expired" errors
    if [ -n "${AWS_SESSION_TOKEN:-}" ]; then
        log_info "Clearing stale AWS_SESSION_TOKEN (overrides profile credentials)"
        unset AWS_SESSION_TOKEN
    fi
    if [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "$PROFILE" ]; then
        # If using a profile, env vars should not override - clear them
        log_info "Clearing AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY to use profile credentials"
        unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
    fi

    # Clear interfering SSO cache if using static credentials
    ensure_clean_credentials

    # Debug: Log current AWS-related environment
    log_info "Environment check before AWS call:"
    log_info "  AWS_PROFILE: ${AWS_PROFILE:-<not set>}"
    log_info "  HTTP_PROXY: ${HTTP_PROXY:-<not set>}"
    log_info "  HTTPS_PROXY: ${HTTPS_PROXY:-<not set>}"
    log_info "  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:+<set>}${AWS_ACCESS_KEY_ID:-<not set>}"
    log_info "  AWS_SESSION_TOKEN: ${AWS_SESSION_TOKEN:+<set - THIS MAY BE THE PROBLEM>}${AWS_SESSION_TOKEN:-<not set>}"

    # Try to get caller identity with timeout
    # Capture stdout and stderr separately - AWS CLI may output warnings to stderr
    # even when credentials are valid
    log_info "Checking AWS credentials with sts get-caller-identity..."

    local aws_stdout aws_stderr aws_exit
    aws_stdout=$(timeout 30 aws sts get-caller-identity 2>/dev/null)
    aws_exit=$?

    # If timeout or command failed, try again capturing stderr for logging
    if [ $aws_exit -ne 0 ]; then
        aws_stderr=$(timeout 30 aws sts get-caller-identity 2>&1 >/dev/null)
        log_warn "AWS authentication check failed (exit $aws_exit): $aws_stderr"
        return 1
    fi

    # Parse the JSON output (stdout only, no stderr contamination)
    ACCOUNT_ID=$(echo "$aws_stdout" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
    USER_ARN=$(echo "$aws_stdout" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)

    if [ -n "$ACCOUNT_ID" ]; then
        log_info "AWS Account: $ACCOUNT_ID"
        log_info "AWS Identity: $USER_ARN"
        print_success "AWS Account: $ACCOUNT_ID"
        print_success "Identity: $USER_ARN"
        return 0
    fi

    log_warn "Could not parse AWS identity from response: $aws_stdout"
    return 1
}

setup_aws_auth() {
    log_step "Setting up AWS authentication"

    # Check if already authenticated
    if detect_aws_auth; then
        log_info "AWS authentication already valid"
        return 0
    fi

    # In non-interactive mode, we must have valid credentials already
    if [ "$NON_INTERACTIVE" = true ]; then
        log_error "Non-interactive mode requires pre-configured AWS credentials"
        print_error "No valid AWS credentials found in non-interactive mode."
        print_info "Set AWS_PROFILE environment variable or configure credentials before running."
        exit 1
    fi

    # Check if we have a profile set that might just need SSO refresh
    local CURRENT_PROFILE="${PROFILE:-$AWS_PROFILE}"
    local IS_SSO_PROFILE=false

    if [ -n "$CURRENT_PROFILE" ]; then
        # Check if this profile uses SSO (only check lines before next profile section)
        local profile_config
        profile_config=$(awk "/\[profile $CURRENT_PROFILE\]/{found=1;next} /^\[/{found=0} found" ~/.aws/config 2>/dev/null)
        if echo "$profile_config" | grep -q "sso_"; then
            IS_SSO_PROFILE=true
        fi
    fi

    if [ "$IS_SSO_PROFILE" = true ]; then
        echo ""
        print_warning "SSO session for profile '$CURRENT_PROFILE' has expired."
        echo ""
        echo "  1) Refresh SSO login for '$CURRENT_PROFILE' (recommended)"
        echo "  2) Choose a different profile"
        echo "  3) Use IAM credentials instead"
        echo "  4) Exit"
        echo ""

        local SSO_CHOICE
        safe_read "Select option [1-4]: " SSO_CHOICE "1" 60

        case $SSO_CHOICE in
            1)
                log_info "Refreshing SSO for profile: $CURRENT_PROFILE"
                print_info "Refreshing SSO login for: $CURRENT_PROFILE"
                if run_with_timeout 300 "AWS SSO login" aws sso login --profile "$CURRENT_PROFILE"; then
                    if detect_aws_auth; then
                        print_success "SSO authentication refreshed"
                        return 0
                    fi
                fi
                print_error "SSO refresh failed"
                exit 1
                ;;
            2)
                setup_profile_auth
                ;;
            3)
                setup_iam_auth
                ;;
            4)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option"
                exit 1
                ;;
        esac
    else
        echo ""
        echo "No valid AWS credentials found. Choose authentication method:"
        echo ""
        echo "  1) AWS SSO (Corporate/Enterprise)"
        echo "  2) AWS Profile (Pre-configured)"
        echo "  3) IAM User Credentials (Access Key)"
        echo "  4) Exit"
        echo ""

        local AUTH_CHOICE
        safe_read "Select option [1-4]: " AUTH_CHOICE "4" 60

        log_info "User selected authentication option: $AUTH_CHOICE"

        case $AUTH_CHOICE in
            1)
                setup_sso_auth
                ;;
            2)
                setup_profile_auth
                ;;
            3)
                setup_iam_auth
                ;;
            4)
                log_info "User chose to exit"
                print_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid authentication option: $AUTH_CHOICE"
                print_error "Invalid option"
                exit 1
                ;;
        esac
    fi
}

setup_sso_auth() {
    log_step "Setting up AWS SSO authentication"

    echo ""
    echo "Available SSO profiles in ~/.aws/config:"
    grep -E "^\[profile.*sso" ~/.aws/config 2>/dev/null | sed 's/\[profile /  - /g' | sed 's/\]//g' || echo "  No SSO profiles found"
    echo ""

    local SSO_PROFILE
    safe_read "Enter SSO profile name: " SSO_PROFILE "" 60

    if [ -z "$SSO_PROFILE" ]; then
        log_error "SSO profile name required but not provided"
        print_error "Profile name required"
        exit 1
    fi

    log_info "Initiating SSO login for profile: $SSO_PROFILE"
    print_info "Initiating SSO login for profile: $SSO_PROFILE"

    # SSO login can take a while (browser interaction)
    if ! run_with_timeout 300 "AWS SSO login" aws sso login --profile "$SSO_PROFILE"; then
        log_error "SSO login failed or timed out"
        print_error "SSO login failed"
        exit 1
    fi

    export AWS_PROFILE="$SSO_PROFILE"
    PROFILE="$SSO_PROFILE"

    if detect_aws_auth; then
        log_info "SSO authentication successful"
        print_success "SSO authentication successful"
    else
        log_error "SSO authentication verification failed"
        print_error "SSO authentication failed"
        exit 1
    fi
}

setup_profile_auth() {
    log_step "Setting up AWS profile authentication"

    echo ""
    echo "Available AWS profiles:"

    # Collect unique profiles from both credentials and config files
    local PROFILES=()
    local i=1

    # Get profiles from credentials file
    while IFS= read -r profile; do
        if [ -n "$profile" ]; then
            PROFILES+=("$profile")
            echo "  $i) $profile"
            ((i++))
        fi
    done < <(grep -E "^\[" ~/.aws/credentials 2>/dev/null | sed 's/\[//g' | sed 's/\]//g' | sort -u)

    # Get profiles from config file (avoiding duplicates)
    while IFS= read -r profile; do
        if [ -n "$profile" ]; then
            # Check if already in list
            local is_dup=false
            for existing in "${PROFILES[@]}"; do
                if [ "$existing" = "$profile" ]; then
                    is_dup=true
                    break
                fi
            done
            if [ "$is_dup" = false ]; then
                PROFILES+=("$profile")
                echo "  $i) $profile"
                ((i++))
            fi
        fi
    done < <(grep -E "^\[profile" ~/.aws/config 2>/dev/null | sed 's/\[profile //g' | sed 's/\]//g' | sort -u)

    if [ ${#PROFILES[@]} -eq 0 ]; then
        echo "  No profiles found"
    fi
    echo ""

    local PROFILE_CHOICE
    safe_read "Select profile number (or enter profile name): " PROFILE_CHOICE "1" 60

    local SELECTED_PROFILE
    # Check if input is a number
    if [[ "$PROFILE_CHOICE" =~ ^[0-9]+$ ]]; then
        local idx=$((PROFILE_CHOICE - 1))
        if [ $idx -ge 0 ] && [ $idx -lt ${#PROFILES[@]} ]; then
            SELECTED_PROFILE="${PROFILES[$idx]}"
            log_info "Selected profile by number: $SELECTED_PROFILE"
        else
            log_error "Invalid profile number: $PROFILE_CHOICE"
            print_error "Invalid selection. Valid range: 1-${#PROFILES[@]}"
            exit 1
        fi
    else
        # Treat as profile name
        SELECTED_PROFILE="$PROFILE_CHOICE"
        log_info "Selected profile by name: $SELECTED_PROFILE"
    fi

    export AWS_PROFILE="$SELECTED_PROFILE"
    PROFILE="$SELECTED_PROFILE"
    print_info "Using profile: $SELECTED_PROFILE"

    if detect_aws_auth; then
        log_info "Profile authentication successful"
        print_success "Profile authentication successful"
        return 0
    fi

    # Auth failed - check if this is an SSO profile that needs refresh
    local IS_SSO=false
    local profile_config
    profile_config=$(awk "/\[profile $SELECTED_PROFILE\]/{found=1;next} /^\[/{found=0} found" ~/.aws/config 2>/dev/null)
    if echo "$profile_config" | grep -q "sso_"; then
        IS_SSO=true
    fi

    if [ "$IS_SSO" = true ]; then
        echo ""
        print_warning "SSO session for '$SELECTED_PROFILE' has expired."
        local REFRESH_SSO
        safe_read "Run 'aws sso login' to refresh? [Y/n]: " REFRESH_SSO "Y" 30

        if [[ "$REFRESH_SSO" =~ ^[Yy]$ ]] || [ -z "$REFRESH_SSO" ]; then
            log_info "Refreshing SSO for profile: $SELECTED_PROFILE"
            if run_with_timeout 300 "AWS SSO login" aws sso login --profile "$SELECTED_PROFILE"; then
                if detect_aws_auth; then
                    print_success "SSO authentication refreshed"
                    return 0
                fi
            fi
            print_error "SSO refresh failed"
            exit 1
        else
            print_error "Cannot proceed without valid credentials"
            exit 1
        fi
    else
        log_error "Profile authentication failed for: $SELECTED_PROFILE"
        print_error "Profile authentication failed"
        exit 1
    fi
}

setup_iam_auth() {
    log_step "Setting up IAM user credentials"

    # IAM auth requires interactive input
    if [ "$NON_INTERACTIVE" = true ]; then
        log_error "IAM credential setup requires interactive mode"
        print_error "Cannot configure IAM credentials in non-interactive mode"
        print_info "Use --profile with pre-configured credentials instead"
        exit 1
    fi

    echo ""
    print_warning "Using long-term credentials is less secure than SSO."
    print_info "Consider using AWS SSO for better security."
    echo ""

    local AWS_ACCESS_KEY_ID_INPUT
    local AWS_SECRET_ACCESS_KEY_INPUT
    local AWS_REGION_INPUT

    safe_read "AWS Access Key ID: " AWS_ACCESS_KEY_ID_INPUT "" 60

    if ! safe_read_secret "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY_INPUT 60; then
        log_error "Failed to read secret access key"
        exit 1
    fi

    safe_read "AWS Region [eu-central-1]: " AWS_REGION_INPUT "eu-central-1" 30

    export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID_INPUT"
    export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY_INPUT"
    export AWS_DEFAULT_REGION="$AWS_REGION_INPUT"

    log_info "Testing IAM credentials for region: $AWS_REGION_INPUT"

    if detect_aws_auth; then
        log_info "IAM authentication successful"
        print_success "IAM authentication successful"

        echo ""
        local SAVE_CREDS
        safe_read "Save credentials to AWS profile? [y/N]: " SAVE_CREDS "N" 30

        if [[ "$SAVE_CREDS" =~ ^[Yy]$ ]]; then
            local PROFILE_NAME
            safe_read "Profile name [default]: " PROFILE_NAME "default" 30

            log_info "Saving credentials to profile: $PROFILE_NAME"
            aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID_INPUT" --profile "$PROFILE_NAME"
            aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY_INPUT" --profile "$PROFILE_NAME"
            aws configure set region "$AWS_REGION_INPUT" --profile "$PROFILE_NAME"

            log_info "Credentials saved to profile: $PROFILE_NAME"
            print_success "Credentials saved to profile: $PROFILE_NAME"
        fi
    else
        log_error "IAM authentication failed"
        print_error "IAM authentication failed"
        exit 1
    fi
}

#######################################################################
# Install Dependencies
#######################################################################

install_dependencies() {
    log_step "Installing dependencies"

    if [ ! -d "node_modules" ]; then
        log_info "node_modules not found, running npm install..."
        if ! run_with_timeout "$DEFAULT_TIMEOUT" "npm install" npm install; then
            log_error "npm install failed"
            print_error "Failed to install dependencies"
            exit 1
        fi
        print_success "Dependencies installed"
    else
        log_info "node_modules already exists"
        print_info "Dependencies already installed"

        if [ "$NON_INTERACTIVE" = true ]; then
            log_info "Skipping reinstall prompt in non-interactive mode"
        else
            local REINSTALL
            safe_read "Run npm install anyway? [y/N]: " REINSTALL "N" 30

            if [[ "$REINSTALL" =~ ^[Yy]$ ]]; then
                log_info "User requested reinstall"
                if ! run_with_timeout "$DEFAULT_TIMEOUT" "npm install (reinstall)" npm install; then
                    log_error "npm install (reinstall) failed"
                    print_error "Failed to reinstall dependencies"
                    exit 1
                fi
                print_success "Dependencies reinstalled"
            fi
        fi
    fi
}

#######################################################################
# Deploy
#######################################################################

select_stage() {
    if [ -n "$STAGE" ]; then
        log_info "Stage already set: $STAGE"
        return 0
    fi

    log_step "Select deployment stage"

    # In non-interactive mode, default to user's name
    if [ "$NON_INTERACTIVE" = true ]; then
        STAGE="$USER"
        log_info "Non-interactive mode: defaulting to personal stage: $STAGE"
        print_info "Using personal stage: $STAGE"
        return 0
    fi

    echo ""
    echo "Available stages:"
    echo "  1) Personal stage (your username: $USER)"
    echo "  2) dev - Development environment"
    echo "  3) int - Integration/staging environment"
    echo "  4) prod - Production environment"
    echo "  5) Custom stage name"
    echo ""

    local STAGE_CHOICE
    safe_read "Select option [1-5]: " STAGE_CHOICE "1" 60

    log_info "User selected stage option: $STAGE_CHOICE"

    case $STAGE_CHOICE in
        1)
            STAGE="$USER"
            ;;
        2)
            STAGE="dev"
            ;;
        3)
            STAGE="int"
            ;;
        4)
            STAGE="prod"
            ;;
        5)
            safe_read "Enter custom stage name: " STAGE "$USER" 60
            ;;
        *)
            STAGE="$USER"
            ;;
    esac

    log_info "Selected stage: $STAGE"
    print_info "Selected stage: $STAGE"
}

#######################################################################
# Export AWS Credentials (bypasses SSO portal refresh issues)
#######################################################################

export_aws_credentials() {
    log_info "Exporting AWS credentials as environment variables..."

    local profile_arg=""
    if [ -n "$PROFILE" ]; then
        profile_arg="--profile $PROFILE"
    fi

    # Export credentials - this gets temp credentials from cached SSO session
    # and exports them as env vars, avoiding SSO portal refresh during SST operations
    local creds_output
    if ! creds_output=$(aws configure export-credentials $profile_arg --format env 2>&1); then
        log_error "Failed to export credentials: $creds_output"
        print_error "Failed to export AWS credentials. Try: aws sso login --profile $PROFILE"
        return 1
    fi

    # Eval the output to set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
    eval "$creds_output"

    if [ -z "$AWS_ACCESS_KEY_ID" ]; then
        log_error "AWS_ACCESS_KEY_ID not set after credential export"
        return 1
    fi

    log_info "Credentials exported successfully (key: ${AWS_ACCESS_KEY_ID:0:8}...)"
    print_success "AWS credentials exported"

    # Unset AWS_PROFILE to force use of env var credentials
    unset AWS_PROFILE

    return 0
}

#######################################################################
# Ensure SST Platform Dependencies (fixes CN/proxy environment issues)
#######################################################################
# SST v3 uses Bun to install its internal platform dependencies in .sst/platform/
# In corporate network environments with proxies, Bun's installation can fail or
# timeout silently, leaving .sst/platform/node_modules empty.
# This function ensures dependencies are installed using npm as a fallback.

ensure_sst_platform_deps() {
    local platform_dir=".sst/platform"
    local pulumi_check="$platform_dir/node_modules/@pulumi/pulumi"

    # Only check if .sst/platform exists (created during first SST run)
    if [ -d "$platform_dir" ] && [ -f "$platform_dir/package.json" ]; then
        if [ ! -d "$pulumi_check" ]; then
            log_warn "SST platform dependencies missing (Bun install may have failed)"
            log_info "Installing .sst/platform dependencies with npm (fallback for CN/proxy environments)..."
            print_info "Installing SST platform dependencies..."

            if (cd "$platform_dir" && npm install >> "$LOG_FILE" 2>&1); then
                log_info "SST platform dependencies installed successfully"
            else
                log_error "Failed to install SST platform dependencies"
                print_error "SST platform dependency installation failed"
                return 1
            fi
        else
            log_info "SST platform dependencies already installed"
        fi
    fi
    return 0
}

#######################################################################
# Run SST Command (with telemetry disabled and proper env)
#######################################################################

run_sst_command() {
    local description="$1"
    local timeout_secs="$2"
    shift 2
    local sst_args="$@"

    # Ensure telemetry is disabled for ALL SST operations
    export SST_TELEMETRY_DISABLED=1
    export DO_NOT_TRACK=1

    log_info "Running SST: npx sst $sst_args"
    log_info "  SST_TELEMETRY_DISABLED=$SST_TELEMETRY_DISABLED"
    log_info "  AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:0:8}..."

    if ! run_with_timeout "$timeout_secs" "$description" npx sst $sst_args; then
        return 1
    fi
    return 0
}

deploy() {
    log_step "Deploying to stage: $STAGE"

    # Export credentials to avoid SSO portal refresh issues
    if ! export_aws_credentials; then
        exit 1
    fi

    # Bump version
    log_info "Bumping version..."
    if ! npm run version:patch >> "$LOG_FILE" 2>&1; then
        log_warn "Version bump failed (continuing anyway)"
    fi
    VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "unknown")
    log_info "Version: $VERSION"
    print_info "Version: $VERSION"

    # Auto-unlock before deploy to prevent lock issues
    log_info "Ensuring app is unlocked before deployment..."
    print_info "Checking/clearing any existing locks..."

    # Try unlock up to 3 times with delays (handles stale locks)
    local unlock_attempts=0
    local max_unlock_attempts=3
    while [ $unlock_attempts -lt $max_unlock_attempts ]; do
        unlock_attempts=$((unlock_attempts + 1))
        log_info "Unlock attempt $unlock_attempts of $max_unlock_attempts"

        if run_sst_command "SST unlock (attempt $unlock_attempts)" 60 unlock 2>/dev/null; then
            log_info "Unlock succeeded, waiting 3 seconds for state to propagate..."
            sleep 3
        else
            log_info "Unlock not needed or already clear"
        fi

        # Small delay between attempts
        if [ $unlock_attempts -lt $max_unlock_attempts ]; then
            sleep 2
        fi
    done

    # Ensure SST platform dependencies are installed (fixes CN/proxy issues)
    # This catches cases where Bun's install failed silently
    if ! ensure_sst_platform_deps; then
        log_error "Cannot proceed without SST platform dependencies"
        exit 1
    fi

    # Run SST deploy
    echo ""
    log_info "Starting SST deployment (this may take several minutes)..."
    print_info "Starting SST deployment..."
    echo ""

    local SST_TIMEOUT=$((DEFAULT_TIMEOUT * 2))  # Double timeout for deployment
    log_info "SST deployment timeout: ${SST_TIMEOUT}s"

    if ! run_sst_command "SST deployment to $STAGE" "$SST_TIMEOUT" deploy --stage "$STAGE"; then
        log_error "SST deployment failed or timed out"
        print_error "Deployment failed! Check logs at: $LOG_FILE"
        exit 1
    fi

    log_info "Deployment completed successfully"
    print_success "Deployment complete!"
}

#######################################################################
# Unlock SST State
#######################################################################

unlock_app() {
    log_step "Unlocking SST state"

    # Export credentials to avoid SSO portal refresh issues
    if ! export_aws_credentials; then
        exit 1
    fi

    print_info "Running sst unlock..."
    echo ""

    if ! run_sst_command "SST unlock" "$DEFAULT_TIMEOUT" unlock; then
        log_error "SST unlock failed"
        print_error "Unlock failed! Check logs at: $LOG_FILE"
        exit 1
    fi

    log_info "SST unlock completed successfully"
    print_success "SST state unlocked!"
    echo ""
    print_info "You can now run deployments again."
}

show_outputs() {
    log_step "Deployment outputs"

    local elapsed=$(($(date +%s) - SCRIPT_START_TIME))
    log_info "Total execution time: ${elapsed}s"

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                    ${BOLD}Deployment Complete!${NC}                    ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Your application has been deployed. The URLs and configuration"
    echo "values are shown above in the SST output."
    echo ""
    echo "Next steps:"
    echo "  1. Open the CloudFront URL in your browser"
    echo "  2. Create a user account using the Sign Up form"
    echo "  3. Verify your email address"
    echo "  4. Sign in and explore the application"
    echo ""
    echo "Useful commands:"
    echo "  npm run dev           # Start local development with SST"
    echo "  npm run deploy        # Deploy to your personal stage"
    echo "  npm run deploy:dev    # Deploy to dev environment"
    echo "  npm run remove        # Remove your deployment"
    echo ""
    echo -e "${CYAN}ℹ${NC} Log file: $LOG_FILE"
    echo -e "${CYAN}ℹ${NC} Total time: ${elapsed}s"
    echo ""
}

#######################################################################
# Main
#######################################################################

main() {
    # Initialize logging
    ensure_log_dir
    log_info "=========================================="
    log_info "Setup script started"
    log_info "Arguments: $*"
    log_info "Working directory: $(pwd)"
    log_info "User: $USER"
    log_info "=========================================="

    # Detect interactive mode if not explicitly set
    if [ "$NON_INTERACTIVE" = false ]; then
        detect_interactive
    else
        log_info "Non-interactive mode set via --non-interactive flag"
    fi

    print_banner

    # Log configuration
    log_info "Configuration:"
    log_info "  STAGE: ${STAGE:-<not set>}"
    log_info "  PROFILE: ${PROFILE:-<not set>}"
    log_info "  CHECK_ONLY: $CHECK_ONLY"
    log_info "  UNLOCK_MODE: $UNLOCK_MODE"
    log_info "  SKIP_INSTALL: $SKIP_INSTALL"
    log_info "  NON_INTERACTIVE: $NON_INTERACTIVE"
    log_info "  VERBOSE: $VERBOSE"
    log_info "  FORCE_NO_TELEMETRY: $FORCE_NO_TELEMETRY"
    log_info "  DEFAULT_TIMEOUT: ${DEFAULT_TIMEOUT}s"
    log_info "  LOG_FILE: $LOG_FILE"

    check_prerequisites
    check_deployment_cache
    detect_corporate_network

    # Log updated config after network detection
    log_info "  NETWORK_MODE: $NETWORK_MODE"
    if [ "$IN_CORPORATE_NETWORK" = true ]; then
        log_info "  IN_CORPORATE_NETWORK: true (telemetry disabled)"
    fi
    if [ "$USING_DEPLOYMENT_CACHE" = true ]; then
        log_info "  USING_DEPLOYMENT_CACHE: true"
    fi
    setup_aws_auth

    if [ "$CHECK_ONLY" = true ]; then
        log_info "Check-only mode: exiting after credential verification"
        print_success "AWS credentials verified successfully"
        exit 0
    fi

    if [ "$UNLOCK_MODE" = true ]; then
        log_info "Unlock mode: running sst unlock with telemetry protection"
        unlock_app
        exit 0
    fi

    if [ "$SKIP_INSTALL" = true ]; then
        log_info "Skipping install check (--skip-install flag)"
        print_info "Skipping dependency check"
    else
        install_dependencies
    fi
    select_stage
    deploy
    show_outputs

    log_info "Setup script completed successfully"
}

# Trap to log errors on exit
trap 'log_error "Script exited with code $?"' ERR

main "$@"
