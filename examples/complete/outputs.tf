output "infra_configs" {
  description = "Merged infrastructure configurations from all repositories"
  value       = module.iter_terraform_complete.infra_configs
  sensitive   = true
}

output "vpc_details" {
  description = "Details of all created VPCs"
  value = {
    for k, v in module.iter_terraform_complete : k => {
      vpc_id             = try(v.vpc_id, null)
      vpc_cidr_block     = try(v.vpc_cidr_block, null)
      private_subnets    = try(v.private_subnets, [])
      public_subnets     = try(v.public_subnets, [])
      database_subnets   = try(v.database_subnets, [])
      nat_gateway_ids    = try(v.natgw_ids, [])
    } if can(v.vpc_id)
  }
}

output "s3_bucket_details" {
  description = "Details of all created S3 buckets"
  value = {
    for k, v in module.iter_terraform_complete : k => {
      bucket_id          = try(v.s3_bucket_id, null)
      bucket_arn         = try(v.s3_bucket_arn, null)
      bucket_domain_name = try(v.s3_bucket_bucket_domain_name, null)
    } if can(v.s3_bucket_id)
  }
}

output "secrets_details" {
  description = "Details of all created secrets"
  value = {
    for k, v in module.iter_terraform_complete : k => {
      secret_id  = try(v.secret_id, null)
      secret_arn = try(v.secret_arn, null)
    } if can(v.secret_id)
  }
  sensitive = true
}
