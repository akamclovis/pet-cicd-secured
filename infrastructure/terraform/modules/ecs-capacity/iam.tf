data "aws_iam_policy_document" "ecs_instance_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_instance" {
  name = "${var.project_name}-${var.environment}-ecs-instance-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_instance_assume_role.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-instance-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${var.project_name}-${var.environment}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-instance-profile"
    Environment = var.environment
  }
}