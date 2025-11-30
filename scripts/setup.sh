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
#   ./scripts/setup.sh --help       # Show help
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
STAGE=""
CHECK_ONLY=false
PROFILE=""

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
    echo "  --stage <name>    Deploy to specific stage (dev, int, prod, or custom)"
    echo "  --profile <name>  Use specific AWS profile"
    echo "  --check           Check AWS credentials only (no deployment)"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./scripts/setup.sh                    # Interactive setup"
    echo "  ./scripts/setup.sh --stage dev        # Deploy to dev stage"
    echo "  ./scripts/setup.sh --profile tanfra   # Use tanfra AWS profile"
    echo "  ./scripts/setup.sh --check            # Verify AWS credentials"
    echo ""
    echo "For SSO authentication:"
    echo "  aws sso login --profile your-profile"
    echo "  ./scripts/setup.sh --profile your-profile"
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
    print_step "Checking prerequisites..."

    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed"
        echo "  Install from: https://nodejs.org/"
        exit 1
    fi
    NODE_VERSION=$(node -v)
    print_success "Node.js $NODE_VERSION"

    # Check npm
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed"
        exit 1
    fi
    NPM_VERSION=$(npm -v)
    print_success "npm $NPM_VERSION"

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        echo ""
        echo "  Install instructions:"
        echo "  - macOS: brew install awscli"
        echo "  - Linux: curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'"
        echo "  - Windows: https://awscli.amazonaws.com/AWSCLIV2.msi"
        exit 1
    fi
    AWS_VERSION=$(aws --version | cut -d' ' -f1)
    print_success "AWS CLI $AWS_VERSION"

    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        print_error "package.json not found. Run this script from the project root."
        exit 1
    fi
    print_success "Project structure OK"
}

#######################################################################
# AWS Authentication
#######################################################################

detect_aws_auth() {
    print_step "Detecting AWS authentication..."

    # If profile specified, set it
    if [ -n "$PROFILE" ]; then
        export AWS_PROFILE="$PROFILE"
        print_info "Using AWS profile: $PROFILE"
    fi

    # Try to get caller identity
    if ! IDENTITY=$(aws sts get-caller-identity 2>&1); then
        return 1
    fi

    ACCOUNT_ID=$(echo "$IDENTITY" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
    USER_ARN=$(echo "$IDENTITY" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)

    if [ -n "$ACCOUNT_ID" ]; then
        print_success "AWS Account: $ACCOUNT_ID"
        print_success "Identity: $USER_ARN"
        return 0
    fi

    return 1
}

setup_aws_auth() {
    print_step "Setting up AWS authentication..."

    # Check if already authenticated
    if detect_aws_auth; then
        return 0
    fi

    echo ""
    echo "No valid AWS credentials found. Choose authentication method:"
    echo ""
    echo "  1) AWS SSO (Corporate/Enterprise)"
    echo "  2) AWS Profile (Pre-configured)"
    echo "  3) IAM User Credentials (Access Key)"
    echo "  4) Exit"
    echo ""
    read -p "Select option [1-4]: " AUTH_CHOICE

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
            print_info "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
}

setup_sso_auth() {
    print_step "Setting up AWS SSO authentication..."

    echo ""
    echo "Available SSO profiles in ~/.aws/config:"
    grep -E "^\[profile.*sso" ~/.aws/config 2>/dev/null | sed 's/\[profile /  - /g' | sed 's/\]//g' || echo "  No SSO profiles found"
    echo ""

    read -p "Enter SSO profile name: " SSO_PROFILE

    if [ -z "$SSO_PROFILE" ]; then
        print_error "Profile name required"
        exit 1
    fi

    print_info "Initiating SSO login for profile: $SSO_PROFILE"
    aws sso login --profile "$SSO_PROFILE"

    export AWS_PROFILE="$SSO_PROFILE"
    PROFILE="$SSO_PROFILE"

    if detect_aws_auth; then
        print_success "SSO authentication successful"
    else
        print_error "SSO authentication failed"
        exit 1
    fi
}

setup_profile_auth() {
    print_step "Setting up AWS profile authentication..."

    echo ""
    echo "Available AWS profiles:"
    grep -E "^\[" ~/.aws/credentials 2>/dev/null | sed 's/\[/  - /g' | sed 's/\]//g' || echo "  No profiles in credentials file"
    grep -E "^\[profile" ~/.aws/config 2>/dev/null | sed 's/\[profile /  - /g' | sed 's/\]//g' || true
    echo ""

    read -p "Enter profile name (or press Enter for default): " SELECTED_PROFILE

    if [ -n "$SELECTED_PROFILE" ]; then
        export AWS_PROFILE="$SELECTED_PROFILE"
        PROFILE="$SELECTED_PROFILE"
    fi

    if detect_aws_auth; then
        print_success "Profile authentication successful"
    else
        print_error "Profile authentication failed"
        echo ""
        echo "If using SSO, run: aws sso login --profile $SELECTED_PROFILE"
        exit 1
    fi
}

setup_iam_auth() {
    print_step "Setting up IAM user credentials..."

    echo ""
    print_warning "Using long-term credentials is less secure than SSO."
    print_info "Consider using AWS SSO for better security."
    echo ""

    read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID_INPUT
    read -s -p "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY_INPUT
    echo ""
    read -p "AWS Region [eu-central-1]: " AWS_REGION_INPUT

    AWS_REGION_INPUT=${AWS_REGION_INPUT:-eu-central-1}

    export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID_INPUT"
    export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY_INPUT"
    export AWS_DEFAULT_REGION="$AWS_REGION_INPUT"

    if detect_aws_auth; then
        print_success "IAM authentication successful"

        echo ""
        read -p "Save credentials to AWS profile? [y/N]: " SAVE_CREDS
        if [[ "$SAVE_CREDS" =~ ^[Yy]$ ]]; then
            read -p "Profile name [default]: " PROFILE_NAME
            PROFILE_NAME=${PROFILE_NAME:-default}

            aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID_INPUT" --profile "$PROFILE_NAME"
            aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY_INPUT" --profile "$PROFILE_NAME"
            aws configure set region "$AWS_REGION_INPUT" --profile "$PROFILE_NAME"

            print_success "Credentials saved to profile: $PROFILE_NAME"
        fi
    else
        print_error "IAM authentication failed"
        exit 1
    fi
}

#######################################################################
# Install Dependencies
#######################################################################

install_dependencies() {
    print_step "Installing dependencies..."

    if [ ! -d "node_modules" ]; then
        npm install
        print_success "Dependencies installed"
    else
        print_info "Dependencies already installed"
        read -p "Run npm install anyway? [y/N]: " REINSTALL
        if [[ "$REINSTALL" =~ ^[Yy]$ ]]; then
            npm install
            print_success "Dependencies reinstalled"
        fi
    fi
}

#######################################################################
# Deploy
#######################################################################

select_stage() {
    if [ -n "$STAGE" ]; then
        return 0
    fi

    print_step "Select deployment stage..."

    echo ""
    echo "Available stages:"
    echo "  1) Personal stage (your username: $USER)"
    echo "  2) dev - Development environment"
    echo "  3) int - Integration/staging environment"
    echo "  4) prod - Production environment"
    echo "  5) Custom stage name"
    echo ""
    read -p "Select option [1-5]: " STAGE_CHOICE

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
            read -p "Enter custom stage name: " STAGE
            ;;
        *)
            STAGE="$USER"
            ;;
    esac

    print_info "Selected stage: $STAGE"
}

deploy() {
    print_step "Deploying to stage: $STAGE"

    # Bump version
    npm run version:patch
    VERSION=$(node -p "require('./package.json').version")
    print_info "Version: $VERSION"

    # Run SST deploy
    echo ""
    print_info "Starting SST deployment..."
    echo ""

    if [ -n "$PROFILE" ]; then
        AWS_PROFILE="$PROFILE" npx sst deploy --stage "$STAGE"
    else
        npx sst deploy --stage "$STAGE"
    fi

    print_success "Deployment complete!"
}

show_outputs() {
    print_step "Deployment outputs"

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
}

#######################################################################
# Main
#######################################################################

main() {
    print_banner

    check_prerequisites
    setup_aws_auth

    if [ "$CHECK_ONLY" = true ]; then
        print_success "AWS credentials verified successfully"
        exit 0
    fi

    install_dependencies
    select_stage
    deploy
    show_outputs
}

main
