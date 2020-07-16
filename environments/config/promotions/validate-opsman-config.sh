#!/bin/bash -e
if [ ! $# -eq 1 ]; then
  echo "Must supply environment as arg"
  exit 1
fi

environment_name=$1
echo "Validating configuration for opsman"

touch ${environment_name}/config-director/vars/infra.yml
touch ${environment_name}/config-director/vars/opsman.yml
touch ${environment_name}/config-director/secrets/opsman.yml

bosh int --var-errs --var-errs-unused ${environment_name}/config-director/templates/opsman.yml \
  --vars-file common-director/opsman.yml \
  --vars-file ${environment_name}/config-director/vars/infra.yml \
  --vars-file ${environment_name}/config-director/vars/opsman.yml \
  --vars-file ${environment_name}/config-director/secrets/opsman.yml > /dev/null


echo "Validating configuration for director"

touch ${environment_name}/config-director/vars/director.yml
touch ${environment_name}/config-director/secrets/director.yml

bosh int --var-errs --var-errs-unused ${environment_name}/config-director/templates/director.yml \
    --vars-file common-director/director.yml \
    --vars-file ${environment_name}/config-director/vars/infra.yml \
    --vars-file ${environment_name}/config-director/vars/director.yml \
    --vars-file ${environment_name}/config-director/secrets/director.yml > /dev/null
