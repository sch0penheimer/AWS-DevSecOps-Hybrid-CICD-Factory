variable "project_name" {
  description     = "aws-devsecops-cicd-platform"
  type            = string
  default         = "AWS DevSecOps CI/CD Platform"
}

variable "aws_account_region" {
  description = "AWS region of the associated AWS root account"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Main & Secondary Availability Zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}