locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = var.region

  # Resource naming
  name_prefix = var.project_name

  # Tags
  common_tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = terraform.workspace
    Repository  = "sagemaker-demo"
  }

  # Network configuration
  vpc_id     = var.enable_vpc_mode ? (var.vpc_id != null ? var.vpc_id : data.aws_vpc.default[0].id) : null
  subnet_ids = var.enable_vpc_mode ? (var.subnet_ids != null ? var.subnet_ids : data.aws_subnets.default[0].ids) : null

  # SageMaker image URIs by region
  sklearn_image_uris = {
    us-east-1    = "683313688378.dkr.ecr.us-east-1.amazonaws.com/sagemaker-scikit-learn:1.2-1-cpu-py3"
    us-east-2    = "257758044811.dkr.ecr.us-east-2.amazonaws.com/sagemaker-scikit-learn:1.2-1-cpu-py3"
    us-west-2    = "246618743249.dkr.ecr.us-west-2.amazonaws.com/sagemaker-scikit-learn:1.2-1-cpu-py3"
    eu-west-1    = "685385470294.dkr.ecr.eu-west-1.amazonaws.com/sagemaker-scikit-learn:1.2-1-cpu-py3"
    eu-west-2    = "644912444149.dkr.ecr.eu-west-2.amazonaws.com/sagemaker-scikit-learn:1.2-1-cpu-py3"
    eu-central-1 = "492215442770.dkr.ecr.eu-central-1.amazonaws.com/sagemaker-scikit-learn:1.2-1-cpu-py3"
  }
}

data "aws_caller_identity" "current" {}