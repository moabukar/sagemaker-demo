variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "sagemaker-demo"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "user_profiles" {
  description = "List of user profile names"
  type        = list(string)
  default     = ["mo"]
}

variable "default_instance_type" {
  description = "Default KernelGateway instance type"
  type        = string
  default     = "ml.t3.medium"
}

variable "enable_vpc_mode" {
  description = "Enable VPC mode (false = public internet mode)"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID (required if enable_vpc_mode = true)"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Subnet IDs (required if enable_vpc_mode = true)"
  type        = list(string)
  default     = null
}