terraform {
  required_version = ">= 1.11.0, < 2.0.0"

  # Partial configuration: supply the bucket with
  # `terraform init -backend-config=backend.hcl` (see backend.hcl.example).
  backend "s3" {
    key          = "aws-devops-infrastructure-lab/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
