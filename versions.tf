terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }

    github = {
      source  = "hashicorp/github"
      version = "~> 6.0"
    }

    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 3.0"
    }
  }
}
