#!/bin/bash

# Threat Detection Testing Script
# This script simulates various security threats to trigger GuardDuty findings

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
    echo "Usage: $0 <target-ip> [options]"
    echo ""
    echo "Options:"
    echo "  -p, --port PORT        Target port (default: 22)"
    echo "  -t, --type TYPE        Threat type: portscan, ssh-brute, all (default: all)"
    echo "  -d, --delay SECONDS    Delay between attempts (default: 2)"
    echo "  -c, --count COUNT      Number of attempts (default: 10)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 1.2.3.4                    # Run all tests"
    echo "  $0 1.2.3.4 -t portscan       # Port scan only"
    echo "  $0 1.2.3.4 -t ssh-brute -c 5 # SSH brute force with 5 attempts"
}

# Default values
TARGET_IP=""
TARGET_PORT=22
THREAT_TYPE="all"
DELAY=2
COUNT=10

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            TARGET_PORT="$2"
            shift 2
            ;;
        -t|--type)
            THREAT_TYPE="$2"
            shift 2
            ;;
        -d|--delay)
            DELAY="$2"
            shift 2
            ;;
        -c|--count)
            COUNT="$2"
            shift 2
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
            if [[ -z "$TARGET_IP" ]]; then
                TARGET_IP="$1"
            else
                print_error "Multiple IP addresses provided"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate target IP
if [[ -z "$TARGET_IP" ]]; then
    print_error "Target IP address is required"
    usage
    exit 1
fi

# Validate IP format (basic check)
if ! [[ $TARGET_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    print_error "Invalid IP address format: $TARGET_IP"
    exit 1
fi

print_status "Starting threat simulation against $TARGET_IP"
print_warning "This script simulates security threats for testing purposes only!"
print_warning "Only use against systems you own or have permission to test!"

echo ""
read -p "Press Enter to continue or Ctrl+C to abort..."

# Function to perform port scan
port_scan() {
    print_status "Performing port scan on $TARGET_IP"
    
    if command_exists nmap; then
        print_status "Using nmap for port scanning..."
        nmap -p 1-1000,3389,5432,6379,8080,8443,9200,27017 "$TARGET_IP"
    elif command_exists nc; then
        print_status "Using netcat for port scanning..."
        for port in 22 23 25 53 80 110 143 443 993 995 3389 5432 6379 8080 8443; do
            if nc -z -w1 "$TARGET_IP" "$port" 2>/dev/null; then
                print_success "Port $port is open"
            fi
        done
    else
        print_error "Neither nmap nor netcat found. Please install one of them."
        return 1
    fi
}

# Function to perform SSH brute force
ssh_brute_force() {
    print_status "Attempting SSH brute force on $TARGET_IP:$TARGET_PORT"
    
    # Common usernames and passwords for testing
    USERS=("root" "admin" "ubuntu" "ec2-user" "centos" "testuser" "user" "guest")
    PASSWORDS=("password" "admin" "root" "123456" "password123" "admin123" "test" "guest")
    
    print_status "Testing common credentials..."
    
    for user in "${USERS[@]}"; do
        for password in "${PASSWORDS[@]}"; do
            print_status "Trying $user:$password"
            
            # Use sshpass if available, otherwise use expect or manual method
            if command_exists sshpass; then
                timeout 5 sshpass -p "$password" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$user@$TARGET_IP" "echo 'Connection successful'" 2>/dev/null
            else
                # Fallback: just attempt connection (will prompt for password)
                timeout 5 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password "$user@$TARGET_IP" "echo 'Connection successful'" 2>/dev/null || true
            fi
            
            sleep "$DELAY"
        done
    done
}

# Function to perform HTTP enumeration
http_enumeration() {
    print_status "Performing HTTP enumeration on $TARGET_IP"
    
    # Test common HTTP ports
    for port in 80 8080 8443; do
        if nc -z -w1 "$TARGET_IP" "$port" 2>/dev/null; then
            print_status "Testing HTTP on port $port"
            
            if command_exists curl; then
                curl -s -I "http://$TARGET_IP:$port" | head -10
                
                # Test common paths
                for path in "/admin" "/login" "/wp-admin" "/.env" "/config" "/api"; do
                    curl -s -o /dev/null -w "%{http_code}" "http://$TARGET_IP:$port$path" && echo " - $path"
                done
            fi
        fi
    done
}

# Function to simulate suspicious network activity
suspicious_activity() {
    print_status "Simulating suspicious network activity"
    
    # Multiple rapid connections to simulate scanning
    print_status "Rapid connection attempts..."
    for i in $(seq 1 "$COUNT"); do
        nc -z -w1 "$TARGET_IP" "$TARGET_PORT" 2>/dev/null || true
        sleep 0.1
    done
    
    # Simulate data exfiltration attempt
    print_status "Simulating data exfiltration attempt..."
    if command_exists curl; then
        curl -s "http://$TARGET_IP" > /dev/null 2>&1 || true
        curl -s "http://$TARGET_IP/admin" > /dev/null 2>&1 || true
        curl -s "http://$TARGET_IP/config" > /dev/null 2>&1 || true
    fi
}

# Main execution
main() {
    echo ""
    print_status "Starting threat simulation..."
    echo "Target: $TARGET_IP:$TARGET_PORT"
    echo "Type: $THREAT_TYPE"
    echo "Delay: ${DELAY}s between attempts"
    echo "Count: $COUNT attempts"
    echo ""
    
    case "$THREAT_TYPE" in
        "portscan")
            port_scan
            ;;
        "ssh-brute")
            ssh_brute_force
            ;;
        "http")
            http_enumeration
            ;;
        "suspicious")
            suspicious_activity
            ;;
        "all")
            port_scan
            echo ""
            ssh_brute_force
            echo ""
            http_enumeration
            echo ""
            suspicious_activity
            ;;
        *)
            print_error "Unknown threat type: $THREAT_TYPE"
            usage
            exit 1
            ;;
    esac
    
    echo ""
print_success "Threat simulation completed!"
print_status "Wait 5-15 minutes for GuardDuty to detect and process findings"
print_status "Check your email for SNS alerts"
print_status "Review findings in AWS GuardDuty console"
}

# Check prerequisites
if ! command_exists nc && ! command_exists nmap; then
    print_error "Neither netcat (nc) nor nmap is installed."
    print_status "Please install one of them:"
    print_status "  Ubuntu/Debian: sudo apt-get install netcat-openbsd nmap"
    print_status "  CentOS/RHEL: sudo yum install nc nmap"
    print_status "  macOS: brew install netcat nmap"
    exit 1
fi

# Run main function
main
