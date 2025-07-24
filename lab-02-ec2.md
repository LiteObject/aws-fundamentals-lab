# Lab 2: EC2 Instances and Security Groups

## Understanding EC2
EC2 (Elastic Compute Cloud) provides resizable compute capacity in the cloud. Security Groups act as virtual firewalls controlling traffic to and from your instances.

## Learning Objectives
By the end of this lab, you will:
- Understand EC2 instances and their components
- Create and configure Security Groups
- Generate and use SSH key pairs
- Deploy EC2 instances using Launch Templates
- Connect to instances via SSH
- Understand basic web server setup

## Prerequisites
- Completed [Lab 1: VPC and Networking Foundation](lab-01-vpc.md)
- SSH client installed (built into Windows 10+, macOS, and Linux)

## Cost Information
**Estimated Monthly Cost: ~$17.00**
- EC2 t3.micro instances: ~$8.50/month each (2 instances = ~$17.00)
- SSH Key Pairs: FREE
- Security Groups: FREE

## Architecture Overview
This lab adds compute resources to your VPC:
- 2 EC2 t3.micro instances in public subnets
- Security groups for web traffic and SSH access
- SSH key pair for secure access
- Apache web server with simple HTML pages

## Security Group Configuration

**Add to your existing `main.tf`:**

```hcl
# =============================================================================
# SECURITY GROUPS
# =============================================================================

# Security Group for Web Servers
# Controls inbound and outbound traffic for EC2 instances
resource "aws_security_group" "web" {
  name_prefix = "${var.project_name}-web"
  vpc_id      = aws_vpc.main.id
  description = "Security group for web servers"

  # Allow HTTP traffic from anywhere
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS traffic from anywhere
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH only from within the VPC (more secure)
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Only from our VPC
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}
```

## SSH Key Pair Setup

**Generate SSH Key (if you don't have one):**

```bash
# For Windows (PowerShell), macOS, or Linux
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

**Add to `main.tf`:**

```hcl
# =============================================================================
# SSH KEY PAIR
# =============================================================================

# Key Pair for EC2 access
# This uploads your public key to AWS for SSH authentication
resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = file("~/.ssh/id_rsa.pub")  # Make sure this file exists

  tags = {
    Name = "${var.project_name}-key-pair"
  }
}
```

## Launch Template and EC2 Instances

**Add to `main.tf`:**

```hcl
# =============================================================================
# EC2 INSTANCES
# =============================================================================

# Launch Template
# Defines the configuration for EC2 instances
resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-web"
  description   = "Launch template for web servers"
  
  # Amazon Linux 2023 AMI (check AWS console for latest AMI ID in your region)
  image_id      = "ami-0c02fb55956c7d316"  # Amazon Linux 2023 - update if needed
  instance_type = "t3.micro"               # Free tier eligible
  key_name      = aws_key_pair.main.key_name

  # Attach security group
  vpc_security_group_ids = [aws_security_group.web.id]

  # User data script to install and configure Apache
  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Update the system
    yum update -y
    
    # Install Apache web server
    yum install -y httpd
    
    # Start and enable Apache
    systemctl start httpd
    systemctl enable httpd
    
    # Create a simple web page
    echo "<h1>Hello from $(hostname -f)</h1>" > /var/www/html/index.html
    echo "<p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>" >> /var/www/html/index.html
    echo "<p>Availability Zone: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>" >> /var/www/html/index.html
    echo "<p>Instance Type: $(curl -s http://169.254.169.254/latest/meta-data/instance-type)</p>" >> /var/www/html/index.html
  EOF
  )

  # Tag instances created from this template
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-web-server"
      Type = "WebServer"
    }
  }

  tags = {
    Name = "${var.project_name}-launch-template"
  }
}

# EC2 Instances
# Deploy 2 instances across different availability zones
resource "aws_instance" "web" {
  count = 2

  subnet_id = aws_subnet.public[count.index].id
  
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tags = {
    Name = "${var.project_name}-web-${count.index + 1}"
    Environment = "lab"
  }
}
```

## Outputs for Easy Access

**Add to `main.tf`:**

```hcl
# =============================================================================
# OUTPUTS
# =============================================================================

# Output the public IP addresses of the instances
output "instance_public_ips" {
  description = "Public IP addresses of EC2 instances"
  value       = aws_instance.web[*].public_ip
}

# Output the instance IDs
output "instance_ids" {
  description = "Instance IDs of EC2 instances"
  value       = aws_instance.web[*].id
}

# Output SSH connection commands
output "ssh_commands" {
  description = "SSH commands to connect to instances"
  value = [
    for i, instance in aws_instance.web :
    "ssh -i ~/.ssh/id_rsa ec2-user@${instance.public_ip}"
  ]
}
```

## Deploy the Infrastructure

```bash
terraform plan
terraform apply
```

Review the plan and type `yes` when prompted.

## Verification and Testing

### Lab Exercise 2A: Connect via SSH

1. **Get the instance public IPs:**
   ```bash
   terraform output instance_public_ips
   ```

2. **SSH into the first instance:**
   ```bash
   ssh -i ~/.ssh/id_rsa ec2-user@<PUBLIC_IP>
   ```

3. **Verify the web server is running:**
   ```bash
   curl localhost
   systemctl status httpd
   ```

### Lab Exercise 2B: Test Web Access

1. **Get the public IP from Terraform output**
2. **Open in your browser:** `http://<PUBLIC_IP>`
3. **Verify you see the custom webpage with instance information**

### Lab Exercise 2C: Security Group Testing

1. **Test HTTP access from browser** ✅ Should work
2. **Test SSH from within VPC** ✅ Should work
3. **Test SSH from internet** ❌ Should be blocked (if configured correctly)

## Understanding the Components

### Security Groups
- **Stateful**: Return traffic is automatically allowed
- **Default deny**: Only explicitly allowed traffic gets through
- **Can reference other security groups**
- **Changes take effect immediately**

### EC2 Instance Types
- **t3.micro**: Burstable performance, free tier eligible
- **2 vCPUs, 1 GB RAM**
- **Good for low to moderate workloads**

### User Data Scripts
- **Runs once** when instance first starts
- **Runs as root** user
- **Used for initial configuration**
- **Can install software, start services, configure applications**

## Best Practices Implemented

1. **Security**:
   - SSH access restricted to VPC CIDR
   - Principle of least privilege
   - Separate security groups for different functions

2. **High Availability**:
   - Instances across multiple AZs
   - Consistent configuration via Launch Template

3. **Automation**:
   - User data for automated setup
   - Infrastructure as Code with Terraform

## Troubleshooting

### Common Issues

1. **Can't SSH to instance**:
   - Check security group rules
   - Verify SSH key permissions: `chmod 600 ~/.ssh/id_rsa`
   - Ensure you're using the correct username (ec2-user for Amazon Linux)

2. **Web page not loading**:
   - Check security group allows port 80
   - Verify Apache is running: `systemctl status httpd`
   - Check instance logs in AWS Console

3. **User data script didn't run**:
   - Check `/var/log/cloud-init-output.log` on the instance
   - Verify script syntax

### Debugging Commands

```bash
# On the EC2 instance:
sudo tail -f /var/log/httpd/access_log    # Apache access logs
sudo tail -f /var/log/httpd/error_log     # Apache error logs
sudo systemctl status httpd               # Apache service status
curl -I localhost                         # Test local HTTP access
```

## Cost Optimization Tips

1. **Stop instances when not in use**:
   ```bash
   aws ec2 stop-instances --instance-ids <INSTANCE_ID>
   ```

2. **Use Spot Instances for testing** (not covered in this lab)

3. **Monitor usage with CloudWatch** (covered in Lab 8)

## Clean Up

```bash
terraform destroy
```

## Next Steps
- Proceed to [Lab 3: Application Load Balancer](lab-03-alb.md)
- Learn about distributing traffic across multiple instances
- Understand health checks and high availability patterns

## Additional Resources
- [EC2 User Guide](https://docs.aws.amazon.com/ec2/latest/userguide/)
- [Security Groups Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
