# AWS Fundamentals Lab with Terraform

## Prerequisites

Before starting this lab, ensure you have:

1. **AWS Account** - Free tier eligible
2. **AWS CLI** installed and configured with your credentials
3. **Terraform** installed (version 1.0+)
4. **Basic understanding** of command line operations

### Setup AWS CLI
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key  
# Default region: us-east-1
# Default output format: json
```

### Configure AWS Profile (If Using Named Profiles)
If you're using named AWS profiles instead of the default profile, you'll need to set the AWS_PROFILE environment variable:

**For PowerShell:**
```powershell
$env:AWS_PROFILE="PROFILE_NAME"
```

**For Bash/Linux/macOS:**
```bash
export AWS_PROFILE=PROFILE_NAME
```

**Alternative**: You can also specify the profile in the AWS provider block:
```hcl
provider "aws" {
  region  = var.aws_region
  profile = "PROFILE_NAME"  # Add this line if using named profiles
}
```

### Verify Setup
```bash
aws sts get-caller-identity
terraform version
```

> **Note**: If you get the error "Error: Retrieving AWS account details: validating provider credentials...", make sure you've set the correct AWS_PROFILE environment variable or configured your AWS credentials properly.

## Lab Overview

This lab covers 8 essential AWS services:
1. **VPC** - Virtual Private Cloud (networking)
2. **EC2** - Elastic Compute Cloud (virtual servers)
3. **RDS** - Relational Database Service
4. **S3** - Simple Storage Service
5. **IAM** - Identity and Access Management
6. **ALB** - Application Load Balancer
7. **Auto Scaling** - Automatic scaling groups
8. **CloudWatch** - Monitoring and logging

## Lab 1: VPC and Networking Foundation

### Understanding VPC
A VPC is your private network in AWS. Think of it as your own data center in the cloud where you control IP ranges, subnets, and routing.

### Create the Terraform Configuration

Create a new directory for your lab:
```bash
mkdir aws-terraform-lab
cd aws-terraform-lab
```

**File: `main.tf`**
```hcl
terraform {
  required_version = ">= 1.0"
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

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "aws-lab"
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${count.index + 1}"
    Type = "Public"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-${count.index + 1}"
    Type = "Private"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
```

**Deploy the VPC:**
```bash
# For PowerShell users with named profiles:
$env:AWS_PROFILE="PROFILE_NAME"

# Then run Terraform commands:
terraform init
terraform plan
terraform apply
```

**Lab Exercise 1:**
- Log into AWS Console and navigate to VPC service
- Find your created VPC, subnets, and internet gateway
- Note the CIDR blocks and availability zones

## Lab 2: EC2 Instances and Security Groups

### Understanding EC2
EC2 provides resizable compute capacity. Security Groups act as virtual firewalls controlling traffic.

**Add to `main.tf`:**
```hcl
# Security Group for Web Servers
resource "aws_security_group" "web" {
  name_prefix = "${var.project_name}-web"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

# Key Pair for EC2 access
resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = file("~/.ssh/id_rsa.pub") # Make sure this file exists
}

# Launch Template
resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-web"
  image_id      = "ami-0c02fb55956c7d316" # Amazon Linux 2023
  instance_type = "t3.micro"
  key_name      = aws_key_pair.main.key_name

  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from $(hostname -f)</h1>" > /var/www/html/index.html
    echo "<p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>" >> /var/www/html/index.html
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-web-server"
    }
  }
}

# EC2 Instance
resource "aws_instance" "web" {
  count = 2

  subnet_id              = aws_subnet.public[count.index].id
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tags = {
    Name = "${var.project_name}-web-${count.index + 1}"
  }
}
```

**Generate SSH Key (if you don't have one):**
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

**Deploy:**
```bash
terraform plan
terraform apply
```

**Lab Exercise 2:**
- SSH into one of your instances using the public IP
- Check that the web server is running: `curl localhost`
- View the webpage in your browser using the public IP

## Lab 3: Application Load Balancer

### Understanding ALB
Application Load Balancer distributes incoming application traffic across multiple targets, improving availability.

**Add to `main.tf`:**
```hcl
# Security Group for ALB
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group
resource "aws_lb_target_group" "web" {
  name     = "${var.project_name}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-web-tg"
  }
}

# Target Group Attachments
resource "aws_lb_target_group_attachment" "web" {
  count = length(aws_instance.web)

  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

# Load Balancer Listener
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
```

**Deploy:**
```bash
terraform plan
terraform apply
```

**Lab Exercise 3:**
- Get the ALB DNS name from AWS Console
- Access the load balancer URL in your browser
- Refresh multiple times to see different instance responses
- Stop one EC2 instance and verify the ALB still works

## Lab 4: Auto Scaling Group

### Understanding Auto Scaling
Auto Scaling automatically adjusts the number of EC2 instances based on demand.

**Add to `main.tf`:**
```hcl
# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name                = "${var.project_name}-asg"
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.web.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = 2
  max_size         = 6
  desired_capacity = 2

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }

  # Replace the existing instances
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
}

# Auto Scaling Policy - Scale Up
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-scale-up"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

# Auto Scaling Policy - Scale Down
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}
```

**Update the EC2 instances section** (comment out or remove the standalone instances):
```hcl
# Remove or comment out the aws_instance.web resource
# The Auto Scaling Group will manage instances now
```

**Deploy:**
```bash
terraform plan
terraform apply
```

**Lab Exercise 4:**
- Check the Auto Scaling Group in AWS Console
- Terminate one instance manually and watch ASG launch a replacement
- Modify desired capacity to 4 and observe new instances launching

## Lab 5: RDS Database

### Understanding RDS
RDS provides managed relational databases with automated backups, patching, and monitoring.

**Add to `main.tf`:**
```hcl
# Security Group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-database"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = "labdb"
  username = "admin"
  password = "changeme123!" # In production, use AWS Secrets Manager

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = true # Only for lab purposes
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-database"
  }
}
```

**Deploy:**
```bash
terraform plan
terraform apply
```

**Lab Exercise 5:**
- Connect to your EC2 instance
- Install MySQL client: `sudo yum install mysql -y`
- Connect to RDS: `mysql -h <RDS_ENDPOINT> -u admin -p`
- Create a table and insert some data

## Lab 6: S3 Bucket

### Understanding S3
S3 is object storage service for storing and retrieving any amount of data from anywhere.

**Add to `main.tf`:**
```hcl
# Random suffix for bucket name
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket
resource "aws_s3_bucket" "main" {
  bucket = "${var.project_name}-bucket-${random_string.bucket_suffix.result}"

  tags = {
    Name = "${var.project_name}-bucket"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Policy for Web Servers
resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowWebServers"
        Effect    = "Allow"
        Principal = {
          AWS = aws_iam_role.ec2_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.main.arn}/*"
      }
    ]
  })
}
```

## Lab 7: IAM Roles and Policies

### Understanding IAM
IAM manages access to AWS services and resources securely.

**Add to `main.tf`:**
```hcl
# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

# IAM Policy for S3 Access
resource "aws_iam_policy" "s3_policy" {
  name        = "${var.project_name}-s3-policy"
  description = "Policy for S3 access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
      }
    ]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}
```

**Update Launch Template** to include IAM role:
```hcl
resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-web"
  image_id      = "ami-0c02fb55956c7d316"
  instance_type = "t3.micro"
  key_name      = aws_key_pair.main.key_name

  vpc_security_group_ids = [aws_security_group.web.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd aws-cli
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from $(hostname -f)</h1>" > /var/www/html/index.html
    echo "<p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>" >> /var/www/html/index.html
    
    # Test S3 access
    echo "Testing S3 access..." > /tmp/test.txt
    aws s3 cp /tmp/test.txt s3://${aws_s3_bucket.main.bucket}/test.txt
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-web-server"
    }
  }
}
```

## Lab 8: CloudWatch Monitoring

### Understanding CloudWatch
CloudWatch provides monitoring for AWS resources and applications.

**Add to `main.tf`:**
```hcl
# CloudWatch Alarm for High CPU
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors ec2 cpu utilization"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_up.arn]

  tags = {
    Name = "${var.project_name}-high-cpu-alarm"
  }
}

# CloudWatch Alarm for Low CPU
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.project_name}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  alarm_description   = "This metric monitors ec2 cpu utilization"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_down.arn]

  tags = {
    Name = "${var.project_name}-low-cpu-alarm"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "web_logs" {
  name              = "/aws/${var.project_name}/web"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-web-logs"
  }
}
```

## Outputs and Final Deployment

**Add to `main.tf`:**
```hcl
# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "load_balancer_dns" {
  description = "Load Balancer DNS"
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "RDS Endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "s3_bucket_name" {
  description = "S3 Bucket Name"
  value       = aws_s3_bucket.main.bucket
}
```

**Final Deployment:**
```bash
terraform plan
terraform apply
```

## Lab Exercises and Testing

### Exercise 1: Load Testing
```bash
# Install Apache Bench on your local machine
# Test the load balancer
ab -n 1000 -c 10 http://<ALB_DNS_NAME>/

# Monitor CloudWatch for CPU spikes and auto scaling
```

### Exercise 2: Database Operations
```bash
# SSH to an EC2 instance
mysql -h <RDS_ENDPOINT> -u admin -p

# Create database operations
CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(100));
INSERT INTO users VALUES (1, 'John Doe');
SELECT * FROM users;
```

### Exercise 3: S3 Operations
```bash
# From EC2 instance
aws s3 ls s3://<BUCKET_NAME>
echo "Hello World" > hello.txt
aws s3 cp hello.txt s3://<BUCKET_NAME>/
aws s3 ls s3://<BUCKET_NAME>
```

## Monitoring and Troubleshooting

### Key Metrics to Monitor
- **EC2**: CPUUtilization, NetworkIn/Out, StatusCheck
- **ALB**: RequestCount, TargetResponseTime, HTTPCode_Target_2XX_Count
- **RDS**: CPUUtilization, DatabaseConnections, FreeStorageSpace
- **Auto Scaling**: GroupDesiredCapacity, GroupInServiceInstances

### Common Issues and Solutions
1. **EC2 instances not accessible**: Check Security Groups and NACLs
2. **Load balancer showing 503 errors**: Verify target group health
3. **RDS connection timeouts**: Check security groups and subnet groups
4. **Auto scaling not working**: Verify CloudWatch alarms and policies

## Cleanup

To avoid charges, destroy all resources:
```bash
terraform destroy
```

Type `yes` when prompted.

## Next Steps

1. **Learn Advanced Services**: 
   - Lambda (serverless computing)
   - API Gateway (API management)
   - CloudFormation (infrastructure as code)
   - ECS/EKS (container services)

2. **Security Best Practices**:
   - Use AWS Secrets Manager for passwords
   - Implement least privilege IAM policies
   - Enable VPC Flow Logs
   - Use AWS Config for compliance

3. **Cost Optimization**:
   - Use Reserved Instances for predictable workloads
   - Implement lifecycle policies for S3
   - Set up billing alerts
   - Use AWS Cost Explorer

4. **Production Readiness**:
   - Multi-region deployments
   - Disaster recovery planning
   - Automated backups
   - Infrastructure monitoring and alerting

## Key Concepts Summary

- **VPC**: Your private network in AWS
- **EC2**: Virtual servers for computing
- **RDS**: Managed database service
- **S3**: Object storage service
- **ALB**: Distributes traffic across instances
- **Auto Scaling**: Automatically adjusts capacity
- **IAM**: Controls access to AWS resources
- **CloudWatch**: Monitoring and alerting service

This lab provides a solid foundation for understanding AWS fundamentals. Practice these concepts and gradually explore more advanced services as you become comfortable with the basics.