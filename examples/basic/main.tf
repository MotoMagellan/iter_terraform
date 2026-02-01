provider "aws" {
  region = "us-east-1"
}

# Basic example showing minimal configuration
#
# This example demonstrates:
# - Configuration defaults from a central repository
# - A single service configuration from GitHub
# - Module-level tagging
#
# Note: Tags are passed to the module via the 'tags' variable.
# Resource-specific tags can be defined within each resource's YAML configuration.
# Tags cannot be set as a top-level key in the YAML configuration files.

module "iter_terraform_basic" {
  source = "../.."

  # Configuration defaults - defines where default settings are stored
  config_defaults = {
    defaults = {
      service    = "github"
      repository = "example-org/infrastructure-defaults"
      branch     = "main"
      file_path  = "config/infra_defaults.yml"
    }
  }

  # Configuration files - defines where infrastructure configs are stored
  config_repo_files = {
    github = [
      {
        repository = "example-org/service-a"
        branch     = "main"
        file_path  = "terraform/infra.yml"
      }
    ]
    gitlab = []
  }

  # Common tags applied to all resources created by this module
  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Example     = "basic"
  }
}
