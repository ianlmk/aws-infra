# Outputs for Ghost Infrastructure

output "ghost_infrastructure" {
  description = "Ghost infrastructure summary"
  value = {
    ec2 = {
      instance_id = aws_instance.ghost.id
      public_ip   = aws_instance.ghost.public_ip
      private_ip  = aws_instance.ghost.private_ip
      ami_id      = data.aws_ami.ubuntu.id
      key_pair    = aws_key_pair.ghost.key_name
    }
    rds = {
      endpoint           = aws_db_instance.ghost.endpoint
      database_name      = aws_db_instance.ghost.db_name
      database_user      = aws_db_instance.ghost.username
      engine             = aws_db_instance.ghost.engine
      engine_version     = aws_db_instance.ghost.engine_version
      instance_class     = aws_db_instance.ghost.instance_class
      allocated_storage  = aws_db_instance.ghost.allocated_storage
    }
    network = {
      vpc_id                    = local.vpc_id
      public_subnet_id          = local.public_subnet_ids[0]
      private_subnet_ids        = local.private_subnet_ids
      web_security_group_id     = aws_security_group.ghost_web.id
      rds_security_group_id     = aws_security_group.rds_ghost.id
    }
  }
}

output "ghost_connection_string" {
  description = "Ghost MySQL connection string"
  value       = "mysql://${local.ghost_db_user}:****@${split(":", aws_db_instance.ghost.endpoint)[0]}:3306/${local.ghost_db_name}"
  sensitive   = false
}

output "ghost_url" {
  description = "Ghost blog URL"
  value       = var.ghost_url
}

output "ghost_access" {
  description = "How to access Ghost"
  value = {
    web_url = "http://${aws_instance.ghost.public_ip}"
    ssh     = "ssh -i ~/.ssh/${aws_key_pair.ghost.key_name} ubuntu@${aws_instance.ghost.public_ip}"
    admin   = "${var.ghost_url}/admin"
  }
}

output "ghost_logs" {
  description = "View Ghost application logs"
  value       = "ssh -i ~/.ssh/${aws_key_pair.ghost.key_name} ubuntu@${aws_instance.ghost.public_ip} 'journalctl -u ghost -f'"
}

output "nginx_logs" {
  description = "View Nginx logs"
  value       = "ssh -i ~/.ssh/${aws_key_pair.ghost.key_name} ubuntu@${aws_instance.ghost.public_ip} 'tail -f /var/log/nginx/error.log'"
}

output "base_infrastructure_outputs" {
  description = "Base infrastructure (free-tier) outputs"
  value = {
    vpc_id              = local.base_vpc_id
    public_subnet_ids   = local.base_public_subnet_ids
    private_subnet_ids  = local.base_private_subnet_ids
    route53_zone_ids    = local.base_route53_zone_ids
  }
}
