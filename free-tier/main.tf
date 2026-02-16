# Root module — orchestrates all child modules

module "iam" {
  source = "../modules/iam"

  environment        = var.environment
  iam_users          = var.iam_users
  user_policies      = merge(var.user_policies, local.policies)
  create_access_keys = var.create_access_keys
  tags               = local.common_tags
}
