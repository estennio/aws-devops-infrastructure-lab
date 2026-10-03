resource "aws_iam_role" "ssm" {
  name               = "${local.name_prefix}-ssm-role"
  description        = "EC2 role for AWS Systems Manager administration"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${local.name_prefix}-ssm-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${local.name_prefix}-ssm-profile"
  role = aws_iam_role.ssm.name

  tags = {
    Name = "${local.name_prefix}-ssm-profile"
  }
}
