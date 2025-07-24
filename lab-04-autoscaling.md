# Lab 4: Auto Scaling Group

## Understanding Auto Scaling
Auto Scaling automatically adjusts the number of EC2 instances in response to demand. This ensures you have the right amount of compute capacity to handle your application's load while optimizing costs.

## Learning Objectives
By the end of this lab, you will:
- Understand Auto Scaling concepts and benefits
- Create an Auto Scaling Group (ASG)
- Configure scaling policies
- Integrate ASG with Application Load Balancer
- Test automatic scaling behavior
- Implement CloudWatch alarms for scaling triggers

## Prerequisites
- Completed [Lab 3: Application Load Balancer](lab-03-alb.md)
- Understanding of EC2 instances and load balancers

## Cost Information
**Estimated Cost Impact: Variable**
- Auto Scaling Group: FREE (you pay only for the EC2 instances)
- EC2 instances: ~$8.50/month per t3.micro instance
- CloudWatch alarms: $0.10/month per alarm
- **Total**: Depends on scaling activity (minimum ~$17/month for 2 instances)

## Architecture Overview
This lab replaces static EC2 instances with an Auto Scaling Group:
- Auto Scaling Group managing 2-6 instances
- Scaling policies triggered by CPU utilization
- Integration with existing Application Load Balancer
- Automatic instance replacement if unhealthy
- CloudWatch alarms for monitoring and triggering

## Auto Scaling Group Configuration

**First, comment out or remove the standalone EC2 instances in `main.tf`:**

```hcl
# =============================================================================
# COMMENT OUT STANDALONE EC2 INSTANCES
# =============================================================================
# The Auto Scaling Group will manage instances now

# Comment out or remove this entire block:
# resource "aws_instance" "web" {
#   count = 2
#   subnet_id = aws_subnet.public[count.index].id
#   launch_template {
#     id      = aws_launch_template.web.id
#     version = "$Latest"
#   }
#   tags = {
#     Name = "${var.project_name}-web-${count.index + 1}"
#     Environment = "lab"
#   }
# }

# Also comment out the target group attachments:
# resource "aws_lb_target_group_attachment" "web" {
#   count = length(aws_instance.web)
#   target_group_arn = aws_lb_target_group.web.arn
#   target_id        = aws_instance.web[count.index].id
#   port             = 80
# }
```

**Add the Auto Scaling Group configuration to `main.tf`:**

```hcl
# =============================================================================
# AUTO SCALING GROUP
# =============================================================================

# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name                = "${var.project_name}-asg"
  vpc_zone_identifier = aws_subnet.public[*].id  # Deploy across public subnets
  target_group_arns   = [aws_lb_target_group.web.arn]  # Integrate with ALB
  health_check_type   = "ELB"  # Use load balancer health checks
  health_check_grace_period = 300  # Wait 5 minutes before health checks

  # Capacity configuration
  min_size         = 2    # Minimum number of instances
  max_size         = 6    # Maximum number of instances
  desired_capacity = 2    # Initial desired number of instances

  # Launch template configuration
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"  # Always use latest version
  }

  # Instance refresh for rolling updates
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50  # Keep at least 50% healthy during updates
      instance_warmup       = 300  # Wait 5 minutes for new instances
    }
  }

  # Tag propagation to instances
  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "lab"
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "AutoScaling"
    propagate_at_launch = true
  }

  # Lifecycle hook for graceful shutdown (optional)
  # termination_policies = ["OldestInstance"]

  # Wait for instances to be healthy before considering deployment complete
  wait_for_capacity_timeout = "10m"
}
```

## Scaling Policies

**Add scaling policies to `main.tf`:**

```hcl
# =============================================================================
# SCALING POLICIES
# =============================================================================

# Scale Up Policy
# Adds instances when CPU utilization is high
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-scale-up"
  scaling_adjustment     = 2                    # Add 2 instances
  adjustment_type        = "ChangeInCapacity"   # Type of adjustment
  cooldown               = 300                  # Wait 5 minutes between scaling actions
  autoscaling_group_name = aws_autoscaling_group.web.name

  tags = {
    Name = "${var.project_name}-scale-up-policy"
  }
}

# Scale Down Policy
# Removes instances when CPU utilization is low
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-scale-down"
  scaling_adjustment     = -1                   # Remove 1 instance
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300                  # Wait 5 minutes between scaling actions
  autoscaling_group_name = aws_autoscaling_group.web.name

  tags = {
    Name = "${var.project_name}-scale-down-policy"
  }
}
```

## CloudWatch Alarms

**Add CloudWatch alarms to trigger scaling policies:**

```hcl
# =============================================================================
# CLOUDWATCH ALARMS
# =============================================================================

# High CPU Alarm
# Triggers scale-up when average CPU > 70%
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"                    # 2 consecutive periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"                  # 2-minute periods
  statistic           = "Average"
  threshold           = "70"                   # 70% CPU threshold
  alarm_description   = "This metric monitors EC2 CPU utilization for scale up"

  # Target the Auto Scaling Group
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  # Trigger scale-up policy
  alarm_actions = [aws_autoscaling_policy.scale_up.arn]

  tags = {
    Name = "${var.project_name}-high-cpu-alarm"
  }
}

# Low CPU Alarm
# Triggers scale-down when average CPU < 30%
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.project_name}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"                    # 2 consecutive periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"                  # 2-minute periods
  statistic           = "Average"
  threshold           = "30"                   # 30% CPU threshold
  alarm_description   = "This metric monitors EC2 CPU utilization for scale down"

  # Target the Auto Scaling Group
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  # Trigger scale-down policy
  alarm_actions = [aws_autoscaling_policy.scale_down.arn]

  tags = {
    Name = "${var.project_name}-low-cpu-alarm"
  }
}
```

## Update Launch Template (Enhanced)

**Update the launch template with better monitoring:**

```hcl
# Update your existing launch template with enhanced configuration
resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-web"
  description   = "Launch template for Auto Scaling web servers"
  
  image_id      = "ami-0c02fb55956c7d316"  # Amazon Linux 2023
  instance_type = "t3.micro"
  key_name      = aws_key_pair.main.key_name

  vpc_security_group_ids = [aws_security_group.web.id]

  # Enable detailed monitoring for better CloudWatch metrics
  monitoring {
    enabled = true
  }

  # Enhanced user data with CPU stress testing capability
  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Update the system
    yum update -y
    
    # Install required packages
    yum install -y httpd stress-ng htop
    
    # Start and enable Apache
    systemctl start httpd
    systemctl enable httpd
    
    # Create enhanced web page with more instance info
    cat > /var/www/html/index.html << 'HTML'
    <!DOCTYPE html>
    <html>
    <head>
        <title>Auto Scaling Lab Server</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background-color: #f0f0f0; }
            .container { background-color: white; padding: 20px; border-radius: 10px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
            .info { background-color: #e7f3ff; padding: 10px; margin: 10px 0; border-radius: 5px; }
            .highlight { color: #0066cc; font-weight: bold; }
        </style>
        <script>
            function refreshPage() { location.reload(); }
            setInterval(refreshPage, 30000); // Refresh every 30 seconds
        </script>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Auto Scaling Web Server</h1>
            <div class="info">
                <p><span class="highlight">Hostname:</span> $(hostname -f)</p>
                <p><span class="highlight">Instance ID:</span> $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
                <p><span class="highlight">Availability Zone:</span> $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
                <p><span class="highlight">Instance Type:</span> $(curl -s http://169.254.169.254/latest/meta-data/instance-type)</p>
                <p><span class="highlight">Private IP:</span> $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)</p>
                <p><span class="highlight">Launch Time:</span> $(date)</p>
            </div>
            <p><em>This page auto-refreshes every 30 seconds</em></p>
            <p>🔄 <strong>Managed by Auto Scaling Group</strong></p>
        </div>
    </body>
    </html>
HTML

    # Create a simple CPU stress test script for testing
    cat > /home/ec2-user/cpu-stress.sh << 'SCRIPT'
#!/bin/bash
echo "Starting CPU stress test for 5 minutes..."
echo "This will trigger Auto Scaling if thresholds are configured correctly"
stress-ng --cpu $(nproc) --timeout 300s --metrics-brief
echo "CPU stress test completed"
SCRIPT

    chmod +x /home/ec2-user/cpu-stress.sh
    chown ec2-user:ec2-user /home/ec2-user/cpu-stress.sh
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-asg-web-server"
      Type = "AutoScalingWebServer"
      Environment = "lab"
    }
  }

  tags = {
    Name = "${var.project_name}-launch-template-v2"
  }
}
```

## Update Outputs

**Update your outputs section:**

```hcl
# Update outputs for Auto Scaling Group
output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.arn
}

output "scale_up_policy_arn" {
  description = "ARN of the scale up policy"
  value       = aws_autoscaling_policy.scale_up.arn
}

output "scale_down_policy_arn" {
  description = "ARN of the scale down policy"
  value       = aws_autoscaling_policy.scale_down.arn
}

# Keep existing load balancer outputs
output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_url" {
  description = "URL of the Application Load Balancer"
  value       = "http://${aws_lb.main.dns_name}"
}
```

## Deploy the Auto Scaling Group

```bash
terraform plan
terraform apply
```

**Note**: The deployment will:
1. Terminate existing standalone instances
2. Create Auto Scaling Group
3. Launch new instances managed by ASG
4. Register instances with the load balancer

## Verification and Testing

### Lab Exercise 4A: Basic Auto Scaling Verification

1. **Check Auto Scaling Group in AWS Console:**
   - Go to EC2 → Auto Scaling Groups
   - Verify your ASG is running with 2 instances
   - Check the "Activity" tab for scaling activities

2. **Verify load balancer integration:**
   ```bash
   # Test load balancer URL
   terraform output load_balancer_url
   curl -s $(terraform output -raw load_balancer_url)
   ```

3. **Check CloudWatch alarms:**
   - Go to CloudWatch → Alarms
   - Verify both CPU alarms are created and in "OK" state

### Lab Exercise 4B: Manual Scaling Test

1. **Manually adjust desired capacity:**
   ```bash
   # Scale up to 4 instances
   aws autoscaling set-desired-capacity \
     --auto-scaling-group-name $(terraform output -raw autoscaling_group_name) \
     --desired-capacity 4
   ```

2. **Watch scaling activity:**
   - Monitor AWS Console for new instance launches
   - Check load balancer target group for new healthy targets
   - Test load balancer to see traffic distributed across 4 instances

3. **Scale back down:**
   ```bash
   # Scale back to 2 instances
   aws autoscaling set-desired-capacity \
     --auto-scaling-group-name $(terraform output -raw autoscaling_group_name) \
     --desired-capacity 2
   ```

### Lab Exercise 4C: Automatic Scaling Test

1. **Generate CPU load to trigger scale-up:**
   ```bash
   # Get one instance IP from load balancer
   ALB_URL=$(terraform output -raw load_balancer_url)
   
   # SSH to instance (you'll need to check instance IPs in console)
   # Use the stress script we installed
   ssh -i ~/.ssh/id_rsa ec2-user@<INSTANCE_IP>
   ./cpu-stress.sh
   ```

2. **Alternative: Generate load via load balancer:**
   ```bash
   # Use Apache Bench to generate load (install if needed)
   ab -n 10000 -c 100 $(terraform output -raw load_balancer_url)/
   ```

3. **Monitor scaling activity:**
   - Watch CloudWatch alarms change state
   - Monitor Auto Scaling Group activity
   - Verify new instances are launched and registered

### Lab Exercise 4D: Instance Replacement Test

1. **Terminate an instance manually:**
   ```bash
   # Get instance IDs
   aws autoscaling describe-auto-scaling-groups \
     --auto-scaling-group-names $(terraform output -raw autoscaling_group_name) \
     --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text
   
   # Terminate one instance
   aws ec2 terminate-instances --instance-ids <INSTANCE_ID>
   ```

2. **Verify automatic replacement:**
   - ASG should launch a replacement instance
   - Load balancer should continue serving traffic
   - New instance should become healthy in target group

## Understanding Auto Scaling Components

### Auto Scaling Group Benefits
- **High Availability**: Automatically replaces failed instances
- **Cost Optimization**: Scales capacity based on demand
- **Load Distribution**: Integrates with load balancers
- **Health Monitoring**: Monitors and replaces unhealthy instances

### Scaling Policies
- **Target Tracking**: Maintain specific metric value
- **Step Scaling**: Scale in steps based on alarm severity
- **Simple Scaling**: Single scaling action per alarm

### CloudWatch Integration
- **Metrics**: CPU, memory, network, custom metrics
- **Alarms**: Trigger scaling actions
- **Dashboards**: Visualize scaling activity

## Best Practices Implemented

1. **Multi-AZ Deployment**: Instances across multiple availability zones
2. **Health Checks**: ELB health checks for more accurate detection
3. **Gradual Scaling**: Conservative scaling policies to avoid flapping
4. **Monitoring**: CloudWatch alarms for visibility
5. **Instance Refresh**: Rolling updates for launch template changes

## Troubleshooting

### Common Issues

1. **Instances failing health checks:**
   - Check security group rules
   - Verify application starts correctly
   - Review user data script logs

2. **Scaling not triggered:**
   - Verify CloudWatch alarms are configured correctly
   - Check alarm state and metrics
   - Ensure scaling policies are attached

3. **Instances stuck in "pending" state:**
   - Check subnet capacity
   - Verify IAM permissions
   - Review launch template configuration

### Monitoring Commands

```bash
# Check Auto Scaling Group status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw autoscaling_group_name)

# Check scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $(terraform output -raw autoscaling_group_name)

# Check CloudWatch alarm states
aws cloudwatch describe-alarms --alarm-names \
  "$(terraform output -raw autoscaling_group_name)-high-cpu" \
  "$(terraform output -raw autoscaling_group_name)-low-cpu"
```

## Cost Optimization Tips

1. **Right-size instances**: Use appropriate instance types
2. **Scheduled scaling**: Scale based on predictable patterns
3. **Spot instances**: Use for fault-tolerant workloads
4. **Monitor unused capacity**: Adjust min/max values based on usage

## Clean Up

```bash
terraform destroy
```

## Next Steps
- Proceed to [Lab 5: RDS Database](lab-05-rds.md)
- Learn about managed database services
- Integrate database with your auto-scaling web application

## Additional Resources
- [Auto Scaling User Guide](https://docs.aws.amazon.com/autoscaling/ec2/userguide/)
- [CloudWatch Alarms Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [Auto Scaling Best Practices](https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-benefits.html)
