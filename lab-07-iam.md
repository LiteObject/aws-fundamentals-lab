# Lab 7: IAM Roles and Policies

## Understanding IAM
AWS Identity and Access Management (IAM) enables you to manage access to AWS services and resources securely. IAM provides fine-grained access control across all of AWS.

## Learning Objectives
By the end of this lab, you will:
- Understand IAM principles and best practices
- Create comprehensive IAM policies
- Implement role-based access control
- Configure cross-service permissions
- Set up IAM for production security

## Prerequisites
- Completed [Lab 6: S3 Storage](lab-06-s3.md)
- Understanding of AWS services from previous labs

## Cost Information
**Cost: FREE**
- IAM users, groups, roles, and policies: No charge
- AWS CloudTrail (first trail): Free
- IAM Access Analyzer: Free

## Architecture Overview
This lab enhances your infrastructure security:
- Comprehensive IAM roles and policies
- Service-specific permissions
- Cross-service access controls
- Security monitoring and compliance

## Enhanced IAM Structure

**Replace and enhance your existing IAM configuration in `main.tf`:**

```hcl
# =============================================================================
# COMPREHENSIVE IAM CONFIGURATION
# =============================================================================

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Data source for current AWS region
data "aws_region" "current" {}

# =============================================================================
# IAM ROLES
# =============================================================================

# EC2 Service Role - Comprehensive permissions for web servers
resource "aws_iam_role" "ec2_service_role" {
  name = "${var.project_name}-ec2-service-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = data.aws_region.current.name
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ec2-service-role"
    Purpose     = "EC2 instances service access"
    Environment = "lab"
  }
}

# Auto Scaling Service Role
resource "aws_iam_role" "autoscaling_service_role" {
  name = "${var.project_name}-autoscaling-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "autoscaling.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-autoscaling-service-role"
    Purpose     = "Auto Scaling service operations"
    Environment = "lab"
  }
}

# CloudWatch Logs Role
resource "aws_iam_role" "cloudwatch_logs_role" {
  name = "${var.project_name}-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["logs.amazonaws.com", "ec2.amazonaws.com"]
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-cloudwatch-logs-role"
    Purpose     = "CloudWatch logs access"
    Environment = "lab"
  }
}

# =============================================================================
# IAM POLICIES - S3 ACCESS
# =============================================================================

# S3 Read-Only Policy
resource "aws_iam_policy" "s3_read_only" {
  name        = "${var.project_name}-s3-read-only"
  description = "Read-only access to specific S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.main.arn
      },
      {
        Sid    = "GetObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.main.arn}/*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-s3-read-only-policy"
  }
}

# S3 Read-Write Policy with restrictions
resource "aws_iam_policy" "s3_read_write" {
  name        = "${var.project_name}-s3-read-write"
  description = "Read-write access to specific S3 bucket with restrictions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.main.arn
      },
      {
        Sid    = "ObjectOperations"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.main.arn}/*"
        Condition = {
          StringLike = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
        }
      },
      {
        Sid    = "PreventDeleteOfCriticalData"
        Effect = "Deny"
        Action = [
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.main.arn}/critical/*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-s3-read-write-policy"
  }
}

# =============================================================================
# IAM POLICIES - RDS ACCESS
# =============================================================================

# RDS Connect Policy
resource "aws_iam_policy" "rds_connect" {
  name        = "${var.project_name}-rds-connect"
  description = "Policy for RDS database connections"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RDSDescribe"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = data.aws_region.current.name
          }
        }
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_password.arn
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-rds-connect-policy"
  }
}

# =============================================================================
# IAM POLICIES - CLOUDWATCH
# =============================================================================

# CloudWatch Monitoring Policy
resource "aws_iam_policy" "cloudwatch_monitoring" {
  name        = "${var.project_name}-cloudwatch-monitoring"
  description = "Policy for CloudWatch monitoring and logging"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = [
              "AWS/EC2",
              "CWAgent",
              "${var.project_name}/Application"
            ]
          }
        }
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/${var.project_name}/*"
      },
      {
        Sid    = "EC2InstanceMetadata"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-cloudwatch-monitoring-policy"
  }
}

# =============================================================================
# IAM POLICIES - SYSTEMS MANAGER
# =============================================================================

# Systems Manager Policy for instance management
resource "aws_iam_policy" "systems_manager" {
  name        = "${var.project_name}-systems-manager"
  description = "Policy for AWS Systems Manager access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMCore"
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssm:SendCommand",
          "ssm:ListCommandInvocations",
          "ssm:DescribeInstanceInformation",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = data.aws_region.current.name
          }
        }
      },
      {
        Sid    = "SSMMessages"
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-systems-manager-policy"
  }
}

# =============================================================================
# POLICY ATTACHMENTS
# =============================================================================

# Attach policies to EC2 service role
resource "aws_iam_role_policy_attachment" "ec2_s3_read_write" {
  role       = aws_iam_role.ec2_service_role.name
  policy_arn = aws_iam_policy.s3_read_write.arn
}

resource "aws_iam_role_policy_attachment" "ec2_rds_connect" {
  role       = aws_iam_role.ec2_service_role.name
  policy_arn = aws_iam_policy.rds_connect.arn
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_monitoring" {
  role       = aws_iam_role.ec2_service_role.name
  policy_arn = aws_iam_policy.cloudwatch_monitoring.arn
}

resource "aws_iam_role_policy_attachment" "ec2_systems_manager" {
  role       = aws_iam_role.ec2_service_role.name
  policy_arn = aws_iam_policy.systems_manager.arn
}

# Attach AWS managed policies
resource "aws_iam_role_policy_attachment" "ec2_ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_agent_server" {
  role       = aws_iam_role.ec2_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# =============================================================================
# INSTANCE PROFILES
# =============================================================================

# Instance profile for EC2 instances
resource "aws_iam_instance_profile" "ec2_comprehensive_profile" {
  name = "${var.project_name}-ec2-comprehensive-profile"
  role = aws_iam_role.ec2_service_role.name

  tags = {
    Name = "${var.project_name}-ec2-comprehensive-profile"
  }
}

# =============================================================================
# IAM USERS AND GROUPS (Optional for demonstration)
# =============================================================================

# Developer group with limited permissions
resource "aws_iam_group" "developers" {
  name = "${var.project_name}-developers"
}

# Developer policy - read-only access to most resources
resource "aws_iam_policy" "developer_policy" {
  name        = "${var.project_name}-developer-policy"
  description = "Policy for developers with read-only access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOnlyAccess"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "rds:Describe*",
          "s3:List*",
          "s3:Get*",
          "autoscaling:Describe*",
          "elasticloadbalancing:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "cloudwatch:Describe*",
          "logs:Describe*",
          "logs:Get*",
          "iam:Get*",
          "iam:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyDestructiveActions"
        Effect = "Deny"
        Action = [
          "*:Delete*",
          "*:Terminate*",
          "*:Stop*",
          "s3:Put*",
          "s3:Create*",
          "iam:Create*",
          "iam:Put*",
          "iam:Attach*",
          "iam:Detach*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-developer-policy"
  }
}

# Attach policy to group
resource "aws_iam_group_policy_attachment" "developers_policy" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.developer_policy.arn
}
```

## Security Best Practices Implementation

**Add security monitoring and compliance:**

```hcl
# =============================================================================
# SECURITY MONITORING
# =============================================================================

# CloudTrail for API logging
resource "aws_cloudtrail" "main" {
  name           = "${var.project_name}-cloudtrail"
  s3_bucket_name = aws_s3_bucket.cloudtrail_logs.bucket

  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    exclude_management_event_sources = ["kms.amazonaws.com", "rdsdata.amazonaws.com"]

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.main.arn}/*"]
    }
  }

  tags = {
    Name        = "${var.project_name}-cloudtrail"
    Environment = "lab"
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "${var.project_name}-cloudtrail-logs-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-cloudtrail-logs"
    Environment = "lab"
  }
}

# CloudTrail S3 bucket policy
resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# IAM Access Analyzer
resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "${var.project_name}-access-analyzer"
  type          = "ACCOUNT"

  tags = {
    Name        = "${var.project_name}-access-analyzer"
    Environment = "lab"
  }
}
```

## Update Launch Template with Enhanced Security

**Update your launch template to use the comprehensive IAM profile:**

```hcl
# Update your existing launch template
resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-web"
  description   = "Launch template with comprehensive IAM security"
  
  image_id      = "ami-0c02fb55956c7d316"
  instance_type = "t3.micro"
  key_name      = aws_key_pair.main.key_name

  vpc_security_group_ids = [aws_security_group.web.id]

  # Use comprehensive IAM instance profile
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_comprehensive_profile.name
  }

  monitoring {
    enabled = true
  }

  # Metadata options for enhanced security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # Require IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Update the system
    yum update -y
    
    # Install required packages including CloudWatch agent
    yum install -y httpd stress-ng htop mysql aws-cli jq amazon-cloudwatch-agent
    
    # Start and enable Apache
    systemctl start httpd
    systemctl enable httpd
    
    # Install and configure CloudWatch agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 -s -c ssm:AmazonCloudWatch-linux
    
    # Get instance metadata
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
    IAM_ROLE=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/)
    
    # Test IAM permissions
    echo "Testing IAM permissions..." > /tmp/iam-test.log
    aws sts get-caller-identity >> /tmp/iam-test.log 2>&1
    aws s3 ls >> /tmp/iam-test.log 2>&1
    aws secretsmanager list-secrets >> /tmp/iam-test.log 2>&1
    
    # Create enhanced web page
    cat > /var/www/html/index.html << HTML
    <!DOCTYPE html>
    <html>
    <head>
        <title>Secure AWS Infrastructure Lab</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
            .container { max-width: 1000px; margin: 0 auto; background: rgba(255,255,255,0.1); padding: 30px; border-radius: 15px; backdrop-filter: blur(10px); }
            .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 20px 0; }
            .info-box { background: rgba(255,255,255,0.2); padding: 15px; border-radius: 8px; }
            .security-box { background: rgba(76, 175, 80, 0.3); padding: 15px; border-radius: 8px; }
            .highlight { color: #ffeb3b; font-weight: bold; }
            .success { color: #4caf50; font-weight: bold; }
            h1 { text-align: center; margin-bottom: 30px; }
            h3 { margin-top: 0; color: #ffeb3b; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🔐 Secure AWS Infrastructure Lab</h1>
            
            <div class="info-grid">
                <div class="info-box">
                    <h3>Server Information</h3>
                    <p><span class="highlight">Instance ID:</span> $INSTANCE_ID</p>
                    <p><span class="highlight">Availability Zone:</span> $AZ</p>
                    <p><span class="highlight">Private IP:</span> $PRIVATE_IP</p>
                    <p><span class="highlight">IAM Role:</span> $IAM_ROLE</p>
                </div>
                
                <div class="security-box">
                    <h3>🛡️ Security Features</h3>
                    <p><span class="success">✅ IAM Role-based Access</span></p>
                    <p><span class="success">✅ IMDSv2 Enforced</span></p>
                    <p><span class="success">✅ CloudWatch Monitoring</span></p>
                    <p><span class="success">✅ CloudTrail Logging</span></p>
                    <p><span class="success">✅ Secrets Manager Integration</span></p>
                </div>
                
                <div class="info-box">
                    <h3>📊 Services Integrated</h3>
                    <p>🔄 Auto Scaling Group</p>
                    <p>⚖️ Application Load Balancer</p>
                    <p>🗄️ RDS MySQL Database</p>
                    <p>📦 S3 Object Storage</p>
                    <p>🔐 Comprehensive IAM</p>
                </div>
            </div>
            
            <div class="security-box">
                <h3>🔑 IAM Permissions Summary</h3>
                <p>• S3 Read/Write with encryption requirements</p>
                <p>• RDS connection via Secrets Manager</p>
                <p>• CloudWatch metrics and logging</p>
                <p>• Systems Manager for instance management</p>
                <p>• Restricted to specific resources and regions</p>
            </div>
        </div>
    </body>
    </html>
HTML

    # Create IAM testing script
    cat > /home/ec2-user/test-iam-permissions.sh << 'SCRIPT'
#!/bin/bash
echo "=== IAM Permissions Test ==="
echo ""

echo "1. Testing STS (Security Token Service)..."
aws sts get-caller-identity && echo "✅ STS access successful" || echo "❌ STS access failed"
echo ""

echo "2. Testing S3 permissions..."
aws s3 ls && echo "✅ S3 list successful" || echo "❌ S3 list failed"
echo ""

echo "3. Testing Secrets Manager..."
aws secretsmanager list-secrets --region $(aws configure get region) && echo "✅ Secrets Manager access successful" || echo "❌ Secrets Manager access failed"
echo ""

echo "4. Testing CloudWatch..."
aws cloudwatch list-metrics --namespace AWS/EC2 --region $(aws configure get region) | head -10 && echo "✅ CloudWatch access successful" || echo "❌ CloudWatch access failed"
echo ""

echo "5. Testing Systems Manager..."
aws ssm describe-instance-information --region $(aws configure get region) && echo "✅ SSM access successful" || echo "❌ SSM access failed"
echo ""

echo "6. Testing restricted actions (should fail)..."
aws iam create-user --user-name test-user 2>&1 | grep -q "AccessDenied\|denied" && echo "✅ Restricted action properly denied" || echo "❌ Security issue: restricted action allowed"
SCRIPT

    chmod +x /home/ec2-user/test-iam-permissions.sh
    chown ec2-user:ec2-user /home/ec2-user/test-iam-permissions.sh
    
    # Run IAM permissions test
    /home/ec2-user/test-iam-permissions.sh > /var/log/iam-test-results.log 2>&1
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-secure-web-server"
      Type = "SecureAutoScalingWebServer"
      Environment = "lab"
      SecurityLevel = "enhanced"
    }
  }

  tags = {
    Name = "${var.project_name}-secure-launch-template"
  }
}
```

## IAM Outputs

**Add comprehensive IAM outputs:**

```hcl
# =============================================================================
# IAM OUTPUTS
# =============================================================================

output "iam_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = aws_iam_role.ec2_service_role.arn
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.ec2_comprehensive_profile.name
}

output "iam_policies" {
  description = "Custom IAM policies created"
  value = {
    s3_read_write         = aws_iam_policy.s3_read_write.arn
    rds_connect          = aws_iam_policy.rds_connect.arn
    cloudwatch_monitoring = aws_iam_policy.cloudwatch_monitoring.arn
    systems_manager      = aws_iam_policy.systems_manager.arn
    developer_policy     = aws_iam_policy.developer_policy.arn
  }
}

output "cloudtrail_bucket" {
  description = "S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail_logs.bucket
}

output "access_analyzer_arn" {
  description = "ARN of the IAM Access Analyzer"
  value       = aws_accessanalyzer_analyzer.main.arn
}
```

## Deploy Enhanced IAM Security

```bash
terraform plan
terraform apply
```

## Verification and Testing

### Lab Exercise 7A: IAM Role Verification

1. **Check IAM role and policies:**
   ```bash
   # List IAM roles
   aws iam list-roles --query 'Roles[?contains(RoleName, `aws-lab`)].RoleName'
   
   # Get role details
   terraform output iam_role_arn
   aws iam get-role --role-name $(terraform output -raw iam_role_arn | cut -d'/' -f2)
   ```

2. **Test from EC2 instance:**
   ```bash
   # SSH to instance
   ssh -i ~/.ssh/id_rsa ec2-user@<INSTANCE_IP>
   
   # Run IAM permissions test
   ./test-iam-permissions.sh
   ```

### Lab Exercise 7B: Security Testing

1. **Test allowed operations:**
   ```bash
   # On EC2 instance - these should work
   aws s3 ls
   aws secretsmanager list-secrets
   aws cloudwatch list-metrics --namespace AWS/EC2
   ```

2. **Test denied operations:**
   ```bash
   # On EC2 instance - these should fail
   aws iam create-user --user-name test-user
   aws ec2 terminate-instances --instance-ids i-1234567890abcdef0
   aws s3 rm s3://some-other-bucket/file.txt
   ```

### Lab Exercise 7C: CloudTrail and Monitoring

1. **Check CloudTrail logs:**
   ```bash
   # List CloudTrail events
   aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=GetObject
   
   # Check CloudTrail S3 bucket
   aws s3 ls s3://$(terraform output -raw cloudtrail_bucket)/
   ```

2. **Access Analyzer findings:**
   ```bash
   # Check Access Analyzer findings
   aws accessanalyzer list-findings --analyzer-arn $(terraform output -raw access_analyzer_arn)
   ```

## Understanding IAM Best Practices

### Principle of Least Privilege
- Grant only the minimum permissions needed
- Use specific resource ARNs when possible
- Implement condition statements for additional restrictions

### Security Features
- **MFA**: Multi-factor authentication
- **Temporary Credentials**: Use roles instead of long-term access keys
- **Regular Rotation**: Rotate credentials regularly
- **Monitoring**: Use CloudTrail and Access Analyzer

### Policy Structure
- **Version**: Always use "2012-10-17"
- **Statement**: Array of permission statements
- **Effect**: Allow or Deny
- **Action**: Specific API actions
- **Resource**: Specific AWS resources
- **Condition**: Additional restrictions

## Best Practices Implemented

1. **Security**:
   - Principle of least privilege
   - Resource-specific permissions
   - Conditional access
   - Monitoring and logging

2. **Compliance**:
   - CloudTrail for auditing
   - Access Analyzer for security insights
   - Structured policy organization

3. **Operational Excellence**:
   - Consistent naming conventions
   - Comprehensive tagging
   - Clear documentation

## Troubleshooting

### Common Issues

1. **Access denied errors:**
   - Check policy syntax and logic
   - Verify resource ARNs
   - Review condition statements

2. **Role assumption failures:**
   - Check trust policy
   - Verify service principals
   - Review assume role permissions

3. **Policy conflicts:**
   - Check for explicit denies
   - Review policy evaluation logic
   - Use policy simulator for testing

### Debugging Commands

```bash
# Test policy simulation
aws iam simulate-principal-policy \
  --policy-source-arn $(terraform output -raw iam_role_arn) \
  --action-names s3:GetObject \
  --resource-arns "arn:aws:s3:::my-bucket/my-object"

# Check attached policies
aws iam list-attached-role-policies --role-name ROLE_NAME

# Get policy version
aws iam get-policy-version --policy-arn POLICY_ARN --version-id v1
```

## Security Monitoring

### CloudWatch Metrics
- Failed API calls
- Unauthorized access attempts
- Policy evaluation failures

### CloudTrail Events
- API calls and their sources
- Authentication events
- Policy changes

### Access Analyzer
- Unintended external access
- Unused permissions
- Public resources

## Clean Up

```bash
terraform destroy
```

## Next Steps
- Proceed to [Lab 8: CloudWatch Monitoring](lab-08-cloudwatch.md)
- Learn comprehensive monitoring and alerting
- Complete the full AWS infrastructure stack

## Additional Resources
- [IAM User Guide](https://docs.aws.amazon.com/iam/latest/userguide/)
- [IAM Best Practices](https://docs.aws.amazon.com/iam/latest/userguide/best-practices.html)
- [Policy Examples](https://docs.aws.amazon.com/iam/latest/userguide/reference_policies_examples.html)
