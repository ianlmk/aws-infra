output "zones" {
  description = "Route53 hosted zones"
  value = {
    for name, zone in aws_route53_zone.this :
    name => {
      zone_id      = zone.zone_id
      name_servers = zone.name_servers
      domain_name  = zone.name
      arn          = zone.arn
    }
  }
}

output "nameservers" {
  description = "Nameservers by domain (for domain registrar configuration)"
  value = {
    for name, zone in aws_route53_zone.this :
    name => zone.name_servers
  }
}
