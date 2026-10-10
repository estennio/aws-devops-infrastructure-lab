variable "aws_region" {
  description = "AWS Region for the laboratory. The remote state backend region in versions.tf is configured separately."
  type        = string
  default     = "us-east-2"

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS Region name such as us-east-2."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the laboratory VPC. AWS allows prefixes between /16 and /28."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition = (
      can(cidrhost(var.vpc_cidr, 0)) &&
      try(tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 28, false) &&
      cidrhost(var.vpc_cidr, 0) == split("/", var.vpc_cidr)[0]
    )
    error_message = "vpc_cidr must be a valid IPv4 network address in CIDR notation with a prefix between /16 and /28."
  }
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR for Public Subnet A. It must be contained in vpc_cidr."
  type        = string
  default     = "10.20.1.0/24"

  validation {
    condition = (
      can(cidrhost(var.public_subnet_cidr, 0)) &&
      try(tonumber(split("/", var.public_subnet_cidr)[1]) >= 16 && tonumber(split("/", var.public_subnet_cidr)[1]) <= 28, false) &&
      cidrhost(var.public_subnet_cidr, 0) == split("/", var.public_subnet_cidr)[0]
    )
    error_message = "public_subnet_cidr must be a valid IPv4 network address in CIDR notation with a prefix between /16 and /28."
  }

  validation {
    # The subnet is inside the VPC when it is at least as specific and its
    # network address, truncated to the VPC prefix, equals the VPC network.
    condition = try(
      tonumber(split("/", var.public_subnet_cidr)[1]) >= tonumber(split("/", var.vpc_cidr)[1]) &&
      cidrhost("${split("/", var.public_subnet_cidr)[0]}/${split("/", var.vpc_cidr)[1]}", 0) == cidrhost(var.vpc_cidr, 0),
      false
    )
    error_message = "public_subnet_cidr must be contained in vpc_cidr."
  }
}

variable "availability_zone" {
  description = "Optional Availability Zone in aws_region. When null, Terraform selects the first available zone returned for the Region."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = var.availability_zone == null ? true : can(
      regex("^${var.aws_region}[a-z]$", var.availability_zone)
    )
    error_message = "availability_zone must be null or an Availability Zone name in the selected aws_region."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the web server. Restricted to low-cost burstable x86_64 families (t3, t3a) to avoid accidental spend. Graviton (t4g) is excluded because ubuntu_ami_ssm_parameter resolves an amd64 image."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^t3a?[.](nano|micro|small|medium)$", var.instance_type))
    error_message = "instance_type must be a t3 or t3a size from nano to medium."
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

variable "github_repository" {
  description = "GitHub repository (owner/name) allowed to assume the deployment role through OIDC."
  type        = string
  default     = "estennio/aws-devops-infrastructure-lab"

  validation {
    condition     = can(regex("^[0-9A-Za-z_.-]+/[0-9A-Za-z_.-]+$", var.github_repository))
    error_message = "github_repository must use the owner/name format."
  }
}

variable "github_owner_id" {
  description = "Numeric, immutable ID of the repository owner, used in the OIDC subject. Set both IDs to null only for a repository that still issues the legacy name-only subject. Look it up with: gh api users/<owner> --jq .id"
  type        = string
  default     = "263081306"
  nullable    = true

  validation {
    condition     = var.github_owner_id == null ? true : can(regex("^[1-9][0-9]*$", var.github_owner_id))
    error_message = "github_owner_id must be null or a positive numeric GitHub ID."
  }
}

variable "github_repository_id" {
  description = "Numeric, immutable ID of the repository, used in the OIDC subject together with github_owner_id. Look it up with: gh api repos/<owner>/<name> --jq .id"
  type        = string
  default     = "1411264152"
  nullable    = true

  validation {
    condition     = var.github_repository_id == null ? true : can(regex("^[1-9][0-9]*$", var.github_repository_id))
    error_message = "github_repository_id must be null or a positive numeric GitHub ID."
  }

  validation {
    condition     = (var.github_owner_id == null) == (var.github_repository_id == null)
    error_message = "Set both github_owner_id and github_repository_id, or neither (legacy subject)."
  }
}

variable "github_environment" {
  description = "GitHub environment whose deployments may assume the role. The OIDC subject is pinned to it."
  type        = string
  default     = "production"

  validation {
    condition     = can(regex("^[0-9A-Za-z_.-]+$", var.github_environment))
    error_message = "github_environment must be a simple environment name."
  }
}

variable "create_github_oidc_provider" {
  description = "Whether to create the account-wide GitHub OIDC provider. Set to false if token.actions.githubusercontent.com already exists in the account."
  type        = bool
  default     = true
}

variable "release_bucket_name" {
  description = "Optional name of the release artifact bucket. When null, <project_name>-releases-<account id> is used."
  type        = string
  default     = null
  nullable    = true
}

variable "release_retention_days" {
  description = "Days after which release artifacts expire from the release bucket."
  type        = number
  default     = 30

  validation {
    condition     = var.release_retention_days >= 1 && floor(var.release_retention_days) == var.release_retention_days
    error_message = "release_retention_days must be a whole number of at least 1."
  }
}
