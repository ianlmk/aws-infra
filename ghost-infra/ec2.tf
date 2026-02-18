# EC2 Instance for Ghost

# Security Group for Ghost Web Server
resource "aws_security_group" "ghost_web" {
  name        = "${local.app_name}-ghost-web-sg"
  description = "Security group for Ghost web server"
  vpc_id      = local.vpc_id

  # SSH access (restrict in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict this in production!
    description = "SSH from anywhere"
  }

  # HTTP (port 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  # HTTPS (port 443)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  # Ghost application port (2368 - for reverse proxy testing)
  ingress {
    from_port   = 2368
    to_port     = 2368
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
    description = "Ghost app server (VPC only)"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    local.ghost_tags,
    { Name = "${local.app_name}-ghost-web-sg" }
  )
}

# Key pair (from Vault)
resource "aws_key_pair" "ghost" {
  key_name   = "${local.app_name}-ghost-web"
  public_key = local.ghost_ssh_key

  tags = merge(
    local.ghost_tags,
    { Name = "${local.app_name}-ghost-web-key" }
  )
}

# IAM Role for Ghost EC2 instance
resource "aws_iam_role" "ghost_ec2" {
  name = "${local.app_name}-ghost-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.ghost_tags,
    { Name = "${local.app_name}-ghost-ec2-role" }
  )
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ghost_ec2" {
  name = "${local.app_name}-ghost-ec2-profile"
  role = aws_iam_role.ghost_ec2.name
}

# IAM Policy for CloudWatch and SSM
resource "aws_iam_role_policy" "ghost_ec2_policy" {
  name = "${local.app_name}-ghost-ec2-policy"
  role = aws_iam_role.ghost_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:AcknowledgeMessage",
          "ssmmessages:GetEndpoint",
          "ssmmessages:GetMessages",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
        ]
        Resource = "*"
      }
    ]
  })
}

# EC2 Instance for Ghost
resource "aws_instance" "ghost" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.ec2_instance_type
  subnet_id              = local.public_subnet_ids[0]  # Use first public subnet
  vpc_security_group_ids = [aws_security_group.ghost_web.id]
  key_name               = aws_key_pair.ghost.key_name
  iam_instance_profile   = aws_iam_instance_profile.ghost_ec2.name

  root_block_device {
    volume_type           = var.ec2_root_volume_type
    volume_size           = var.ec2_root_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = merge(
      local.ghost_tags,
      { Name = "${local.app_name}-ghost-root-volume" }
    )
  }

  # User data script (bash provisioning)
  user_data = base64encode(templatefile("${path.module}/user-data-ghost.sh", {
    ghost_db_host     = split(":", aws_db_instance.ghost.endpoint)[0]
    ghost_db_port     = 3306
    ghost_db_name     = local.ghost_db_name
    ghost_db_user     = local.ghost_db_user
    ghost_db_password = local.ghost_db_password
    ghost_url         = var.ghost_url
    node_version      = var.node_version
  }))

  monitoring             = true
  disable_api_stop       = false
  disable_api_termination = false

  tags = merge(
    local.ghost_tags,
    { Name = "${local.app_name}-ghost-web" }
  )

  depends_on = [
    aws_db_instance.ghost,
    aws_security_group.ghost_web,
  ]
}

# Elastic IP (optional - uncomment for production)
# resource "aws_eip" "ghost" {
#   instance = aws_instance.ghost.id
#   domain   = "vpc"
#
#   tags = merge(
#     local.ghost_tags,
#     { Name = "${local.app_name}-ghost-eip" }
#   )
#
#   depends_on = [aws_instance.ghost]
# }

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ghost" {
  name              = "/aws/ec2/${local.app_name}-ghost"
  retention_in_days = 7

  tags = merge(
    local.ghost_tags,
    { Name = "${local.app_name}-ghost-logs" }
  )
}

output "ghost_instance_id" {
  description = "Ghost EC2 instance ID"
  value       = aws_instance.ghost.id
}

output "ghost_instance_public_ip" {
  description = "Ghost EC2 instance public IP"
  value       = aws_instance.ghost.public_ip
}

output "ghost_instance_private_ip" {
  description = "Ghost EC2 instance private IP"
  value       = aws_instance.ghost.private_ip
}

output "ghost_web_security_group_id" {
  description = "Ghost web security group ID"
  value       = aws_security_group.ghost_web.id
}

output "ghost_key_pair_name" {
  description = "Ghost SSH key pair name"
  value       = aws_key_pair.ghost.key_name
}
