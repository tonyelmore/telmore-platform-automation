#!/bin/bash -e

bypass_unused=false

if [ $# -eq 4 ]; then
  echo "got 4 params $#"
  bypass_unused=$4
elif [ ! $# -eq 3 ]; then
  echo "Must supply iaas and environment and product name as arguments"
  exit 1
fi

iaas=$1
environment_name=$2
product=$3

echo "Validating configuration for product $product"

deploy_type="tile"
if [ "${product}" == "os-conf" ]; then
  deploy_type="runtime-config"
fi
if [ "${product}" == "clamav" ]; then
  deploy_type="runtime-config"
fi

vars_files_args=("")
if [ -f "../${iaas}/${environment_name}/config/defaults/${product}.yml" ]; then
  vars_files_args+=("--vars-file ../${iaas}/${environment_name}/config/defaults/${product}.yml")
fi

if [[ "${deploy_type}" == "runtime-config" ]]; then
  vars_files_args+=("--vars-file ../${iaas}/${INITIAL_FOUNDATION}/versions/${product}.yml")
fi

if [ -f "../${iaas}/common/${product}.yml" ]; then
  vars_files_args+=("--vars-file ../${iaas}/common/${product}.yml")
fi

if [ -f "../${iaas}/${environment_name}/config/vars/${product}.yml" ]; then
  vars_files_args+=("--vars-file ../${iaas}/${environment_name}/config/vars/${product}.yml")
fi

if [ -f "../${iaas}/${environment_name}/config/secrets/${product}.yml" ]; then
  vars_files_args+=("--vars-file ../${iaas}/${environment_name}/config/secrets/${product}.yml")
fi

if [ "${deploy_type}" == "tile" ]; then
  if [ "${bypass_unused}" == true ]; then
    echo "Bypassing check for unused variables ... because there can be defaults that are not actually used"
  else
    echo "Checking for unused vars"
    bosh int --var-errs-unused ../${iaas}/${environment_name}/config/templates/${product}.yml ${vars_files_args[@]} > /dev/null
  fi
fi

echo "Checking for missing vars"
bosh int --var-errs ../${iaas}/${environment_name}/config/templates/${product}.yml ${vars_files_args[@]} > /dev/null
