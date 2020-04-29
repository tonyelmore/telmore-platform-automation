#!/bin/bash -e

if [ ! $# -eq 2 ]; then
  echo "Must supply iaas and environment name as arg"
  exit 1
fi

iaas=$1
environment_name=$2

echo "Validating configuration for opsman"

touch ../${iaas}/${environment_name}/config-director/vars/infra.yml
touch ../${iaas}/${environment_name}/config-director/vars/opsman.yml
touch ../${iaas}/${environment_name}/config-director/secrets/opsman.yml

bosh int --var-errs --var-errs-unused ../${iaas}/${environment_name}/config-director/templates/opsman.yml \
  --vars-file ../${iaas}/common-director/opsman.yml \
  --vars-file ../${iaas}/${environment_name}/config-director/vars/infra.yml \
  --vars-file ../${iaas}/${environment_name}/config-director/vars/opsman.yml \
  --vars-file ../${iaas}/${environment_name}/config-director/secrets/opsman.yml


echo "Validating configuration for director"

touch ../${iaas}/${environment_name}/config-director/vars/director.yml
touch ../${iaas}/${environment_name}/config-director/secrets/director.yml

bosh int --var-errs --var-errs-unused ../${iaas}/${environment_name}/config-director/templates/director.yml \
    --vars-file ../${iaas}/common-director/director.yml \
    --vars-file ../${iaas}/${environment_name}/config-director/vars/infra.yml \
    --vars-file ../${iaas}/${environment_name}/config-director/vars/director.yml \
    --vars-file ../${iaas}/${environment_name}/config-director/secrets/director.yml
