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

data "aws_route_tables" "selected" {
  count  = var.enable_vpc_mode ? 1 : 0
  vpc_id = local.vpc_id
}

# Availability zones
data "aws_availability_zones" "available" {
  state = "available"
}