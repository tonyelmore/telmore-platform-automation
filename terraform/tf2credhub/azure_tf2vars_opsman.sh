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
echo "Opsman vars file: " ${vars_file}

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


tf2vars 'location'
tf2vars 'resource_group_name'
tf2vars 'ops_manager_storage_account_name'
tf2vars 'management_subnet_id'
tf2vars 'ops_manager_public_ip'
tf2vars 'ops_manager_private_ip'
tf2vars 'iaas_configuration_environment_azurecloud'
tf2vars 'ops_manager_security_group_name'

