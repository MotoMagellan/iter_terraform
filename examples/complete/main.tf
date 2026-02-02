provider "aws" {
  region = "us-east-1"
}

# For YAML configuration examples, see ../config-samples/README.md

module "iter_terraform_complete" {
  source = "../.."

  config_defaults = {
    defaults = {
      service    = "github"
      repository = "example-org/infrastructure-defaults"
      branch     = "main"
      file_path  = "config/infra_defaults.yml"
    }
  }

  config_repo_files = {
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

    gitlab = [
      {
        project   = "example-group/service-c"
        ref       = "main"
        file_path = "terraform/infra.yml"
      }
    ]
  }

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
    CostCenter  = "engineering"
    Project     = "multi-service-infrastructure"
    Example     = "complete"
    Compliance  = "required"
  }
}
