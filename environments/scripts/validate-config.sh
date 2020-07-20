#!/bin/bash -e
if [ ! $# -eq 3 ]; then
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
  bosh int --var-errs-unused ../${iaas}/${environment_name}/config/templates/${product}.yml ${vars_files_args[@]} > /dev/null
fi

if [ -f "../${iaas}/${environment_name}/config/defaults/${product}.yml" ]; then
  vars_files_args+=("--vars-file ../${iaas}/${environment_name}/config/defaults/${product}.yml")
fi
bosh int --var-errs ../${iaas}/${environment_name}/config/templates/${product}.yml ${vars_files_args[@]} > /dev/null
