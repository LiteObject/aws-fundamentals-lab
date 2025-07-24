# Lab 8: CloudWatch Monitoring

## Understanding CloudWatch
Amazon CloudWatch is a monitoring and observability service that provides data and actionable insights to monitor applications, respond to system-wide performance changes, and optimize resource utilization.

## Learning Objectives
By the end of this lab, you will:
- Understand comprehensive monitoring concepts
- Create custom CloudWatch dashboards
- Set up detailed alerting systems
- Implement log aggregation and analysis
- Configure application performance monitoring
- Understand cost optimization through monitoring

## Prerequisites
- Completed [Lab 7: IAM Roles and Policies](lab-07-iam.md)
- All previous lab infrastructure deployed

## Cost Information
**Estimated Additional Monthly Cost: ~$5.00**
- CloudWatch alarms: $0.10/alarm per month
- Custom metrics: $0.30/metric per month
- Dashboard: $3.00/dashboard per month
- Log storage: $0.50/GB per month
- **Total**: ~$5-10/month depending on usage

## Architecture Overview
This lab completes your monitoring infrastructure:
- Comprehensive CloudWatch dashboards
- Custom metrics and alarms
- Log aggregation from all services
- Application performance monitoring
- Cost and resource optimization alerts

## Enhanced CloudWatch Configuration

**Add to your `main.tf`:**

```hcl
# =============================================================================
# CLOUDWATCH DASHBOARDS
# =============================================================================

# Main infrastructure dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-infrastructure-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.web.name],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix],
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix],
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.identifier]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Key Performance Metrics"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.web.arn_suffix],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", aws_lb_target_group.web.arn_suffix],
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", aws_autoscaling_group.web.name],
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.web.name]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Health and Capacity Metrics"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.main.identifier],
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.main.identifier],
            ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", aws_db_instance.main.identifier],
            ["AWS/RDS", "WriteLatency", "DBInstanceIdentifier", aws_db_instance.main.identifier]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Database Performance Metrics"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6

        properties = {
          query = "SOURCE '/aws/${var.project_name}/application' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          region = data.aws_region.current.name
          title = "Recent Application Logs"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-main-dashboard"
    Environment = "lab"
  }
}

# Cost monitoring dashboard
resource "aws_cloudwatch_dashboard" "cost" {
  dashboard_name = "${var.project_name}-cost-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Currency", "USD"]
          ]
          period = 86400  # Daily
          stat   = "Maximum"
          region = "us-east-1"  # Billing metrics only available in us-east-1
          title  = "Estimated Monthly Charges"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-cost-dashboard"
    Environment = "lab"
  }
}
```

## Enhanced CloudWatch Alarms

**Add comprehensive alerting to your `main.tf`:**

```hcl
# =============================================================================
# COMPREHENSIVE CLOUDWATCH ALARMS
# =============================================================================

# SNS topic for notifications
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name        = "${var.project_name}-alerts"
    Environment = "lab"
  }
}

# SNS topic subscription (email - replace with your email)
resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "your-email@example.com"  # Replace with your email

  depends_on = [aws_sns_topic.alerts]
}

# High CPU Alarm (updated with SNS)
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors EC2 CPU utilization for scale up"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn, aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  tags = {
    Name        = "${var.project_name}-high-cpu-alarm"
    Severity    = "warning"
    Environment = "lab"
  }
}

# Low CPU Alarm (updated with SNS)
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.project_name}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  alarm_description   = "This metric monitors EC2 CPU utilization for scale down"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn, aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  tags = {
    Name        = "${var.project_name}-low-cpu-alarm"
    Severity    = "info"
    Environment = "lab"
  }
}

# Load Balancer Response Time Alarm
resource "aws_cloudwatch_metric_alarm" "high_response_time" {
  alarm_name          = "${var.project_name}-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "120"
  statistic           = "Average"
  threshold           = "1.0"  # 1 second
  alarm_description   = "High response time detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-high-response-time"
    Severity    = "warning"
    Environment = "lab"
  }
}

# Unhealthy Hosts Alarm
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.project_name}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "Unhealthy hosts detected in target group"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup = aws_lb_target_group.web.arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-unhealthy-hosts"
    Severity    = "critical"
    Environment = "lab"
  }
}

# Database CPU Alarm
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  alarm_name          = "${var.project_name}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "High CPU usage on RDS instance"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = {
    Name        = "${var.project_name}-rds-high-cpu"
    Severity    = "warning"
    Environment = "lab"
  }
}

# Database Connection Alarm
resource "aws_cloudwatch_metric_alarm" "rds_high_connections" {
  alarm_name          = "${var.project_name}-rds-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"  # Adjust based on your instance class
  alarm_description   = "High number of database connections"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = {
    Name        = "${var.project_name}-rds-high-connections"
    Severity    = "warning"
    Environment = "lab"
  }
}

# Cost Alert
resource "aws_cloudwatch_metric_alarm" "high_billing" {
  alarm_name          = "${var.project_name}-high-billing"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"  # Daily
  statistic           = "Maximum"
  threshold           = "50"  # $50 threshold - adjust as needed
  alarm_description   = "High estimated charges detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    Currency = "USD"
  }

  tags = {
    Name        = "${var.project_name}-high-billing"
    Severity    = "critical"
    Environment = "lab"
  }
}
```

## CloudWatch Logs Configuration

**Add comprehensive logging to your `main.tf`:**

```hcl
# =============================================================================
# CLOUDWATCH LOGS
# =============================================================================

# Application Log Group
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/${var.project_name}/application"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-application-logs"
    Environment = "lab"
  }
}

# Web Server Access Logs
resource "aws_cloudwatch_log_group" "web_access" {
  name              = "/aws/${var.project_name}/web/access"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-web-access-logs"
    Environment = "lab"
  }
}

# Web Server Error Logs
resource "aws_cloudwatch_log_group" "web_error" {
  name              = "/aws/${var.project_name}/web/error"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-web-error-logs"
    Environment = "lab"
  }
}

# System Logs
resource "aws_cloudwatch_log_group" "system" {
  name              = "/aws/${var.project_name}/system"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-system-logs"
    Environment = "lab"
  }
}

# CloudWatch Log Stream for application metrics
resource "aws_cloudwatch_log_stream" "application_metrics" {
  name           = "metrics-stream"
  log_group_name = aws_cloudwatch_log_group.application.name
}

# Log Metric Filters
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  name           = "${var.project_name}-error-count"
  log_group_name = aws_cloudwatch_log_group.application.name
  pattern        = "[timestamp, request_id, \"ERROR\"]"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "${var.project_name}/Application"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "response_time" {
  name           = "${var.project_name}-response-time"
  log_group_name = aws_cloudwatch_log_group.web_access.name
  pattern        = "[ip, identity, user, timestamp, request, status_code, size, response_time]"

  metric_transformation {
    name      = "ResponseTime"
    namespace = "${var.project_name}/Application"
    value     = "$response_time"
  }
}

# Custom Application Error Alarm
resource "aws_cloudwatch_metric_alarm" "application_errors" {
  alarm_name          = "${var.project_name}-application-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ErrorCount"
  namespace           = "${var.project_name}/Application"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "High application error rate detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = {
    Name        = "${var.project_name}-application-errors"
    Severity    = "warning"
    Environment = "lab"
  }
}
```

## Update Launch Template with CloudWatch Agent

**Update your launch template for comprehensive monitoring:**

```hcl
# Update your existing launch template
resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-web"
  description   = "Launch template with comprehensive monitoring"
  
  image_id      = "ami-0c02fb55956c7d316"
  instance_type = "t3.micro"
  key_name      = aws_key_pair.main.key_name

  vpc_security_group_ids = [aws_security_group.web.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_comprehensive_profile.name
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Update the system
    yum update -y
    
    # Install required packages
    yum install -y httpd stress-ng htop mysql aws-cli jq amazon-cloudwatch-agent
    
    # Start and enable Apache
    systemctl start httpd
    systemctl enable httpd
    
    # Configure CloudWatch Agent
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CW_CONFIG'
    {
      "metrics": {
        "namespace": "${var.project_name}/EC2",
        "metrics_collected": {
          "cpu": {
            "measurement": [
              "cpu_usage_idle",
              "cpu_usage_iowait",
              "cpu_usage_user",
              "cpu_usage_system"
            ],
            "metrics_collection_interval": 60,
            "totalcpu": false
          },
          "disk": {
            "measurement": [
              "used_percent"
            ],
            "metrics_collection_interval": 60,
            "resources": [
              "*"
            ]
          },
          "diskio": {
            "measurement": [
              "io_time"
            ],
            "metrics_collection_interval": 60,
            "resources": [
              "*"
            ]
          },
          "mem": {
            "measurement": [
              "mem_used_percent"
            ],
            "metrics_collection_interval": 60
          },
          "netstat": {
            "measurement": [
              "tcp_established",
              "tcp_time_wait"
            ],
            "metrics_collection_interval": 60
          },
          "swap": {
            "measurement": [
              "swap_used_percent"
            ],
            "metrics_collection_interval": 60
          }
        }
      },
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/httpd/access_log",
                "log_group_name": "/aws/${var.project_name}/web/access",
                "log_stream_name": "{instance_id}/access.log"
              },
              {
                "file_path": "/var/log/httpd/error_log",
                "log_group_name": "/aws/${var.project_name}/web/error",
                "log_stream_name": "{instance_id}/error.log"
              },
              {
                "file_path": "/var/log/messages",
                "log_group_name": "/aws/${var.project_name}/system",
                "log_stream_name": "{instance_id}/messages"
              }
            ]
          }
        }
      }
    }
CW_CONFIG

    # Start CloudWatch Agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 -s \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
    
    # Get instance metadata
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
    
    # Create application monitoring script
    cat > /home/ec2-user/send-custom-metrics.sh << 'SCRIPT'
#!/bin/bash
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
NAMESPACE="${var.project_name}/Application"

# Send custom application metrics
aws cloudwatch put-metric-data \
  --namespace "$NAMESPACE" \
  --metric-data MetricName=ApplicationHealth,Value=1,Unit=Count,Dimensions=InstanceId=$INSTANCE_ID

# Send memory usage
MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.2f", $3/$2 * 100.0)}')
aws cloudwatch put-metric-data \
  --namespace "$NAMESPACE" \
  --metric-data MetricName=MemoryUtilization,Value=$MEMORY_USAGE,Unit=Percent,Dimensions=InstanceId=$INSTANCE_ID

# Send disk usage
DISK_USAGE=$(df / | grep -vE '^Filesystem' | awk '{print $5}' | sed 's/%//g')
aws cloudwatch put-metric-data \
  --namespace "$NAMESPACE" \
  --metric-data MetricName=DiskUtilization,Value=$DISK_USAGE,Unit=Percent,Dimensions=InstanceId=$INSTANCE_ID

echo "Custom metrics sent to CloudWatch"
SCRIPT

    chmod +x /home/ec2-user/send-custom-metrics.sh
    chown ec2-user:ec2-user /home/ec2-user/send-custom-metrics.sh
    
    # Set up cron job for regular metrics
    echo "*/5 * * * * /home/ec2-user/send-custom-metrics.sh >> /var/log/custom-metrics.log 2>&1" | crontab -u ec2-user -
    
    # Create enhanced web page with monitoring info
    cat > /var/www/html/index.html << HTML
    <!DOCTYPE html>
    <html>
    <head>
        <title>Complete AWS Infrastructure with Monitoring</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
            .container { max-width: 1200px; margin: 0 auto; background: rgba(255,255,255,0.1); padding: 30px; border-radius: 15px; backdrop-filter: blur(10px); }
            .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 20px 0; }
            .info-box { background: rgba(255,255,255,0.2); padding: 15px; border-radius: 8px; }
            .monitoring-box { background: rgba(255, 193, 7, 0.3); padding: 15px; border-radius: 8px; }
            .highlight { color: #ffeb3b; font-weight: bold; }
            .success { color: #4caf50; font-weight: bold; }
            h1 { text-align: center; margin-bottom: 30px; }
            h3 { margin-top: 0; color: #ffeb3b; }
            .status-indicator { display: inline-block; width: 10px; height: 10px; border-radius: 50%; background-color: #4caf50; margin-right: 5px; }
        </style>
        <script>
            function updateTimestamp() {
                document.getElementById('timestamp').textContent = new Date().toLocaleString();
            }
            setInterval(updateTimestamp, 1000);
            window.onload = updateTimestamp;
        </script>
    </head>
    <body>
        <div class="container">
            <h1>📊 Complete AWS Infrastructure Lab</h1>
            
            <div class="info-grid">
                <div class="info-box">
                    <h3>Server Information</h3>
                    <p><span class="highlight">Instance ID:</span> $INSTANCE_ID</p>
                    <p><span class="highlight">Availability Zone:</span> $AZ</p>
                    <p><span class="highlight">Private IP:</span> $PRIVATE_IP</p>
                    <p><span class="highlight">Current Time:</span> <span id="timestamp"></span></p>
                </div>
                
                <div class="monitoring-box">
                    <h3>📊 Monitoring Features</h3>
                    <p><span class="status-indicator"></span><span class="success">CloudWatch Agent Active</span></p>
                    <p><span class="status-indicator"></span><span class="success">Custom Metrics Enabled</span></p>
                    <p><span class="status-indicator"></span><span class="success">Log Aggregation Active</span></p>
                    <p><span class="status-indicator"></span><span class="success">Alerting Configured</span></p>
                    <p><span class="status-indicator"></span><span class="success">Dashboard Available</span></p>
                </div>
                
                <div class="info-box">
                    <h3>🏗️ Infrastructure Stack</h3>
                    <p>🔄 Auto Scaling Group</p>
                    <p>⚖️ Application Load Balancer</p>
                    <p>🗄️ RDS MySQL Database</p>
                    <p>📦 S3 Object Storage</p>
                    <p>🔐 Comprehensive IAM</p>
                    <p>📊 CloudWatch Monitoring</p>
                </div>
                
                <div class="monitoring-box">
                    <h3>🔔 Active Monitoring</h3>
                    <p>• CPU Utilization Tracking</p>
                    <p>• Memory and Disk Usage</p>
                    <p>• Application Response Times</p>
                    <p>• Database Performance</p>
                    <p>• Health Check Monitoring</p>
                    <p>• Cost Tracking</p>
                </div>
            </div>
            
            <div class="info-box">
                <h3>📈 Metrics Dashboard</h3>
                <p>Access your CloudWatch Dashboard: <strong>aws-lab-infrastructure-dashboard</strong></p>
                <p>View cost monitoring: <strong>aws-lab-cost-dashboard</strong></p>
                <p>All metrics are updated every 5 minutes with custom application data.</p>
            </div>
        </div>
    </body>
    </html>
HTML

    # Log application startup
    aws logs put-log-events \
      --log-group-name "/aws/${var.project_name}/application" \
      --log-stream-name "$INSTANCE_ID" \
      --log-events timestamp=$(date +%s)000,message="Application started on instance $INSTANCE_ID" \
      --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region) 2>/dev/null || true
    
    # Send initial custom metrics
    /home/ec2-user/send-custom-metrics.sh
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-monitored-web-server"
      Type = "MonitoredAutoScalingWebServer"
      Environment = "lab"
      Monitoring = "comprehensive"
    }
  }

  tags = {
    Name = "${var.project_name}-monitored-launch-template"
  }
}
```

## CloudWatch Outputs

**Add monitoring-related outputs:**

```hcl
# =============================================================================
# CLOUDWATCH OUTPUTS
# =============================================================================

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "cost_dashboard_url" {
  description = "URL to the cost monitoring dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.cost.dashboard_name}"
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "log_groups" {
  description = "CloudWatch log groups created"
  value = {
    application = aws_cloudwatch_log_group.application.name
    web_access  = aws_cloudwatch_log_group.web_access.name
    web_error   = aws_cloudwatch_log_group.web_error.name
    system      = aws_cloudwatch_log_group.system.name
  }
}

output "monitoring_alarms" {
  description = "CloudWatch alarms configured"
  value = {
    high_cpu           = aws_cloudwatch_metric_alarm.high_cpu.alarm_name
    low_cpu           = aws_cloudwatch_metric_alarm.low_cpu.alarm_name
    high_response_time = aws_cloudwatch_metric_alarm.high_response_time.alarm_name
    unhealthy_hosts   = aws_cloudwatch_metric_alarm.unhealthy_hosts.alarm_name
    rds_high_cpu      = aws_cloudwatch_metric_alarm.rds_high_cpu.alarm_name
    high_billing      = aws_cloudwatch_metric_alarm.high_billing.alarm_name
  }
}
```

## Deploy Complete Monitoring

```bash
terraform plan
terraform apply
```

**Note**: Remember to update the SNS subscription email address to your actual email.

## Verification and Testing

### Lab Exercise 8A: Dashboard Verification

1. **Access CloudWatch Dashboards:**
   ```bash
   # Get dashboard URLs
   terraform output cloudwatch_dashboard_url
   terraform output cost_dashboard_url
   
   # Open in browser or AWS Console
   ```

2. **Verify metrics are flowing:**
   - Check dashboard widgets show data
   - Verify custom metrics appear
   - Confirm log streams are active

### Lab Exercise 8B: Alerting Testing

1. **Test CPU-based scaling:**
   ```bash
   # SSH to an instance
   ssh -i ~/.ssh/id_rsa ec2-user@<INSTANCE_IP>
   
   # Generate CPU load
   stress-ng --cpu $(nproc) --timeout 600s
   ```

2. **Monitor alert behavior:**
   - Check email for SNS notifications
   - Verify alarms change state in console
   - Confirm auto scaling triggers

### Lab Exercise 8C: Log Analysis

1. **Generate application logs:**
   ```bash
   # On EC2 instance
   echo "$(date): INFO: User action completed successfully" | aws logs put-log-events \
     --log-group-name "/aws/aws-lab/application" \
     --log-stream-name "$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" \
     --log-events timestamp=$(date +%s)000,message="$(cat -)"
   ```

2. **Query logs using CloudWatch Insights:**
   ```sql
   fields @timestamp, @message
   | filter @message like /ERROR/
   | sort @timestamp desc
   | limit 20
   ```

### Lab Exercise 8D: Cost Monitoring

1. **Review billing metrics:**
   ```bash
   # Get current estimated charges
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Billing \
     --metric-name EstimatedCharges \
     --dimensions Name=Currency,Value=USD \
     --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 86400 \
     --statistics Maximum \
     --region us-east-1
   ```

## Understanding CloudWatch Components

### Metrics
- **Standard Metrics**: Provided by AWS services
- **Custom Metrics**: Application-specific metrics
- **High Resolution**: Sub-minute data points
- **Dimensions**: Filter and aggregate data

### Logs
- **Log Groups**: Collections of log streams
- **Log Streams**: Sequences of log events
- **Metric Filters**: Extract metrics from logs
- **Insights**: Query and analyze logs

### Alarms
- **Threshold Alarms**: Based on metric values
- **Composite Alarms**: Based on other alarms
- **Actions**: SNS, Auto Scaling, EC2 actions
- **States**: OK, ALARM, INSUFFICIENT_DATA

## Best Practices Implemented

1. **Comprehensive Monitoring**:
   - Infrastructure and application metrics
   - Log aggregation and analysis
   - Proactive alerting
   - Cost monitoring

2. **Operational Excellence**:
   - Automated response to issues
   - Historical data for analysis
   - Dashboard for visualization
   - Documentation through tags

3. **Cost Optimization**:
   - Appropriate log retention
   - Efficient metric collection
   - Targeted alerting
   - Regular monitoring review

## Troubleshooting

### Common Issues

1. **Missing metrics:**
   - Check CloudWatch agent configuration
   - Verify IAM permissions
   - Confirm log group creation

2. **Alarm not triggering:**
   - Review threshold settings
   - Check evaluation periods
   - Verify metric data availability

3. **High CloudWatch costs:**
   - Review metric retention
   - Optimize log retention
   - Reduce custom metric frequency

### Monitoring Commands

```bash
# Check CloudWatch agent status
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 -a query-config

# View recent log events
aws logs filter-log-events \
  --log-group-name "/aws/aws-lab/application" \
  --start-time $(date -d '1 hour ago' +%s)000

# Check alarm states
aws cloudwatch describe-alarms \
  --alarm-names aws-lab-high-cpu aws-lab-low-cpu
```

## Cost Optimization

### Monitoring Costs
1. **Log Retention**: Adjust based on compliance needs
2. **Metric Resolution**: Use appropriate intervals
3. **Dashboard Usage**: Share dashboards efficiently
4. **Alert Frequency**: Avoid noisy alerts

### Resource Optimization
1. **Right-sizing**: Use metrics to optimize instance sizes
2. **Auto Scaling**: Optimize scaling policies
3. **Reserved Instances**: Use for predictable workloads
4. **Spot Instances**: For fault-tolerant workloads

## Clean Up

```bash
terraform destroy
```

**Note**: This will remove all infrastructure. Ensure you've saved any important data or configurations.

## Lab Completion

Congratulations! You have successfully completed all 8 labs and built a comprehensive, production-ready AWS infrastructure including:

✅ **VPC with public/private subnets**
✅ **Auto Scaling EC2 instances**
✅ **Application Load Balancer**
✅ **RDS MySQL database**
✅ **S3 object storage**
✅ **Comprehensive IAM security**
✅ **Complete monitoring and alerting**

## Next Steps

1. **Production Deployment**:
   - Enable deletion protection
   - Implement multi-region setup
   - Add disaster recovery

2. **Advanced Features**:
   - CI/CD pipelines
   - Container orchestration
   - Serverless integration

3. **Certification Preparation**:
   - AWS Solutions Architect
   - AWS SysOps Administrator
   - AWS DevOps Engineer

## Additional Resources
- [CloudWatch User Guide](https://docs.aws.amazon.com/cloudwatch/latest/monitoring/)
- [CloudWatch Best Practices](https://docs.aws.amazon.com/cloudwatch/latest/monitoring/cloudwatch_architecture.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
