# AWS Fundamentals Lab

A comprehensive, hands-on learning repository for mastering AWS cloud infrastructure using Terraform. This lab series takes you from basic networking concepts to production-ready, monitored infrastructure through practical exercises.

## Learning Path Overview

This lab series is designed as a progressive learning experience. Each lab builds upon the previous one, culminating in a complete, production-ready AWS infrastructure.

### Lab Series

| Lab | Focus Area | Duration | Cost Impact |
|-----|------------|----------|-------------|
| [Lab 1: VPC Networking](lab-01-vpc.md) | Foundation networking, subnets, routing | 30 mins | Free Tier |
| [Lab 2: EC2 Compute](lab-02-ec2.md) | Virtual machines, security groups, SSH access | 45 mins | ~$15/month |
| [Lab 3: Load Balancing](lab-03-alb.md) | Application Load Balancer, high availability | 30 mins | ~$20/month |
| [Lab 4: Auto Scaling](lab-04-autoscaling.md) | Dynamic scaling, launch templates | 45 mins | Variable |
| [Lab 5: RDS Database](lab-05-rds.md) | Managed databases, backups, multi-AZ | 30 mins | ~$15/month |
| [Lab 6: S3 Storage](lab-06-s3.md) | Object storage, versioning, lifecycle | 30 mins | ~$5/month |
| [Lab 7: IAM Security](lab-07-iam.md) | Identity management, policies, roles | 45 mins | Free |
| [Lab 8: CloudWatch Monitoring](lab-08-cloudwatch.md) | Dashboards, alerts, log aggregation | 60 mins | ~$5/month |

**Total Estimated Cost**: ~$60-80/month for complete infrastructure

## Quick Start Guide

### Prerequisites Checklist

- [ ] **AWS Account** with administrative access
- [ ] **AWS CLI** installed and configured ([Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- [ ] **Terraform** v1.0+ installed ([Download](https://developer.hashicorp.com/terraform/downloads))
- [ ] **SSH key pair** for EC2 access
- [ ] **Text editor** (VS Code recommended)

### Initial Setup

1. **Clone this repository**:
   ```bash
   git clone https://github.com/YourUsername/aws-fundamentals-lab
   cd aws-fundamentals-lab
   ```

2. **Configure AWS credentials**:
   ```bash
   aws configure
   # Or use AWS SSO: aws configure sso
   ```

3. **Verify setup**:
   ```bash
   aws sts get-caller-identity
   terraform version
   ```

### AWS Profile Configuration

#### For Bash/Zsh (Mac/Linux):
```bash
export AWS_PROFILE="your-profile-name"
```

#### For PowerShell (Windows):
```powershell
$env:AWS_PROFILE="your-profile-name"
```

#### Alternative: Direct Provider Configuration
```hcl
provider "aws" {
  region  = var.aws_region
  profile = "your-profile-name"
  
  # Optional: Assume role configuration
  assume_role {
    role_arn = "arn:aws:iam::ACCOUNT-ID:role/TerraformRole"
  }
}
```

## AWS Fundamentals

### Core AWS Concepts

#### **Regions and Availability Zones**
- **Region**: Physical locations worldwide (e.g., us-east-1, eu-west-1)
- **Availability Zone**: Isolated data centers within a region
- **Best Practice**: Deploy across multiple AZs for high availability

#### **AWS Global Infrastructure**
```
Region (us-east-1)
├── Availability Zone A (us-east-1a)
├── Availability Zone B (us-east-1b)
└── Availability Zone C (us-east-1c)
```

#### **AWS Service Categories**
- **Compute**: EC2, Lambda, ECS, EKS
- **Storage**: S3, EBS, EFS
- **Database**: RDS, DynamoDB, ElastiCache
- **Networking**: VPC, CloudFront, Route 53
- **Security**: IAM, WAF, GuardDuty

### AWS Well-Architected Framework

Our labs implement the five pillars:

1. **Operational Excellence** - Monitoring, automation, improvement
2. **Security** - IAM, encryption, network security
3. **Reliability** - Multi-AZ, auto scaling, backup
4. **Performance Efficiency** - Right-sizing, monitoring
5. **Cost Optimization** - Resource management, monitoring

## Terraform Fundamentals

### Infrastructure as Code Benefits
- **Version Control**: Track infrastructure changes
- **Reproducibility**: Consistent environments
- **Collaboration**: Team-based infrastructure management
- **Documentation**: Self-documenting infrastructure

### Terraform Workflow
```bash
terraform init      # Initialize working directory
terraform plan      # Preview changes
terraform apply     # Create/update infrastructure
terraform destroy   # Remove infrastructure
```

### Terraform Best Practices Implemented
- **State Management**: Remote state with locking
- **Module Structure**: Reusable, maintainable code
- **Variable Management**: Environment-specific configurations
- **Output Values**: Important resource information
- **Tagging Strategy**: Consistent resource identification

### Key Terraform Concepts

#### **Resources**
```hcl
resource "aws_instance" "example" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  
  tags = {
    Name = "example-server"
  }
}
```

#### **Variables**
```hcl
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}
```

#### **Outputs**
```hcl
output "instance_ip" {
  description = "Public IP of the instance"
  value       = aws_instance.example.public_ip
}
```

## Cost Management

### Understanding AWS Pricing
- **On-Demand**: Pay-per-use, no long-term commitment
- **Reserved Instances**: 1-3 year commitments for significant savings
- **Spot Instances**: Unused capacity at reduced rates
- **Free Tier**: 12 months of limited free usage for new accounts

### Cost Optimization Strategies
1. **Right-sizing**: Match instance size to workload
2. **Auto Scaling**: Scale resources based on demand
3. **Reserved Capacity**: For predictable workloads
4. **Monitoring**: Track usage and costs regularly
5. **Lifecycle Management**: Automated data archival

### Lab Cost Breakdown
```
Monthly Estimated Costs:
├── EC2 (2x t3.micro)      ~$15
├── RDS (db.t3.micro)      ~$15
├── ALB                    ~$20
├── S3 Storage             ~$5
├── CloudWatch             ~$5
├── Data Transfer          ~$5
└── NAT Gateway            ~$32
Total: ~$97/month
```

## Security Best Practices

### AWS Security Fundamentals
- **Principle of Least Privilege**: Minimum required permissions
- **Defense in Depth**: Multiple security layers
- **Encryption**: Data at rest and in transit
- **Monitoring**: Comprehensive logging and alerting

### Security Features Implemented
1. **IAM Roles**: Service-to-service authentication
2. **Security Groups**: Instance-level firewalls
3. **NACLs**: Subnet-level access control
4. **VPC**: Network isolation
5. **CloudTrail**: API call logging
6. **Encryption**: EBS, RDS, S3 encryption

## Monitoring and Observability

### CloudWatch Components
- **Metrics**: Quantitative data about resources
- **Logs**: Application and system log files
- **Alarms**: Automated responses to metric thresholds
- **Dashboards**: Visual representation of metrics

### Monitoring Strategy
1. **Infrastructure Monitoring**: CPU, memory, disk, network
2. **Application Monitoring**: Response times, error rates
3. **Business Monitoring**: User activity, revenue metrics
4. **Security Monitoring**: Failed logins, unusual activity

## Learning Objectives

### By Lab Completion, You Will:
- **Understand** AWS core services and their interactions
- **Design** secure, scalable cloud architectures
- **Implement** infrastructure as code with Terraform
- **Configure** comprehensive monitoring and alerting
- **Apply** AWS Well-Architected Framework principles
- **Manage** costs and optimize resource usage
- **Troubleshoot** common infrastructure issues

### Skills Gained
- ✅ VPC design and implementation
- ✅ EC2 instance management and scaling
- ✅ Load balancer configuration
- ✅ Database design with RDS
- ✅ Object storage with S3
- ✅ IAM security implementation
- ✅ CloudWatch monitoring setup
- ✅ Terraform infrastructure automation

## 🏃‍♂️ Getting Started

1. **Start with [Lab 1: VPC Networking](lab-01-vpc.md)** - Foundation networking concepts
2. **Follow the sequence** - Each lab builds on the previous
3. **Complete exercises** - Hands-on practice reinforces learning
4. **Experiment** - Modify configurations to deepen understanding

## 🧹 Cleanup Instructions

**Important**: Always clean up resources to avoid unnecessary charges!

```bash
# Destroy all infrastructure
terraform destroy

# Verify removal
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name]'
```

## Troubleshooting

### Common Issues and Solutions

#### **Authentication Errors**
```
Error: Error configuring AWS Provider: no valid credential sources
```
**Solution**: Configure AWS credentials or profile

#### **Permission Denied**
```
Error: AccessDenied: User is not authorized to perform
```
**Solution**: Ensure IAM user has necessary permissions

#### **Resource Conflicts**
```
Error: InvalidVpcID.NotFound
```
**Solution**: Check resource dependencies and state

#### **Rate Limiting**
```
Error: RequestLimitExceeded
```
**Solution**: Implement exponential backoff, reduce parallel operations

### Getting Help
- **AWS Documentation**: [docs.aws.amazon.com](https://docs.aws.amazon.com/)
- **Terraform Documentation**: [terraform.io/docs](https://terraform.io/docs)
- **AWS Support**: Use AWS Support Center for technical issues
- **Community**: Stack Overflow, Reddit r/aws

## Additional Resources

### AWS Learning Resources
- [AWS Training and Certification](https://aws.amazon.com/training/)
- [AWS Well-Architected Labs](https://wellarchitectedlabs.com/)
- [AWS Samples GitHub](https://github.com/aws-samples)
- [AWS Architecture Center](https://aws.amazon.com/architecture/)

### Terraform Resources
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [HashiCorp Learn](https://learn.hashicorp.com/terraform)


---

**Ready to start your AWS journey? Begin with [Lab 1: VPC Networking](lab-01-vpc.md)!** 🚀