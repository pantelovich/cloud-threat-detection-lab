# Outputs for Cloud Threat Detection Lab

output "instance_public_ip" {
  description = "Public IP address of the target EC2 instance"
  value       = aws_instance.target.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the target EC2 instance"
  value       = aws_instance.target.public_dns
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for security alerts"
  value       = aws_sns_topic.security_alerts.arn
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = aws_guardduty_detector.main.id
}

output "cloudwatch_event_rule_arn" {
  description = "ARN of the CloudWatch event rule"
  value       = aws_cloudwatch_event_rule.guardduty_findings.arn
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function (if auto-remediation is enabled)"
  value       = var.enable_auto_remediation ? aws_lambda_function.auto_remediation[0].arn : null
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "security_group_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2.id
}

output "testing_instructions" {
  description = "Instructions for testing the setup"
  value = <<EOF

CLOUD THREAT DETECTION LAB - TESTING INSTRUCTIONS

1. Wait 5-10 minutes after deployment for GuardDuty to initialize
2. From another machine, run: nmap -p 22 ${aws_instance.target.public_ip}
3. Or attempt SSH connection: ssh ec2-user@${aws_instance.target.public_ip}
4. Check your email for SNS alerts within 10-15 minutes
5. Verify findings in AWS GuardDuty console

REMEMBER: This instance is intentionally vulnerable for testing purposes!
EOF
}
