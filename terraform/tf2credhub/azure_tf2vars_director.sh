#!/usr/bin/env bash

# This script extracts the vars required for director config from a Terraform output file
# output json file.
#
#    $ tf2vars.sh terraform-outputs.yml director-vars.yml
#

set -eu

terraform output -raw -state=../paving-azure-sbx/terraform.tfstate stable_config > terraform-outputs.yml
tf_output_file="terraform-outputs.yml"

vars_file="output/$1"
[[ -z "$vars_file" ]] && { echo "Error: expected an output path to the director vars file"; exit 1; }
echo "Director vars file: " ${vars_file}

function tf_value {
  local o
  o=$(jq -r ".$1" < "$tf_output_file")
  [[ "null" = "$o" ]] && { echo "Error: expected to find $1 in terraform output"; exit 1; }
  echo "$o"
}

function vars_append {
  if [[ $2 == *$'\n'*  ]]; then
    val=$(echo "$2" | sed $'s/^/    /')
    cat << EOF >> "$vars_file"
$1: $val
EOF
  else
    cat << EOF >> "$vars_file"
$1: $2
EOF
  fi
}

function tf2vars {
  val=$(tf_value "$1")
  vars_append "$1" "$val"
}

environment_name=$(tf_value 'environment_name')
echo "Found environment: $environment_name"

cat << EOF > "$vars_file"
EOF


tf2vars 'apps_dns_domain'
tf2vars 'availability_zones'
tf2vars 'buildpacks_bucket_name'
tf2vars 'droplets_bucket_name'

tf2vars 'management_subnet_cidr'
tf2vars 'management_subnet_gateway'
tf2vars 'management_subnet_id' 
tf2vars 'management_subnet_reserved_ip_range'

tf2vars 'mysql_security_group_id'
tf2vars 'mysql_security_group_name'
tf2vars 'nat_security_group_id'
tf2vars 'nat_security_group_name'
tf2vars 'ops_manager_bucket'
tf2vars 'ops_manager_dns'
tf2vars 'ops_manager_iam_instance_profile_name'
tf2vars 'ops_manager_key_pair_name'
tf2vars 'ops_manager_security_group_id'
tf2vars 'ops_manager_security_group_name'
tf2vars 'ops_manager_subnet_id'
tf2vars 'packages_bucket_name'

tf2vars 'pas_subnet_cidr'
tf2vars 'pas_subnet_gateway'
tf2vars 'pas_subnet_id'
tf2vars 'pas_subnet_reserved_ip_range'

tf2vars 'pks_api_dns'
tf2vars 'pks_api_lb_security_group_id'
tf2vars 'pks_api_lb_security_group_name'
tf2vars 'pks_api_target_groups'
tf2vars 'pks_internal_security_group_id'
tf2vars 'pks_internal_security_group_name'
tf2vars 'pks_master_iam_instance_profile_name'
tf2vars 'pks_subnet_cidr'
tf2vars 'pks_subnet_gateway'
tf2vars 'pks_subnet_id'
tf2vars 'pks_subnet_reserved_ip_range'
tf2vars 'pks_worker_iam_instance_profile_name'

tf2vars 'platform_vms_security_group_id'
tf2vars 'platform_vms_security_group_name'
tf2vars 'public_subnet_cidr'
tf2vars 'public_subnet_id'
tf2vars 'region'
tf2vars 'resources_bucket_name'

tf2vars 'services_subnet_cidr'
tf2vars 'services_subnet_gateway'
tf2vars 'services_subnet_id'
tf2vars 'services_subnet_reserved_ip_ranges'

tf2vars 'ssh_dns'
tf2vars 'ssh_lb_security_group_id'
tf2vars 'ssh_lb_security_group_name'
tf2vars 'ssh_target_group_name'
tf2vars 'sys_dns_domain'
tf2vars 'tcp_dns'
tf2vars 'tcp_lb_security_group_id'
tf2vars 'tcp_lb_security_group_name'
tf2vars 'tcp_target_group_names'
tf2vars 'vpc_id'
tf2vars 'web_lb_security_group_id'
tf2vars 'web_lb_security_group_name'
tf2vars 'web_target_group_names'

