#!/bin/bash -e
if [ ! $# -eq 3 ]; then
  echo "Must supply iaas and environment source and target"
  exit 1
fi

iaas=$1
environment_source=$2
environment_target=$3
echo "Promoting from ${environment_source} to ${environment_target} on ${iaas}"

mkdir -p ../${iaas}/${environment_target}/config-director/vars
mkdir -p ../${iaas}/${environment_target}/config-director/secrets
mkdir -p ../${iaas}/${environment_target}/config-director/versions
mkdir -p ../${iaas}/${environment_target}/config-director/templates

mkdir -p ../${iaas}/${environment_target}/config/defaults
mkdir -p ../${iaas}/${environment_target}/config/vars
mkdir -p ../${iaas}/${environment_target}/config/secrets
mkdir -p ../${iaas}/${environment_target}/config/versions
mkdir -p ../${iaas}/${environment_target}/config/templates


cp -r ../${iaas}/${environment_source}/config-director/versions/* ../${iaas}/${environment_target}/config-director/versions/.
cp -r ../${iaas}/../${iaas}/${environment_source}/config-director/templates/* ../${iaas}/${environment_target}/config-director/templates/.
cp -r ../${iaas}/../${iaas}/${environment_source}/config-director/secrets/* ../${iaas}/${environment_target}/config-director/secrets/.

cp -r ../${iaas}/${environment_source}/pipeline.yml ../${iaas}/${environment_target}/pipeline.yml
cp -r ../${iaas}/${environment_source}/config/defaults/* ../${iaas}/${environment_target}/config/defaults/.
cp -r ../${iaas}/${environment_source}/config/versions/* ../${iaas}/${environment_target}/config/versions/.
cp -r ../${iaas}/${environment_source}/config/templates/* ../${iaas}/${environment_target}/config/templates/.
cp -r ../${iaas}/${environment_source}/config/secrets/* ../${iaas}/${environment_target}/config/secrets/.

# source ./common.sh
# pwd=$(pwd)
# pushd ../config-util
#   for product in ${products[@]}; do
#     go run main.go remove-duplicates -f ${pwd}/${environment_target}/config/defaults/${product}.yml \
#       -f ${pwd}/common/${product}.yml \
#       -f ${pwd}/${environment_target}/config/vars/${product}.yml
#   done

# popd

./validate-environment.sh ${iaas} ${environment_target}
