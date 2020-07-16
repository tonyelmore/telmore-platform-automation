#!/bin/bash -e
if [ ! $# -eq 1 ]; then
  echo "Must supply environment"
  exit 1
fi

environment=$1
echo "Validating ${environment}"
source ./common.sh

./validate-opsman-config.sh ${environment}
for product in ${products[@]}; do
  ./validate-config.sh ${product} ${environment}
done

./validate-config.sh clamav ${environment}
./validate-config.sh os-conf ${environment}
