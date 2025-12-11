output "domain_id" {
  description = "SageMaker Studio Domain ID"
  value       = aws_sagemaker_domain.studio.id
}

output "domain_arn" {
  description = "SageMaker Studio Domain ARN"
  value       = aws_sagemaker_domain.studio.arn
}

output "studio_url" {
  description = "SageMaker Studio URL (needs presigned URL generation)"
  value       = "https://${aws_sagemaker_domain.studio.id}.studio.${var.region}.sagemaker.aws"
}

output "user_profiles" {
  description = "Created user profiles"
  value       = { for k, v in aws_sagemaker_user_profile.users : k => v.arn }
}

output "execution_role_arn" {
  description = "IAM role ARN for SageMaker execution"
  value       = aws_iam_role.studio_execution.arn
}

output "s3_bucket" {
  description = "S3 bucket for SageMaker artifacts"
  value       = aws_s3_bucket.sagemaker.id
}

output "model_package_group" {
  description = "Model package group name"
  value       = aws_sagemaker_model_package_group.classification.model_package_group_name
}

output "presigned_url_command" {
  description = "AWS CLI command to generate presigned Studio URL"
  value       = <<-EOT
    aws sagemaker create-presigned-domain-url \
      --domain-id ${aws_sagemaker_domain.studio.id} \
      --user-profile-name mo \
      --region ${var.region} \
      --query 'AuthorizedUrl' \
      --output text
  EOT
}
