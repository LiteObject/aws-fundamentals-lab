# Lab 3: Application Load Balancer

## Understanding Application Load Balancer (ALB)
An Application Load Balancer distributes incoming application traffic across multiple targets, such as EC2 instances, in multiple Availability Zones. This improves the availability and fault tolerance of your applications.

## Learning Objectives
By the end of this lab, you will:
- Understand load balancing concepts and benefits
- Create an Application Load Balancer
- Configure target groups and health checks
- Set up load balancer listeners
- Test traffic distribution across multiple instances

## Prerequisites
- Completed [Lab 2: EC2 Instances and Security Groups](lab-02-ec2.md)
- 2 running EC2 instances from previous lab

## Cost Information
**💰 Estimated Additional Monthly Cost: ~$22.00**
- Application Load Balancer: ~$22/month + data processing charges
- Target Groups: FREE
- Health Checks: FREE

## Architecture Overview
This lab adds load balancing to your infrastructure:
- 1 Application Load Balancer in public subnets
- 1 Target Group with health checks
- Load balancer distributing traffic to EC2 instances
- Improved availability and fault tolerance

## Security Group for Load Balancer

**Add to your existing `main.tf`:**

```hcl
# =============================================================================
# LOAD BALANCER SECURITY GROUP
# =============================================================================

# Security Group for ALB
# Controls traffic to the Application Load Balancer
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb"
  vpc_id      = aws_vpc.main.id
  description = "Security group for Application Load Balancer"

  # Allow HTTP traffic from anywhere
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS traffic from anywhere (for future use)
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
    Name = "${var.project_name}-alb-sg"
  }
}
```

## Update Web Server Security Group

**Modify the existing web security group in `main.tf` to allow traffic from the load balancer:**

```hcl
# Update the existing aws_security_group.web resource
resource "aws_security_group" "web" {
  name_prefix = "${var.project_name}-web"
  vpc_id      = aws_vpc.main.id
  description = "Security group for web servers"

  # Allow HTTP from Load Balancer only (more secure)
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]  # Only from ALB
  }

  # Allow HTTPS from Load Balancer only
  ingress {
    description     = "HTTPS from ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow SSH from within VPC for management
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
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

## Application Load Balancer Configuration

**Add to your `main.tf`:**

```hcl
# =============================================================================
# APPLICATION LOAD BALANCER
# =============================================================================

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false                    # Internet-facing
  load_balancer_type = "application"            # ALB for HTTP/HTTPS
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id  # Deploy across public subnets

  # Enable deletion protection in production
  enable_deletion_protection = false  # Set to true in production

  # Access logs (optional, requires S3 bucket)
  # access_logs {
  #   bucket  = aws_s3_bucket.alb_logs.bucket
  #   prefix  = "alb-logs"
  #   enabled = true
  # }

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = "lab"
  }
}

# Target Group
# Defines the targets (EC2 instances) for the load balancer
resource "aws_lb_target_group" "web" {
  name     = "${var.project_name}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Health check configuration
  health_check {
    enabled             = true
    healthy_threshold   = 2          # Number of consecutive successful checks
    interval            = 30         # Frequency of health checks (seconds)
    matcher             = "200"      # Expected HTTP response code
    path                = "/"        # Health check path
    port                = "traffic-port"  # Use the same port as target
    protocol            = "HTTP"
    timeout             = 5          # Timeout for each health check
    unhealthy_threshold = 2          # Number of consecutive failed checks
  }

  # Deregistration delay
  deregistration_delay = 300  # Time to wait before deregistering targets

  tags = {
    Name = "${var.project_name}-web-tg"
  }
}

# Target Group Attachments
# Register EC2 instances with the target group
resource "aws_lb_target_group_attachment" "web" {
  count = length(aws_instance.web)

  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

# Load Balancer Listener
# Defines how the load balancer processes incoming requests
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action - forward to target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  tags = {
    Name = "${var.project_name}-web-listener"
  }
}
```

## Update Outputs

**Add to the outputs section in `main.tf`:**

```hcl
# Add these outputs to your existing outputs section

# Load Balancer DNS name
output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

# Load Balancer URL
output "load_balancer_url" {
  description = "URL of the Application Load Balancer"
  value       = "http://${aws_lb.main.dns_name}"
}

# Target Group ARN
output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.web.arn
}
```

## Deploy the Load Balancer

```bash
terraform plan
terraform apply
```

**Note**: It may take 2-5 minutes for the load balancer to become fully operational.

## Verification and Testing

### Lab Exercise 3A: Basic Load Balancer Testing

1. **Get the load balancer URL:**
   ```bash
   terraform output load_balancer_url
   ```

2. **Test the load balancer in your browser:**
   - Open the URL in your browser
   - Refresh multiple times
   - Notice different instance IDs appearing (load balancing in action)

3. **Test via command line:**
   ```bash
   # Replace with your ALB DNS name
   ALB_DNS="your-alb-dns-name"
   
   # Make multiple requests to see load balancing
   for i in {1..10}; do
     curl -s http://$ALB_DNS | grep "Instance ID"
     sleep 1
   done
   ```

### Lab Exercise 3B: Health Check Testing

1. **Check target health in AWS Console:**
   - Go to EC2 → Load Balancers
   - Select your load balancer
   - Check "Target Groups" tab
   - Verify all targets are "healthy"

2. **Test health check failure:**
   ```bash
   # SSH to one instance
   ssh -i ~/.ssh/id_rsa ec2-user@<INSTANCE_IP>
   
   # Stop Apache to simulate failure
   sudo systemctl stop httpd
   ```

3. **Observe behavior:**
   - Wait 1-2 minutes
   - Check target group health in AWS Console
   - Test load balancer URL - traffic should only go to healthy instance
   - Restart Apache: `sudo systemctl start httpd`

### Lab Exercise 3C: High Availability Testing

1. **Stop one EC2 instance:**
   ```bash
   # Get instance ID
   terraform output instance_ids
   
   # Stop instance via AWS CLI
   aws ec2 stop-instances --instance-ids <INSTANCE_ID>
   ```

2. **Verify continued service:**
   - Load balancer URL should still work
   - All traffic goes to remaining healthy instance
   - Start the instance again to restore full capacity

## Understanding Load Balancer Components

### Target Groups
- **Health Checks**: Automatically detect unhealthy instances
- **Sticky Sessions**: Can be enabled to route users to same instance
- **Multiple Protocols**: Support for HTTP, HTTPS, and more

### Listeners
- **Port and Protocol**: Define what traffic to accept
- **Rules**: Route traffic based on conditions
- **Actions**: Forward, redirect, return fixed response

### Security Benefits
- **Hide Backend Servers**: Direct access to instances not needed
- **SSL Termination**: Can handle SSL certificates (not in this lab)
- **DDoS Protection**: Better protection against attacks

## Monitoring and Troubleshooting

### CloudWatch Metrics (Automatic)
- **RequestCount**: Number of requests processed
- **TargetResponseTime**: Response time from targets
- **HTTPCode_Target_2XX_Count**: Successful responses
- **UnHealthyHostCount**: Number of unhealthy targets

### Common Issues

1. **Load balancer returns 503 errors**:
   - Check target group health
   - Verify security group rules
   - Check if instances are running

2. **Health checks failing**:
   - Verify web server is running on targets
   - Check health check path exists
   - Review security group rules

3. **Uneven traffic distribution**:
   - Normal for small numbers of requests
   - ALB uses round-robin by default
   - Stickiness might be enabled

### Debugging Commands

```bash
# Check target group health via AWS CLI
aws elbv2 describe-target-health --target-group-arn <TARGET_GROUP_ARN>

# Test direct instance access (should be blocked now)
curl -I http://<INSTANCE_PUBLIC_IP>

# Test load balancer access
curl -I http://<ALB_DNS_NAME>
```

## Best Practices Implemented

1. **Security**:
   - Instances only accept traffic from load balancer
   - Load balancer accepts traffic from internet
   - Principle of least privilege

2. **High Availability**:
   - Load balancer spans multiple AZs
   - Automatic health checking
   - Traffic routing to healthy instances only

3. **Scalability**:
   - Easy to add/remove backend instances
   - Automatic distribution of load

## Cost Optimization

1. **Right-sizing**: Choose appropriate load balancer type
2. **Target Utilization**: Minimize number of load balancers
3. **Monitoring**: Track actual usage vs. capacity

## Clean Up

```bash
terraform destroy
```

## Next Steps
- Proceed to [Lab 4: Auto Scaling Group](lab-04-autoscaling.md)
- Learn about automatic scaling based on demand
- Integrate Auto Scaling with your load balancer

## Additional Resources
- [Application Load Balancer Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Target Groups Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)
- [Health Checks Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)
