locals {
  name_prefix = var.project_name
  common_tags = merge(var.additional_tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
  availability_zone = coalesce(
    var.availability_zone,
    data.aws_availability_zones.available.names[0]
  )
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
