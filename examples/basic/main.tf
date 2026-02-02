provider "aws" {
  region = "us-east-1"
}

# For YAML configuration examples, see ../config-samples/README.md

module "iter_terraform_basic" {
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
      }
    ]
    gitlab = []
  }

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Example     = "basic"
  }
}
