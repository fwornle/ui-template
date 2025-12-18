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
PROFILE="${AWS_PROFILE:-}"
NON_INTERACTIVE=false
VERBOSE=false
IN_CORPORATE_NETWORK=false
FORCE_NO_TELEMETRY=false

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

# Detect if running inside corporate network (CN)
# Uses BMW contenthub as the CN indicator - responds only inside the corporate network
detect_corporate_network() {
    log_step "Detecting network environment"

    # Check if telemetry was explicitly disabled via --no-telemetry flag
    if [ "$FORCE_NO_TELEMETRY" = true ]; then
        export SST_TELEMETRY_DISABLED=1
        export DO_NOT_TRACK=1
        log_info "SST telemetry disabled via --no-telemetry flag"
        print_info "SST telemetry disabled (--no-telemetry flag)"
        return 0
    fi

    # Test CN-only endpoint with 5 second timeout
    # This URL only responds inside the BMW corporate network
    local CN_TEST_URL="https://contenthub.bmwgroup.net/web/start/"
    local CN_TIMEOUT=5

    if curl --silent --head --fail --max-time "$CN_TIMEOUT" "$CN_TEST_URL" > /dev/null 2>&1; then
        IN_CORPORATE_NETWORK=true
        log_info "Corporate network detected (contenthub.bmwgroup.net responded)"
        print_info "Corporate network detected"

        # Disable SST telemetry in corporate network (firewalls block telemetry.ion.sst.dev)
        export SST_TELEMETRY_DISABLED=1
        export DO_NOT_TRACK=1
        log_info "SST telemetry disabled (corporate firewall blocks telemetry endpoints)"
        print_info "SST telemetry disabled (corporate firewall workaround)"
    else
        IN_CORPORATE_NETWORK=false
        log_info "Outside corporate network (contenthub.bmwgroup.net unreachable)"
        print_success "External network - telemetry enabled"
    fi
}

#######################################################################
# Helper Functions
#######################################################################

print_banner() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}           ${BOLD}UI Template - Setup & Deployment${NC}               ${CYAN}║${NC}"
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
    echo "Corporate Network:"
    echo "  The script auto-detects corporate network by checking contenthub.bmwgroup.net"
    echo "  When in CN, SST telemetry is automatically disabled to avoid firewall timeouts"
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

    # Use timeout command if available, otherwise implement our own
    if command -v timeout &> /dev/null; then
        if timeout "$timeout_secs" "$@" 2>&1 | tee -a "$LOG_FILE"; then
            local elapsed=$(($(date +%s) - start_time))
            log_info "Completed: $description (took ${elapsed}s)"
            return 0
        else
            local exit_code=$?
            local elapsed=$(($(date +%s) - start_time))
            if [ $exit_code -eq 124 ]; then
                log_error "TIMEOUT: $description exceeded ${timeout_secs}s limit"
                return 124
            else
                log_error "FAILED: $description (exit code: $exit_code, took ${elapsed}s)"
                return $exit_code
            fi
        fi
    else
        # Fallback: run without timeout but with logging
        if "$@" 2>&1 | tee -a "$LOG_FILE"; then
            local elapsed=$(($(date +%s) - start_time))
            log_info "Completed: $description (took ${elapsed}s)"
            return 0
        else
            local exit_code=$?
            local elapsed=$(($(date +%s) - start_time))
            log_error "FAILED: $description (exit code: $exit_code, took ${elapsed}s)"
            return $exit_code
        fi
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

detect_aws_auth() {
    log_step "Detecting AWS authentication"

    # If profile specified, set it
    if [ -n "$PROFILE" ]; then
        export AWS_PROFILE="$PROFILE"
        log_info "Using AWS profile: $PROFILE"
        print_info "Using AWS profile: $PROFILE"
    fi

    # Try to get caller identity with timeout
    log_info "Checking AWS credentials with sts get-caller-identity..."
    if ! IDENTITY=$(timeout 30 aws sts get-caller-identity 2>&1); then
        log_warn "AWS authentication check failed: $IDENTITY"
        return 1
    fi

    ACCOUNT_ID=$(echo "$IDENTITY" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
    USER_ARN=$(echo "$IDENTITY" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)

    if [ -n "$ACCOUNT_ID" ]; then
        log_info "AWS Account: $ACCOUNT_ID"
        log_info "AWS Identity: $USER_ARN"
        print_success "AWS Account: $ACCOUNT_ID"
        print_success "Identity: $USER_ARN"
        return 0
    fi

    log_warn "Could not parse AWS identity from response"
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
    grep -E "^\[" ~/.aws/credentials 2>/dev/null | sed 's/\[/  - /g' | sed 's/\]//g' || echo "  No profiles in credentials file"
    grep -E "^\[profile" ~/.aws/config 2>/dev/null | sed 's/\[profile /  - /g' | sed 's/\]//g' || true
    echo ""

    local SELECTED_PROFILE
    safe_read "Enter profile name (or press Enter for default): " SELECTED_PROFILE "default" 60

    if [ -n "$SELECTED_PROFILE" ] && [ "$SELECTED_PROFILE" != "default" ]; then
        export AWS_PROFILE="$SELECTED_PROFILE"
        PROFILE="$SELECTED_PROFILE"
        log_info "Selected AWS profile: $SELECTED_PROFILE"
    fi

    if detect_aws_auth; then
        log_info "Profile authentication successful"
        print_success "Profile authentication successful"
    else
        log_error "Profile authentication failed for: $SELECTED_PROFILE"
        print_error "Profile authentication failed"
        echo ""
        echo "If using SSO, run: aws sso login --profile $SELECTED_PROFILE"
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

deploy() {
    log_step "Deploying to stage: $STAGE"

    # Bump version
    log_info "Bumping version..."
    if ! npm run version:patch >> "$LOG_FILE" 2>&1; then
        log_warn "Version bump failed (continuing anyway)"
    fi
    VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "unknown")
    log_info "Version: $VERSION"
    print_info "Version: $VERSION"

    # Run SST deploy (this is the long operation - use extended timeout)
    echo ""
    log_info "Starting SST deployment (this may take several minutes)..."
    print_info "Starting SST deployment..."
    echo ""

    local SST_TIMEOUT=$((DEFAULT_TIMEOUT * 2))  # Double timeout for deployment
    log_info "SST deployment timeout: ${SST_TIMEOUT}s"

    local deploy_cmd
    if [ -n "$PROFILE" ]; then
        deploy_cmd="AWS_PROFILE=$PROFILE npx sst deploy --stage $STAGE"
        log_info "Running: $deploy_cmd"
        if ! run_with_timeout "$SST_TIMEOUT" "SST deployment to $STAGE" bash -c "AWS_PROFILE=\"$PROFILE\" npx sst deploy --stage \"$STAGE\""; then
            log_error "SST deployment failed or timed out"
            print_error "Deployment failed! Check logs at: $LOG_FILE"
            exit 1
        fi
    else
        deploy_cmd="npx sst deploy --stage $STAGE"
        log_info "Running: $deploy_cmd"
        if ! run_with_timeout "$SST_TIMEOUT" "SST deployment to $STAGE" npx sst deploy --stage "$STAGE"; then
            log_error "SST deployment failed or timed out"
            print_error "Deployment failed! Check logs at: $LOG_FILE"
            exit 1
        fi
    fi

    log_info "Deployment completed successfully"
    print_success "Deployment complete!"
}

#######################################################################
# Unlock SST State
#######################################################################

unlock_app() {
    log_step "Unlocking SST state"

    print_info "Running sst unlock with telemetry disabled..."
    echo ""

    local unlock_cmd
    if [ -n "$PROFILE" ]; then
        unlock_cmd="AWS_PROFILE=$PROFILE npx sst unlock"
        log_info "Running: $unlock_cmd"
        if ! run_with_timeout "$DEFAULT_TIMEOUT" "SST unlock" bash -c "AWS_PROFILE=\"$PROFILE\" npx sst unlock"; then
            log_error "SST unlock failed"
            print_error "Unlock failed! Check logs at: $LOG_FILE"
            exit 1
        fi
    else
        unlock_cmd="npx sst unlock"
        log_info "Running: $unlock_cmd"
        if ! run_with_timeout "$DEFAULT_TIMEOUT" "SST unlock" npx sst unlock; then
            log_error "SST unlock failed"
            print_error "Unlock failed! Check logs at: $LOG_FILE"
            exit 1
        fi
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
    log_info "  NON_INTERACTIVE: $NON_INTERACTIVE"
    log_info "  VERBOSE: $VERBOSE"
    log_info "  FORCE_NO_TELEMETRY: $FORCE_NO_TELEMETRY"
    log_info "  DEFAULT_TIMEOUT: ${DEFAULT_TIMEOUT}s"
    log_info "  LOG_FILE: $LOG_FILE"

    check_prerequisites
    detect_corporate_network

    # Log updated config after CN detection
    if [ "$IN_CORPORATE_NETWORK" = true ]; then
        log_info "  IN_CORPORATE_NETWORK: true (telemetry disabled)"
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

    install_dependencies
    select_stage
    deploy
    show_outputs

    log_info "Setup script completed successfully"
}

# Trap to log errors on exit
trap 'log_error "Script exited with code $?"' ERR

main "$@"
