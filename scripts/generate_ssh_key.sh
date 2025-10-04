#!/bin/bash

# SSH Key Generation Script for Cloud Threat Detection Lab
# This script generates SSH keys specifically for this lab

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

# Default values
KEY_NAME="threat-detection-key"
KEY_DIR="$HOME/.ssh"
PUBLIC_KEY_FILE="$KEY_DIR/${KEY_NAME}.pub"
PRIVATE_KEY_FILE="$KEY_DIR/$KEY_NAME"

print_status "SSH Key Generator for Cloud Threat Detection Lab"
echo ""

# Check if key already exists
if [[ -f "$PRIVATE_KEY_FILE" ]]; then
    print_warning "SSH key already exists: $PRIVATE_KEY_FILE"
    read -p "Do you want to overwrite it? (y/N): " overwrite
    if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
        print_status "Keeping existing key."
        exit 0
    fi
fi

# Create .ssh directory if it doesn't exist
if [[ ! -d "$KEY_DIR" ]]; then
    print_status "Creating SSH directory: $KEY_DIR"
    mkdir -p "$KEY_DIR"
    chmod 700 "$KEY_DIR"
fi

# Generate SSH key
print_status "Generating SSH key pair..."
ssh-keygen -t rsa -b 4096 -f "$PRIVATE_KEY_FILE" -N "" -C "threat-detection-lab-$(date +%Y%m%d)"

if [[ $? -eq 0 ]]; then
    print_success "SSH key pair generated successfully!"
else
    print_error "Failed to generate SSH key pair"
    exit 1
fi

# Set proper permissions
chmod 600 "$PRIVATE_KEY_FILE"
chmod 644 "$PUBLIC_KEY_FILE"

print_status "Setting proper file permissions..."

# Display the public key
echo ""
print_success "SSH key generation complete!"
echo ""
print_status "Your public key (copy this to terraform.tfvars):"
echo ""
echo "----------------------------------------"
cat "$PUBLIC_KEY_FILE"
echo "----------------------------------------"
echo ""

# Create terraform.tfvars template
TFVARS_FILE="../infra/terraform.tfvars.template"
print_status "Creating terraform.tfvars template..."

cat > "$TFVARS_FILE" << EOF
# Terraform variables for Cloud Threat Detection Lab
# Generated on $(date)

# AWS Configuration
aws_region = "us-east-1"

# EC2 Configuration
instance_type = "t3.micro"

# SSH Key (generated automatically)
ssh_public_key = "$(cat "$PUBLIC_KEY_FILE")"

# Email for security alerts (REQUIRED - change this!)
alert_email = "your-email@example.com"

# Enable auto-remediation (Lambda function that stops instance on high-severity findings)
enable_auto_remediation = false

# Environment and project settings
environment = "lab"
project_name = "threat-detection"
EOF

print_success "Created terraform.tfvars template: $TFVARS_FILE"
echo ""
print_warning "IMPORTANT NEXT STEPS:"
echo "1. Edit $TFVARS_FILE and set your email address"
echo "2. Copy $TFVARS_FILE to terraform.tfvars"
echo "3. Run the deployment script"
echo ""
print_status "To deploy:"
echo "  cd ../infra"
echo "  cp terraform.tfvars.template terraform.tfvars"
echo "  # Edit terraform.tfvars with your email"
echo "  ../scripts/deploy.sh -i -a"
echo ""
print_status "To test:"
echo "  # After deployment, get the instance IP"
echo "  terraform output instance_public_ip"
echo "  # Run threat simulation"
echo "  ../scripts/test_threats.sh <instance-ip>"
