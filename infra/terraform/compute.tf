resource "aws_instance" "web" {
  ami                         = data.aws_ssm_parameter.ubuntu_ami.insecure_value
  instance_type               = var.instance_type
  availability_zone           = local.availability_zone
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  key_name                    = var.enable_ssh ? var.ec2_key_name : null
  monitoring                  = false

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

  depends_on = [
    aws_iam_role_policy_attachment.ssm_core,
    aws_route.public_default,
    aws_route_table_association.public_a,
  ]
}
