output "infra_configs" {
  description = "Merged infrastructure configurations from all repositories"
  value       = module.iter_terraform_basic.infra_configs
}

output "vpcs" {
  description = "All VPC resources created"
  value       = module.iter_terraform_basic.vpcs
}

output "vpc_ids" {
  description = "Map of VPC names to their IDs"
  value       = { for k, v in module.iter_terraform_basic.vpcs : k => v.vpc_id }
}

output "s3_buckets" {
  description = "All S3 bucket resources created"
  value       = module.iter_terraform_basic.s3_buckets
}

output "secrets" {
  description = "All Secrets Manager resources created"
  value       = module.iter_terraform_basic.secrets
  sensitive   = true
}

output "kms_keys" {
  description = "All KMS key resources created"
  value       = module.iter_terraform_basic.kms_keys
}

output "kms_key_ids" {
  description = "Map of KMS key names to their IDs"
  value       = { for k, v in module.iter_terraform_basic.kms_keys : k => v.key_id }
}

output "dynamodb_tables" {
  description = "All DynamoDB table resources created"
  value       = module.iter_terraform_basic.dynamodb_tables
}

output "dynamodb_table_ids" {
  description = "Map of DynamoDB table names to their IDs"
  value       = { for k, v in module.iter_terraform_basic.dynamodb_tables : k => v.dynamodb_table_id }
}
