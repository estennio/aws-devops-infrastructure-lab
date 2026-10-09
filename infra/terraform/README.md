# Minimal AWS Lab Infrastructure with Terraform

## Scope

This directory defines the laboratory's minimum AWS architecture as code. It is written to create a new environment, or to be imported over the existing one with the procedure below; state and apply output are not committed.

The configuration does not create credentials, access keys, private keys, an EC2 key pair, NAT Gateway, RDS, Load Balancer, Auto Scaling, containers, or resources outside this scope:

- Region `us-east-2`;
- VPC `10.20.0.0/16`;
- Public Subnet A `10.20.1.0/24`;
- Internet Gateway, public route table, and default route through the IGW;
- Security Group for HTTP, HTTPS, and optional restricted SSH;
- one `t3.micro` EC2 instance by default (`instance_type`: t3 or t3a, nano to medium; t4g is excluded because the AMI parameter is amd64) using Ubuntu Server 24.04 LTS;
- IAM role and instance profile with `AmazonSSMManagedInstanceCore`.

The AMI ID is not hard-coded. Terraform reads Canonical's public Systems Manager parameter for the current Ubuntu Server 24.04 LTS (`noble`) amd64 EBS gp3 image. Because that alias can advance, the resolved AMI ID is shown in the plan and output.

## Files

| File | Purpose |
|---|---|
| `versions.tf` | Terraform and AWS provider constraints, plus the partial S3 backend. |
| `backend.hcl.example` | Template for the ignored `backend.hcl` that supplies the state bucket name. |
| `providers.tf` | AWS provider, enforced common tags, and local naming. |
| `data.tf` | Availability Zones, public Ubuntu AMI parameter, partition, and EC2 trust policy. |
| `network.tf` | VPC, subnet, Internet Gateway, route table, route, and association. |
| `security.tf` | Security Group and independently managed ingress/egress rules. |
| `iam.tf` | SSM IAM role, managed-policy attachment, and instance profile. |
| `compute.tf` | EC2, IMDSv2, encrypted gp3 root volume, and optional bootstrap user data. |
| `github-oidc.tf` | GitHub OIDC provider, least-privilege deploy role, and the private release artifact bucket. |
| `outputs.tf` | Non-secret resource IDs, endpoints, and SSM session command. |
| `terraform.tfvars.example` | Non-sensitive starting values. Real `.tfvars` files are ignored. |

## Parameters that require a decision

For a new environment, decide before planning:

- `availability_zone`: optional; `null` selects the first available zone returned in `aws_region`, and an explicit value must belong to that Region;
- `bootstrap_repository_ref`: `main` is convenient, but an immutable commit SHA is recommended for repeatability;
- `web_ingress_cidrs`: defaults to public HTTP/HTTPS access (`0.0.0.0/0`);
- `enable_ssh`: defaults to `false`, leaving administration to SSM;
- `ssh_ingress_cidrs`: mandatory when SSH is enabled and must never contain `0.0.0.0/0`;
- `ec2_key_name`: mandatory when SSH is enabled and must name a key pair that already exists in `aws_region`.

Terraform never creates or reads an SSH private key. With `enable_ssh=false`, no TCP/22 ingress rule or key-pair association is configured.

The reused bootstrap may generate the laboratory TLS key locally on the EC2 filesystem, as documented in `../../docs/03-server-bootstrap.md`. Terraform does not generate, receive, output, or store that key in state.

No DNS record is created. The bootstrap's `web.lab.test` certificate remains a self-signed laboratory certificate, and clients must supply their own name resolution for hostname-based tests.

The existing GitHub Actions deployment uses SSH. An SSM-only instance is intentionally incompatible with that delivery path until the workflow is redesigned. If that workflow must be used, enable SSH only for explicitly approved administrator or runner CIDRs and maintain those CIDRs; do not open TCP/22 to the world. The workflow's `EC2_HOST`, `EC2_USER`, key, and known-host secrets remain external to Terraform.

## State and credentials

Terraform uses the standard AWS provider credential chain. Authenticate outside the repository, for example with an approved AWS profile or short-lived identity. Do not put access keys in `.tf`, `.tfvars`, shell history, or committed files.

State is stored in an S3 bucket with native S3 locking (`use_lockfile = true`, no DynamoDB table), which requires Terraform `>= 1.11.0`. The bucket is created by the separate configuration in `../bootstrap`, which itself uses local state (see its README for why). The `backend "s3"` block in `versions.tf` is a partial configuration: the bucket name is supplied at init time from `backend.hcl`, which is ignored by Git. State, plans, local variable files, and crash logs are never committed; state can contain resource details and must still be protected.

### Remote state setup order

1. **Bootstrap the bucket.** Follow `../bootstrap/README.md` once to create the state bucket and note its name.
2. **Create `backend.hcl`.** Copy `backend.hcl.example` to `backend.hcl` and set `bucket` to the bootstrap output:

   ```powershell
   cd infra	erraform
   Copy-Item backend.hcl.example backend.hcl
   # edit backend.hcl
   ```

3. **Initialize with the backend configuration:**

   ```powershell
   terraform init -backend-config=backend.hcl
   ```

4. **Migrate existing local state, if any.** If a local `terraform.tfstate` exists from earlier work, `terraform init` detects the backend change; migrate it explicitly and answer `yes` when asked to copy the state:

   ```powershell
   terraform init -backend-config=backend.hcl -migrate-state
   ```

   Afterwards, run `terraform state list` to confirm the resources are present, and keep the old local file as a backup until `terraform plan` shows no unexpected changes.

CI validates the configuration with `terraform init -backend=false`, so it needs neither the bucket nor AWS credentials.

Commit `.terraform.lock.hcl` after the first successful `terraform init` so provider selections are reproducible. Do not commit `.terraform/`.

## Keyless deployment from GitHub Actions (OIDC + SSM)

`github-oidc.tf` lets `.github/workflows/deploy-ssm.yml` deploy without an AWS access key and without opening TCP/22 to GitHub runners:

1. The workflow requests an OIDC token and assumes the `github-actions` role (`sts:AssumeRoleWithWebIdentity`).
2. It uploads `index.html`, `style.css`, and `VERSION` to `s3://<release bucket>/releases/<sha>/`.
3. It sends an SSM Run Command (`AWS-RunShellScript`) to the instance, which downloads the release and runs the unchanged `/usr/local/sbin/aws-devops-versioned-deploy activate <sha> <dir>`.
4. It validates HTTP/HTTPS from the runner and, on failure, requests `rollback` through SSM.

### Trust policy

The role trusts only `repo:<github_repository>:environment:<github_environment>` (default `production`) with audience `sts.amazonaws.com`. An environment subject is preferred over `ref:refs/heads/main` because the environment can require reviewers and limit deployments to `main`, so an unreviewed push or a pull request cannot obtain AWS credentials. Configure the `production` environment in GitHub (Settings, Environments) with required reviewers and a `main`-only deployment branch rule.

### Permissions

- GitHub role: `ssm:SendCommand` only on this instance and the `AWS-RunShellScript` document, `ssm:GetCommandInvocation`/`ListCommandInvocations` (no resource-level scoping exists for them), and `s3:PutObject` on the `releases/` prefix.
- EC2 role: `AmazonSSMManagedInstanceCore` plus read-only access (`s3:GetObject`, prefix-limited `s3:ListBucket`) to `releases/`.
- The release bucket is private, encrypted (SSE-S3), TLS-only, and expires objects after `release_retention_days` (default 30).

The target instance needs the AWS CLI. The deploy command installs it with `snap install aws-cli --classic` when missing.

An account can hold only one provider for `token.actions.githubusercontent.com`. If it already exists, set `create_github_oidc_provider = false`.

### GitHub configuration

Nothing here is secret. Create these repository (or `production` environment) **variables** from the Terraform outputs:

| Variable | Source |
|---|---|
| `AWS_ROLE_ARN` | `terraform output github_actions_role_arn` |
| `AWS_REGION` | `us-east-2` |
| `RELEASE_BUCKET` | `terraform output release_bucket_name` |
| `EC2_INSTANCE_ID` | `terraform output instance_id` |
| `EC2_HOST` | current public address of the instance (`terraform output`) |

The SSH-based `deploy-versioned.yml` still uses the secrets `EC2_SSH_KEY`, `EC2_KNOWN_HOSTS`, `EC2_HOST`, and `EC2_USER`. Keep them until the SSM path is validated.

### Validate before removing the SSH path

1. Review `terraform plan` and apply it deliberately; confirm the instance appears as an `Online` SSM managed node.
2. Create the `production` environment and the variables above.
3. Run **Deploy versioned website via SSM** manually and confirm the S3 upload, the SSM output in the log, and the served `VERSION`.
4. Test the failure path: deploy a release that fails external validation (for example, stop Nginx temporarily) and confirm that rollback is requested; also confirm that a run from a non-`production` context cannot assume the role.
5. Run both workflows once with SSH still enabled to compare results, then repeat the SSM run with `enable_ssh = false` (no port 22 rule).
6. Only then delete `deploy-versioned.yml`, the SSH secrets, and any SSH ingress CIDRs.

## Create a new environment

This procedure is only for creating a separate environment when the plan shows new resources. It is not the import procedure for the already documented lab.

1. Install Terraform `>= 1.11.0, < 2.0.0` and configure authorized AWS credentials outside the repository.
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
2. Set variables to match the real environment. For an existing manually configured instance, start with `enable_bootstrap=false` unless its current user data exactly matches this configuration.
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
