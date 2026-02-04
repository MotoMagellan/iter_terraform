# tests/vpc_preconditions.tftest.hcl
# Validates all 3 preconditions on terraform_data.vpc_config_validation (iter_vpc.tf)

mock_provider "aws" {}
mock_provider "github" {}
mock_provider "gitlab" {}

variables {
  config_repo_files = {
    github = [{
      repository = "test/repo"
      file_path  = "infra.yml"
    }]
    gitlab = []
  }
  config_defaults = {
    service = {
      service    = "github"
      repository = "test/defaults"
      file_path  = "defaults.yml"
    }
  }
}

# ------------------------------------------------------------------------------
# Positive test: valid VPC config passes all preconditions
# ------------------------------------------------------------------------------
run "valid_vpc_config_passes" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        vpcs:
          test-vpc:
            cidr: "10.0.0.0/16"
      EOT
    }
  }

  override_module {
    target = module.vpc
  }
}

# ------------------------------------------------------------------------------
# Precondition 1 (iter_vpc.tf L51-57):
# Cannot set both single_nat_gateway and one_nat_gateway_per_az to true
# Expected error: "VPC 'test-vpc': Cannot set both 'single_nat_gateway' and
#   'one_nat_gateway_per_az' to true. These options are mutually exclusive."
# ------------------------------------------------------------------------------
run "vpc_single_nat_and_per_az_mutually_exclusive" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        vpcs:
          test-vpc:
            cidr: "10.0.0.0/16"
            single_nat_gateway: true
            one_nat_gateway_per_az: true
      EOT
    }
  }

  override_module {
    target = module.vpc
  }

  expect_failures = [
    terraform_data.vpc_config_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 2 (iter_vpc.tf L59-64):
# Cannot set both create_database_nat_gateway_route and
# create_database_internet_gateway_route to true
# Expected error: "VPC 'test-vpc': Cannot set both
#   'create_database_nat_gateway_route' and
#   'create_database_internet_gateway_route' to true..."
# ------------------------------------------------------------------------------
run "vpc_db_nat_and_igw_route_mutually_exclusive" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        vpcs:
          test-vpc:
            cidr: "10.0.0.0/16"
            create_database_nat_gateway_route: true
            create_database_internet_gateway_route: true
      EOT
    }
  }

  override_module {
    target = module.vpc
  }

  expect_failures = [
    terraform_data.vpc_config_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 3 (iter_vpc.tf L67-72):
# Cannot specify both cidr and vpc_cidr_offset
# Expected error: "VPC 'test-vpc': Cannot specify both 'cidr' and
#   'vpc_cidr_offset'. Use either an explicit CIDR or the offset calculation,
#   not both."
# ------------------------------------------------------------------------------
run "vpc_cidr_and_offset_mutually_exclusive" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        vpcs:
          test-vpc:
            cidr: "10.0.0.0/16"
            vpc_cidr_offset: 1
      EOT
    }
  }

  override_module {
    target = module.vpc
  }

  expect_failures = [
    terraform_data.vpc_config_validation,
  ]
}
