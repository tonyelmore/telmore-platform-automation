#!/bin/bash 

set -e

if [ "$#" -lt 1 ]; then
  echo "usage: `basename "$0"` [environment name]"
  exit 1
fi

foundation=$1

secrets_folder=/Volumes/Keybase/private/tonyelmore/dev/telmore/environments/azure/terraforming/secrets/${foundation}
terraform_target_dir=$PWD/targets/${foundation}_terraform_target

pushd "${terraform_target_dir}"
terraform apply \
  "${@:2}" "${secrets_folder}"/terraform.plan

terraform output stable_config | jq . > ${secrets_folder}/output.json
popd
