output "aws_region" {
  description = "AWS Region used by the configuration."
  value       = var.aws_region
}

output "availability_zone" {
  description = "Availability Zone selected for Public Subnet A and EC2."
  value       = local.availability_zone
}

output "vpc_id" {
  description = "ID of the laboratory VPC."
  value       = aws_vpc.lab.id
}

output "public_subnet_id" {
  description = "ID of Public Subnet A."
  value       = aws_subnet.public_a.id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.lab.id
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "public_route_table_association_id" {
  description = "ID of the Public Subnet A route-table association."
  value       = aws_route_table_association.public_a.id
}

output "security_group_id" {
  description = "ID of the EC2 Security Group."
  value       = aws_security_group.web.id
}

output "security_group_rule_ids" {
  description = "IDs of the independently managed Security Group rules."
  value = {
    http   = { for cidr, rule in aws_vpc_security_group_ingress_rule.http : cidr => rule.security_group_rule_id }
    https  = { for cidr, rule in aws_vpc_security_group_ingress_rule.https : cidr => rule.security_group_rule_id }
    ssh    = { for cidr, rule in aws_vpc_security_group_ingress_rule.ssh : cidr => rule.security_group_rule_id }
    egress = aws_vpc_security_group_egress_rule.all_ipv4.security_group_rule_id
  }
}

output "instance_id" {
  description = "ID of the web EC2 instance."
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Current public IPv4 address. It can change because this configuration does not create an Elastic IP."
  value       = aws_instance.web.public_ip
}

output "instance_public_dns" {
  description = "Current public DNS name assigned by EC2."
  value       = aws_instance.web.public_dns
}

output "ubuntu_ami_id" {
  description = "Ubuntu 24.04 LTS AMI resolved from Canonical's public SSM parameter at plan/apply time."
  value       = data.aws_ssm_parameter.ubuntu_ami.insecure_value
}

output "ssm_role_name" {
  description = "IAM role attached to EC2 for Systems Manager."
  value       = aws_iam_role.ssm.name
}

output "ssm_instance_profile_name" {
  description = "IAM instance profile attached to EC2."
  value       = aws_iam_instance_profile.ssm.name
}

output "ssm_start_session_command" {
  description = "AWS CLI command for starting a Session Manager session after the managed node becomes online."
  value       = "aws ssm start-session --target ${aws_instance.web.id} --region ${var.aws_region}"
}

output "http_url" {
  description = "HTTP URL using the current public IPv4 address."
  value       = "http://${aws_instance.web.public_ip}/"
}

output "ssh_target" {
  description = "SSH target when SSH is enabled; null for SSM-only administration."
  value       = var.enable_ssh ? "ubuntu@${aws_instance.web.public_dns}" : null
}
