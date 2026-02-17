# Fetch latest Ubuntu 22.04 LTS AMI if not provided
data "aws_ami" "ubuntu" {
  count       = var.ami == "" ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = var.ami != "" ? var.ami : data.aws_ami.ubuntu[0].id
}

# EC2 Instance
resource "aws_instance" "main" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  monitoring             = var.monitoring_enabled
  key_name               = var.key_name != "" && var.key_name != null ? var.key_name : null
  user_data              = var.user_data != "" ? base64encode(var.user_data) : null

  # Root volume configuration
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = merge(
      var.tags,
      {
        Name = "${var.project}-${var.name}-root"
      }
    )
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.name}"
    }
  )
}

# Optional Elastic IP
resource "aws_eip" "main" {
  count    = var.eip_allocation ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-${var.name}-eip"
    }
  )

  depends_on = [aws_instance.main]
}
