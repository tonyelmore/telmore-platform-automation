#!/bin/bash -e

# set -x

export IAAS="azure"
export PLATFORM="darwin"
TOOLKIT_IMAGE_VERSION="5.0.17"
CONCOURSE_VERSION="6.7.6"

echo "*********** Getting terraform output..."
# with Terraform v 0.14.3+ use "--raw" to ensure output is not JSON encoded
terraform output --raw -state=../paving-${IAAS}-concourse/terraform.tfstate stable_config > terraform-outputs-${IAAS}.yml

export CONCOURSE_URL="$(terraform output --raw -state=../paving-${IAAS}-concourse/terraform.tfstate concourse_url)"

: ${OM_USERNAME?"Need to set OM_USERNAME ... Please run '. ./0-set-env.sh'"}
: ${OM_PASSWORD?"Need to set OM_PASSWORD ... Please run '. ./0-set-env.sh'"}
: ${OM_DECRYPTION_PASSPHRASE?"Need to set OM_DECRYPTION_PASSPHRASE ... Please run '. ./0-set-env.sh'"}
: ${ADMIN_USERNAME?"Need to set ADMIN_USERNAME ... Please run '. ./0-set-env.sh'"}
: ${ADMIN_PASSWORD?"Need to set ADMIN_PASSWORD ... Please run '. ./0-set-env.sh'"}
: ${CONCOURSE_URL?"Need to set CONCOURSE_URL ... Please set as an environment variable"}

echo "*********** Checking for existing docker image for platform automation toolkit"
if [[ "$(docker images -q platform-automation-toolkit-image:${TOOLKIT_IMAGE_VERSION} 2> /dev/null)" == "" ]]; then
    echo "*********** Image not found... importing docker image"
    docker import downloaded-resources/platform-automation-image/platform-automation-image-${TOOLKIT_IMAGE_VERSION}.tgz platform-automation-toolkit-image:${TOOLKIT_IMAGE_VERSION}
fi


echo "*********** Creating opsman"

# copy iaas specific state file 
touch state-${IAAS}.yml
cp state-${IAAS}.yml state.yml

# find the correct image file
# Hack to look for only yml file ... old regex isn't working anymore
# IMAGE_FILE="$(find downloaded-resources/opsman-image/${IAAS}/*.{yml,ova,raw} 2>/dev/null | head -n1)"
IMAGE_FILE="$(find downloaded-resources/opsman-image/${IAAS}/*.yml 2>/dev/null | head -n1)"
echo $IMAGE_FILE

docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-toolkit-image:${TOOLKIT_IMAGE_VERSION} \
  om vm-lifecycle create-vm \
    --config config-files/${IAAS}/opsman-config.yml \
    --image-file "${IMAGE_FILE}" \
    --vars-file terraform-outputs-${IAAS}.yml
cp state.yml state-${IAAS}.yml

export OM_TARGET="$(om interpolate -c terraform-outputs-${IAAS}.yml --path /ops_manager_dns)"

echo "*********** Sleep for 2 min to allow opsman vm time to initialize"
sleep 120

echo "*********** Configuring basic authentication"
om --env config-files/env.yml configure-authentication \
   --username ${OM_USERNAME} \
   --password ${OM_PASSWORD} \
   --decryption-passphrase ${OM_DECRYPTION_PASSPHRASE}

echo "*********** Configuring Director"
om --env config-files/env.yml configure-director \
   --config config-files/${IAAS}/director-config.yml \
   --vars-file terraform-outputs-${IAAS}.yml

echo "*********** Applying Changes for Director configuration"
om --env config-files/env.yml apply-changes \
   --skip-deploy-products

om interpolate \
  -c terraform-outputs-${IAAS}.yml \
  --path /ops_manager_ssh_private_key > /tmp/private_key

eval "$(om --env config-files/env.yml bosh-env --ssh-private-key=/tmp/private_key)"

# Will return a non-error if properly targeted 
# TODO: check results !!!
bosh curl /info

echo "*********** Uploading releases"
bosh upload-release downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-release*.tgz
bosh upload-release downloaded-resources/releases/${CONCOURSE_VERSION}/bpm-release*.tgz
bosh upload-release downloaded-resources/releases/${CONCOURSE_VERSION}/postgres-release*.tgz
bosh upload-release downloaded-resources/releases/${CONCOURSE_VERSION}/uaa-release*.tgz
bosh upload-release downloaded-resources/releases/${CONCOURSE_VERSION}/credhub-release*.tgz
bosh upload-release downloaded-resources/releases/${CONCOURSE_VERSION}/backup-and-restore-sdk-release*.tgz

echo "*********** Uploading stemcell"
bosh upload-stemcell downloaded-resources/stemcells/${IAAS}/*.tgz

credhub set \
   -n /p-bosh/concourse/local_user \
   -t user \
   -z "${ADMIN_USERNAME}" \
   -w "${ADMIN_PASSWORD}"

echo "*********** Deploying concourse"
# I used to have "--vars-env CONCOURSE" ... but but doc no longer has it
bosh -n -d concourse deploy downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment/cluster/concourse.yml \
  -o downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment/cluster/operations/privileged-http.yml \
  -o downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment/cluster/operations/privileged-https.yml \
  -o downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment/cluster/operations/basic-auth.yml \
  -o downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment/cluster/operations/tls-vars.yml \
  -o downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment/cluster/operations/tls.yml \
  -o downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment/cluster/operations/uaa.yml \
  -o downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment/cluster/operations/credhub-colocated.yml \
  -o downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment/cluster/operations/offline-releases.yml \
  -o downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment/cluster/operations/backup-atc-colocated-web.yml \
  -o downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment/cluster/operations/secure-internal-postgres.yml \
  -o downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment/cluster/operations/secure-internal-postgres-bbr.yml \
  -o downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment/cluster/operations/secure-internal-postgres-uaa.yml \
  -o downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment/cluster/operations/secure-internal-postgres-credhub.yml \
  -o config-files/${IAAS}/operations.yml \
  -l <(om interpolate --config config-files/${IAAS}/vars.yml --vars-file terraform-outputs-${IAAS}.yml) \
  -l downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment/versions.yml

export CONCOURSE_CREDHUB_SECRET="$(credhub get -n /p-bosh/concourse/credhub_admin_secret -q)"
export CONCOURSE_CA_CERT="$(credhub get -n /p-bosh/concourse/atc_tls -k ca)"

unset CREDHUB_SECRET CREDHUB_CLIENT CREDHUB_SERVER CREDHUB_PROXY CREDHUB_CA_CERT

echo "*********** Logging in to concourse credhub"
credhub login \
  --server "https://${CONCOURSE_URL}:8844" \
  --client-name=credhub_admin \
  --client-secret="${CONCOURSE_CREDHUB_SECRET}" \
  --ca-cert "${CONCOURSE_CA_CERT}"


# set +x

