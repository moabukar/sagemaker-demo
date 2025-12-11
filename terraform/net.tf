data "aws_vpc" "default" {
  count   = var.enable_vpc_mode && var.vpc_id == null ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.enable_vpc_mode && var.subnet_ids == null ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

resource "aws_security_group" "studio" {
  count       = var.enable_vpc_mode ? 1 : 0
  name        = "${var.project_name}-studio-sg"
  description = "Security group for SageMaker Studio"
  vpc_id      = local.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-studio-sg"
  }
}

resource "aws_vpc_endpoint" "s3" {
  count             = var.enable_vpc_mode ? 1 : 0
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.selected[0].ids

  tags = {
    Name = "${var.project_name}-s3-endpoint"
  }
}

data "aws_route_tables" "selected" {
  count  = var.enable_vpc_mode ? 1 : 0
  vpc_id = local.vpc_id
}

resource "aws_vpc_endpoint" "sagemaker_api" {
  count               = var.enable_vpc_mode ? 1 : 0
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.region}.sagemaker.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.subnet_ids
  security_group_ids  = [aws_security_group.studio[0].id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-sagemaker-api-endpoint"
  }
}

resource "aws_vpc_endpoint" "sagemaker_runtime" {
  count               = var.enable_vpc_mode ? 1 : 0
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.region}.sagemaker.runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.subnet_ids
  security_group_ids  = [aws_security_group.studio[0].id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-sagemaker-runtime-endpoint"
  }
}

locals {
  vpc_id     = var.enable_vpc_mode ? (var.vpc_id != null ? var.vpc_id : data.aws_vpc.default[0].id) : null
  subnet_ids = var.enable_vpc_mode ? (var.subnet_ids != null ? var.subnet_ids : data.aws_subnets.default[0].ids) : null
}
