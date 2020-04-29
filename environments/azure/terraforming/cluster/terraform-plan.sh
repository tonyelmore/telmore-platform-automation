#!/bin/bash 

set -e

if [ "$#" -lt 2 ]; then
  echo "usage: `basename "$0"` <environment name> <cluster name>"
  exit 1
fi

foundation=$1
cluster_name=$2

secrets_folder=$PWD/../secrets/${foundation}

terraform_source_dir=$PWD/azure
terraform_target_dir=$PWD/${foundation}_terraform_target

echo "cleaning old terraform dir ${terraform_target_dir}"
rm -rf ${terraform_target_dir}

echo "copying terraform files from ${terraform_source_dir} to ${terraform_target_dir}"
mkdir -p ${terraform_target_dir}
cp ${terraform_source_dir}/*.tf ${terraform_target_dir}

cp ${secrets_folder}/${cluster_name}_provider_override.tf ${terraform_target_dir}

pushd ${terraform_target_dir}
terraform init .

terraform plan \
  -var-file=${secrets_folder}/${cluster_name}_terraform.tfvars \
  -out=${secrets_folder}/${cluster_name}_terraform.plan \
  ${@:3} .

popd