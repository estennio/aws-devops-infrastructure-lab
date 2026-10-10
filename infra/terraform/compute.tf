resource "aws_instance" "web" {
  ami                  = data.aws_ssm_parameter.ubuntu_ami.insecure_value
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ssm.name
  key_name             = var.enable_ssh ? var.ec2_key_name : null
  monitoring           = false

  # The subnet, Security Group and Elastic IP belong to this interface, which
  # outlives the instance. A replaced instance boots with the same public
  # address, so nothing outside Terraform has to be updated.
  primary_network_interface {
    network_interface_id = aws_network_interface.web.id
  }

  user_data = var.enable_bootstrap ? templatefile("${path.module}/templates/user-data.sh.tftpl", {
    repository_url = var.bootstrap_repository_url
    repository_ref = var.bootstrap_repository_ref
  }) : null
  user_data_replace_on_change = var.enable_bootstrap

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    encrypted             = true
    delete_on_termination = true
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gib
  }

  volume_tags = {
    Name = "${local.name_prefix}-web-root"
  }

  tags = {
    Name = "lab-web-server"
    Role = "web"
  }

  # The Elastic IP is associated before boot, so first-boot downloads never
  # see the public address change underneath them.
  depends_on = [
    aws_eip.web,
    aws_iam_role_policy_attachment.ssm_core,
    aws_route.public_default,
    aws_route_table_association.public_a,
  ]
}
