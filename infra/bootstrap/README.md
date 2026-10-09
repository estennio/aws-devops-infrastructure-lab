# Terraform State Bucket Bootstrap

This configuration creates the S3 bucket that stores the state of `../terraform`. It is a separate root module because the main configuration cannot create the bucket that holds its own state.

## Why this configuration uses local state

This is the chicken-and-egg problem of remote state: the bucket must exist before any backend can use it, so this configuration has no `backend` block and keeps its own state in a local `terraform.tfstate` file. That file is ignored by Git. Keep it (or back it up securely) as long as the bucket exists; it only tracks a handful of bucket settings and is easy to re-import if lost.

## What it creates

- one S3 bucket with `prevent_destroy = true`;
- versioning enabled, so earlier state versions can be recovered;
- default server-side encryption (SSE-S3, AES256);
- all four S3 public access blocks enabled;
- a bucket policy that denies any request not using TLS (`aws:SecureTransport = false`).

State locking uses the native S3 lock file (`use_lockfile = true`); no DynamoDB table is created.

## Usage

```powershell
cd infra\bootstrap
Copy-Item terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars and set a globally unique state_bucket_name
terraform init
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
terraform output state_bucket_name
```

Then continue with the backend setup in `../terraform/README.md`.

`prevent_destroy` makes `terraform destroy` fail on purpose. To remove the bucket, first empty all object versions, then remove the `prevent_destroy` argument in a reviewed change.
