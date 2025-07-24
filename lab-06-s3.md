# Lab 6: S3 Storage

## Understanding S3
Amazon Simple Storage Service (S3) is object storage designed to store and retrieve any amount of data from anywhere. It's highly durable, available, and scalable storage for backup, archival, analytics, and static website hosting.

## Learning Objectives
By the end of this lab, you will:
- Understand object storage concepts
- Create and configure S3 buckets
- Implement S3 security best practices
- Enable versioning and encryption
- Configure bucket policies and IAM access
- Upload and manage objects in S3

## Prerequisites
- Completed [Lab 5: RDS Database](lab-05-rds.md)
- Understanding of IAM roles and policies

## Cost Information
**Estimated Additional Monthly Cost: ~$1.00**
- S3 Standard storage: $0.023/GB per month
- PUT/POST requests: $0.0005 per 1,000 requests
- GET requests: $0.0004 per 1,000 requests
- **Total**: Very low for typical lab usage (~$1/month)

## Architecture Overview
This lab adds object storage to your infrastructure:
- S3 bucket with versioning and encryption
- Bucket policies for secure access
- IAM roles for EC2 access to S3
- Integration with web applications

## S3 Bucket Configuration

**Add to your `main.tf`:**

```hcl
# =============================================================================
# S3 BUCKET CONFIGURATION
# =============================================================================

# Random suffix for globally unique bucket name
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket for application data and static content
resource "aws_s3_bucket" "main" {
  bucket = "${var.project_name}-app-bucket-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.project_name}-app-bucket"
    Environment = "lab"
    Purpose     = "Application data and static content"
  }
}

# S3 Bucket Versioning
# Keeps multiple versions of objects for data protection
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server Side Encryption
# Encrypts all objects stored in the bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # AWS-managed encryption keys
    }
    bucket_key_enabled = true  # Reduces encryption costs
  }
}

# S3 Bucket Public Access Block
# Prevents accidental public exposure of objects
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration
# Manages object lifecycle to optimize costs
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "main_lifecycle_rule"
    status = "Enabled"

    # Transition objects to cheaper storage classes
    transition {
      days          = 30
      storage_class = "STANDARD_IA"  # Infrequent Access after 30 days
    }

    transition {
      days          = 90
      storage_class = "GLACIER"  # Archive after 90 days
    }

    # Delete old versions to control costs
    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# S3 Bucket Logging (Optional)
# Log access to the bucket for security monitoring
resource "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-access-logs-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.project_name}-access-logs"
    Environment = "lab"
    Purpose     = "S3 access logs"
  }
}

resource "aws_s3_bucket_logging" "main" {
  bucket = aws_s3_bucket.main.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "access-logs/"
}
```

## IAM Roles and Policies for S3 Access

**Add to your `main.tf`:**

```hcl
# =============================================================================
# IAM CONFIGURATION FOR S3 ACCESS
# =============================================================================

# IAM Policy for S3 Access
resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-s3-access-policy"
  description = "Policy for EC2 instances to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListAllMyBuckets"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-s3-policy"
  }
}

# Update existing IAM role or create new one
resource "aws_iam_role" "ec2_s3_role" {
  name = "${var.project_name}-ec2-s3-role"

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
    Name = "${var.project_name}-ec2-s3-role"
  }
}

# Attach S3 policy to role
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# Attach existing database secrets policy if it exists
resource "aws_iam_role_policy_attachment" "db_secrets_attachment_s3_role" {
  count      = var.enable_database ? 1 : 0
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.db_secrets_policy[0].arn
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "${var.project_name}-ec2-s3-profile"
  role = aws_iam_role.ec2_s3_role.name
}
```

## S3 Bucket Policy

**Add to your `main.tf`:**

```hcl
# =============================================================================
# S3 BUCKET POLICY
# =============================================================================

# S3 Bucket Policy for additional security
resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEC2Access"
        Effect    = "Allow"
        Principal = {
          AWS = aws_iam_role.ec2_s3_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.main.arn}/*"
      },
      {
        Sid       = "AllowEC2ListBucket"
        Effect    = "Allow"
        Principal = {
          AWS = aws_iam_role.ec2_s3_role.arn
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.main.arn
      },
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.main]
}
```

## Update Launch Template for S3 Integration

**Update your launch template to include S3 functionality:**

```hcl
# Update your existing launch template
resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-web"
  description   = "Launch template for web servers with S3 access"
  
  image_id      = "ami-0c02fb55956c7d316"  # Amazon Linux 2023
  instance_type = "t3.micro"
  key_name      = aws_key_pair.main.key_name

  vpc_security_group_ids = [aws_security_group.web.id]

  # Attach IAM instance profile for S3 access
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_s3_profile.name
  }

  monitoring {
    enabled = true
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Update the system
    yum update -y
    
    # Install required packages
    yum install -y httpd stress-ng htop mysql aws-cli jq
    
    # Start and enable Apache
    systemctl start httpd
    systemctl enable httpd
    
    # Get instance metadata
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
    
    # S3 bucket name from Terraform
    S3_BUCKET="${aws_s3_bucket.main.bucket}"
    
    # Create enhanced web page with S3 integration
    cat > /var/www/html/index.html << HTML
    <!DOCTYPE html>
    <html>
    <head>
        <title>Auto Scaling Lab Server with S3 Storage</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background-color: #f0f0f0; }
            .container { background-color: white; padding: 20px; border-radius: 10px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
            .info { background-color: #e7f3ff; padding: 10px; margin: 10px 0; border-radius: 5px; }
            .database { background-color: #f0f8e7; padding: 10px; margin: 10px 0; border-radius: 5px; }
            .storage { background-color: #fff3e0; padding: 10px; margin: 10px 0; border-radius: 5px; }
            .highlight { color: #0066cc; font-weight: bold; }
            .success { color: #4caf50; font-weight: bold; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Complete AWS Infrastructure Lab</h1>
            
            <div class="info">
                <h3>Server Information</h3>
                <p><span class="highlight">Hostname:</span> $(hostname -f)</p>
                <p><span class="highlight">Instance ID:</span> $INSTANCE_ID</p>
                <p><span class="highlight">Availability Zone:</span> $AZ</p>
                <p><span class="highlight">Private IP:</span> $PRIVATE_IP</p>
                <p><span class="highlight">Launch Time:</span> $(date)</p>
            </div>
            
            <div class="storage">
                <h3>S3 Storage Information</h3>
                <p><span class="highlight">S3 Bucket:</span> $S3_BUCKET</p>
                <p><span class="highlight">Storage Status:</span> <span class="success">Connected ✅</span></p>
                <p><span class="highlight">Encryption:</span> AES-256 Enabled</p>
                <p><span class="highlight">Versioning:</span> Enabled</p>
            </div>
            
            <div class="database">
                <h3>Database Information</h3>
                <p><span class="highlight">Database Status:</span> <span class="success">Available ✅</span></p>
                <p><em>Database and S3 operations available via SSH</em></p>
            </div>
            
            <p>🔄 <strong>Managed by Auto Scaling Group</strong></p>
            <p>🗄️ <strong>Connected to RDS MySQL Database</strong></p>
            <p>📦 <strong>Integrated with S3 Object Storage</strong></p>
        </div>
    </body>
    </html>
HTML

    # Create S3 operations script
    cat > /home/ec2-user/s3-operations.sh << 'SCRIPT'
#!/bin/bash
S3_BUCKET="${aws_s3_bucket.main.bucket}"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

echo "=== S3 Operations for $S3_BUCKET ==="
echo ""

# Test S3 access
echo "1. Testing S3 access..."
aws s3 ls s3://$S3_BUCKET/ && echo "✅ S3 access successful" || echo "❌ S3 access failed"
echo ""

# Upload a test file
echo "2. Creating and uploading test file..."
echo "Hello from instance $INSTANCE_ID at $(date)" > /tmp/test-file.txt
aws s3 cp /tmp/test-file.txt s3://$S3_BUCKET/test-files/instance-$INSTANCE_ID.txt
echo "✅ File uploaded to s3://$S3_BUCKET/test-files/instance-$INSTANCE_ID.txt"
echo ""

# List bucket contents
echo "3. Listing bucket contents..."
aws s3 ls s3://$S3_BUCKET/ --recursive
echo ""

# Download example
echo "4. Sample download command:"
echo "aws s3 cp s3://$S3_BUCKET/test-files/instance-$INSTANCE_ID.txt /tmp/downloaded-file.txt"
echo ""

echo "=== S3 Useful Commands ==="
echo "List all objects: aws s3 ls s3://$S3_BUCKET/ --recursive"
echo "Upload file: aws s3 cp <local-file> s3://$S3_BUCKET/<path>"
echo "Download file: aws s3 cp s3://$S3_BUCKET/<path> <local-file>"
echo "Sync directory: aws s3 sync <local-dir> s3://$S3_BUCKET/<path>"
echo "Remove file: aws s3 rm s3://$S3_BUCKET/<path>"
SCRIPT

    chmod +x /home/ec2-user/s3-operations.sh
    chown ec2-user:ec2-user /home/ec2-user/s3-operations.sh
    
    # Run initial S3 test
    /home/ec2-user/s3-operations.sh > /var/log/s3-setup.log 2>&1
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-asg-web-server-s3"
      Type = "AutoScalingWebServerWithS3"
      Environment = "lab"
    }
  }

  tags = {
    Name = "${var.project_name}-launch-template-s3"
  }
}
```

## Sample S3 Objects

**Add some sample objects to demonstrate S3 functionality:**

```hcl
# =============================================================================
# SAMPLE S3 OBJECTS
# =============================================================================

# Upload sample static content
resource "aws_s3_object" "sample_html" {
  bucket = aws_s3_bucket.main.id
  key    = "static/sample.html"
  content = <<-HTML
    <!DOCTYPE html>
    <html>
    <head>
        <title>Sample Static Content</title>
    </head>
    <body>
        <h1>Hello from S3!</h1>
        <p>This is a sample static file stored in S3.</p>
        <p>Generated at: ${timestamp()}</p>
    </body>
    </html>
  HTML
  content_type = "text/html"

  tags = {
    Name = "Sample HTML file"
  }
}

# Upload sample JSON configuration
resource "aws_s3_object" "sample_config" {
  bucket = aws_s3_bucket.main.id
  key    = "config/app-config.json"
  content = jsonencode({
    app_name    = var.project_name
    environment = "lab"
    database_enabled = true
    s3_enabled = true
    features = [
      "auto-scaling",
      "load-balancing",
      "database",
      "object-storage"
    ]
    created_at = timestamp()
  })
  content_type = "application/json"

  tags = {
    Name = "Application configuration"
  }
}

# Upload sample CSS file
resource "aws_s3_object" "sample_css" {
  bucket = aws_s3_bucket.main.id
  key    = "static/style.css"
  content = <<-CSS
    body {
        font-family: 'Arial', sans-serif;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        margin: 0;
        padding: 40px;
    }
    .container {
        max-width: 800px;
        margin: 0 auto;
        background: rgba(255,255,255,0.1);
        padding: 30px;
        border-radius: 15px;
        backdrop-filter: blur(10px);
    }
    h1 { text-align: center; margin-bottom: 30px; }
    .info-box { 
        background: rgba(255,255,255,0.2); 
        padding: 15px; 
        margin: 15px 0; 
        border-radius: 8px; 
    }
  CSS
  content_type = "text/css"

  tags = {
    Name = "Sample CSS file"
  }
}
```

## Update Outputs

**Add S3-related outputs:**

```hcl
# =============================================================================
# S3 OUTPUTS
# =============================================================================

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.main.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.main.arn
}

output "s3_bucket_region" {
  description = "Region of the S3 bucket"
  value       = aws_s3_bucket.main.region
}

output "s3_sample_objects" {
  description = "Sample objects uploaded to S3"
  value = {
    html_file   = "s3://${aws_s3_bucket.main.bucket}/${aws_s3_object.sample_html.key}"
    config_file = "s3://${aws_s3_bucket.main.bucket}/${aws_s3_object.sample_config.key}"
    css_file    = "s3://${aws_s3_bucket.main.bucket}/${aws_s3_object.sample_css.key}"
  }
}
```

## Deploy S3 Integration

```bash
terraform plan
terraform apply
```

## Verification and Testing

### Lab Exercise 6A: Basic S3 Operations

1. **Verify S3 bucket creation:**
   ```bash
   # List your buckets
   aws s3 ls
   
   # Get bucket details
   terraform output s3_bucket_name
   aws s3 ls s3://$(terraform output -raw s3_bucket_name)/
   ```

2. **Test from EC2 instance:**
   ```bash
   # SSH to an instance
   ssh -i ~/.ssh/id_rsa ec2-user@<INSTANCE_IP>
   
   # Run S3 operations script
   ./s3-operations.sh
   ```

### Lab Exercise 6B: File Upload and Download

1. **Upload files from EC2:**
   ```bash
   # On EC2 instance
   echo "Test content from $(hostname)" > test-upload.txt
   aws s3 cp test-upload.txt s3://$(aws s3 ls | grep aws-lab | awk '{print $3}')/uploads/
   ```

2. **Download and verify:**
   ```bash
   # Download from S3
   aws s3 cp s3://YOUR-BUCKET-NAME/uploads/test-upload.txt downloaded-file.txt
   cat downloaded-file.txt
   ```

3. **Test versioning:**
   ```bash
   # Upload same file with different content
   echo "Updated content from $(hostname)" > test-upload.txt
   aws s3 cp test-upload.txt s3://YOUR-BUCKET-NAME/uploads/
   
   # List versions
   aws s3api list-object-versions --bucket YOUR-BUCKET-NAME --prefix uploads/test-upload.txt
   ```

### Lab Exercise 6C: Web Application Integration

1. **Create application data:**
   ```bash
   # On EC2 instance, create application logs
   cat > app-log.json << EOF
   {
     "instance_id": "$(curl -s http://169.254.169.254/latest/meta-data/instance-id)",
     "timestamp": "$(date -Iseconds)",
     "event": "application_start",
     "metrics": {
       "cpu_count": $(nproc),
       "memory_mb": $(free -m | awk 'NR==2{printf "%.0f", $2}')
     }
   }
   EOF
   
   # Upload to S3
   aws s3 cp app-log.json s3://YOUR-BUCKET-NAME/logs/$(date +%Y/%m/%d)/
   ```

2. **Retrieve configuration from S3:**
   ```bash
   # Download configuration file
   aws s3 cp s3://YOUR-BUCKET-NAME/config/app-config.json /tmp/
   cat /tmp/app-config.json | jq .
   ```

## Understanding S3 Features

### Storage Classes
- **Standard**: Frequently accessed data
- **Standard-IA**: Infrequently accessed data
- **Glacier**: Archive storage
- **Deep Archive**: Long-term archival

### Security Features
- **Bucket Policies**: Resource-based permissions
- **IAM Policies**: User/role-based permissions
- **Access Control Lists**: Object-level permissions
- **Encryption**: Server-side and client-side

### Management Features
- **Versioning**: Multiple versions of objects
- **Lifecycle Policies**: Automatic transitions and deletions
- **Cross-Region Replication**: Geographic redundancy
- **Event Notifications**: Trigger actions on object changes

## Best Practices Implemented

1. **Security**:
   - Public access blocked
   - Encryption enabled
   - Secure transport required
   - IAM roles for access

2. **Cost Optimization**:
   - Lifecycle policies
   - Appropriate storage classes
   - Old version cleanup

3. **Data Management**:
   - Versioning enabled
   - Logical object organization
   - Access logging

## Troubleshooting

### Common Issues

1. **Access denied errors:**
   - Check IAM policies and roles
   - Verify bucket policies
   - Ensure proper instance profile attached

2. **Slow uploads/downloads:**
   - Check network bandwidth
   - Consider multipart uploads for large files
   - Use appropriate AWS CLI configuration

3. **High costs:**
   - Review storage class usage
   - Check lifecycle policies
   - Monitor request patterns

### Monitoring Commands

```bash
# Check bucket size and object count
aws s3 ls s3://YOUR-BUCKET-NAME --recursive --human-readable --summarize

# Monitor access patterns
aws logs filter-log-events \
  --log-group-name /aws/s3/YOUR-BUCKET-NAME \
  --start-time $(date -d '1 hour ago' +%s)000

# Check lifecycle policy status
aws s3api get-bucket-lifecycle-configuration --bucket YOUR-BUCKET-NAME
```

## Cost Optimization

1. **Storage Class Analysis**: Use S3 Analytics to optimize storage classes
2. **Lifecycle Policies**: Automate transitions and deletions
3. **Request Optimization**: Batch operations when possible
4. **Transfer Acceleration**: For global applications

## Clean Up

```bash
# Empty bucket before destroying (Terraform can't destroy non-empty buckets)
aws s3 rm s3://$(terraform output -raw s3_bucket_name) --recursive

terraform destroy
```

## Next Steps
- Proceed to [Lab 7: IAM Roles and Policies](lab-07-iam.md)
- Learn advanced IAM concepts
- Implement comprehensive security policies

## Additional Resources
- [S3 User Guide](https://docs.aws.amazon.com/s3/latest/userguide/)
- [S3 Best Practices](https://docs.aws.amazon.com/s3/latest/userguide/security-best-practices.html)
- [S3 Storage Classes](https://aws.amazon.com/s3/storage-classes/)
