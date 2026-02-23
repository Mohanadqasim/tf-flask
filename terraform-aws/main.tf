resource "aws_security_group" "tf_flask_sg" {
  name        = "tf-flask-sg"
  description = "Allow SSH and TCP 5000"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TCP 5000 from anywhere"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tf-flask-sg"
  }
}

#--------------------------------------key pair--------------------------------------------------#
resource "tls_private_key" "tf_flask_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "tf_flask_key" {
  key_name   = "tf-flask-key"
  public_key = tls_private_key.tf_flask_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.tf_flask_key.private_key_pem
  filename        = "${path.module}/tf-flask-key.pem"
  file_permission = "0400"
}
#-----------------------------------iam role-----------------------------------------------------#
resource "aws_iam_role" "tf_flask_ec2_role" {
  name = "tf-flask-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ecr_readonly_attach" {
  role       = aws_iam_role.tf_flask_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "tf_flask_instance_profile" {
  name = "tf-flask-instance-profile"
  role = aws_iam_role.tf_flask_ec2_role.name
}
#---------------------------------------ec2-------------------------------------------------#

resource "aws_instance" "tf_flask_ec2" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  subnet_id = data.aws_subnet.default_subnet.id

  vpc_security_group_ids = [
    aws_security_group.tf_flask_sg.id
  ]

  key_name = aws_key_pair.tf_flask_key.key_name

  iam_instance_profile = aws_iam_instance_profile.tf_flask_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ec2-user
              EOF

  tags = {
    Name = "tf-flask-ec2"
  }
}

#---------------------------------------ecr-------------------------------------------------#
resource "aws_ecr_repository" "tf_flask_ecr" {
  name = "tf-flask-ecr"
  force_delete = true
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "tf-flask-ecr"
  }
}
#---------------------------------------github actions-------------------------------------------------#

resource "aws_iam_openid_connect_provider" "github_oidc" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

resource "aws_iam_role" "github_actions_role" {
  name = "tf-flask-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:Mohanadqasim/tf-flask:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_ecr_policy" {
  name = "tf-flask-github-ecr-policy"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = aws_ecr_repository.tf_flask_ecr.arn
      }
    ]
  })
}