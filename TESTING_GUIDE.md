# 🧪 Testing Guide - Cloud Threat Detection Lab

This guide provides detailed instructions for testing the Cloud Threat Detection lab and understanding the expected outcomes.

## 📋 Pre-Testing Checklist

Before running any tests, ensure:

- [ ] Infrastructure is deployed successfully
- [ ] SNS email subscription is confirmed
- [ ] GuardDuty has been running for at least 10 minutes
- [ ] You have the target instance IP address
- [ ] Testing tools are installed (nmap, netcat, ssh)

## 🎯 Getting Started

### 1. Get Target Information

```bash
cd infra
terraform output
```

Note down:
- `instance_public_ip`: The target IP address
- `sns_topic_arn`: SNS topic for alerts
- `guardduty_detector_id`: GuardDuty detector ID

### 2. Verify Infrastructure

```bash
# Check if instance is running
aws ec2 describe-instances --instance-ids $(terraform output -raw instance_id)

# Check GuardDuty status
aws guardduty list-detectors --region $(terraform output -raw aws_region)
```

## 🚀 Test Scenarios

### Scenario 1: Port Scanning Detection

**Objective**: Trigger GuardDuty port scanning findings

**Command**:
```bash
./scripts/test_threats.sh <target-ip> -t portscan
```

**Expected GuardDuty Findings**:
- `Recon:EC2/PortProbeUnprotectedPort`
- `Recon:EC2/Portscan`

**Timeline**: Findings appear within 5-15 minutes

### Scenario 2: SSH Brute Force Detection

**Objective**: Trigger SSH brute force findings

**Command**:
```bash
./scripts/test_threats.sh <target-ip> -t ssh-brute -c 20
```

**Expected GuardDuty Findings**:
- `UnauthorizedAPICall:EC2/SSHBruteForce`

**Timeline**: Findings appear within 10-20 minutes

### Scenario 3: Comprehensive Attack Simulation

**Objective**: Trigger multiple types of findings

**Command**:
```bash
./scripts/test_threats.sh <target-ip>
```

**Expected GuardDuty Findings**:
- Multiple reconnaissance findings
- Potential SSH brute force findings
- Network traffic anomalies

### Scenario 4: Manual Testing

If automated scripts don't work, try manual commands:

```bash
# Port scan with nmap
nmap -p 1-1000 <target-ip>

# Port scan with netcat
for port in 22 23 25 53 80 110 143 443 993 995 3389 5432 6379 8080 8443; do
    nc -z -w1 <target-ip> $port && echo "Port $port is open"
done

# SSH connection attempts
ssh -o ConnectTimeout=5 root@<target-ip>
ssh -o ConnectTimeout=5 admin@<target-ip>
ssh -o ConnectTimeout=5 testuser@<target-ip>
```

## 📊 Monitoring Results

### 1. Check GuardDuty Console

1. Navigate to AWS GuardDuty console
2. Select your region
3. Click on "Findings" tab
4. Look for findings with these types:
   - `Recon:EC2/PortProbeUnprotectedPort`
   - `Recon:EC2/Portscan`
   - `UnauthorizedAPICall:EC2/SSHBruteForce`

### 2. Check Email Alerts

Look for emails from AWS SNS with subject:
```
AWS Notification Message - threat-detection-security-alerts
```

Email content should include:
- Finding ID
- Finding type
- Severity level
- Detailed description
- Affected resources

### 3. Check CloudWatch Logs

If auto-remediation is enabled:

```bash
# Check Lambda function logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/threat-detection"

# Get recent log events
aws logs filter-log-events --log-group-name "/aws/lambda/threat-detection-auto-remediation" --start-time $(date -d '1 hour ago' +%s)000
```

### 4. Check CloudWatch Metrics

```bash
# List custom metrics
aws cloudwatch list-metrics --namespace "ThreatDetection/AutoRemediation"

# Get metric data
aws cloudwatch get-metric-statistics \
    --namespace "ThreatDetection/AutoRemediation" \
    --metric-name "InstancesStopped" \
    --dimensions Name=FindingType,Value=Recon:EC2/PortProbeUnprotectedPort \
    --statistics Sum \
    --start-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300
```

## 🔍 Troubleshooting

### No Findings Appearing

**Possible Causes**:
1. GuardDuty needs time to initialize (up to 15 minutes)
2. Insufficient traffic to trigger findings
3. Region mismatch between GuardDuty and EC2 instance

**Solutions**:
```bash
# Check GuardDuty detector status
aws guardduty get-detector --detector-id $(terraform output -raw guardduty_detector_id)

# Verify region consistency
terraform output aws_region
aws guardduty list-detectors --region $(terraform output -raw aws_region)

# Increase test intensity
./scripts/test_threats.sh <target-ip> -c 50 -d 1
```

### No Email Alerts

**Possible Causes**:
1. SNS subscription not confirmed
2. Email in spam folder
3. Incorrect email address

**Solutions**:
```bash
# Check SNS topic subscriptions
aws sns list-subscriptions-by-topic --topic-arn $(terraform output -raw sns_topic_arn)

# Resend confirmation
aws sns confirm-subscription --topic-arn $(terraform output -raw sns_topic_arn) --token <confirmation-token>
```

### Auto-Remediation Not Working

**Possible Causes**:
1. Lambda function not triggered
2. IAM permissions insufficient
3. Instance already stopped

**Solutions**:
```bash
# Check Lambda function
aws lambda get-function --function-name threat-detection-auto-remediation

# Check CloudWatch event rules
aws events list-rules --name-prefix threat-detection

# Check instance state
aws ec2 describe-instances --instance-ids $(terraform output -raw instance_id) --query 'Reservations[0].Instances[0].State.Name'
```

## 📈 Expected Timeline

| Event | Timeline | Description |
|-------|----------|-------------|
| Infrastructure Deploy | 5-10 minutes | Terraform creates all resources |
| GuardDuty Initialization | 10-15 minutes | GuardDuty starts monitoring |
| First Findings | 5-15 minutes | After running tests |
| Email Alerts | 1-5 minutes | After findings are generated |
| Auto-Remediation | 1-2 minutes | If enabled and triggered |

## 🎯 Success Criteria

The lab is successful when you observe:

1. **GuardDuty Findings**: At least one finding appears in the console
2. **Email Alerts**: You receive an email notification
3. **CloudWatch Events**: Events are captured and processed
4. **Auto-Remediation**: Instance stops automatically (if enabled)

## 🧹 Cleanup After Testing

Always clean up resources after testing:

```bash
cd infra
terraform destroy -auto-approve
```

Or use the deployment script:

```bash
./scripts/deploy.sh -d
```

## 📚 Additional Testing Ideas

### Advanced Scenarios

1. **Multi-Region Testing**: Deploy in different regions
2. **Load Testing**: Generate high-volume traffic
3. **Custom Rules**: Create custom GuardDuty rules
4. **Integration Testing**: Test with Security Hub

### Custom Threat Simulation

Create your own test scenarios:

```bash
# Custom port scanning
nmap -sS -sV -O <target-ip>

# Custom HTTP enumeration
dirb http://<target-ip> /usr/share/wordlists/dirb/common.txt

# Custom network flooding
hping3 -S -p 22 --flood <target-ip>
```

## 🆘 Getting Help

If you encounter issues:

1. Check the troubleshooting section above
2. Review AWS CloudTrail logs for API errors
3. Check Terraform state for deployment issues
4. Verify AWS service limits and quotas
5. Consult AWS documentation for specific services

---

**Happy Testing! 🎉**

Remember: This lab is for educational purposes only. Always follow responsible disclosure practices and only test on systems you own or have explicit permission to test.
