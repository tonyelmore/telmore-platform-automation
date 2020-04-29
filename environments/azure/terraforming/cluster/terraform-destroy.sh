#!/bin/bash 

set -e

if [ "$#" -lt 2 ]; then
  echo "usage: `basename "$0"` <environment name> <cluster name>"
  exit 1
fi

foundation=$1
cluster_name=$2

secrets_folder=$PWD/../secrets/${foundation}
terraform_target_dir=$PWD/${foundation}_terraform_target

pushd ${terraform_target_dir}
terraform destroy \
  -var-file=${secrets_folder}/${cluster_name}_terraform.tfvars \
  ${@:3} .
popd