resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "HTTP, HTTPS, and optional restricted SSH for the lab web server"
  vpc_id      = aws_vpc.lab.id

  tags = {
    Name = "${local.name_prefix}-web-sg"
  }

  lifecycle {
    precondition {
      condition     = !var.enable_ssh || length(var.ssh_ingress_cidrs) > 0
      error_message = "enable_ssh=true requires at least one explicit ssh_ingress_cidrs entry."
    }

    precondition {
      condition     = !var.enable_ssh || var.ec2_key_name != null
      error_message = "enable_ssh=true requires ec2_key_name to reference an existing EC2 key pair."
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each = toset(var.web_ingress_cidrs)

  security_group_id = aws_security_group.web.id
  description       = "Public HTTP"
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"

  tags = {
    Name = "${local.name_prefix}-http-${replace(each.value, "/", "-")}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each = toset(var.web_ingress_cidrs)

  security_group_id = aws_security_group.web.id
  description       = "Public HTTPS"
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = {
    Name = "${local.name_prefix}-https-${replace(each.value, "/", "-")}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = var.enable_ssh ? toset(var.ssh_ingress_cidrs) : toset([])

  security_group_id = aws_security_group.web.id
  description       = "Restricted SSH administration"
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"

  tags = {
    Name = "${local.name_prefix}-ssh-${replace(each.value, "/", "-")}"
  }
}

resource "aws_vpc_security_group_egress_rule" "all_ipv4" {
  security_group_id = aws_security_group.web.id
  description       = "Outbound access for packages, SSM, and repository bootstrap"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = {
    Name = "${local.name_prefix}-all-egress"
  }
}
