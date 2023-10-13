provider "aws" {
  region = "eu-central-1"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile"
  role = aws_iam_role.ecs_role.name
}

# IAM Role
resource "aws_iam_role" "ecs_role" {
  name = "ecs-role"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "ecs_policy_attachment" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAzZQ0qRDzSgp2vbYKS6Xnq/VMzw89VGUrXGJnPp35QKGCiQdjvezL7S+2ANcbhZhT0a3wlwTgXAt72DdZA/ZN5q+5vtXrpj2F2cZxdGE3WkPnB74UaLOW+MQAe+sIdFHP+gqj8MmD0MvF9ImPBVnbNCb6j3v3sOOoDPZyzCgbdkKTxbjoNaC5Ayi84AUcTIIultSTFTTpb3VGR4S2Tb+yyCnF3XsjAJaVxog/PyrNG8jkbuwDlSp7kNpeiO+bsbXvJj8+OabaqrrZXJW5jq7PnJv5q9sRcqLKr2IhERNUYx5iw29WjLGK7R6pAvmyfF6nM+dPnFXYGFqo+zSLs1kvQQ== rsa-key-20221204"
}

data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["31.18.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "eduard_test_cluster" {
  name = "eduard-test-cluster"
}

resource "aws_instance" "ecs_instance" {
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.ecs_instance_profile.name
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo mkdir -p /etc/ecs
              echo "ECS_CLUSTER=eduard-test-cluster" | sudo tee -a /etc/ecs/ecs.config
              sudo yum update -y
              sudo amazon-linux-extras enable ecs
              sudo yum install -y ecs-init
              sudo service docker start
              sudo service ecs start
              sleep 10
              sudo service ecs stop
              sleep 10
              sudo service ecs start
              EOF

  tags = {
    Name = "ECS Instance - ${aws_ecs_cluster.eduard_test_cluster.name}"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "app"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "app",
      "image": "my-golang-app:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "hostPort": 8080
        }
      ]
    }
  ]
  DEFINITION
}

# ECS Service
resource "aws_ecs_service" "app_service" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.eduard_test_cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
}
