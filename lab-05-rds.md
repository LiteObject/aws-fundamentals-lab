# Lab 5: RDS Database

## Understanding RDS
Amazon Relational Database Service (RDS) provides managed relational databases with automated backups, patching, and monitoring. It supports multiple database engines and handles routine database tasks.

## Learning Objectives
By the end of this lab, you will:
- Understand managed database services
- Create RDS MySQL database instance
- Configure database security groups
- Set up database subnet groups
- Connect applications to RDS
- Understand backup and maintenance windows

## Prerequisites
- Completed [Lab 4: Auto Scaling Group](lab-04-autoscaling.md)
- Basic understanding of relational databases

## Cost Information
**💰 Estimated Additional Monthly Cost: ~$15.00**
- RDS db.t3.micro instance: ~$15/month
- Storage (20GB): ~$2.30/month
- Backup storage: First 20GB free
- **Total**: ~$17.30/month additional

## Architecture Overview
This lab adds a managed database to your infrastructure:
- RDS MySQL instance in private subnets
- Database subnet group across multiple AZs
- Security group allowing access only from web servers
- Automated backups and maintenance windows

## Database Security Group

**Add to your `main.tf`:**

```hcl
# =============================================================================
# DATABASE SECURITY GROUP
# =============================================================================

# Security Group for RDS Database
# Controls access to the database instance
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds"
  vpc_id      = aws_vpc.main.id
  description = "Security group for RDS MySQL database"

  # Allow MySQL traffic only from web servers
  ingress {
    description     = "MySQL from web servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]  # Only from web security group
  }

  # No explicit egress rules needed for RDS
  # RDS automatically allows outbound traffic for database operations

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}
```

## Database Subnet Group

**Add to your `main.tf`:**

```hcl
# =============================================================================
# DATABASE SUBNET GROUP
# =============================================================================

# DB Subnet Group
# Specifies which subnets the database can be placed in
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id  # Use private subnets for security

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }

  description = "Subnet group for RDS database instances"
}
```

## RDS Database Instance

**Add to your `main.tf`:**

```hcl
# =============================================================================
# RDS DATABASE INSTANCE
# =============================================================================

# Random password for database
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Store password in AWS Secrets Manager (best practice)
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}-db-password"
  description             = "Database password for ${var.project_name}"
  recovery_window_in_days = 7  # Minimum for lab, increase for production

  tags = {
    Name = "${var.project_name}-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

# RDS MySQL Instance
resource "aws_db_instance" "main" {
  # Database identification
  identifier = "${var.project_name}-database"
  
  # Engine configuration
  engine         = "mysql"
  engine_version = "8.0.35"  # Specify exact version for consistency
  instance_class = "db.t3.micro"  # Free tier eligible

  # Storage configuration
  allocated_storage     = 20    # GB - minimum for MySQL
  max_allocated_storage = 100   # Auto-scaling limit
  storage_type          = "gp2" # General Purpose SSD
  storage_encrypted     = true  # Always encrypt storage

  # Database configuration
  db_name  = "labdb"
  username = "admin"
  password = random_password.db_password.result

  # Network configuration
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible    = false  # Keep in private subnets

  # Backup configuration
  backup_retention_period = 7          # Keep backups for 7 days
  backup_window          = "03:00-04:00"  # UTC time
  maintenance_window     = "sun:04:00-sun:05:00"  # UTC time

  # Monitoring and logging
  monitoring_interval = 60  # Enhanced monitoring every 60 seconds
  enabled_cloudwatch_logs_exports = ["error", "general", "slow-query"]

  # Performance Insights (optional)
  performance_insights_enabled = true
  performance_insights_retention_period = 7

  # Parameter group for custom configuration (optional)
  # parameter_group_name = aws_db_parameter_group.main.name

  # Option group for additional features (optional)
  # option_group_name = aws_db_option_group.main.name

  # High availability (disabled for cost in lab)
  multi_az = false  # Set to true for production

  # Deletion configuration (ONLY for lab environment)
  skip_final_snapshot = true   # NEVER set to true in production
  deletion_protection = false  # NEVER set to false in production

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  tags = {
    Name        = "${var.project_name}-database"
    Environment = "lab"
    BackupRetention = "7-days"
  }

  # Lifecycle management
  lifecycle {
    # Prevent accidental deletion in production
    # prevent_destroy = true
    
    # Ignore password changes after creation (use Secrets Manager for rotation)
    ignore_changes = [
      password,
    ]
  }
}
```

## Database Parameter Group (Optional Enhancement)

**Add to your `main.tf` for custom database configuration:**

```hcl
# =============================================================================
# DATABASE PARAMETER GROUP (OPTIONAL)
# =============================================================================

# Custom parameter group for MySQL tuning
resource "aws_db_parameter_group" "main" {
  family = "mysql8.0"
  name   = "${var.project_name}-mysql-params"

  # Example parameters - adjust based on your needs
  parameter {
    name  = "innodb_buffer_pool_size"
    value = "{DBInstanceClassMemory*3/4}"  # Use 75% of available memory
  }

  parameter {
    name  = "max_connections"
    value = "100"  # Adjust based on expected load
  }

  parameter {
    name  = "slow_query_log"
    value = "1"  # Enable slow query logging
  }

  parameter {
    name  = "long_query_time"
    value = "2"  # Log queries taking longer than 2 seconds
  }

  tags = {
    Name = "${var.project_name}-mysql-params"
  }
}
```

## Update Web Application to Use Database

**Update your launch template user data to install MySQL client:**

```hcl
# Update the user_data section in your launch template
resource "aws_launch_template" "web" {
  # ... existing configuration ...

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Update the system
    yum update -y
    
    # Install required packages including MySQL client
    yum install -y httpd stress-ng htop mysql
    
    # Start and enable Apache
    systemctl start httpd
    systemctl enable httpd
    
    # Get database endpoint from AWS (requires IAM permissions)
    DB_ENDPOINT="${aws_db_instance.main.endpoint}"
    
    # Create enhanced web page with database connection test
    cat > /var/www/html/index.html << HTML
    <!DOCTYPE html>
    <html>
    <head>
        <title>Auto Scaling Lab Server with Database</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background-color: #f0f0f0; }
            .container { background-color: white; padding: 20px; border-radius: 10px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
            .info { background-color: #e7f3ff; padding: 10px; margin: 10px 0; border-radius: 5px; }
            .database { background-color: #f0f8e7; padding: 10px; margin: 10px 0; border-radius: 5px; }
            .highlight { color: #0066cc; font-weight: bold; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Auto Scaling Web Server with Database</h1>
            
            <div class="info">
                <h3>Server Information</h3>
                <p><span class="highlight">Hostname:</span> $(hostname -f)</p>
                <p><span class="highlight">Instance ID:</span> $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
                <p><span class="highlight">Availability Zone:</span> $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
                <p><span class="highlight">Private IP:</span> $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)</p>
                <p><span class="highlight">Launch Time:</span> $(date)</p>
            </div>
            
            <div class="database">
                <h3>Database Information</h3>
                <p><span class="highlight">Database Endpoint:</span> $DB_ENDPOINT</p>
                <p><span class="highlight">Database Status:</span> Connected ✅</p>
                <p><em>Database connection details available via SSH</em></p>
            </div>
            
            <p>🔄 <strong>Managed by Auto Scaling Group</strong></p>
            <p>🗄️ <strong>Connected to RDS MySQL Database</strong></p>
        </div>
    </body>
    </html>
HTML

    # Create database connection test script
    cat > /home/ec2-user/test-db.sh << 'SCRIPT'
#!/bin/bash
echo "Testing database connection..."
echo "Database endpoint: ${aws_db_instance.main.endpoint}"
echo "To connect to database, use:"
echo "mysql -h ${aws_db_instance.main.endpoint} -u admin -p"
echo ""
echo "Sample SQL commands to try:"
echo "CREATE TABLE users (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(100), email VARCHAR(100));"
echo "INSERT INTO users (name, email) VALUES ('John Doe', 'john@example.com');"
echo "SELECT * FROM users;"
SCRIPT

    chmod +x /home/ec2-user/test-db.sh
    chown ec2-user:ec2-user /home/ec2-user/test-db.sh
  EOF
  )

  # ... rest of configuration ...
}
```

## IAM Role for Database Access (Enhancement)

**Add IAM role for instances to access Secrets Manager:**

```hcl
# =============================================================================
# IAM ROLE FOR DATABASE ACCESS
# =============================================================================

# IAM role for EC2 instances to access database secrets
resource "aws_iam_role" "ec2_db_role" {
  name = "${var.project_name}-ec2-db-role"

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
    Name = "${var.project_name}-ec2-db-role"
  }
}

# IAM policy for accessing database secrets
resource "aws_iam_policy" "db_secrets_policy" {
  name        = "${var.project_name}-db-secrets-policy"
  description = "Policy for accessing database secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db_password.arn
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "db_secrets_attachment" {
  role       = aws_iam_role.ec2_db_role.name
  policy_arn = aws_iam_policy.db_secrets_policy.arn
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "ec2_db_profile" {
  name = "${var.project_name}-ec2-db-profile"
  role = aws_iam_role.ec2_db_role.name
}
```

## Update Outputs

**Add database-related outputs:**

```hcl
# =============================================================================
# DATABASE OUTPUTS
# =============================================================================

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true  # Don't display in terminal output
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "Name of the database"
  value       = aws_db_instance.main.db_name
}

output "database_username" {
  description = "Database master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "secrets_manager_secret_name" {
  description = "Name of the Secrets Manager secret containing DB password"
  value       = aws_secretsmanager_secret.db_password.name
}
```

## Deploy the Database

```bash
terraform plan
terraform apply
```

**Note**: RDS deployment can take 5-10 minutes.

## Verification and Testing

### Lab Exercise 5A: Database Connection Test

1. **Get database connection information:**
   ```bash
   # Get database endpoint (sensitive output)
   terraform output rds_endpoint
   
   # Get the password from Secrets Manager
   aws secretsmanager get-secret-value \
     --secret-id $(terraform output -raw secrets_manager_secret_name) \
     --query SecretString --output text
   ```

2. **Connect to an EC2 instance:**
   ```bash
   # SSH to one of your instances
   ALB_URL=$(terraform output -raw load_balancer_url)
   # Get instance IP from AWS console or describe-instances
   ssh -i ~/.ssh/id_rsa ec2-user@<INSTANCE_IP>
   ```

3. **Test database connection:**
   ```bash
   # On the EC2 instance
   ./test-db.sh
   
   # Connect to database
   mysql -h <RDS_ENDPOINT> -u admin -p
   # Enter the password from Secrets Manager
   ```

### Lab Exercise 5B: Database Operations

1. **Create a sample table and data:**
   ```sql
   -- Once connected to MySQL
   USE labdb;
   
   CREATE TABLE visitors (
       id INT PRIMARY KEY AUTO_INCREMENT,
       instance_id VARCHAR(20),
       visit_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
       ip_address VARCHAR(45)
   );
   
   -- Insert sample data
   INSERT INTO visitors (instance_id, ip_address) 
   VALUES ('i-1234567890abcdef0', '10.0.1.100');
   
   -- Query data
   SELECT * FROM visitors;
   
   -- Show database info
   SHOW TABLES;
   SELECT DATABASE();
   ```

2. **Test from multiple instances:**
   - Connect to different EC2 instances
   - Insert data from each instance
   - Verify data persistence across instances

### Lab Exercise 5C: Backup and Recovery

1. **Check automated backups:**
   - Go to RDS Console
   - Select your database instance
   - Check "Maintenance & backups" tab
   - Verify backup schedule and retention

2. **Create manual snapshot:**
   ```bash
   aws rds create-db-snapshot \
     --db-instance-identifier $(terraform output -raw rds_endpoint | cut -d. -f1) \
     --db-snapshot-identifier ${var.project_name}-manual-snapshot-$(date +%Y%m%d)
   ```

## Understanding RDS Components

### Database Engine Features
- **Automated Backups**: Point-in-time recovery
- **Multi-AZ**: High availability with automatic failover
- **Read Replicas**: Scale read operations
- **Performance Insights**: Database performance monitoring

### Security Features
- **VPC Security Groups**: Network-level security
- **Encryption**: At-rest and in-transit encryption
- **IAM Integration**: Database authentication
- **Secrets Manager**: Credential management

### Monitoring and Maintenance
- **CloudWatch Metrics**: Performance monitoring
- **Enhanced Monitoring**: OS-level metrics
- **Maintenance Windows**: Automated patching
- **Parameter Groups**: Database configuration

## Best Practices Implemented

1. **Security**:
   - Database in private subnets
   - Security groups restrict access
   - Encryption enabled
   - Secrets Manager for passwords

2. **High Availability**:
   - Multi-AZ subnet group
   - Automated backups
   - Monitoring enabled

3. **Performance**:
   - Appropriate instance sizing
   - Performance Insights enabled
   - Parameter group optimization

## Troubleshooting

### Common Issues

1. **Can't connect to database:**
   - Check security group rules
   - Verify database is in "available" state
   - Confirm connection string and credentials

2. **Connection timeouts:**
   - Check subnet group configuration
   - Verify route tables for private subnets
   - Ensure database is not publicly accessible

3. **Performance issues:**
   - Monitor CloudWatch metrics
   - Check slow query logs
   - Review parameter group settings

### Monitoring Commands

```bash
# Check database status
aws rds describe-db-instances \
  --db-instance-identifier $(terraform output -raw rds_endpoint | cut -d. -f1)

# View database metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=<DB_INSTANCE_ID> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## Cost Optimization

1. **Right-sizing**: Monitor CPU and memory usage
2. **Reserved Instances**: For long-term workloads
3. **Storage Optimization**: Monitor storage growth
4. **Backup Management**: Adjust retention based on needs

## Clean Up

```bash
terraform destroy
```

**Note**: RDS deletion protection is disabled for this lab. In production, always enable deletion protection.

## Next Steps
- Proceed to [Lab 6: S3 Storage](lab-06-s3.md)
- Learn about object storage and static content
- Integrate S3 with your web application

## Additional Resources
- [RDS User Guide](https://docs.aws.amazon.com/rds/latest/userguide/)
- [MySQL on RDS](https://docs.aws.amazon.com/rds/latest/userguide/CHAP_MySQL.html)
- [RDS Best Practices](https://docs.aws.amazon.com/rds/latest/userguide/CHAP_BestPractices.html)
