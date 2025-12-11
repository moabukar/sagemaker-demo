# SageMaker Studio Demo

SageMaker Studio env demo with end-to-end ML workflow automation.

## Quick Start

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.6.6
- Python >= 3.11
- make (optional, for convenience commands)

### Installation

```bash
# Setup environment
make setup

# Deploy infrastructure
make tf-init
make tf-apply

# Run demo
export BUCKET=$(cd terraform && terraform output -raw s3_bucket)
export ROLE_ARN=$(cd terraform && terraform output -raw execution_role_arn)
make demo BUCKET=$BUCKET ROLE_ARN=$ROLE_ARN REGION=eu-west-2
```

### Access Studio

```bash
# Generate presigned URL
DOMAIN_ID=$(cd terraform && terraform output -raw domain_id)

aws sagemaker create-presigned-domain-url \
  --domain-id $DOMAIN_ID \
  --user-profile-name mo \
  --region eu-west-2 \
  --query 'AuthorizedUrl' \
  --output text
```

## Development

### Dev

```bash
# Install development dependencies
make install-dev

# Install pre-commit hooks
pre-commit install
```

### Running Tests

```bash
# Run all tests
make test

# Run specific test suites
make test-unit
make test-integration

# Run with coverage report
pytest tests/ --cov=scripts --cov-report=html
```

## Architecture

See [docs/architecture.md](docs/architecture.md) for detailed architecture documentation.

### Key Components

- **SageMaker Studio Domain** – Multi-user ML development environment
- **IAM Roles** – Least privilege access for Studio and training jobs
- **S3 Buckets** – Versioned storage for data and model artifacts
- **VPC Configuration** – Network isolation with VPC endpoints
- **CloudWatch** – Centralized logging and monitoring

## Usage Examples

### Training a Model
```python
from sagemaker.sklearn import SKLearn

estimator = SKLearn(
    entry_point='train.py',
    role=role_arn,
    instance_type='ml.m5.large',
    framework_version='1.2-1'
)

estimator.fit({'train': 's3://bucket/data/train.csv'})
```

### Deploying an Endpoint
```python
predictor = estimator.deploy(
    initial_instance_count=1,
    instance_type='ml.m5.large'
)

result = predictor.predict(test_data)
```

See [notebooks/](notebooks/) for complete examples.

## Configuration

### Terraform Variables

Key variables in `terraform/variables.tf`:

- `project_name` – Resource naming prefix
- `region` – AWS region
- `enable_vpc_mode` – Enable VPC networking
- `default_instance_type` – Default compute instance type

### Environment-Specific Config

Different configurations for dev/staging/prod in `terraform/environments/`.

## Monitoring

### CloudWatch Dashboards
```bash
# View training job logs
aws logs tail /aws/sagemaker/TrainingJobs --follow

# View endpoint logs
aws logs tail /aws/sagemaker/Endpoints/demo-endpoint --follow
```

### Metrics

Key metrics monitored:
- Endpoint invocations and latency
- Training job duration and resource utilization
- Model accuracy and performance

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for common issues and solutions.

### Common Issues

**Domain creation fails**
```bash
# Check VPC endpoint configuration
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID"
```

**Training job fails**
```bash
# Check CloudWatch logs
aws logs tail /aws/sagemaker/TrainingJobs/<job-name> --follow
```

## Cost Optimisation

- Enable auto-stop for idle KernelGateway apps (1 hour timeout)
- Use spot instances for training jobs
- Right-size endpoint instances based on traffic
- Enable S3 lifecycle policies for old artifacts

Estimated costs:
- Studio Domain: $0/month (metadata only)
- KernelGateway: ~$0.05/hour (ml.t3.medium)
- Training: ~$0.23/hour (ml.m5.large)
- Endpoint: ~$0.23/hour (ml.m5.large)


### Security Features

- VPC isolation with private subnets
- IAM roles with least privilege
- S3 bucket encryption at rest
- VPC endpoints for AWS service access
- No public internet access for compute

## Roadmap

- [ ] Multi-model endpoints
- [ ] Model monitoring with drift detection
- [ ] SageMaker Pipelines integration
- [ ] Feature Store implementation
- [ ] A/B testing capabilities
- [ ] Cost analysis dashboard
