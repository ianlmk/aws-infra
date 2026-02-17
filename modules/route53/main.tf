# Route53 Hosted Zones (Public DNS)
resource "aws_route53_zone" "this" {
  for_each = var.zones

  name    = each.value.domain_name
  comment = each.value.comment

  tags = merge(
    var.tags,
    {
      Name        = each.value.domain_name
      Environment = var.environment
    }
  )
}
