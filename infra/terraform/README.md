# Minimal AWS Lab Infrastructure with Terraform

## Status and scope

This directory defines a reproducible proposal for the laboratory's minimum AWS architecture. Versioned Terraform configuration does **not** mean that the resources have been created, imported, validated against the current account, or applied to the documented EC2 environment.

No `terraform apply`, `terraform destroy`, or `terraform import` was executed while preparing these files. The configuration does not create credentials, access keys, private keys, an EC2 key pair, NAT Gateway, RDS, Load Balancer, Auto Scaling, containers, or resources outside this scope:

- Region `us-east-2`;
- VPC `10.20.0.0/16`;
- Public Subnet A `10.20.1.0/24`;
- Internet Gateway, public route table, and default route through the IGW;
- Security Group for HTTP, HTTPS, and optional restricted SSH;
- one `t3.micro` EC2 instance using Ubuntu Server 24.04 LTS;
- IAM role and instance profile with `AmazonSSMManagedInstanceCore`.

The AMI ID is not hard-coded. Terraform reads Canonical's public Systems Manager parameter for the current Ubuntu Server 24.04 LTS (`noble`) amd64 EBS gp3 image. Because that alias can advance, the resolved AMI ID is shown in the plan and output.

## Files

| File | Purpose |
|---|---|
| `versions.tf` | Terraform and AWS provider constraints. |
| `providers.tf` | AWS provider, enforced common tags, and local naming. |
| `data.tf` | Availability Zones, public Ubuntu AMI parameter, partition, and EC2 trust policy. |
| `network.tf` | VPC, subnet, Internet Gateway, route table, route, and association. |
| `security.tf` | Security Group and independently managed ingress/egress rules. |
| `iam.tf` | SSM IAM role, managed-policy attachment, and instance profile. |
| `compute.tf` | EC2, IMDSv2, encrypted gp3 root volume, and optional bootstrap user data. |
| `outputs.tf` | Non-secret resource IDs, endpoints, and SSM session command. |
| `terraform.tfvars.example` | Non-sensitive starting values. Real `.tfvars` files are ignored. |

## Parameters that require a decision

For a new environment, decide before planning:

- `availability_zone`: optional; `null` selects the first available zone returned in `us-east-2`;
- `bootstrap_repository_ref`: `main` is convenient, but an immutable commit SHA is recommended for repeatability;
- `web_ingress_cidrs`: defaults to public HTTP/HTTPS access (`0.0.0.0/0`);
- `enable_ssh`: defaults to `false`, leaving administration to SSM;
- `ssh_ingress_cidrs`: mandatory when SSH is enabled and must never contain `0.0.0.0/0`;
- `ec2_key_name`: mandatory when SSH is enabled and must name a key pair that already exists in `us-east-2`.

Terraform never creates or reads an SSH private key. With `enable_ssh=false`, no TCP/22 ingress rule or key-pair association is configured.

The reused bootstrap may generate the laboratory TLS key locally on the EC2 filesystem, as documented in `../../docs/04-server-bootstrap.md`. Terraform does not generate, receive, output, or store that key in state.

No DNS record is created. The bootstrap's `web.lab.test` certificate remains a self-signed laboratory certificate, and clients must supply their own name resolution for hostname-based tests.

The existing GitHub Actions deployment uses SSH. An SSM-only instance is intentionally incompatible with that delivery path until the workflow is redesigned. If that workflow must be used, enable SSH only for explicitly approved administrator or runner CIDRs and maintain those CIDRs; do not open TCP/22 to the world. The workflow's `EC2_HOST`, `EC2_USER`, key, and known-host secrets remain external to Terraform.

## State and credentials

Terraform uses the standard AWS provider credential chain. Authenticate outside the repository, for example with an approved AWS profile or short-lived identity. Do not put access keys in `.tf`, `.tfvars`, shell history, or committed files.

Local state is the default because no state backend is created in this minimum scope. State, plans, local variable files, and crash logs are ignored by Git. State can contain resource details and must still be protected. For team use, configure an approved remote backend with locking and encryption before creating resources; backend infrastructure is deliberately outside this configuration.

Commit `.terraform.lock.hcl` after the first successful `terraform init` so provider selections are reproducible. Do not commit `.terraform/`.

## Create a new environment

This procedure is only for creating a separate environment when the plan shows new resources. It is not the import procedure for the already documented lab.

1. Install Terraform `>= 1.6.0, < 2.0.0` and configure authorized AWS credentials outside the repository.
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and make the decisions listed above. The destination file is ignored by Git.
3. Initialize and validate:

   ```bash
   cd infra/terraform
   terraform init
   terraform fmt -check -recursive
   terraform validate
   ```

4. Create and inspect a saved plan:

   ```bash
   terraform plan -out=lab.tfplan
   terraform show lab.tfplan
   ```

5. Confirm that the plan contains only the resources in the documented scope, then deliberately apply it:

   ```bash
   terraform apply lab.tfplan
   ```

The EC2 first-boot script installs Git, checks out `bootstrap_repository_ref`, and runs the existing `scripts/bootstrap.sh`. Package installation and repository access require outbound Internet connectivity. Pin the repository ref to the intended commit before creation when reproducibility matters.

While bootstrap is enabled, `user_data_replace_on_change` is also enabled. A change to the rendered user data can therefore replace a Terraform-created instance; always inspect the plan before applying changes.

## Verify a newly created environment

Terraform outputs provide the resource IDs, selected AMI, current public address, and an SSM command. Verification still requires real observations; code and state alone do not prove service health.

```bash
terraform output
terraform state list
terraform plan -detailed-exitcode
```

After the instance registers as an SSM managed node, use the generated `ssm_start_session_command` output. On the instance, run the repository's evidence collector only after reviewing it:

```bash
sudo bash /opt/aws-devops-infrastructure-lab/scripts/collect-evidence.sh
```

Also verify HTTP/HTTPS externally as documented in `../../evidence/README.md`. Do not mark evidence available until the real, reviewed output is preserved.

## Import existing resources

Import is a separate migration procedure. Do not run the new-environment apply first, because that would attempt to create duplicate resources. The instance ID recorded elsewhere in this repository was not revalidated and is intentionally not inserted here.

Before importing, an authorized operator must collect the actual current identifiers and names:

- VPC, subnet, Internet Gateway, route table, route-table association, and default-route identifiers;
- Security Group ID plus every managed HTTP, HTTPS, optional SSH, and egress rule ID (`sgr-...`);
- IAM role name, instance-profile name, and existing SSM policy attachment;
- EC2 instance ID;
- actual Availability Zone, key-pair name if any, CIDRs, tags, AMI, root-volume settings, user data, and other managed attributes.

Then:

1. Back up any existing Terraform state and use an isolated migration branch/workspace.
2. Set variables to match the real environment. For an existing manually configured instance, start with `enable_bootstrap=false` unless its current user data exactly matches this proposal.
3. Update resource arguments to match reality before allowing Terraform to manage anything.
4. Initialize Terraform, then import each resource with its real identifier. The following are templates, not executable IDs:

   ```bash
   terraform import aws_vpc.lab VPC_ID_TO_VERIFY
   terraform import aws_subnet.public_a SUBNET_ID_TO_VERIFY
   terraform import aws_internet_gateway.lab IGW_ID_TO_VERIFY
   terraform import aws_route_table.public ROUTE_TABLE_ID_TO_VERIFY
   terraform import aws_route.public_default 'ROUTE_TABLE_ID_TO_VERIFY_0.0.0.0/0'
   terraform import aws_route_table_association.public_a 'SUBNET_ID_TO_VERIFY/ROUTE_TABLE_ID_TO_VERIFY'
   terraform import aws_security_group.web SECURITY_GROUP_ID_TO_VERIFY

   terraform import 'aws_vpc_security_group_ingress_rule.http["CIDR_TO_VERIFY"]' HTTP_RULE_ID_TO_VERIFY
   terraform import 'aws_vpc_security_group_ingress_rule.https["CIDR_TO_VERIFY"]' HTTPS_RULE_ID_TO_VERIFY
   terraform import 'aws_vpc_security_group_ingress_rule.ssh["CIDR_TO_VERIFY"]' SSH_RULE_ID_TO_VERIFY
   terraform import aws_vpc_security_group_egress_rule.all_ipv4 EGRESS_RULE_ID_TO_VERIFY

   terraform import aws_iam_role.ssm ROLE_NAME_TO_VERIFY
   terraform import aws_iam_role_policy_attachment.ssm_core 'ROLE_NAME_TO_VERIFY/arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore'
   terraform import aws_iam_instance_profile.ssm INSTANCE_PROFILE_NAME_TO_VERIFY
   terraform import aws_instance.web INSTANCE_ID_TO_VERIFY
   ```

   Omit the SSH rule import when SSH is disabled. Repeat the keyed HTTP, HTTPS, or SSH commands for every CIDR represented by `for_each`.

5. Run `terraform plan -detailed-exitcode` repeatedly and reconcile the configuration until the result proposes no unintended add, change, replacement, or destroy action.
6. Do not apply an import migration plan until every difference and ownership boundary has been reviewed. Import writes state; it does not prove that the configuration already matches the resource.

No import block or real ID is committed because the required current identifiers have not been collected and verified.

## Potential costs

Review current AWS pricing before creation. Potential billable items include:

- `t3.micro` instance runtime;
- the encrypted gp3 EBS root volume and retained snapshots, if any are created outside this code;
- the public IPv4 address while assigned;
- Internet data transfer and package/repository downloads;
- optional logging, advanced Systems Manager features, or other services enabled outside this configuration.

The VPC design intentionally excludes NAT Gateway, Load Balancer, RDS, and additional instances. Free Tier or promotional eligibility must not be assumed.

## Remove a Terraform-created environment

Removal applies only to resources created and owned by this Terraform state. Never use it against an incompletely reviewed import.

```bash
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan
terraform apply destroy.tfplan
```

Review the destroy plan carefully. The EC2 instance and its root volume are configured for deletion; data stored on them is not preserved by this configuration. Confirm completion with `terraform state list` and the authorized AWS inventory process.
