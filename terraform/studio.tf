data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "sagemaker" {
  bucket = "${var.project_name}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-sagemaker"
  }
}

resource "aws_s3_bucket_versioning" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "train_script" {
  bucket = aws_s3_bucket.sagemaker.id
  key    = "scripts/train.py"
  source = "${path.module}/../scripts/train.py"
  etag   = filemd5("${path.module}/../scripts/train.py")
}

resource "aws_s3_object" "inference_script" {
  bucket = aws_s3_bucket.sagemaker.id
  key    = "scripts/inference.py"
  source = "${path.module}/../scripts/inference.py"
  etag   = filemd5("${path.module}/../scripts/inference.py")
}

resource "aws_sagemaker_domain" "studio" {
  domain_name = var.project_name
  auth_mode   = "IAM"
  vpc_id      = var.enable_vpc_mode ? local.vpc_id : null
  subnet_ids  = var.enable_vpc_mode ? local.subnet_ids : null

  default_user_settings {
    execution_role = aws_iam_role.studio_execution.arn
    security_groups = var.enable_vpc_mode ? [
      aws_security_group.studio[0].id
    ] : null

    jupyter_server_app_settings {
      default_resource_spec {
        instance_type       = "system"
        sagemaker_image_arn = "arn:aws:sagemaker:${var.region}:081325390199:image/jupyter-server-3"
      }

      lifecycle_config_arns = [
        aws_sagemaker_studio_lifecycle_config.jupyter_setup.arn
      ]
    }

    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type       = var.default_instance_type
        sagemaker_image_arn = "arn:aws:sagemaker:${var.region}:081325390199:image/datascience-1.0"
      }

      lifecycle_config_arns = [
        aws_sagemaker_studio_lifecycle_config.kernel_setup.arn
      ]
    }

    sharing_settings {
      notebook_output_option = "Allowed"
      s3_output_path         = "s3://${aws_s3_bucket.sagemaker.id}/sharing"
    }
  }

  default_space_settings {
    execution_role = aws_iam_role.studio_execution.arn
  }

  tags = {
    Name = var.project_name
  }
}

resource "aws_sagemaker_studio_lifecycle_config" "jupyter_setup" {
  studio_lifecycle_config_name     = "${var.project_name}-jupyter-setup"
  studio_lifecycle_config_app_type = "JupyterServer"

  studio_lifecycle_config_content = base64encode(<<-EOF
    #!/bin/bash
    set -e
    
    echo "JupyterServer startup script running..."
    
    # Install additional packages
    pip install --upgrade pip
    pip install mlflow==2.9.2 wandb==0.16.2
    
    # Configure Git
    git config --global user.name "Demo User"
    git config --global user.email "demo@example.com"
    
    echo "JupyterServer setup complete"
  EOF
  )
}

resource "aws_sagemaker_studio_lifecycle_config" "kernel_setup" {
  studio_lifecycle_config_name     = "${var.project_name}-kernel-setup"
  studio_lifecycle_config_app_type = "KernelGateway"

  studio_lifecycle_config_content = base64encode(<<-EOF
    #!/bin/bash
    set -e
    
    echo "KernelGateway startup script running..."
    
    # Install ML packages
    pip install --upgrade pip
    pip install scikit-learn==1.3.2 xgboost==2.0.3 lightgbm==4.1.0
    pip install shap==0.44.0 optuna==3.5.0
    
    # Set environment variables
    export SAGEMAKER_BUCKET=${aws_s3_bucket.sagemaker.id}
    
    echo "KernelGateway setup complete"
  EOF
  )
}

resource "aws_sagemaker_user_profile" "users" {
  for_each          = toset(var.user_profiles)
  domain_id         = aws_sagemaker_domain.studio.id
  user_profile_name = each.value

  user_settings {
    execution_role = aws_iam_role.studio_execution.arn

    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type = var.default_instance_type
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${each.value}"
  }
}

resource "aws_sagemaker_model_package_group" "classification" {
  model_package_group_name        = "${var.project_name}-classification-models"
  model_package_group_description = "Classification models for demo"

  tags = {
    Name = "${var.project_name}-classification-models"
  }
}

resource "aws_cloudwatch_log_group" "training" {
  name              = "/aws/sagemaker/TrainingJobs"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-training-logs"
  }
}

resource "aws_cloudwatch_log_group" "endpoints" {
  name              = "/aws/sagemaker/Endpoints/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-endpoint-logs"
  }
}
