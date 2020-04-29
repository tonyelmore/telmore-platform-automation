#!/bin/bash 

set -e

if [ "$#" -lt 1 ]; then
  echo "usage: `basename "$0"` [environment name]"
  exit 1
fi

foundation=$1

secrets_folder=/Volumes/Keybase/private/tonyelmore/dev/telmore/environments/azure/terraforming/secrets/${foundation}
terraform_source_dir=~/dev/paving-voor-fork/paving/azure
terraform_target_dir=$PWD/targets/${foundation}_terraform_target

echo "cleaning old terraform dir ${terraform_target_dir}"
rm -rf ${terraform_target_dir}

echo "copying terraform files from ${terraform_source_dir} to ${terraform_target_dir}"
mkdir -p ${terraform_target_dir}
cp -R ${terraform_source_dir}/ ${terraform_target_dir}

# Copy any additional terraform not included in the paving repo
# cp $PWD/optional_terraform/*.tf ${terraform_target_dir}

# Copy the provider_override in order to save state to azure blob store
# cp ${secrets_folder}/provider_override.tf ${terraform_target_dir}

pushd "${terraform_target_dir}"
terraform init .

terraform plan \
  -var-file="${secrets_folder}"/terraform.tfvars \
  -out="${secrets_folder}"/terraform.plan \
  "${@:2}" .

popd