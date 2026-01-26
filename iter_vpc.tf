# VPC Definition
# 
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#



data "aws_availability_zones" "available" {}

locals {
  #   name   = "ex-${basename(path.cwd)}"
  #   region = "eu-west-1"

  #   vpc_cidr = "10.0.0.0/16"
  azs = data.aws_availability_zones.available.names

  vpc_defaults = lookup(local.defaults, "vpc", {})       # default VPC values for any VPC created
  vpc_config   = lookup(local.infra_configs, "vpcs", {}) # does not create a VPC simply by defaults

  # Calculate VPC CIDR with offset applied to second octet
  # If vpc_cidr_offset = 1, converts 10.0.0.0/8 to 10.1.0.0/8
  vpc_cidrs = { for k, v in local.vpc_config : k => (
    can(v.cidr) ? v.cidr : format(
      "10.%s.0.0/8",
      try(v.vpc_cidr_offset, 0)
    )
  ) }
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  for_each = local.vpc_config

  region = try(each.value.region, null
  )

  name = try(each.value.name, each.key)
  cidr = local.vpc_cidrs[each.key]

  azs = slice(local.azs, 0, try(each.value.az_count, local.vpc_defaults["az_count"], 3))

  private_subnets     = [for k, v in slice(local.azs, 0, try(each.value.az_count, local.vpc_defaults["az_count"], 3)) : cidrsubnet(local.vpc_cidrs[each.key], 8, k)]
  public_subnets      = lookup(each.value, "create_public_subnets", false) ? [for k, v in slice(local.azs, 0, try(each.value.az_count, local.vpc_defaults["az_count"], 3)) : cidrsubnet(local.vpc_cidrs[each.key], 8, k + 4)] : null
  database_subnets    = lookup(each.value, "create_database_subnets", false) ? [for k, v in slice(local.azs, 0, try(each.value.az_count, local.vpc_defaults["az_count"], 3)) : cidrsubnet(local.vpc_cidrs[each.key], 8, k + 8)] : null
  elasticache_subnets = lookup(each.value, "create_elasticache_subnets", false) ? [for k, v in slice(local.azs, 0, try(each.value.az_count, local.vpc_defaults["az_count"], 3)) : cidrsubnet(local.vpc_cidrs[each.key], 8, k + 12)] : null
  redshift_subnets    = lookup(each.value, "create_redshift_subnets", false) ? [for k, v in slice(local.azs, 0, try(each.value.az_count, local.vpc_defaults["az_count"], 3)) : cidrsubnet(local.vpc_cidrs[each.key], 8, k + 16)] : null
  intra_subnets       = lookup(each.value, "create_intra_subnets", false) ? [for k, v in slice(local.azs, 0, try(each.value.az_count, local.vpc_defaults["az_count"], 3)) : cidrsubnet(local.vpc_cidrs[each.key], 8, k + 20)] : null

  create_database_subnet_group  = try(each.value.create_database_subnet_group, local.vpc_defaults.create_database_subnet_group, false) # Enables public access
  manage_default_network_acl    = try(each.value.manage_default_network_acl, local.vpc_defaults.manage_default_network_acl, false)
  manage_default_route_table    = try(each.value.manage_default_route_table, local.vpc_defaults.manage_default_route_table, false)
  manage_default_security_group = try(each.value.manage_default_security_group, local.vpc_defaults.manage_default_security_group, false)

  enable_dns_hostnames = try(each.value.enable_dns_hostnames, local.vpc_defaults.enable_dns_hostnames, true)
  enable_dns_support   = try(each.value.enable_dns_support, local.vpc_defaults.enable_dns_support, true)

  enable_nat_gateway     = try(each.value.enable_nat_gateway, local.vpc_defaults.enable_nat_gateway, true)
  single_nat_gateway     = try(each.value.single_nat_gateway, local.vpc_defaults.single_nat_gateway, true)
  one_nat_gateway_per_az = try(each.value.one_nat_gateway_per_az, local.vpc_defaults.one_nat_gateway_per_az, false)
  reuse_nat_ips          = try(each.value.reuse_nat_ips, local.vpc_defaults.reuse_nat_ips, false)
  external_nat_ip_ids    = try(each.value.external_nat_ip_ids, local.vpc_defaults.external_nat_ip_ids, [])
  external_nat_ips       = try(each.value.external_nat_ips, local.vpc_defaults.external_nat_ips, [])

  enable_ipv6                                        = try(each.value.enable_ipv6, local.vpc_defaults.enable_ipv6, false)
  ipv6_cidr                                          = try(each.value.ipv6_cidr, local.vpc_defaults.ipv6_cidr, null)
  private_subnet_assign_ipv6_address_on_creation     = try(each.value.private_subnet_assign_ipv6_address_on_creation, local.vpc_defaults.private_subnet_assign_ipv6_address_on_creation, null)
  public_subnet_assign_ipv6_address_on_creation      = try(each.value.public_subnet_assign_ipv6_address_on_creation, local.vpc_defaults.public_subnet_assign_ipv6_address_on_creation, null)
  database_subnet_assign_ipv6_address_on_creation    = try(each.value.database_subnet_assign_ipv6_address_on_creation, local.vpc_defaults.database_subnet_assign_ipv6_address_on_creation, null)
  elasticache_subnet_assign_ipv6_address_on_creation = try(each.value.elasticache_subnet_assign_ipv6_address_on_creation, local.vpc_defaults.elasticache_subnet_assign_ipv6_address_on_creation, null)
  redshift_subnet_assign_ipv6_address_on_creation    = try(each.value.redshift_subnet_assign_ipv6_address_on_creation, local.vpc_defaults.redshift_subnet_assign_ipv6_address_on_creation, null)
  intra_subnet_assign_ipv6_address_on_creation       = try(each.value.intra_subnet_assign_ipv6_address_on_creation, local.vpc_defaults.intra_subnet_assign_ipv6_address_on_creation, null)
  private_subnet_ipv6_prefixes                       = try(each.value.private_subnet_ipv6_prefixes, local.vpc_defaults.private_subnet_ipv6_prefixes, [])
  public_subnet_ipv6_prefixes                        = try(each.value.public_subnet_ipv6_prefixes, local.vpc_defaults.public_subnet_ipv6_prefixes, [])
  database_subnet_ipv6_prefixes                      = try(each.value.database_subnet_ipv6_prefixes, local.vpc_defaults.database_subnet_ipv6_prefixes, [])
  elasticache_subnet_ipv6_prefixes                   = try(each.value.elasticache_subnet_ipv6_prefixes, local.vpc_defaults.elasticache_subnet_ipv6_prefixes, [])
  redshift_subnet_ipv6_prefixes                      = try(each.value.redshift_subnet_ipv6_prefixes, local.vpc_defaults.redshift_subnet_ipv6_prefixes, [])
  intra_subnet_ipv6_prefixes                         = try(each.value.intra_subnet_ipv6_prefixes, local.vpc_defaults.intra_subnet_ipv6_prefixes, [])

  create_egress_only_igw              = try(each.value.create_egress_only_igw, local.vpc_defaults.create_egress_only_igw, true)
  create_igw                          = try(each.value.create_igw, local.vpc_defaults.create_igw, true)
  create_multiple_public_route_tables = try(each.value.create_multiple_public_route_tables, local.vpc_defaults.create_multiple_public_route_tables, false)

  create_database_subnet_route_table     = try(each.value.create_database_subnet_route_table, local.vpc_defaults.create_database_subnet_route_table, false)
  create_database_nat_gateway_route      = try(each.value.create_database_nat_gateway_route, local.vpc_defaults.create_database_nat_gateway_route, false)
  create_database_internet_gateway_route = try(each.value.create_database_internet_gateway_route, local.vpc_defaults.create_database_internet_gateway_route, false)

  create_elasticache_subnet_route_table = try(each.value.create_elasticache_subnet_route_table, local.vpc_defaults.create_elasticache_subnet_route_table, false)
  create_elasticache_subnet_group       = try(each.value.create_elasticache_subnet_group, local.vpc_defaults.create_elasticache_subnet_group, true)

  create_redshift_subnet_route_table = try(each.value.create_redshift_subnet_route_table, local.vpc_defaults.create_redshift_subnet_route_table, false)
  create_redshift_subnet_group       = try(each.value.create_redshift_subnet_group, local.vpc_defaults.create_redshift_subnet_group, true)
  enable_public_redshift             = try(each.value.enable_public_redshift, local.vpc_defaults.enable_public_redshift, false)

  map_public_ip_on_launch = try(each.value.map_public_ip_on_launch, local.vpc_defaults.map_public_ip_on_launch, true)

  private_subnet_suffix     = try(each.value.private_subnet_suffix, local.vpc_defaults.private_subnet_suffix, "private")
  public_subnet_suffix      = try(each.value.public_subnet_suffix, local.vpc_defaults.public_subnet_suffix, "public")
  database_subnet_suffix    = try(each.value.database_subnet_suffix, local.vpc_defaults.database_subnet_suffix, "db")
  elasticache_subnet_suffix = try(each.value.elasticache_subnet_suffix, local.vpc_defaults.elasticache_subnet_suffix, "elasticache")
  redshift_subnet_suffix    = try(each.value.redshift_subnet_suffix, local.vpc_defaults.redshift_subnet_suffix, "redshift")
  intra_subnet_suffix       = try(each.value.intra_subnet_suffix, local.vpc_defaults.intra_subnet_suffix, "intra")

  private_subnet_tags     = try(each.value.private_subnet_tags, local.vpc_defaults.private_subnet_tags, {})
  public_subnet_tags      = try(each.value.public_subnet_tags, local.vpc_defaults.public_subnet_tags, {})
  database_subnet_tags    = try(each.value.database_subnet_tags, local.vpc_defaults.database_subnet_tags, {})
  elasticache_subnet_tags = try(each.value.elasticache_subnet_tags, local.vpc_defaults.elasticache_subnet_tags, {})
  redshift_subnet_tags    = try(each.value.redshift_subnet_tags, local.vpc_defaults.redshift_subnet_tags, {})
  intra_subnet_tags       = try(each.value.intra_subnet_tags, local.vpc_defaults.intra_subnet_tags, {})

  public_route_table_tags      = try(each.value.public_route_table_tags, local.vpc_defaults.public_route_table_tags, {})
  private_route_table_tags     = try(each.value.private_route_table_tags, local.vpc_defaults.private_route_table_tags, {})
  database_route_table_tags    = try(each.value.database_route_table_tags, local.vpc_defaults.database_route_table_tags, {})
  elasticache_route_table_tags = try(each.value.elasticache_route_table_tags, local.vpc_defaults.elasticache_route_table_tags, {})
  redshift_route_table_tags    = try(each.value.redshift_route_table_tags, local.vpc_defaults.redshift_route_table_tags, {})
  intra_route_table_tags       = try(each.value.intra_route_table_tags, local.vpc_defaults.intra_route_table_tags, {})

  public_acl_tags      = try(each.value.public_acl_tags, local.vpc_defaults.public_acl_tags, {})
  private_acl_tags     = try(each.value.private_acl_tags, local.vpc_defaults.private_acl_tags, {})
  database_acl_tags    = try(each.value.database_acl_tags, local.vpc_defaults.database_acl_tags, {})
  elasticache_acl_tags = try(each.value.elasticache_acl_tags, local.vpc_defaults.elasticache_acl_tags, {})
  redshift_acl_tags    = try(each.value.redshift_acl_tags, local.vpc_defaults.redshift_acl_tags, {})
  intra_acl_tags       = try(each.value.intra_acl_tags, local.vpc_defaults.intra_acl_tags, {})

  vpc_tags                    = try(each.value.vpc_tags, local.vpc_defaults.vpc_tags, {})
  igw_tags                    = try(each.value.igw_tags, local.vpc_defaults.igw_tags, {})
  nat_gateway_tags            = try(each.value.nat_gateway_tags, local.vpc_defaults.nat_gateway_tags, {})
  nat_eip_tags                = try(each.value.nat_eip_tags, local.vpc_defaults.nat_eip_tags, {})
  customer_gateway_tags       = try(each.value.customer_gateway_tags, local.vpc_defaults.customer_gateway_tags, {})
  vpn_gateway_tags            = try(each.value.vpn_gateway_tags, local.vpc_defaults.vpn_gateway_tags, {})
  dhcp_options_tags           = try(each.value.dhcp_options_tags, local.vpc_defaults.dhcp_options_tags, {})
  default_security_group_tags = try(each.value.default_security_group_tags, local.vpc_defaults.default_security_group_tags, {})
  default_network_acl_tags    = try(each.value.default_network_acl_tags, local.vpc_defaults.default_network_acl_tags, {})
  default_route_table_tags    = try(each.value.default_route_table_tags, local.vpc_defaults.default_route_table_tags, {})

  propagate_intra_route_tables_vgw   = try(each.value.propagate_intra_route_tables_vgw, local.vpc_defaults.propagate_intra_route_tables_vgw, false)
  propagate_private_route_tables_vgw = try(each.value.propagate_private_route_tables_vgw, local.vpc_defaults.propagate_private_route_tables_vgw, false)
  propagate_public_route_tables_vgw  = try(each.value.propagate_public_route_tables_vgw, local.vpc_defaults.propagate_public_route_tables_vgw, false)

  enable_flow_log                                 = try(each.value.enable_flow_log, local.vpc_defaults.enable_flow_log, false)
  create_flow_log_cloudwatch_iam_role             = try(each.value.create_flow_log_cloudwatch_iam_role, local.vpc_defaults.create_flow_log_cloudwatch_iam_role, false)
  create_flow_log_cloudwatch_log_group            = try(each.value.create_flow_log_cloudwatch_log_group, local.vpc_defaults.create_flow_log_cloudwatch_log_group, false)
  flow_log_traffic_type                           = try(each.value.flow_log_traffic_type, local.vpc_defaults.flow_log_traffic_type, "ALL")
  flow_log_destination_type                       = try(each.value.flow_log_destination_type, local.vpc_defaults.flow_log_destination_type, "cloud-watch-logs")
  flow_log_destination_arn                        = try(each.value.flow_log_destination_arn, local.vpc_defaults.flow_log_destination_arn, null)
  flow_log_log_format                             = try(each.value.flow_log_log_format, local.vpc_defaults.flow_log_log_format, null)
  flow_log_cloudwatch_iam_role_arn                = try(each.value.flow_log_cloudwatch_iam_role_arn, local.vpc_defaults.flow_log_cloudwatch_iam_role_arn, null)
  flow_log_cloudwatch_log_group_name_prefix       = try(each.value.flow_log_cloudwatch_log_group_name_prefix, local.vpc_defaults.flow_log_cloudwatch_log_group_name_prefix, "/aws/vpc-flow-log/")
  flow_log_cloudwatch_log_group_name_suffix       = try(each.value.flow_log_cloudwatch_log_group_name_suffix, local.vpc_defaults.flow_log_cloudwatch_log_group_name_suffix, "")
  flow_log_cloudwatch_log_group_retention_in_days = try(each.value.flow_log_cloudwatch_log_group_retention_in_days, local.vpc_defaults.flow_log_cloudwatch_log_group_retention_in_days, null)
  flow_log_cloudwatch_log_group_kms_key_id        = try(each.value.flow_log_cloudwatch_log_group_kms_key_id, local.vpc_defaults.flow_log_cloudwatch_log_group_kms_key_id, null)
  flow_log_cloudwatch_log_group_skip_destroy      = try(each.value.flow_log_cloudwatch_log_group_skip_destroy, local.vpc_defaults.flow_log_cloudwatch_log_group_skip_destroy, false)
  flow_log_cloudwatch_log_group_class             = try(each.value.flow_log_cloudwatch_log_group_class, local.vpc_defaults.flow_log_cloudwatch_log_group_class, null)
  flow_log_max_aggregation_interval               = try(each.value.flow_log_max_aggregation_interval, local.vpc_defaults.flow_log_max_aggregation_interval, 600)
  flow_log_file_format                            = try(each.value.flow_log_file_format, local.vpc_defaults.flow_log_file_format, null)
  flow_log_hive_compatible_partitions             = try(each.value.flow_log_hive_compatible_partitions, local.vpc_defaults.flow_log_hive_compatible_partitions, false)
  flow_log_per_hour_partition                     = try(each.value.flow_log_per_hour_partition, local.vpc_defaults.flow_log_per_hour_partition, false)
  vpc_flow_log_permissions_boundary               = try(each.value.vpc_flow_log_permissions_boundary, local.vpc_defaults.vpc_flow_log_permissions_boundary, null)
  vpc_flow_log_tags                               = try(each.value.vpc_flow_log_tags, local.vpc_defaults.vpc_flow_log_tags, {})

  customer_gateways = try(each.value.customer_gateways, local.vpc_defaults.customer_gateways, {})

  enable_vpn_gateway = try(each.value.enable_vpn_gateway, local.vpc_defaults.enable_vpn_gateway, false)
  vpn_gateway_id     = try(each.value.vpn_gateway_id, local.vpc_defaults.vpn_gateway_id, null)
  amazon_side_asn    = try(each.value.amazon_side_asn, local.vpc_defaults.amazon_side_asn, null)
  vpn_gateway_az     = try(each.value.vpn_gateway_az, local.vpc_defaults.vpn_gateway_az, null)

  enable_dhcp_options               = try(each.value.enable_dhcp_options, local.vpc_defaults.enable_dhcp_options, false)
  dhcp_options_domain_name          = try(each.value.dhcp_options_domain_name, local.vpc_defaults.dhcp_options_domain_name, null)
  dhcp_options_domain_name_servers  = try(each.value.dhcp_options_domain_name_servers, local.vpc_defaults.dhcp_options_domain_name_servers, ["AmazonProvidedDNS"])
  dhcp_options_ntp_servers          = try(each.value.dhcp_options_ntp_servers, local.vpc_defaults.dhcp_options_ntp_servers, [])
  dhcp_options_netbios_name_servers = try(each.value.dhcp_options_netbios_name_servers, local.vpc_defaults.dhcp_options_netbios_name_servers, [])
  dhcp_options_netbios_node_type    = try(each.value.dhcp_options_netbios_node_type, local.vpc_defaults.dhcp_options_netbios_node_type, null)

  default_security_group_name    = try(each.value.default_security_group_name, local.vpc_defaults.default_security_group_name, null)
  default_security_group_ingress = try(each.value.default_security_group_ingress, local.vpc_defaults.default_security_group_ingress, [])
  default_security_group_egress  = try(each.value.default_security_group_egress, local.vpc_defaults.default_security_group_egress, [])

  default_network_acl_name    = try(each.value.default_network_acl_name, local.vpc_defaults.default_network_acl_name, null)
  default_network_acl_ingress = try(each.value.default_network_acl_ingress, local.vpc_defaults.default_network_acl_ingress, [])
  default_network_acl_egress  = try(each.value.default_network_acl_egress, local.vpc_defaults.default_network_acl_egress, [])

  public_dedicated_network_acl      = try(each.value.public_dedicated_network_acl, local.vpc_defaults.public_dedicated_network_acl, false)
  private_dedicated_network_acl     = try(each.value.private_dedicated_network_acl, local.vpc_defaults.private_dedicated_network_acl, false)
  database_dedicated_network_acl    = try(each.value.database_dedicated_network_acl, local.vpc_defaults.database_dedicated_network_acl, false)
  elasticache_dedicated_network_acl = try(each.value.elasticache_dedicated_network_acl, local.vpc_defaults.elasticache_dedicated_network_acl, false)
  redshift_dedicated_network_acl    = try(each.value.redshift_dedicated_network_acl, local.vpc_defaults.redshift_dedicated_network_acl, false)
  intra_dedicated_network_acl       = try(each.value.intra_dedicated_network_acl, local.vpc_defaults.intra_dedicated_network_acl, false)

  public_inbound_acl_rules       = try(each.value.public_inbound_acl_rules, local.vpc_defaults.public_inbound_acl_rules, [])
  public_outbound_acl_rules      = try(each.value.public_outbound_acl_rules, local.vpc_defaults.public_outbound_acl_rules, [])
  private_inbound_acl_rules      = try(each.value.private_inbound_acl_rules, local.vpc_defaults.private_inbound_acl_rules, [])
  private_outbound_acl_rules     = try(each.value.private_outbound_acl_rules, local.vpc_defaults.private_outbound_acl_rules, [])
  database_inbound_acl_rules     = try(each.value.database_inbound_acl_rules, local.vpc_defaults.database_inbound_acl_rules, [])
  database_outbound_acl_rules    = try(each.value.database_outbound_acl_rules, local.vpc_defaults.database_outbound_acl_rules, [])
  elasticache_inbound_acl_rules  = try(each.value.elasticache_inbound_acl_rules, local.vpc_defaults.elasticache_inbound_acl_rules, [])
  elasticache_outbound_acl_rules = try(each.value.elasticache_outbound_acl_rules, local.vpc_defaults.elasticache_outbound_acl_rules, [])
  redshift_inbound_acl_rules     = try(each.value.redshift_inbound_acl_rules, local.vpc_defaults.redshift_inbound_acl_rules, [])
  redshift_outbound_acl_rules    = try(each.value.redshift_outbound_acl_rules, local.vpc_defaults.redshift_outbound_acl_rules, [])
  intra_inbound_acl_rules        = try(each.value.intra_inbound_acl_rules, local.vpc_defaults.intra_inbound_acl_rules, [])
  intra_outbound_acl_rules       = try(each.value.intra_outbound_acl_rules, local.vpc_defaults.intra_outbound_acl_rules, [])

  default_route_table_name             = try(each.value.default_route_table_name, local.vpc_defaults.default_route_table_name, null)
  default_route_table_propagating_vgws = try(each.value.default_route_table_propagating_vgws, local.vpc_defaults.default_route_table_propagating_vgws, [])
  default_route_table_routes           = try(each.value.default_route_table_routes, local.vpc_defaults.default_route_table_routes, [])

  tags = merge(
    lookup(local.vpc_defaults, "tags"),
    local.tags,
    {
      TFModule = "terraform-aws-modules/vpc/aws"
    },
    lookup(each.value, "tags", {}),
  )
}

################################################################################
# VPC Endpoints Module
################################################################################

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "6.6.0"

  for_each = {
    for k, v in local.vpc_config : k => v
    if can(v.vpc_endpoints)
  }

  vpc_id = module.vpc[each.key].vpc_id

  # set "create" vpc_endpoint key to false to remove endpoints but keep the VPC Endpoints config
  # in the YAML for later use or deploying in 
  create = lookup(each.value, "create", true)

  create_security_group      = lookup(each.value, "security_group_rules", {}) != {} && lookup(each.value, "create_security_group", true)
  security_group_name_prefix = "${module.vpc[each.key].name}-vpc-endpoints-"
  security_group_description = lookup(each.value, "security_group_description", "VPC endpoint security group")
  security_group_rules       = lookup(each.value, "security_group_rules", {})
  # security_group_rules = {
  #   ingress_https = {
  #     description = "HTTPS from VPC"
  #     cidr_blocks = [module.vpc[each.key].vpc_cidr_block]
  #   }
  # }

  endpoints = {
    for service_key, service_config in merge(
      try(local.vpc_defaults.vpc_endpoints.endpoint_services, {}),
      try(each.value.vpc_endpoints.endpoint_services, {})
    ) :
    service_key => merge(
      # Default configuration based on service type
      lookup({
        s3 = {
          service             = "s3"
          private_dns_enabled = true
          dns_options = {
            private_dns_only_for_inbound_resolver_endpoint = false
          }
          tags = { Name = "s3-vpc-endpoint" }
        }
        dynamodb = {
          service      = "dynamodb"
          service_type = "Gateway"
          route_table_ids = flatten([
            module.vpc[each.key].intra_route_table_ids,
            module.vpc[each.key].private_route_table_ids,
            module.vpc[each.key].public_route_table_ids
          ])
          policy = data.aws_iam_policy_document.dynamodb_endpoint_policy[each.key].json
          tags   = { Name = "dynamodb-vpc-endpoint" }
        }
        ecs = {
          service             = "ecs"
          private_dns_enabled = true
          subnet_ids          = module.vpc[each.key].private_subnets
          subnet_configurations = [
            for v in module.vpc[each.key].private_subnet_objects :
            {
              ipv4      = cidrhost(v.cidr_block, 10)
              subnet_id = v.id
            }
          ]
        }
        ecs_telemetry = {
          create              = false
          service             = "ecs-telemetry"
          private_dns_enabled = true
          subnet_ids          = module.vpc[each.key].private_subnets
        }
        ecr_api = {
          service             = "ecr.api"
          private_dns_enabled = true
          subnet_ids          = module.vpc[each.key].private_subnets
          policy              = data.aws_iam_policy_document.generic_endpoint_policy[each.key].json
        }
        ecr_dkr = {
          service             = "ecr.dkr"
          private_dns_enabled = true
          subnet_ids          = module.vpc[each.key].private_subnets
          policy              = data.aws_iam_policy_document.generic_endpoint_policy[each.key].json
        }
        rds = {
          service             = "rds"
          private_dns_enabled = true
          subnet_ids          = module.vpc[each.key].private_subnets
          security_group_ids  = [aws_security_group.rds[each.key].id]
        }
      }, service_key, {}),
      # Merge with user-provided config (from defaults or VPC-specific)
      service_config
    )
  }

  tags = merge(local.tags, {
    Project  = "Secret"
    Endpoint = "true"
  })
}


################################################################################
# Supporting Resources
################################################################################

data "aws_iam_policy_document" "dynamodb_endpoint_policy" {
  for_each = {
    for k, v in local.vpc_config : k => v
    if can(v.vpc_endpoints)
  }

  statement {
    effect    = "Deny"
    actions   = ["dynamodb:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:sourceVpc"

      values = [module.vpc[each.key].vpc_id]
    }
  }
}

data "aws_iam_policy_document" "generic_endpoint_policy" {
  for_each = {
    for k, v in local.vpc_config : k => v
    if can(v.vpc_endpoints)
  }

  statement {
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpc"

      values = [module.vpc[each.key].vpc_id]
    }
  }
}

resource "aws_security_group" "rds" {
  for_each = {
    for k, v in local.vpc_config : k => v
    if can(v.vpc_endpoints)
  }

  name_prefix = "${each.key}-rds-"
  description = "Allow PostgreSQL inbound traffic"
  vpc_id      = module.vpc[each.key].vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc[each.key].vpc_cidr_block]
  }

  tags = local.tags
}
