#!/usr/bin/env bash

# CloudFormation Stack Deletion Script
# Description: Safely deletes the Multi-OS Infrastructure stack in eu-central-1

set -e  # Exit on any error

# Configuration
STACK_NAME="multi-os-infrastructure"
REGION="eu-central-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if stack exists
check_stack_exists() {
    aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION >/dev/null 2>&1
}

# Function to get stack status
get_stack_status() {
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null
}

# Function to show stack resources
show_stack_resources() {
    print_status "Current stack resources that will be deleted:"
    aws cloudformation describe-stack-resources \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'StackResources[*].[ResourceType,LogicalResourceId,ResourceStatus]' \
        --output table 2>/dev/null || {
        print_warning "Could not retrieve stack resources"
    }
}

# Function to show stack outputs
show_stack_outputs() {
    print_status "Current stack outputs:"
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table 2>/dev/null || {
        print_warning "No stack outputs found"
    }
}

# Main script starts here
echo "=================================="
echo "  CloudFormation Stack Deleter    "
echo "=================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check AWS credentials
print_status "Checking AWS credentials..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_error "AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

print_success "AWS credentials are valid"

# Check if stack exists
if ! check_stack_exists; then
    print_warning "Stack '$STACK_NAME' does not exist in region $REGION"
    print_status "Nothing to delete."
    exit 0
fi

# Get stack status
STACK_STATUS=$(get_stack_status)
print_status "Current stack status: $STACK_STATUS"

# Check if stack is in a deletable state
case $STACK_STATUS in
    *_IN_PROGRESS)
        print_error "Stack is currently in progress: $STACK_STATUS"
        print_error "Please wait for the current operation to complete before deleting."
        exit 1
        ;;
    *_FAILED)
        print_warning "Stack is in a failed state: $STACK_STATUS"
        print_warning "Deletion may help clean up failed resources."
        ;;
    CREATE_COMPLETE|UPDATE_COMPLETE|UPDATE_ROLLBACK_COMPLETE)
        print_success "Stack is in a valid state for deletion: $STACK_STATUS"
        ;;
esac

# Show what will be deleted
echo ""
show_stack_outputs
echo ""
show_stack_resources

# Multiple confirmation prompts for safety
echo ""
print_warning "⚠️  DANGER ZONE ⚠️"
print_warning "This will permanently delete ALL resources in the stack including:"
print_warning "  • EC2 Instances (RedHat, Ubuntu, Windows)"
print_warning "  • EBS Volumes (30GB each)"
print_warning "  • Elastic IPs"
print_warning "  • Network Interfaces"
print_warning "  • VPC and Subnets"
print_warning "  • Security Groups"
print_warning "  • All data on the instances"
echo ""

# First confirmation
read -p "Are you absolutely sure you want to delete stack '$STACK_NAME'? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_success "Deletion cancelled. Your stack is safe."
    exit 0
fi

# Second confirmation
echo ""
print_warning "This is your last chance to abort!"
read -p "Type 'DELETE' in uppercase to confirm permanent deletion: " -r
if [[ $REPLY != "DELETE" ]]; then
    print_success "Deletion cancelled. Your stack is safe."
    exit 0
fi

# Final countdown
print_warning "Deletion will begin in:"
for i in {5..1}; do
    echo -e "${RED}$i...${NC}"
    sleep 1
done

# Start deletion
echo ""
print_status "Starting stack deletion..."

aws cloudformation delete-stack \
    --stack-name $STACK_NAME \
    --region $REGION || {
    print_error "Failed to initiate stack deletion"
    exit 1
}

print_success "Stack deletion initiated successfully!"

# Wait for deletion to complete
print_status "Waiting for stack deletion to complete..."
print_status "This may take 5-10 minutes. You can monitor progress in the AWS Console."

# Monitor deletion progress
echo ""
print_status "Monitoring deletion progress..."

while check_stack_exists; do
    CURRENT_STATUS=$(get_stack_status)
    print_status "Current status: $CURRENT_STATUS"
    
    case $CURRENT_STATUS in
        DELETE_FAILED)
            print_error "Stack deletion failed!"
            print_status "Check the CloudFormation console for detailed error information"
            print_status "You may need to manually clean up some resources"
            exit 1
            ;;
        DELETE_IN_PROGRESS)
            print_status "Deletion in progress... (checking again in 30 seconds)"
            sleep 30
            ;;
        *)
            print_status "Unexpected status: $CURRENT_STATUS (checking again in 15 seconds)"
            sleep 15
            ;;
    esac
done

# Verify deletion
if ! check_stack_exists; then
    echo ""
    print_success "✅ Stack '$STACK_NAME' has been completely deleted!"
    print_success "All resources have been cleaned up."
    print_status "Goodbye! 👋"
else
    print_error "Stack still exists. Please check the CloudFormation console."
    exit 1
fi