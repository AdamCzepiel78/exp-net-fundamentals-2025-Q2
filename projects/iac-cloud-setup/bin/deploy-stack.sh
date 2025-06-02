#!/bin/bash

# CloudFormation Stack Deployment Script
# Description: Deploys the Multi-OS Infrastructure stack in eu-central-1

set -e  # Exit on any error

# Configuration
STACK_NAME="multi-os-infrastructure"
TEMPLATE_FILE="/run/media/aczepiel/Daten/DevOps/Linux/exp-net-fundamentals-2025-Q2/projects/iac-cloud-setup/template.yaml"
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

# Function to get user's public IP
get_public_ip() {
    # Silently get IP without any output
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || curl -s icanhazip.com 2>/dev/null)
    if [ -z "$PUBLIC_IP" ]; then
        print_error "Could not detect your public IP address"
        read -p "Please enter your public IP address: " PUBLIC_IP
    fi
    # Return just the IP with /32, no output to stdout
    echo "${PUBLIC_IP}/32"
}

# Function to list available key pairs
list_key_pairs() {
    print_status "Available EC2 Key Pairs in $REGION:"
    aws ec2 describe-key-pairs --region $REGION --query 'KeyPairs[*].KeyName' --output table 2>/dev/null || {
        print_error "Could not list key pairs. Please check your AWS credentials and region."
        return 1
    }
}

# Function to check if stack exists
check_stack_exists() {
    aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION >/dev/null 2>&1
}

# Main script starts here
echo "=================================="
echo "  CloudFormation Stack Deployer  "
echo "=================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    print_error "Template file '$TEMPLATE_FILE' not found in current directory."
    exit 1
fi

# Check AWS credentials
print_status "Checking AWS credentials..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_error "AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

print_success "AWS credentials are valid"

# Get parameters
echo ""
print_status "Gathering deployment parameters..."

# Get Key Pair Name
list_key_pairs
echo ""
read -p "Enter the EC2 Key Pair name: " KEY_PAIR_NAME

if [ -z "$KEY_PAIR_NAME" ]; then
    print_error "Key Pair name cannot be empty"
    exit 1
fi

# Verify key pair exists
if ! aws ec2 describe-key-pairs --key-names "$KEY_PAIR_NAME" --region $REGION >/dev/null 2>&1; then
    print_error "Key Pair '$KEY_PAIR_NAME' does not exist in $REGION"
    exit 1
fi

# Get Public IP
print_status "Detecting your public IP address..."
MY_IP=$(get_public_ip)
print_success "Detected IP: $MY_IP"

# Confirm deployment
echo ""
echo "Deployment Configuration:"
echo "  Stack Name: $STACK_NAME"
echo "  Region: $REGION"
echo "  Template: $TEMPLATE_FILE"
echo "  Key Pair: $KEY_PAIR_NAME"
echo "  Your IP: $MY_IP"
echo ""

read -p "Do you want to proceed with deployment? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled by user"
    exit 0
fi

# Check if stack already exists
if check_stack_exists; then
    print_warning "Stack '$STACK_NAME' already exists"
    read -p "Do you want to update the existing stack? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ACTION="update-stack"
        print_status "Updating existing stack..."
    else
        print_warning "Deployment cancelled"
        exit 0
    fi
else
    ACTION="create-stack"
    print_status "Creating new stack..."
fi

# Deploy the stack
echo ""
print_status "Starting CloudFormation deployment..."

aws cloudformation $ACTION \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --parameters "ParameterKey=KeyPairName,ParameterValue=$KEY_PAIR_NAME" \
                 "ParameterKey=MyIPAddress,ParameterValue=$MY_IP" \
    --region $REGION \
    --capabilities CAPABILITY_IAM || {
    print_error "Failed to start deployment"
    exit 1
}

print_success "CloudFormation deployment initiated successfully!"

# Wait for stack completion
print_status "Waiting for stack deployment to complete..."
print_status "This may take 5-15 minutes. You can monitor progress in the AWS Console."

aws cloudformation wait stack-${ACTION%-stack}-complete \
    --stack-name $STACK_NAME \
    --region $REGION && {
    print_success "Stack deployment completed successfully!"
    
    # Show stack outputs
    echo ""
    print_status "Stack Outputs:"
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
        
} || {
    print_error "Stack deployment failed or was cancelled"
    print_status "Check the CloudFormation console for detailed error information"
    exit 1
}

echo ""
print_success "Deployment completed! Your infrastructure is ready to use."
print_status "Check the outputs above for connection details."