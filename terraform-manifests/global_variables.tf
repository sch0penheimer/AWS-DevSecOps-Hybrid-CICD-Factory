################################################################################
#  File: global_variables.tf
#  Description: Global variable definitions for the AWS DevSecOps Hybrid CI/CD Platform.
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 04/09/2025
#
#  Purpose: Centralizes project-wide variables for consistent configuration across modules.
################################################################################

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