#!/bin/bash -e
if [ ! $# -eq 2 ]; then
  echo "Must supply product name as arg and environment"
  exit 1
fi

product=$1
environment_name=$2
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
  vars_files_args+=("--vars-file ${environment_name}/config/versions/${product}.yml")
fi
if [ -f "common/${product}.yml" ]; then
  vars_files_args+=("--vars-file common/${product}.yml")
fi
if [ -f "${environment_name}/config/vars/${product}.yml" ]; then
  vars_files_args+=("--vars-file ${environment_name}/config/vars/${product}.yml")
fi
if [ -f "${environment_name}/config/secrets/${product}.yml" ]; then
  vars_files_args+=("--vars-file ${environment_name}/config/secrets/${product}.yml")
fi

bosh int --var-errs-unused ${environment_name}/config/templates/${product}.yml ${vars_files_args[@]} > /dev/null

if [ -f "${environment_name}/config/defaults/${product}.yml" ]; then
  vars_files_args+=("--vars-file ${environment_name}/config/defaults/${product}.yml")
fi
bosh int --var-errs ${environment_name}/config/templates/${product}.yml ${vars_files_args[@]} > /dev/null
