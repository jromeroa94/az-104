#!/usr/bin/env bash
# scripts/deploy.sh
# One-command deployment for the AZ-104 Lab Landing Zone
#
# Prerequisites:
#   1. Azure CLI installed and logged in (az login)
#   2. SSH key generated: ssh-keygen -t ed25519 -C "az104-lab"
#   3. Set environment variable: export AZ104_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
#
# Usage:
#   chmod +x scripts/deploy.sh
#   ./scripts/deploy.sh

set -euo pipefail

# --- Configuration ---
RESOURCE_GROUP="rg-lab-dev-eus-001"
LOCATION="eastus"
TEMPLATE_FILE="main.bicep"
PARAMS_FILE="main.bicepparam"

# --- Color output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Pre-flight checks ---
log_info "Running pre-flight checks..."

if ! command -v az &> /dev/null; then
    log_error "Azure CLI not found. Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

if ! az account show &> /dev/null; then
    log_error "Not logged in. Run: az login"
    exit 1
fi

if [ -z "${AZ104_SSH_PUBLIC_KEY:-}" ]; then
    log_error "SSH public key not set. Run: export AZ104_SSH_PUBLIC_KEY=\"\$(cat ~/.ssh/id_ed25519.pub)\""
    exit 1
fi

# --- Show current context ---
ACCOUNT_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
log_info "Subscription: ${ACCOUNT_NAME} (${SUBSCRIPTION_ID})"
log_info "Resource Group: ${RESOURCE_GROUP}"
log_info "Location: ${LOCATION}"

echo ""
read -p "Continue with deployment? (y/N): " CONFIRM
if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
    log_warn "Deployment cancelled."
    exit 0
fi

# --- Create Resource Group ---
log_info "Creating resource group: ${RESOURCE_GROUP}..."
az group create \
    --name "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --tags environment=dev workload=lab managedBy=bicep purpose=az104-lab \
    --output none

# --- Deploy Bicep template ---
log_info "Deploying landing zone (this takes ~10-15 minutes due to Bastion)..."
az deployment group create \
    --resource-group "${RESOURCE_GROUP}" \
    --template-file "${TEMPLATE_FILE}" \
    --parameters "${PARAMS_FILE}" \
    --name "az104-lab-$(date +%Y%m%d-%H%M%S)" \
    --output table

log_info "Deployment complete!"

# --- Show outputs ---
echo ""
log_info "=== Deployment Summary ==="
az deployment group show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "$(az deployment group list --resource-group ${RESOURCE_GROUP} --query '[0].name' -o tsv)" \
    --query properties.outputs \
    --output table

echo ""
log_info "=== Next Steps ==="
echo "  1. Connect to VM via Bastion:"
echo "     az network bastion ssh --name bas-lab-dev-eus-001 --resource-group ${RESOURCE_GROUP} --target-resource-id <vm-resource-id> --auth-type ssh-key --username azureadmin --ssh-key ~/.ssh/id_ed25519"
echo ""
echo "  2. Or connect via Azure Portal:"
echo "     Portal > Virtual Machines > vm-lab-dev-eus-001 > Connect > Bastion"
echo ""
echo "  3. To destroy all resources when done:"
echo "     az group delete --name ${RESOURCE_GROUP} --yes --no-wait"
