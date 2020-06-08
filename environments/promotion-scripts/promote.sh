#!/bin/bash -e
if [ ! $# -eq 2 ]; then
  echo "Must supply environment source and target"
  exit 1
fi

environment_source=$1
environment_target=$2
echo "Promoting from ${environment_source} to ${environment_target}"

mkdir -p ${environment_target}/config-director/vars
mkdir -p ${environment_target}/config-director/secrets
mkdir -p ${environment_target}/config-director/versions
mkdir -p ${environment_target}/config-director/templates

mkdir -p ${environment_target}/config/defaults
mkdir -p ${environment_target}/config/vars
mkdir -p ${environment_target}/config/secrets
mkdir -p ${environment_target}/config/versions
mkdir -p ${environment_target}/config/templates


cp -r ${environment_source}/config-director/versions/* ${environment_target}/config-director/versions/.
cp -r ${environment_source}/config-director/templates/* ${environment_target}/config-director/templates/.
cp -r ${environment_source}/config-director/secrets/* ${environment_target}/config-director/secrets/.

cp -r ${environment_source}/pipeline.yml ${environment_target}/pipeline.yml
cp -r ${environment_source}/config/defaults/* ${environment_target}/config/defaults/.
cp -r ${environment_source}/config/versions/* ${environment_target}/config/versions/.
cp -r ${environment_source}/config/templates/* ${environment_target}/config/templates/.
cp -r ${environment_source}/config/secrets/* ${environment_target}/config/secrets/.

source ./common.sh
pwd=$(pwd)
pushd ../config-util
  for product in ${products[@]}; do
    go run main.go remove-duplicates -f ${pwd}/${environment_target}/config/defaults/${product}.yml \
      -f ${pwd}/common/${product}.yml \
      -f ${pwd}/${environment_target}/config/vars/${product}.yml
  done

popd

./validate-environment.sh ${environment_target}
