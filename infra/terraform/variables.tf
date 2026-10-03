variable "aws_region" {
  description = "AWS Region for the laboratory. This configuration is intentionally scoped to us-east-2."
  type        = string
  default     = "us-east-2"

  validation {
    condition     = var.aws_region == "us-east-2"
    error_message = "aws_region must remain us-east-2 for this laboratory."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the laboratory VPC."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = var.vpc_cidr == "10.20.0.0/16"
    error_message = "vpc_cidr must remain 10.20.0.0/16 for this laboratory."
  }
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR for Public Subnet A."
  type        = string
  default     = "10.20.1.0/24"

  validation {
    condition     = var.public_subnet_cidr == "10.20.1.0/24"
    error_message = "public_subnet_cidr must remain 10.20.1.0/24 for this laboratory."
  }
}

variable "availability_zone" {
  description = "Optional Availability Zone. When null, Terraform selects the first available zone returned for us-east-2."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = var.availability_zone == null ? true : can(
      regex("^us-east-2[a-z]$", var.availability_zone)
    )
    error_message = "availability_zone must be null or an Availability Zone name in us-east-2."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the web server."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = var.instance_type == "t3.micro"
    error_message = "instance_type must remain t3.micro for this laboratory."
  }
}

variable "ubuntu_ami_ssm_parameter" {
  description = "Canonical public SSM parameter that resolves the current Ubuntu Server 24.04 LTS amd64 EBS gp3 AMI."
  type        = string
  default     = "/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id"

  validation {
    condition = can(regex(
      "^/aws/service/canonical/ubuntu/server/(noble|24[.]04)/stable/current/amd64/hvm/ebs-gp3/ami-id$",
      var.ubuntu_ami_ssm_parameter
    ))
    error_message = "ubuntu_ami_ssm_parameter must reference the Canonical Ubuntu Server 24.04/noble amd64 EBS gp3 public parameter."
  }
}

variable "root_volume_size_gib" {
  description = "Size of the encrypted gp3 root volume in GiB."
  type        = number
  default     = 8

  validation {
    condition = (
      var.root_volume_size_gib >= 8 &&
      var.root_volume_size_gib <= 100 &&
      floor(var.root_volume_size_gib) == var.root_volume_size_gib
    )
    error_message = "root_volume_size_gib must be a whole number between 8 and 100."
  }
}

variable "web_ingress_cidrs" {
  description = "IPv4 CIDRs allowed to reach public HTTP and HTTPS."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = (
      length(var.web_ingress_cidrs) > 0 &&
      alltrue([for cidr in var.web_ingress_cidrs : can(cidrnetmask(cidr))])
    )
    error_message = "web_ingress_cidrs must contain at least one valid IPv4 CIDR."
  }
}

variable "enable_ssh" {
  description = "Whether to create SSH ingress rules and associate an existing EC2 key pair. Leave false for SSM-only administration."
  type        = bool
  default     = false
}

variable "ssh_ingress_cidrs" {
  description = "Explicit IPv4 CIDRs allowed to use SSH when enable_ssh is true. The world-open CIDR is rejected."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.ssh_ingress_cidrs :
      can(cidrnetmask(cidr)) && try(tonumber(split("/", cidr)[1]) > 0, false)
    ])
    error_message = "Every SSH source must be a valid IPv4 CIDR with a prefix longer than /0; world-open SSH is forbidden."
  }
}

variable "ec2_key_name" {
  description = "Name of an existing EC2 key pair. Required only when enable_ssh is true; Terraform does not create or store the private key."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = var.ec2_key_name == null ? true : (
      length(trimspace(var.ec2_key_name)) > 0 &&
      length(var.ec2_key_name) <= 255
    )
    error_message = "ec2_key_name must be null or the non-empty name of an existing EC2 key pair."
  }
}

variable "enable_bootstrap" {
  description = "Whether EC2 user data clones the repository and runs scripts/bootstrap.sh on first boot."
  type        = bool
  default     = true
}

variable "bootstrap_repository_url" {
  description = "Public Git repository used by first-boot configuration."
  type        = string
  default     = "https://github.com/estennio/aws-devops-infrastructure-lab.git"

  validation {
    condition = can(regex(
      "^https://github[.]com/[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+([.]git)?$",
      var.bootstrap_repository_url
    ))
    error_message = "bootstrap_repository_url must be a public HTTPS GitHub repository URL."
  }
}

variable "bootstrap_repository_ref" {
  description = "Git branch, tag, or commit fetched before running the bootstrap. Prefer an immutable commit SHA for repeatable creation."
  type        = string
  default     = "main"

  validation {
    condition = (
      can(regex("^[0-9A-Za-z][0-9A-Za-z._/-]{0,127}$", var.bootstrap_repository_ref)) &&
      !strcontains(var.bootstrap_repository_ref, "..")
    )
    error_message = "bootstrap_repository_ref must be a safe branch, tag, or commit without spaces or '..'."
  }
}

variable "project_name" {
  description = "Name prefix and Project tag for resources."
  type        = string
  default     = "aws-devops-infrastructure-lab"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,31}$", var.project_name))
    error_message = "project_name must be 3-32 lowercase letters, numbers, or hyphens and start with a letter."
  }
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.environment))
    error_message = "environment must be 2-16 lowercase letters, numbers, or hyphens and start with a letter."
  }
}

variable "additional_tags" {
  description = "Additional non-sensitive tags. Project, Environment, and ManagedBy are enforced by this configuration."
  type        = map(string)
  default     = {}
}
