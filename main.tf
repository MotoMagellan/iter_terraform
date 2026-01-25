# This local declaration is for managing of default values and global
# locals used by multiple module
locals {
  defaults = lookup(local.infra_configs, "defaults", {})

  tags = {
    TFParentModule = "iter_terraform"
  }
}
