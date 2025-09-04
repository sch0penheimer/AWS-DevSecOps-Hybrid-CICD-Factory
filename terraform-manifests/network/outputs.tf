################################################################################
#  File: network/outputs.tf
#  Description: Output definitions for the network module's resources.
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 04/09/2025
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

output "alb_security_group_id" {
  description = "The security group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "The security group ID for ECS instances"
  value       = aws_security_group.ecs.id
}