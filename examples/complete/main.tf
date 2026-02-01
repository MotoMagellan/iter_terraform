provider "aws" {
  region = "us-east-1"
}

# Complete example showing all features of iter_terraform
#
# This example demonstrates:
# - Multiple Git repository sources (GitHub and GitLab)
# - Configuration defaults loaded from a central repository
# - Service-specific configurations from multiple repositories
# - VPCs with VPC endpoints
# - S3 buckets with various configurations
# - Secrets Manager secrets with rotation and replication
# - Comprehensive tagging at the module level
#
# Note: Tags are passed to the module via the 'tags' variable.
# Resource-specific tags can be defined within each resource's YAML configuration.
# Tags cannot be set as a top-level key in the YAML configuration files.

module "iter_terraform_complete" {
  source = "../.."

  # Configuration defaults from a central repository
  config_defaults = {
    defaults = {
      service    = "github"
      repository = "example-org/infrastructure-defaults"
      branch     = "main"
      file_path  = "config/infra_defaults.yml"
    }
  }

  # Multiple configuration sources
  config_repo_files = {
    # GitHub repositories
    github = [
      {
        repository = "example-org/service-a"
        branch     = "main"
        file_path  = "terraform/infra.yml"
      },
      {
        repository = "example-org/service-b"
        branch     = "main"
        file_path  = "infrastructure/config.yml"
      }
    ]

    # GitLab repositories
    gitlab = [
      {
        project   = "example-group/service-c"
        ref       = "main"
        file_path = "terraform/infra.yml"
      }
    ]
  }

  # Common tags applied to all resources
  tags = {
    Environment   = "production"
    ManagedBy     = "Terraform"
    CostCenter    = "engineering"
    Project       = "multi-service-infrastructure"
    Example       = "complete"
    Compliance    = "required"
  }
}
