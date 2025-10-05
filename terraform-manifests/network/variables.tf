################################################################################
#  File: network/variables.tf
#  Description: Variable definitions for the network module
#  Author: Haitam Bidiouane (@sch0penheimer)
#  Last Modified: 04/09/2025
#
#  Purpose: Parameterizes network configuration for flexibility and reuse.
################################################################################

variable "project_name" {}

variable "availability_zones" {}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "nat_instance_type" {
  description = "EC2 instance type for the NAT instances"
  type    = string
  default = "t2.micro"
}