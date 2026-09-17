data "aws_iam_policy_document" "github_ecs_deployment" {
  statement {
    sid    = "RegisterAndDescribeTaskDefinitions"
    effect = "Allow"

    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "DeployPetClinicService"
    effect = "Allow"

    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService"
    ]

    resources = [
      aws_ecs_service.app.id
    ]
  }

  statement {
    sid    = "PassTaskExecutionRole"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      aws_iam_role.task_execution.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "github_ecs_deployment" {
  name        = "${var.project_name}-${var.environment}-github-ecs-deployment"
  description = "Allows GitHub Actions to deploy PetClinic task definitions to the ECS service"
  policy      = data.aws_iam_policy_document.github_ecs_deployment.json

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "github_ecs_deployment" {
  role       = var.github_actions_role_name
  policy_arn = aws_iam_policy.github_ecs_deployment.arn
}