# IAM Users
resource "aws_iam_user" "this" {
  for_each = var.iam_users

  name = each.key
  tags = merge(
    var.tags,
    {
      Purpose = each.value.description
    }
  )
}

# IAM Policies
resource "aws_iam_policy" "this" {
  for_each = var.user_policies

  name        = each.value.policy_name
  description = "Policy for ${each.value.user}"
  policy      = each.value.policy

  tags = var.tags
}

# Attach Policies to Users
resource "aws_iam_user_policy_attachment" "this" {
  for_each = {
    for name, policy in var.user_policies :
    name => policy
    if contains(keys(aws_iam_user.this), policy.user)
  }

  user       = each.value.user
  policy_arn = aws_iam_policy.this[each.key].arn
}

# IAM Access Keys
resource "aws_iam_access_key" "this" {
  for_each = toset(var.create_access_keys)

  user = aws_iam_user.this[each.value].name

  depends_on = [aws_iam_user_policy_attachment.this]

  lifecycle {
    create_before_destroy = true
  }
}
