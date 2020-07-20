#!/bin/bash -e
if [ ! $# -eq 2 ]; then
  echo "Must supply iaas and environment name as arg"
  exit 1
fi

iaas=$1
environment=$2

echo "Validating ${environment}"
source ./common.sh

./validate-opsman-config.sh ${iaas} ${environment}

for product in ${products[@]}; do
  ./validate-config.sh ${iaas} ${environment} ${product} 
done

for runtime-product in ${runtime-products[@]}; do
  ./validate-config.sh ${iaas} ${environment} ${runtime-product} 
done
