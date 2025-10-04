# Variables for Cloud Threat Detection Lab

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 access"
  type        = string
  sensitive   = true
}

variable "alert_email" {
  description = "Email address for security alerts"
  type        = string
}

variable "enable_auto_remediation" {
  description = "Enable Lambda auto-remediation (stops instance on high severity findings)"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "threat-detection"
}
