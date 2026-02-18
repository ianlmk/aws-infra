# Ansible Provider Configuration and Playbook Trigger

# Create Ansible inventory entry for WordPress web server
resource "ansible_host" "wordpress_web" {
  name   = data.aws_instance.web_server.public_ip
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
