output "state_bucket_name" {
  description = "Name of the state bucket, to be used in infra/terraform/backend.hcl."
  value       = aws_s3_bucket.state.id
}
