variable "aws_region" {
  description = "AWS Region for the state bucket. Must match the region used by the backend configuration."
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Project tag applied to the bootstrap resources."
  type        = string
  default     = "aws-devops-infrastructure-lab"
}

variable "state_bucket_name" {
  description = "Globally unique name of the S3 bucket that stores the Terraform state."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid S3 bucket name: 3-63 lowercase letters, numbers, dots, or hyphens."
  }
}
