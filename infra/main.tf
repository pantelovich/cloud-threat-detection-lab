# Cloud Threat Detection & Incident Response Lab
# AWS GuardDuty + CloudWatch + SNS

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPC and Networking
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "threat-detection-vpc"
    Environment = "lab"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "threat-detection-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "threat-detection-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "threat-detection-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group - Intentionally permissive for SSH (to trigger GuardDuty)
resource "aws_security_group" "ec2" {
  name_prefix = "threat-detection-ec2-"
  vpc_id      = aws_vpc.main.id

  # SSH - intentionally open to all IPs to trigger GuardDuty
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH - intentionally open for testing"
  }

  # HTTP for basic connectivity testing
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "threat-detection-ec2-sg"
  }
}

# Key Pair for EC2 access
resource "aws_key_pair" "main" {
  key_name   = "threat-detection-key"
  public_key = var.ssh_public_key

  tags = {
    Name = "threat-detection-keypair"
  }
}

# EC2 Instance - Intentionally misconfigured for testing
resource "aws_instance" "target" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name              = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id             = aws_subnet.public.id

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    instance_name = "threat-detection-target"
  }))

  tags = {
    Name        = "threat-detection-target"
    Environment = "lab"
    Purpose     = "security-testing"
  }
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# GuardDuty Detector
resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = {
    Name = "threat-detection-guardduty"
  }
}

# SNS Topic for alerts
resource "aws_sns_topic" "security_alerts" {
  name = "threat-detection-security-alerts"

  tags = {
    Name = "threat-detection-sns"
  }
}

# SNS Topic Subscription (Email)
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# IAM Role for CloudWatch Events to publish to SNS
resource "aws_iam_role" "cloudwatch_sns_role" {
  name = "threat-detection-cloudwatch-sns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "threat-detection-cloudwatch-sns-role"
  }
}

resource "aws_iam_role_policy" "cloudwatch_sns_policy" {
  name = "threat-detection-cloudwatch-sns-policy"
  role = aws_iam_role.cloudwatch_sns_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}

# CloudWatch Event Rule for GuardDuty findings
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "threat-detection-guardduty-findings"
  description = "Capture GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  })

  tags = {
    Name = "threat-detection-guardduty-rule"
  }
}

# CloudWatch Event Target - SNS
resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
  role_arn  = aws_iam_role.cloudwatch_sns_role.arn

  input_transformer {
    input_paths = {
      finding_id    = "$.detail.id"
      finding_type  = "$.detail.type"
      severity      = "$.detail.severity"
      title         = "$.detail.title"
      description   = "$.detail.description"
      region        = "$.detail.region"
      account_id    = "$.detail.accountId"
      service       = "$.detail.service.serviceName"
      resource_type = "$.detail.resource.resourceType"
    }
    input_template = <<EOF
{
  "default": "AWS GuardDuty Security Alert\n\nFinding ID: <finding_id>\nType: <finding_type>\nSeverity: <severity>\nTitle: <title>\nDescription: <description>\nRegion: <region>\nAccount: <account_id>\nService: <service>\nResource: <resource_type>\n\nPlease investigate this security finding immediately.\n\nThis alert was generated by the Cloud Threat Detection Lab."
}
EOF
  }
}

# Optional: Lambda function for auto-remediation
resource "aws_lambda_function" "auto_remediation" {
  count = var.enable_auto_remediation ? 1 : 0

  filename         = "${path.module}/lambda_function.zip"
  function_name    = "threat-detection-auto-remediation"
  role            = aws_iam_role.lambda_role[0].arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      INSTANCE_ID = aws_instance.target.id
    }
  }

  tags = {
    Name = "threat-detection-lambda"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  count = var.enable_auto_remediation ? 1 : 0

  name = "threat-detection-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "threat-detection-lambda-role"
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  count = var.enable_auto_remediation ? 1 : 0

  name = "threat-detection-lambda-policy"
  role = aws_iam_role.lambda_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:StopInstances",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Event Target - Lambda (for auto-remediation)
resource "aws_cloudwatch_event_target" "lambda" {
  count = var.enable_auto_remediation ? 1 : 0

  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.auto_remediation[0].arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  count = var.enable_auto_remediation ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_remediation[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_findings.arn
}
