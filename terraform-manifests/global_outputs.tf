################################################################################
#  File: global_outputs.tf
#  Description: Global outputs for AWS DevSecOps Hybrid CI/CD Platform
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 27/09/2025
#
#  Purpose: Centralizes root-level Terraform outputs for deployment script consumption
################################################################################


##-- Root Level Outputs --##
output "aws_region" {
  description = "AWS region where infrastucture is deployed"
  value       = var.aws_account_region
}