output "infra_configs" {
  description = "Merged infrastructure configurations from all specified repositories"
  value       = local.infra_configs
}

################################################################################
# VPC Outputs
################################################################################

output "vpcs" {
  description = "Map of VPC resources created by the module"
  value       = module.vpc
}

output "vpc_endpoints" {
  description = "Map of VPC endpoint resources created by the module"
  value       = module.vpc_endpoints
}

################################################################################
# S3 Outputs
################################################################################

output "s3_buckets" {
  description = "Map of S3 bucket resources created by the module"
  value       = module.s3_bucket
}

################################################################################
# Secrets Manager Outputs
################################################################################

output "secrets" {
  description = "Map of Secrets Manager resources created by the module"
  value       = module.secrets_manager
  sensitive   = true
}

################################################################################
# KMS Outputs
################################################################################

output "kms_keys" {
  description = "Map of KMS key resources created by the module"
  value = {
    for k, v in module.kms : k => {
      key_arn                      = v.key_arn
      key_id                       = v.key_id
      key_region                   = v.key_region
      key_policy                   = v.key_policy
      external_key_expiration_model = v.external_key_expiration_model
      external_key_state           = v.external_key_state
      external_key_usage           = v.external_key_usage
      aliases                      = v.aliases
    }
  }
}

output "kms_key_grants" {
  description = "Map of KMS key grants created by the module"
  value       = { for k, v in module.kms : k => v.grants }
  sensitive   = true
}

################################################################################
# DynamoDB Outputs
################################################################################

output "dynamodb_tables" {
  description = "Map of DynamoDB table resources created by the module"
  value       = module.dynamodb_table
}
