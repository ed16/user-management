provider "aws" {
  region = "eu-central-1"
}

resource "aws_iam_role" "codebuild_service_role" {
  name               = "codebuild-service-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
resource "aws_iam_role_policy" "codebuild_logs_policy" {
  name = "codebuild-logs-policy"
  role = aws_iam_role.codebuild_service_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_attachment" {
  role       = aws_iam_role.codebuild_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildAdminAccess"
}

resource "aws_iam_role_policy_attachment" "ecr_policy_attachment" {
  role       = aws_iam_role.codebuild_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_ecr_repository" "my_golang_app" {
  name = "my-golang-app"
}

resource "aws_codebuild_project" "example" {
  name          = "my-golang-app"
  description   = "My Golang App build project"
  build_timeout = "15"
  service_role  = aws_iam_role.codebuild_service_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = "us-west-2"
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = "365309254644"
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = "my-golang-app"
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }

    environment_variable {
      name  = "REPOSITORY_URI"
      value = "https://365309254644.dkr.ecr.eu-central-1.amazonaws.com/my-golang-app"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/ed16/user-management"
    git_clone_depth = 1
    buildspec       = "infrastructure/codebuild/buildspec.yml"
  }
}
