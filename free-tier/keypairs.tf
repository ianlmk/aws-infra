#-----------------#
# SSH Key Pairs #
#-----------------#

resource "aws_key_pair" "ghost_web" {
  key_name   = "ghost-web"
  # Read public key from local file
  public_key = trimspace(file(pathexpand("~/.ssh/id_rsa.pub")))

  tags = merge(
    local.common_tags,
    {
      Name = "ghost-web"
    }
  )
}
