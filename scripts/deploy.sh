#!/bin/bash

# Deployment script for Cloud Threat Detection Lab
# This script automates the deployment process

set -e

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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to display usage
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -a, --apply           Apply Terraform configuration"
    echo "  -d, --destroy         Destroy Terraform configuration"
    echo "  -p, --plan            Plan Terraform changes"
    echo "  -i, --init            Initialize Terraform"
    echo "  -o, --output          Show Terraform outputs"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -i -a              # Initialize and apply"
    echo "  $0 -p                 # Plan changes"
    echo "  $0 -d                 # Destroy infrastructure"
}

# Default values
ACTION=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--apply)
            ACTION="apply"
            shift
            ;;
        -d|--destroy)
            ACTION="destroy"
            shift
            ;;
        -p|--plan)
            ACTION="plan"
            shift
            ;;
        -i|--init)
            ACTION="init"
            shift
            ;;
        -o|--output)
            ACTION="output"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*|--*)
            print_error "Unknown option $1"
            usage
            exit 1
            ;;
        *)
            print_error "Unknown argument $1"
            usage
            exit 1
            ;;
    esac
done

# Check if Terraform is installed
if ! command_exists terraform; then
    print_error "Terraform is not installed!"
    print_status "Please install Terraform: https://developer.hashicorp.com/terraform/downloads"
    exit 1
fi

# Check if AWS CLI is installed
if ! command_exists aws; then
    print_error "AWS CLI is not installed!"
    print_status "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_error "AWS credentials not configured!"
    print_status "Please configure AWS credentials: aws configure"
    exit 1
fi

# Navigate to infra directory
cd "$(dirname "$0")/../infra"

# Check if terraform.tfvars exists
if [[ ! -f "terraform.tfvars" ]]; then
    print_warning "terraform.tfvars not found!"
    print_status "Please copy terraform.tfvars.example to terraform.tfvars and configure your values:"
    print_status "  cp terraform.tfvars.example terraform.tfvars"
    print_status "  # Edit terraform.tfvars with your values"
    exit 1
fi

# Execute Terraform commands
case "$ACTION" in
    "init")
        print_status "Initializing Terraform..."
        terraform init
        print_success "Terraform initialized successfully!"
        ;;
    "plan")
        print_status "Planning Terraform changes..."
        terraform plan
        ;;
    "apply")
        print_status "Applying Terraform configuration..."
        terraform apply -auto-approve
        print_success "Infrastructure deployed successfully!"
        echo ""
        print_status "Don't forget to:"
        print_status "  1. Check your email and confirm SNS subscription"
        print_status "  2. Wait 5-10 minutes for GuardDuty to initialize"
        print_status "  3. Run the testing script to simulate threats"
        ;;
    "destroy")
        print_warning "This will destroy all infrastructure!"
        read -p "Are you sure? Type 'yes' to continue: " confirm
        if [[ "$confirm" == "yes" ]]; then
            print_status "Destroying infrastructure..."
            terraform destroy -auto-approve
            print_success "Infrastructure destroyed successfully!"
        else
            print_status "Destroy cancelled."
        fi
        ;;
    "output")
        print_status "Terraform outputs:"
        terraform output
        ;;
    "")
        print_error "No action specified!"
        usage
        exit 1
        ;;
    *)
        print_error "Unknown action: $ACTION"
        usage
        exit 1
        ;;
esac
