data "aws_iam_user" "serverless_user" {
  user_name = "Serverless"
}

resource "aws_iam_user_policy" "serverless_codebuild_trigger" {
  name = "CodeBuildTriggerPolicy"
  user = data.aws_iam_user.serverless_user.user_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:StopBuild",
          "codebuild:BatchGetBuilds",
          "codebuild:ListBuilds",
          "codebuild:ListBuildsForProject",
          "codebuild:ListProjects",
          "codebuild:BatchGetProjects",
          "logs:GetLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}
