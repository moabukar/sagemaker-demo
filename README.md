# SageMaker Studio Demo

SageMaker Studio env demo with end-to-end ML workflow automation.

## Setup & Deploy

```bash
# setup env
make setup

# deploy infra
make tf-init
make tf-apply

# Run demo
export BUCKET=$(cd terraform && terraform output -raw s3_bucket)
export ROLE_ARN=$(cd terraform && terraform output -raw execution_role_arn)
make demo BUCKET=$BUCKET ROLE_ARN=$ROLE_ARN REGION=eu-west-2
```

### SM Studio access

```bash

# generate presigned URL
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

### Common Issues

**Domain creation fails**

```bash
# vpc endpoints
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID"
```

**Training job fails**

```bash
# cloudwatch logs
aws logs tail /aws/sagemaker/TrainingJobs/<job-name> --follow
```

## Make commands

| Command | Description | Usage Example |
|---------|-------------|---------------|
| `make help` | Show all available commands with descriptions | `make help` |
| **Setup & Installation** | | |
| `make install` | Install production dependencies only | `make install` |
| `make install-dev` | Install development dependencies + pre-commit hooks | `make install-dev` |
| `make setup` | Complete setup (install-dev + tf-init) | `make setup` |
| **Code Quality** | | |
| `make format` | Auto-format Python code (black + isort) | `make format` |
| `make format-check` | Check formatting without modifying files | `make format-check` |
| `make lint` | Run all linters (flake8, mypy, bandit) | `make lint` |
| `make security` | Run security checks (bandit + detect-secrets) | `make security` |
| `make pre-commit` | Run all pre-commit hooks on all files | `make pre-commit` |
| `make ci` | Run all CI checks (format-check, lint, test, security) | `make ci` |
| **Testing** | | |
| `make test` | Run all tests with coverage report | `make test` |
| `make test-unit` | Run unit tests only | `make test-unit` |
| `make test-integration` | Run integration tests only | `make test-integration` |
| **Terraform** | | |
| `make tf-init` | Initialize Terraform | `make tf-init` |
| `make tf-validate` | Validate Terraform configuration | `make tf-validate` |
| `make tf-fmt` | Format Terraform files | `make tf-fmt` |
| `make tf-plan` | Preview Terraform changes | `make tf-plan` |
| `make tf-apply` | Apply Terraform configuration (deploy) | `make tf-apply` |
| `make tf-destroy` | Destroy all Terraform resources | `make tf-destroy` |
| `make tf-output` | Show Terraform outputs as JSON | `make tf-output` |
| **Demo & Cleanup** | | |
| `make demo` | Run end-to-end demo script (requires BUCKET, ROLE_ARN, REGION) | `make demo BUCKET=my-bucket ROLE_ARN=arn:aws:iam::123:role/SageMaker REGION=eu-west-2` |
| `make clean` | Remove Python cache files and build artifacts | `make clean` |
