#!/usr/bin/env bash

# This script builds a credhub import compatible json document from a Terraform
# output json file.
#
#    $ tf2credhub.sh /tmp/prod01.json /tmp/prod01-credhub.json
#    Target concourse credhub
#    $ credhub import -f /tmp/prod01-credhub.json
#

terraform output -raw -state=../paving-azure-sbx/terraform.tfstate stable_config > terraform-outputs.yml
tf_output_file="terraform-outputs.yml"

credhub_import_file="output/$1"
[[ -z "$credhub_import_file" ]] && { echo "Error: expected an output path to the credhub import file"; exit 1; }

secrets_file="output/$2"
[[ -z "$secrets_file" ]] && { echo "Error: expected an output path to the secrets file"; exit 1; }

echo "Credhub import file: " ${credhub_import_file}
echo "Opsman secrets file: " ${secrets_file}

function tf_value {
  local o
  o=$(jq -r ".$1" < "$tf_output_file")
  [[ "null" = "$o" ]] && { echo "Error: expected to find $1 in terraform output"; exit 1; }
  echo "$o"
}

function credhub_import_append {
  if [[ $2 == *$'\n'*  ]]; then
    val=$(echo "$2" | sed $'s/^/    /')
    cat << EOF >> "$credhub_import_file"
- name: /concourse/$environment_name/$1
  type: value
  value: |-
$val
EOF
  else
    cat << EOF >> "$credhub_import_file"
- name: /concourse/$environment_name/$1
  type: value
  value: $2
EOF
  fi

    cat << EOF >> "$secrets_file"
$1: (($1))
EOF
  
}

function tf2credhub {
  val=$(tf_value "$1")
  credhub_import_append "$1" "$val"
}

environment_name=$(tf_value 'environment_name')
echo "Found environment: $environment_name"

cat << EOF > "$credhub_import_file"
credentials:
EOF

cat << EOF > "$secrets_file"
EOF

tf2credhub 'tenant_id'
tf2credhub 'subscription_id'
tf2credhub 'client_id'
tf2credhub 'client_secret'
tf2credhub 'ops_manager_storage_account_name'
tf2credhub 'pas_storage_account_access_key'
tf2credhub 'ops_manager_ssh_private_key'
tf2credhub 'ops_manager_ssh_public_key'
tf2credhub 'ops_manager_storage_account_access_key'
