#!/bin/bash
#######################################################################
# create-deployment-cache.sh
# Creates a portable cache bundle for offline SST deployment
#
# Run this from an unrestricted network (home) AFTER a successful deployment
# to create a cache bundle that can be used in restricted networks.
#
# Usage:
#   ./scripts/create-deployment-cache.sh                    # Cache Pulumi + SST only
#   ./scripts/create-deployment-cache.sh --include-node-modules  # Include node_modules
#   ./scripts/create-deployment-cache.sh --help             # Show help
#
# The cache enables deployment in air-gapped/restricted networks where:
# - npm registry is blocked
# - GitHub is blocked
# - Only AWS endpoints are accessible
#######################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CACHE_DIR="$PROJECT_ROOT/.deployment-cache"

# Options
INCLUDE_NODE_MODULES=false
FORCE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${CYAN}ℹ${NC} $1"; }

show_help() {
    echo "Usage: ./scripts/create-deployment-cache.sh [OPTIONS]"
    echo ""
    echo "Creates a portable cache for offline/air-gapped SST deployment."
    echo ""
    echo "Options:"
    echo "  --include-node-modules  Include node_modules in cache (required for air-gapped)"
    echo "  --force                 Overwrite existing cache without prompting"
    echo "  --help                  Show this help message"
    echo ""
    echo "What gets cached:"
    echo "  - Pulumi plugins (~200MB for AWS provider)"
    echo "  - SST binaries (Pulumi, Bun)"
    echo "  - node_modules (if --include-node-modules, ~200-500MB)"
    echo ""
    echo "Requirements:"
    echo "  - Must run AFTER a successful deployment (to have cached binaries)"
    echo "  - Run from unrestricted network with full internet access"
    echo ""
    echo "Usage in restricted network:"
    echo "  1. Copy .deployment-cache/ to restricted machine"
    echo "  2. Run: ./scripts/setup.sh --stage dev"
    echo "  3. Script auto-detects cache and uses it"
    echo ""
    echo "See docs-content/sst-deployment-network-requirements.md for details"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --include-node-modules)
            INCLUDE_NODE_MODULES=true
            shift
            ;;
        --force)
            FORCE=true
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

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}        ${BOLD}SST Deployment Cache Creator${NC}                        ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if we've had a successful deployment
if [ ! -d "$HOME/.pulumi/plugins" ] || [ -z "$(ls -A $HOME/.pulumi/plugins 2>/dev/null)" ]; then
    print_error "No Pulumi plugins found in ~/.pulumi/plugins"
    echo ""
    print_info "Please run a successful deployment first:"
    echo "  ./scripts/setup.sh --stage dev"
    echo ""
    exit 1
fi

# Check for AWS provider specifically
AWS_PROVIDER=$(ls -d $HOME/.pulumi/plugins/resource-aws-* 2>/dev/null | head -1)
if [ -z "$AWS_PROVIDER" ]; then
    print_error "AWS provider not found in Pulumi plugins"
    echo ""
    print_info "Please run a successful deployment first:"
    echo "  ./scripts/setup.sh --stage dev"
    echo ""
    exit 1
fi

print_success "Found AWS provider: $(basename $AWS_PROVIDER)"

# Check for node_modules if including
if [ "$INCLUDE_NODE_MODULES" = true ]; then
    if [ ! -d "$PROJECT_ROOT/node_modules" ]; then
        print_error "node_modules not found"
        echo ""
        print_info "Run npm install first:"
        echo "  npm install"
        echo ""
        exit 1
    fi
    NODE_MODULES_SIZE=$(du -sh "$PROJECT_ROOT/node_modules" | cut -f1)
    print_success "Found node_modules: $NODE_MODULES_SIZE"
fi

# Check if cache already exists
if [ -d "$CACHE_DIR" ]; then
    if [ "$FORCE" = true ]; then
        print_warning "Removing existing cache (--force)"
        rm -rf "$CACHE_DIR"
    else
        echo ""
        print_warning "Cache already exists at $CACHE_DIR"
        read -p "Overwrite? [y/N]: " OVERWRITE
        if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
            print_info "Aborted"
            exit 0
        fi
        rm -rf "$CACHE_DIR"
    fi
fi

# Create cache directory structure
echo ""
print_info "Creating cache directory..."
mkdir -p "$CACHE_DIR/pulumi-plugins"
mkdir -p "$CACHE_DIR/sst-binaries"

# Copy Pulumi plugins
echo ""
print_info "Copying Pulumi plugins..."
cp -r $HOME/.pulumi/plugins/* "$CACHE_DIR/pulumi-plugins/"
PULUMI_SIZE=$(du -sh "$CACHE_DIR/pulumi-plugins" | cut -f1)
print_success "Pulumi plugins: $PULUMI_SIZE"

# Copy SST binaries if they exist (macOS)
SST_APP_SUPPORT="$HOME/Library/Application Support/sst"
if [ -d "$SST_APP_SUPPORT" ]; then
    print_info "Copying SST binaries..."
    cp -r "$SST_APP_SUPPORT"/* "$CACHE_DIR/sst-binaries/" 2>/dev/null || true
    SST_SIZE=$(du -sh "$CACHE_DIR/sst-binaries" | cut -f1)
    print_success "SST binaries: $SST_SIZE"
else
    print_warning "SST binaries not found (may be in different location on Linux)"
fi

# Copy node_modules if requested
if [ "$INCLUDE_NODE_MODULES" = true ]; then
    echo ""
    print_info "Copying node_modules (this may take a while)..."
    cp -r "$PROJECT_ROOT/node_modules" "$CACHE_DIR/node_modules"
    CACHED_NODE_MODULES_SIZE=$(du -sh "$CACHE_DIR/node_modules" | cut -f1)
    print_success "node_modules: $CACHED_NODE_MODULES_SIZE"
fi

# Create manifest file
print_info "Creating manifest..."
cat > "$CACHE_DIR/manifest.json" << EOF
{
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "created_by": "$(whoami)",
  "hostname": "$(hostname)",
  "node_version": "$(node --version 2>/dev/null || echo 'unknown')",
  "npm_version": "$(npm --version 2>/dev/null || echo 'unknown')",
  "aws_provider": "$(basename $AWS_PROVIDER)",
  "includes_node_modules": $INCLUDE_NODE_MODULES,
  "pulumi_plugins": $(ls "$CACHE_DIR/pulumi-plugins" 2>/dev/null | jq -R -s -c 'split("\n") | map(select(length > 0))' || echo '[]'),
  "notes": "Cache created for offline SST deployment. Use with setup.sh in air-gapped networks."
}
EOF

# Calculate total size
CACHE_SIZE=$(du -sh "$CACHE_DIR" | cut -f1)

# Summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}              ${BOLD}Cache Created Successfully${NC}                     ${GREEN}║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Location: $CACHE_DIR"
echo "Total size: $CACHE_SIZE"
echo ""
echo "Contents:"
ls -la "$CACHE_DIR"
echo ""

# Show manifest
echo "Manifest:"
cat "$CACHE_DIR/manifest.json" | head -15
echo ""

# Next steps
echo -e "${BOLD}Next steps:${NC}"
echo ""
echo "Option 1: Commit to repository"
echo "  git add .deployment-cache"
echo "  git commit -m 'Add deployment cache for offline use'"
echo "  git push"
echo ""
echo "Option 2: Create tarball for transfer"
echo "  cd $PROJECT_ROOT"
echo "  tar -czf deployment-cache.tar.gz .deployment-cache"
echo "  # Transfer deployment-cache.tar.gz to restricted machine"
echo "  # On restricted machine: tar -xzf deployment-cache.tar.gz"
echo ""
echo "Usage in restricted network:"
echo "  ./scripts/setup.sh --stage dev"
echo "  # Script auto-detects cache and uses it"
echo ""

# Warn if node_modules not included
if [ "$INCLUDE_NODE_MODULES" = false ]; then
    print_warning "node_modules NOT included in cache"
    print_info "For fully air-gapped deployment, re-run with:"
    echo "  ./scripts/create-deployment-cache.sh --include-node-modules"
    echo ""
fi
