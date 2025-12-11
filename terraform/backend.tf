# Copy this file to backend.tf and configure your backend

terraform {
  backend "s3" {
    bucket       = "your-terraform-state-bucket"
    key          = "sagemaker-demo/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
    # encrypt        = true
    # dynamodb_table = "terraform-locks"
  }
}