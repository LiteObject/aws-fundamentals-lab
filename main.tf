# =============================================================================
# TERRAFORM CONFIGURATION
# =============================================================================
# This file creates a basic AWS VPC infrastructure with public and private subnets
# suitable for hosting web applications with proper network isolation.

terraform {
  # Require Terraform version 1.0 or higher for stability and feature support
  required_version = ">= 1.0"
  
  # Specify required providers and their versions
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Use AWS provider version 5.x (latest stable)
    }
  }
}

# Configure the AWS Provider
# This tells Terraform which AWS region to deploy resources in
provider "aws" {
  region = var.aws_region
}

# =============================================================================
# VARIABLES
# =============================================================================
# Variables allow customization of the infrastructure without modifying the code

# AWS Region where all resources will be created
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"  # N. Virginia - popular choice for its extensive service availability
}

# Project name used for consistent resource naming and tagging
variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "aws-lab"  # Will be prefixed to all resource names
}

# =============================================================================
# DATA SOURCES
# =============================================================================
# Data sources fetch information about existing AWS resources

# Get list of available Availability Zones in the current region
# This ensures we deploy across multiple AZs for high availability
data "aws_availability_zones" "available" {
  state = "available"  # Only include AZs that are currently available
}

# =============================================================================
# NETWORKING INFRASTRUCTURE
# =============================================================================
# 
# 💰 COST SUMMARY FOR LAB 1 (VPC Infrastructure):
# ✅ FREE RESOURCES:
#    - VPC (Virtual Private Cloud)
#    - Subnets (Public and Private)
#    - Internet Gateway
#    - Route Tables and Route Table Associations
#    - Security Groups (when added in later labs)
#    - NACLs (Network Access Control Lists)
# 
# 💸 POTENTIAL COSTS IN FUTURE LABS:
#    - EC2 Instances (~$8.50/month for t3.micro)
#    - NAT Gateways (~$45/month + data processing charges)
#    - Load Balancers (~$22/month + data processing)
#    - RDS Instances (~$15/month for db.t3.micro)
#    - Data Transfer (charges for data leaving AWS)
# 
# 🎓 LAB 1 TOTAL COST: $0.00 (All resources are FREE!)
# =============================================================================

# Virtual Private Cloud (VPC)
# This creates an isolated network environment in AWS
# 💰 COST: FREE - VPCs themselves do not incur charges
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"        # Private IP range (65,536 IP addresses)
  enable_dns_hostnames = true                 # Enable DNS hostnames for instances
  enable_dns_support   = true                 # Enable DNS resolution within the VPC

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway
# This provides internet access to resources in public subnets
# 💰 COST: FREE - Internet Gateways do not incur charges
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id                   # Attach to our VPC

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# =============================================================================
# SUBNETS
# =============================================================================

# Public Subnets
# These subnets have direct internet access via the Internet Gateway
# Ideal for load balancers, NAT gateways, and bastion hosts
# 💰 COST: FREE - Subnets themselves do not incur charges
resource "aws_subnet" "public" {
  count = 2                                   # Create 2 public subnets for high availability

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"    # 10.0.1.0/24, 10.0.2.0/24 (256 IPs each)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true             # Automatically assign public IPs to instances

  tags = {
    Name = "${var.project_name}-public-${count.index + 1}"
    Type = "Public"
  }
}

# Private Subnets
# These subnets have no direct internet access - more secure for application servers and databases
# Internet access can be provided via NAT Gateway if needed
# 💰 COST: FREE - Subnets themselves do not incur charges
resource "aws_subnet" "private" {
  count = 2                                   # Create 2 private subnets for high availability

  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"        # 10.0.10.0/24, 10.0.11.0/24 (256 IPs each)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-${count.index + 1}"
    Type = "Private"
  }
}

# =============================================================================
# ROUTING
# =============================================================================

# Route Table for Public Subnets
# This defines how traffic flows from public subnets to the internet
# 💰 COST: FREE - Route tables do not incur charges
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Route all internet traffic (0.0.0.0/0) through the Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"                 # All IP addresses (internet)
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associate Public Subnets with Public Route Table
# This connects each public subnet to the route table, enabling internet access
# 💰 COST: FREE - Route table associations do not incur charges
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)          # Associate all public subnets

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}