#!/bin/bash

# User data script for threat detection target instance
# This script sets up the instance for security testing

set -e

# Update system
yum update -y

# Install basic tools
yum install -y nmap telnet htop iotop netstat-nat

# Install and configure Apache (to provide some network activity)
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Create a simple test page
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Threat Detection Lab - Target Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f0f0f0; }
        .container { background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .warning { color: #d73502; font-weight: bold; }
        .info { color: #0066cc; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Threat Detection Lab Target</h1>
        <p class="warning">WARNING: This server is intentionally vulnerable for security testing!</p>
        <p>This is a test server set up for AWS GuardDuty threat detection demonstration.</p>
        <h2>Server Information:</h2>
        <ul>
            <li><strong>Instance Name:</strong> ${instance_name}</li>
            <li><strong>Purpose:</strong> Security testing and threat detection</li>
            <li><strong>Status:</strong> Intentionally exposed for testing</li>
        </ul>
        <h2>Testing Instructions:</h2>
        <ol>
            <li>Run port scans: <code>nmap -p 22,80 <server-ip></code></li>
            <li>Attempt SSH connections to trigger GuardDuty</li>
            <li>Check your email for security alerts</li>
            <li>Review findings in AWS GuardDuty console</li>
        </ol>
        <p class="info">This server is designed to trigger security findings for demonstration purposes.</p>
    </div>
</body>
</html>
EOF

# Configure SSH to be more permissive (for testing)
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Create a test user with weak password (for demonstration)
useradd -m -s /bin/bash testuser
echo 'testuser:password123' | chpasswd
usermod -aG wheel testuser

# Enable password authentication for root (dangerous - for testing only)
echo 'root:admin123' | chpasswd
sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config

# Restart SSH service
systemctl restart sshd

# Install fail2ban (but don't configure it aggressively - we want to trigger GuardDuty)
yum install -y epel-release
yum install -y fail2ban

# Create basic fail2ban config (but with high thresholds to allow testing)
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 10

[sshd]
enabled = true
port = ssh
logpath = /var/log/secure
maxretry = 10
bantime = 3600
EOF

systemctl start fail2ban
systemctl enable fail2ban

# Create some fake log entries to simulate suspicious activity
echo "$(date '+%b %d %H:%M:%S') $(hostname) sshd[1234]: Failed password for invalid user admin from 192.168.1.100 port 22 ssh2" >> /var/log/secure
echo "$(date '+%b %d %H:%M:%S') $(hostname) sshd[1235]: Failed password for root from 10.0.0.50 port 22 ssh2" >> /var/log/secure

# Set up log rotation for security logs
cat > /etc/logrotate.d/security-testing << 'EOF'
/var/log/secure {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

# Create a simple monitoring script
cat > /usr/local/bin/security-monitor.sh << 'EOF'
#!/bin/bash
# Simple security monitoring script

echo "=== Security Status Check ==="
echo "Date: $(date)"
echo "Uptime: $(uptime)"
echo "Active SSH connections:"
ss -tuln | grep :22
echo "Recent failed login attempts:"
grep "Failed password" /var/log/secure | tail -5
echo "=== End Security Check ==="
EOF

chmod +x /usr/local/bin/security-monitor.sh

# Add to crontab for periodic monitoring
echo "*/5 * * * * /usr/local/bin/security-monitor.sh >> /var/log/security-monitor.log" | crontab -

# Create a welcome message
cat > /etc/motd << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                    THREAT DETECTION LAB                      ║
║                                                              ║
║  WARNING: This server is intentionally vulnerable!          ║
║                                                              ║
║  This instance is configured for AWS GuardDuty testing:     ║
║  • Open SSH port (0.0.0.0/0)                                ║
║  • Weak passwords enabled                                    ║
║  • Root login permitted                                      ║
║                                                              ║
║  Test credentials:                                           ║
║  • root / admin123                                           ║
║  • testuser / password123                                    ║
║                                                              ║
║  This is for educational purposes only!                      ║
╚══════════════════════════════════════════════════════════════╝
EOF

# Log completion
echo "$(date): User data script completed successfully" >> /var/log/user-data.log
