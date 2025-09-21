################################################################################
#  File: network/outputs.tf
#  Description: Output definitions for the network module's resources.
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 21/09/2025
#
#  Purpose: Exposes network resource IDs for cross-module integration.
################################################################################

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "prod_alb_security_group_id" {
  description = "The security group ID for the Production ALB"
  value       = aws_security_group.prod_alb.id
}

output "prod_ecs_security_group_id" {
  description = "The security group ID for Production ECS instances"
  value       = aws_security_group.prod_ecs.id
}

output "staging_alb_security_group_id" {
  description = "The security group ID for the Staging ALB"
  value       = aws_security_group.staging_alb.id
}

output "staging_ecs_security_group_id" {
  description = "The security group ID for Staging ECS instances"
  value       = aws_security_group.staging_ecs.id
}

output "codebuild_security_group_id" {
  description = "The security group ID for CodeBuild Projects (Especially the DAST one)"
  value       = aws_security_group.codebuild.id
}
