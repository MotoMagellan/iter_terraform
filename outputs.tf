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
  value       = module.kms
}

################################################################################
# DynamoDB Outputs
################################################################################

output "dynamodb_tables" {
  description = "Map of DynamoDB table resources created by the module"
  value       = module.dynamodb_table
}
