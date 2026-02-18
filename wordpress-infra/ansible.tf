# Ansible Provider Configuration and Playbook Trigger

# Create EC2 instance for WordPress
resource "aws_instance" "wordpress_web" {
  ami                 = data.aws_ami.ubuntu.id
  instance_type       = var.ec2_instance_type
  subnet_id           = local.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.wordpress_web.id]
  iam_instance_profile = aws_iam_instance_profile.wordpress_ec2.name
  
  # Root volume configuration
  root_block_device {
    volume_type           = var.ec2_root_volume_type
    volume_size           = var.ec2_root_volume_size
    delete_on_termination = true
    encrypted             = true
  }
  
  # User data for initial setup
  user_data = base64encode(templatefile("${path.module}/templates/user-data.sh", {
    # Can add initialization commands here if needed
  }))
  
  tags = merge(
    local.wordpress_tags,
    { Name = "${local.app_name}-wordpress-web" }
  )

  depends_on = [aws_security_group.wordpress_web]
}

# Security group for WordPress web server
resource "aws_security_group" "wordpress_web" {
  name        = "${local.app_name}-wordpress-web-sg"
  description = "Security group for WordPress web server"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Consider restricting to your IP
    description = "SSH"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    local.wordpress_tags,
    { Name = "${local.app_name}-wordpress-web-sg" }
  )
}

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create Ansible inventory entry for WordPress web server
resource "ansible_host" "wordpress_web" {
  name   = aws_instance.wordpress_web.public_ip
  groups = ["webservers"]
  variables = {
    # WordPress configuration
    wordpress_url      = var.wordpress_url
    wordpress_db_host  = aws_db_instance.wordpress.address
    wordpress_db_port  = aws_db_instance.wordpress.port
    wordpress_db_name  = local.wordpress_db_name
    wordpress_db_user  = local.wordpress_db_user
    wordpress_db_password = local.wordpress_db_password  # From Vault
    
    # S3 configuration
    s3_bucket_name = aws_s3_bucket.wordpress_uploads.id
    s3_region      = var.aws_region
    
    # Other configuration
    enable_ssl                  = var.enable_ssl
    wordpress_admin_email       = var.wordpress_admin_email
    wordpress_php_version       = var.wordpress_php_version
    wordpress_memory_limit      = var.wordpress_memory_limit
    wordpress_max_upload_size   = var.wordpress_max_upload_size
  }

  depends_on = [aws_instance.wordpress_web]
}

# Trigger Ansible deployment
resource "ansible_playbook" "deploy_wordpress" {
  count      = var.deploy_wordpress ? 1 : 0
  playbook   = var.ansible_playbook_path
  inventory  = ansible_host.wordpress_web.inventory_hostname
  verbosity  = var.ansible_verbosity
  extra_vars = {
    database_host     = aws_db_instance.wordpress.address
    database_port     = aws_db_instance.wordpress.port
    database_name     = local.wordpress_db_name
    database_user     = local.wordpress_db_user
    database_password = local.wordpress_db_password
  }

  # Optional: Wait for EC2 to be ready before deploying
  provisioner "remote-exec" {
    inline = ["echo 'Waiting for EC2 to be ready...'"]

    connection {
      type        = "ssh"
      user        = "ansible"
      private_key = file(var.ssh_private_key_path)
      host        = data.aws_instance.web_server.public_ip
    }
  }

  depends_on = [
    aws_db_instance.wordpress,
    aws_s3_bucket.wordpress_uploads,
    ansible_host.wordpress_web
  ]
}

# Optional: Create local Ansible inventory file for manual runs
resource "local_file" "ansible_inventory_wordpress" {
  filename = "${var.output_inventory_path}/wordpress_hosts.ini"
  content = templatefile("${path.module}/templates/inventory.ini.tpl", {
    web_server_ip      = data.aws_instance.web_server.public_ip
    db_host            = aws_db_instance.wordpress.address
    s3_bucket_name     = aws_s3_bucket.wordpress_uploads.id
    wordpress_url      = var.wordpress_url
  })
}
