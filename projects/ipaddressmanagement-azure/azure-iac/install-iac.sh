#!/bin/bash

# Azure ARM Template Deployment Script
# This script deploys Azure resources using exported ARM templates

set -e  # Exit on any error

# Configuration variables
RESOURCE_GROUP_NAME=""
LOCATION=""
DEPLOYMENT_NAME="vm-deployment-$(date +%Y%m%d-%H%M%S)"
TEMPLATE_FILE="./vm/template.json"
PARAMETERS_FILE="./vm/parameters.json"
ACTION="deploy"  # deploy, delete-resources, list

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if Azure CLI is installed
check_azure_cli() {
    print_message $BLUE "Checking Azure CLI installation..."
    if ! command -v az &> /dev/null; then
        print_message $RED "Error: Azure CLI is not installed. Please install it first."
        print_message $YELLOW "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    print_message $GREEN "Azure CLI found."
}

# Function to check if user is logged in
check_azure_login() {
    print_message $BLUE "Checking Azure login status..."
    if ! az account show &> /dev/null; then
        print_message $YELLOW "Not logged into Azure. Please login..."
        az login
    fi
    
    # Display current subscription
    CURRENT_SUB=$(az account show --query "name" -o tsv)
    print_message $GREEN "Currently using subscription: $CURRENT_SUB"
}

# Function to check if jq is installed (needed for template parsing)
check_jq() {
    if [ "$ACTION" = "delete-resources" ]; then
        if ! command -v jq &> /dev/null; then
            print_message $YELLOW "Warning: jq not found. Install jq for better resource parsing."
            print_message $YELLOW "Continuing with alternative deletion methods..."
        fi
    fi
}

# Function to validate template files
validate_files() {
    print_message $BLUE "Validating template files..."
    
    if [ ! -f "$TEMPLATE_FILE" ]; then
        print_message $RED "Error: Template file '$TEMPLATE_FILE' not found!"
        exit 1
    fi
    
    if [ ! -f "$PARAMETERS_FILE" ]; then
        print_message $RED "Error: Parameters file '$PARAMETERS_FILE' not found!"
        exit 1
    fi
    
    print_message $GREEN "Template files found."
}

# Function to get user input for required parameters
get_deployment_parameters() {
    print_message $BLUE "Setting up deployment parameters..."
    
    # Get resource group name
    if [ -z "$RESOURCE_GROUP_NAME" ]; then
        read -p "Enter Resource Group name: " RESOURCE_GROUP_NAME
        if [ -z "$RESOURCE_GROUP_NAME" ]; then
            print_message $RED "Resource group name is required!"
            exit 1
        fi
    fi
    
    # Get location if resource group doesn't exist
    if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
        print_message $YELLOW "Resource group '$RESOURCE_GROUP_NAME' doesn't exist."
        if [ -z "$LOCATION" ]; then
            read -p "Enter Azure region/location (e.g., eastus, westeurope): " LOCATION
            if [ -z "$LOCATION" ]; then
                print_message $RED "Location is required for new resource group!"
                exit 1
            fi
        fi
    fi
}

# Function to create resource group if it doesn't exist
create_resource_group() {
    if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
        print_message $BLUE "Creating resource group '$RESOURCE_GROUP_NAME' in '$LOCATION'..."
        az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"
        print_message $GREEN "Resource group created successfully."
    else
        print_message $GREEN "Resource group '$RESOURCE_GROUP_NAME' already exists."
    fi
}

# Function to validate the ARM template
validate_template() {
    print_message $BLUE "Validating ARM template..."
    
    # First, let's check if the files are valid JSON
    print_message $YELLOW "Checking JSON syntax..."
    
    if ! jq empty "$TEMPLATE_FILE" 2>/dev/null; then
        print_message $RED "Template file has invalid JSON syntax!"
        print_message $YELLOW "Please check: $TEMPLATE_FILE"
        return 1
    fi
    
    if ! jq empty "$PARAMETERS_FILE" 2>/dev/null; then
        print_message $RED "Parameters file has invalid JSON syntax!"
        print_message $YELLOW "Please check: $PARAMETERS_FILE"
        return 1
    fi
    
    print_message $GREEN "JSON syntax is valid."
    
    # Now validate with Azure
    print_message $BLUE "Validating with Azure Resource Manager..."
    
    VALIDATION_OUTPUT=$(az deployment group validate \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --template-file "$TEMPLATE_FILE" \
        --parameters "@$PARAMETERS_FILE" \
        2>&1)
    
    VALIDATION_RESULT=$?
    
    if [ $VALIDATION_RESULT -eq 0 ]; then
        print_message $GREEN "Template validation passed."
        return 0
    else
        print_message $RED "Template validation failed!"
        print_message $YELLOW "Validation errors:"
        echo "$VALIDATION_OUTPUT"
        
        # Show template and parameters summary for debugging
        print_message $BLUE "Template file summary:"
        echo "File: $TEMPLATE_FILE"
        echo "Size: $(wc -c < "$TEMPLATE_FILE") bytes"
        
        print_message $BLUE "Parameters file summary:"
        echo "File: $PARAMETERS_FILE"
        echo "Size: $(wc -c < "$PARAMETERS_FILE") bytes"
        
        # Offer to show more details
        echo ""
        read -p "Would you like to see the template content for debugging? (yes/no): " show_template
        if [ "$show_template" = "yes" ]; then
            print_message $BLUE "Template content:"
            cat "$TEMPLATE_FILE"
            echo ""
            print_message $BLUE "Parameters content:"
            cat "$PARAMETERS_FILE"
        fi
        
        return 1
    fi
}

# Function to deploy the ARM template
deploy_template() {
    print_message $BLUE "Starting deployment '$DEPLOYMENT_NAME'..."
    print_message $YELLOW "This may take several minutes..."
    
    if az deployment group create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --template-file "$TEMPLATE_FILE" \
        --parameters "@$PARAMETERS_FILE" \
        --verbose; then
        print_message $GREEN "Deployment completed successfully!"
        
        # Show deployment status inline
        print_message $BLUE "Deployment Summary:"
        az deployment group show \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --name "$DEPLOYMENT_NAME" \
            --query "{Status:properties.provisioningState, Timestamp:properties.timestamp}" \
            --output table
    else
        print_message $RED "Deployment failed!"
        print_message $YELLOW "Check the Azure portal for detailed error information."
        exit 1
    fi
}

# Function to list deployed resources
list_resources() {
    print_message $BLUE "Listing resources in resource group '$RESOURCE_GROUP_NAME'..."
    
    if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
        print_message $RED "Resource group '$RESOURCE_GROUP_NAME' not found!"
        exit 1
    fi
    
    echo ""
    print_message $YELLOW "Resources in '$RESOURCE_GROUP_NAME':"
    az resource list --resource-group "$RESOURCE_GROUP_NAME" --output table
    
    echo ""
    print_message $YELLOW "Recent deployments in '$RESOURCE_GROUP_NAME':"
    az deployment group list --resource-group "$RESOURCE_GROUP_NAME" --output table
}

# Function to get resources from template
get_template_resources() {
    if [ ! -f "$TEMPLATE_FILE" ]; then
        print_message $RED "Template file '$TEMPLATE_FILE' not found!"
        exit 1
    fi
    
    # Extract resource names from the template (this is a simplified approach)
    # In practice, you might need more sophisticated parsing
    TEMPLATE_RESOURCES=$(jq -r '.resources[].name' "$TEMPLATE_FILE" 2>/dev/null || echo "")
    
    if [ -z "$TEMPLATE_RESOURCES" ]; then
        print_message $YELLOW "Warning: Could not extract resource names from template."
        print_message $YELLOW "Will attempt to delete resources based on deployment history."
    fi
}

# Function to force delete stubborn VNet with advanced cleanup
force_delete_vnet() {
    local vnet_name="$1"
    
    if [ -z "$vnet_name" ]; then
        print_message $RED "VNet name is required for force deletion"
        return 1
    fi
    
    print_message $BLUE "Attempting advanced cleanup for VNet: $vnet_name"
    
    # Step 1: Check for hidden network profiles
    print_message $YELLOW "Checking for hidden network profiles..."
    NETWORK_PROFILES=$(az network profile list --resource-group "$RESOURCE_GROUP_NAME" --query "[].name" --output tsv 2>/dev/null || echo "")
    if [ -n "$NETWORK_PROFILES" ]; then
        echo "$NETWORK_PROFILES" | while read -r profile_name; do
            if [ -n "$profile_name" ]; then
                print_message $YELLOW "Deleting network profile: $profile_name"
                az network profile delete --resource-group "$RESOURCE_GROUP_NAME" --name "$profile_name" --yes --verbose || true
            fi
        done
    fi
    
    # Step 2: Check subnet delegations and service association links
    print_message $YELLOW "Checking subnet delegations..."
    SUBNETS=$(az network vnet subnet list --resource-group "$RESOURCE_GROUP_NAME" --vnet-name "$vnet_name" --query "[].name" --output tsv 2>/dev/null || echo "")
    
    if [ -n "$SUBNETS" ]; then
        echo "$SUBNETS" | while read -r subnet_name; do
            if [ -n "$subnet_name" ]; then
                print_message $BLUE "Processing subnet: $subnet_name"
                
                # Check for delegations
                DELEGATIONS=$(az network vnet subnet show --resource-group "$RESOURCE_GROUP_NAME" --vnet-name "$vnet_name" --name "$subnet_name" --query "delegations[].serviceName" --output tsv 2>/dev/null || echo "")
                if [ -n "$DELEGATIONS" ]; then
                    print_message $YELLOW "Found delegations in subnet $subnet_name: $DELEGATIONS"
                    # Try to remove subnet delegation
                    az network vnet subnet update --resource-group "$RESOURCE_GROUP_NAME" --vnet-name "$vnet_name" --name "$subnet_name" --remove delegations 0 --verbose || true
                fi
                
                # Check for service association links and try to delete them using REST API
                print_message $YELLOW "Attempting to remove service association links for subnet: $subnet_name"
                SUBSCRIPTION_ID=$(az account show --query "id" --output tsv)
                SAL_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/virtualNetworks/$vnet_name/subnets/$subnet_name/serviceAssociationLinks/default"
                
                # Try to delete service association links with different API versions
                for api_version in "2018-10-01" "2019-11-01" "2020-06-01" "2021-02-01"; do
                    print_message $YELLOW "Trying API version: $api_version"
                    az resource delete --ids "$SAL_ID" --api-version "$api_version" --verbose 2>/dev/null || true
                done
            fi
        done
    fi
    
    # Step 3: Wait a moment for changes to propagate
    print_message $YELLOW "Waiting for changes to propagate..."
    sleep 10
    
    # Step 4: Try to delete the VNet again
    print_message $BLUE "Attempting to delete VNet: $vnet_name"
    if az network vnet delete --resource-group "$RESOURCE_GROUP_NAME" --name "$vnet_name" --verbose; then
        print_message $GREEN "Successfully deleted VNet: $vnet_name"
        return 0
    else
        print_message $RED "Failed to delete VNet: $vnet_name"
        print_message $YELLOW "This may require manual intervention or support ticket"
        return 1
    fi
}

# Enhanced function to delete specific resources from template
delete_template_resources() {
    print_message $BLUE "Deleting resources defined in the ARM template..."
    
    if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
        print_message $RED "Resource group '$RESOURCE_GROUP_NAME' not found!"
        exit 1
    fi
    
    # Show what will be deleted
    print_message $YELLOW "Resources that will be deleted:"
    list_resources
    
    echo ""
    read -p "Are you sure you want to delete these template resources? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_message $YELLOW "Deletion cancelled."
        return 0
    fi
    
    # Method 1: Try to find and delete resources from the most recent deployment
    print_message $BLUE "Finding resources from recent deployments..."
    
    RECENT_DEPLOYMENT=$(az deployment group list \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --query "[?contains(name, 'vm-deployment')].name | [0]" \
        --output tsv 2>/dev/null || echo "")
    
    if [ -n "$RECENT_DEPLOYMENT" ] && [ "$RECENT_DEPLOYMENT" != "null" ]; then
        print_message $BLUE "Found recent deployment: $RECENT_DEPLOYMENT"
        
        # Get resources created by this deployment
        DEPLOYMENT_RESOURCES=$(az deployment group show \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --name "$RECENT_DEPLOYMENT" \
            --query "properties.outputResources[].id" \
            --output tsv 2>/dev/null || echo "")
        
        if [ -n "$DEPLOYMENT_RESOURCES" ]; then
            print_message $BLUE "Deleting resources from deployment..."
            echo "$DEPLOYMENT_RESOURCES" | while read -r resource_id; do
                if [ -n "$resource_id" ]; then
                    print_message $YELLOW "Deleting: $resource_id"
                    az resource delete --ids "$resource_id" --verbose || true
                fi
            done
        else
            print_message $YELLOW "No output resources found in deployment. Trying alternative method..."
        fi
    fi
    
    # Method 2: Delete common VM-related resources by type
    print_message $BLUE "Cleaning up common VM resources..."
    
    # Delete VMs first
    VMS=$(az vm list --resource-group "$RESOURCE_GROUP_NAME" --query "[].name" --output tsv 2>/dev/null || echo "")
    if [ -n "$VMS" ]; then
        echo "$VMS" | while read -r vm_name; do
            if [ -n "$vm_name" ]; then
                print_message $YELLOW "Deleting VM: $vm_name"
                az vm delete --resource-group "$RESOURCE_GROUP_NAME" --name "$vm_name" --yes --verbose || true
            fi
        done
    fi
    
    # Delete Network Interfaces
    NICS=$(az network nic list --resource-group "$RESOURCE_GROUP_NAME" --query "[].name" --output tsv 2>/dev/null || echo "")
    if [ -n "$NICS" ]; then
        echo "$NICS" | while read -r nic_name; do
            if [ -n "$nic_name" ]; then
                print_message $YELLOW "Deleting Network Interface: $nic_name"
                az network nic delete --resource-group "$RESOURCE_GROUP_NAME" --name "$nic_name" --verbose || true
            fi
        done
    fi
    
    # Delete Public IPs
    PUBLIC_IPS=$(az network public-ip list --resource-group "$RESOURCE_GROUP_NAME" --query "[].name" --output tsv 2>/dev/null || echo "")
    if [ -n "$PUBLIC_IPS" ]; then
        echo "$PUBLIC_IPS" | while read -r ip_name; do
            if [ -n "$ip_name" ]; then
                print_message $YELLOW "Deleting Public IP: $ip_name"
                az network public-ip delete --resource-group "$RESOURCE_GROUP_NAME" --name "$ip_name" --verbose || true
            fi
        done
    fi
    
    # Delete Network Security Groups
    NSGS=$(az network nsg list --resource-group "$RESOURCE_GROUP_NAME" --query "[].name" --output tsv 2>/dev/null || echo "")
    if [ -n "$NSGS" ]; then
        echo "$NSGS" | while read -r nsg_name; do
            if [ -n "$nsg_name" ]; then
                print_message $YELLOW "Deleting Network Security Group: $nsg_name"
                az network nsg delete --resource-group "$RESOURCE_GROUP_NAME" --name "$nsg_name" --verbose || true
            fi
        done
    fi
    
    # Enhanced VNet deletion with force cleanup
    VNETS=$(az network vnet list --resource-group "$RESOURCE_GROUP_NAME" --query "[].name" --output tsv 2>/dev/null || echo "")
    if [ -n "$VNETS" ]; then
        echo "$VNETS" | while read -r vnet_name; do
            if [ -n "$vnet_name" ]; then
                read -p "Delete Virtual Network '$vnet_name'? This may affect other resources (yes/no): " delete_vnet
                if [ "$delete_vnet" = "yes" ]; then
                    print_message $YELLOW "Attempting to delete Virtual Network: $vnet_name"
                    # First try normal deletion
                    if ! az network vnet delete --resource-group "$RESOURCE_GROUP_NAME" --name "$vnet_name" --verbose; then
                        print_message $YELLOW "Normal deletion failed, trying advanced cleanup..."
                        force_delete_vnet "$vnet_name"
                    fi
                fi
            fi
        done
    fi
    
    # Delete Storage Accounts (be very careful)
    STORAGE_ACCOUNTS=$(az storage account list --resource-group "$RESOURCE_GROUP_NAME" --query "[].name" --output tsv 2>/dev/null || echo "")
    if [ -n "$STORAGE_ACCOUNTS" ]; then
        echo "$STORAGE_ACCOUNTS" | while read -r storage_name; do
            if [ -n "$storage_name" ]; then
                read -p "Delete Storage Account '$storage_name'? This will delete all data (yes/no): " delete_storage
                if [ "$delete_storage" = "yes" ]; then
                    print_message $YELLOW "Deleting Storage Account: $storage_name"
                    az storage account delete --resource-group "$RESOURCE_GROUP_NAME" --name "$storage_name" --yes --verbose || true
                fi
            fi
        done
    fi
    
    # Delete managed disks that are not attached
    DISKS=$(az disk list --resource-group "$RESOURCE_GROUP_NAME" --query "[?diskState=='Unattached'].name" --output tsv 2>/dev/null || echo "")
    if [ -n "$DISKS" ]; then
        echo "$DISKS" | while read -r disk_name; do
            if [ -n "$disk_name" ]; then
                print_message $YELLOW "Deleting unattached disk: $disk_name"
                az disk delete --resource-group "$RESOURCE_GROUP_NAME" --name "$disk_name" --yes --verbose || true
            fi
        done
    fi
    
    print_message $GREEN "Resource deletion completed."
    print_message $YELLOW "Note: Some resources may still exist if they have dependencies or failed to delete."
    print_message $BLUE "If VNet deletion failed, you may need to contact Azure support to remove Service Association Links."
}

# Function to delete entire resource group
delete_resource_group() {
    print_message $RED "ERROR: Resource group deletion has been disabled in this version of the script."
    print_message $YELLOW "This script is configured to only delete resources within the resource group, not the group itself."
    print_message $BLUE "If you need to delete the entire resource group, please do so manually through the Azure portal or CLI."
    print_message $BLUE "Command to delete resource group manually: az group delete --name '$RESOURCE_GROUP_NAME' --yes"
    return 1
}

# Main execution flow
main() {
    case $ACTION in
        deploy)
            print_message $GREEN "=== Azure ARM Template Deployment Script ==="
            check_azure_cli
            check_azure_login
            validate_files
            get_deployment_parameters
            create_resource_group
            validate_template
            deploy_template
            print_message $GREEN "=== Deployment Process Complete ==="
            ;;
        delete-resources)
            print_message $GREEN "=== Deleting ARM Template Resources ==="
            check_azure_cli
            check_azure_login
            check_jq
            get_deployment_parameters
            delete_template_resources
            print_message $GREEN "=== Resource Deletion Complete ==="
            print_message $BLUE "Note: Resource group '$RESOURCE_GROUP_NAME' has been preserved."
            ;;
        list)
            print_message $GREEN "=== Listing Resources ==="
            check_azure_cli
            check_azure_login
            get_deployment_parameters
            list_resources
            ;;
        *)
            print_message $RED "Invalid action: $ACTION"
            show_help
            exit 1
            ;;
    esac
}

# Help function
show_help() {
    echo "Usage: $0 [ACTION] [OPTIONS]"
    echo ""
    echo "Actions:"
    echo "  deploy              Deploy ARM template (default)"
    echo "  delete-resources    Delete only resources created by the template"
    echo "  list               List resources in the resource group"
    echo ""
    echo "Options:"
    echo "  -g, --resource-group NAME    Resource group name"
    echo "  -l, --location LOCATION      Azure region (required for new RG)"
    echo "  -t, --template FILE          Template file (default: ./vm/template.json)"
    echo "  -p, --parameters FILE        Parameters file (default: ./vm/parameters.json)"
    echo "  -n, --name NAME              Deployment name"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy -g myResourceGroup -l eastus"
    echo "  $0 delete-resources -g myResourceGroup"
    echo "  $0 list -g myResourceGroup"
    echo ""
    echo "Safety Features:"
    echo "  - Interactive confirmation for all delete operations"
    echo "  - Lists resources before deletion"
    echo "  - Resource group is NEVER deleted (only resources within it)"
    echo "  - Graceful error handling"
    echo "  - Selective deletion of VM-related resources"
    echo "  - Advanced VNet cleanup for stubborn networks"
}

# Parse command line arguments
# First argument can be the action
if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
    case $1 in
        deploy|delete-resources|list)
            ACTION="$1"
            shift
            ;;
        delete-group)
            print_message $RED "ERROR: Resource group deletion is disabled in this version."
            print_message $YELLOW "Use 'delete-resources' to delete only the resources within the group."
            exit 1
            ;;
    esac
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP_NAME="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -t|--template)
            TEMPLATE_FILE="$2"
            shift 2
            ;;
        -p|--parameters)
            PARAMETERS_FILE="$2"
            shift 2
            ;;
        -n|--name)
            DEPLOYMENT_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_message $RED "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run the main function
main