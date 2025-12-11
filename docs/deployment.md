# Deployment Guide

## Prerequisites

- AWS CLI configured
- Terraform >= 1.6.6
- Python >= 3.11

## Steps

### 1. Configure Backend
```bash
cp terraform/backend.tf.example terraform/backend.tf
# Edit backend.tf with your S3 bucket
```

### 2. Set Variables
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars
```

### 3. Deploy
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 4. Access Studio
```bash
DOMAIN_ID=$(terraform output -raw domain_id)
aws sagemaker create-presigned-domain-url \
  --domain-id $DOMAIN_ID \
  --user-profile-name mo \
  --region eu-west-2 \
  --query 'AuthorizedUrl' \
  --output text
```

## Environments

Deploy to different environments:
```bash
terraform workspace new staging
terraform workspace select staging
terraform apply -var-file=environments/staging.tfvars
```