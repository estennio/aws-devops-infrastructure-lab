resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = local.availability_zone
  map_public_ip_on_launch = false

  lifecycle {
    precondition {
      condition     = contains(data.aws_availability_zones.available.names, local.availability_zone)
      error_message = "availability_zone must be an available Availability Zone in the selected aws_region."
    }
  }

  tags = {
    Name = "${local.name_prefix}-public-a"
    Tier = "public"
  }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.lab.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

# Created separately from the instance so that its private address and the
# Elastic IP survive an instance replacement.
resource "aws_network_interface" "web" {
  subnet_id       = aws_subnet.public_a.id
  security_groups = [aws_security_group.web.id]
  description     = "Primary interface of the lab web server"

  tags = {
    Name = "${local.name_prefix}-web-eni"
  }
}

resource "aws_eip" "web" {
  domain            = "vpc"
  network_interface = aws_network_interface.web.id

  tags = {
    Name = "${local.name_prefix}-web-eip"
  }

  depends_on = [aws_internet_gateway.lab]
}
