#!/bin/bash -e

# set -x

export IAAS="azure"

OPSMAN_VERSION="2.10.16"
TOOLKIT_IMAGE_VERSION="5.0.17"
STEMCELL_VERSION="621.136"
CONCOURSE_VERSION="6.7.6"


# Opsman
# This will not work for vSphere - because it isn't a yml - fix that when get a chance
mkdir -p downloaded-resources/opsman-image/${IAAS}
pivnet dlpf --product-slug='ops-manager' --release-version=${OPSMAN_VERSION} --glob='*'${IAAS}'*.yml' --download-dir='downloaded-resources/opsman-image/'${IAAS}

# Platform Automation Toolkit
pivnet dlpf --product-slug='platform-automation' --release-version=${TOOLKIT_IMAGE_VERSION} --glob='*image*.tgz' --download-dir='downloaded-resources/platform-automation-image'

# Stemcell
# This will not work for AWS (heavy vs light) - fix that when get a chance
mkdir -p downloaded-resources/stemcells/${IAAS}
pivnet dlpf --product-slug='stemcells-ubuntu-xenial' --release-version=${STEMCELL_VERSION} --glob='*'${IAAS}'*.tgz' --download-dir='downloaded-resources/stemcells/'${IAAS}

# Concourse required releases
mkdir -p downloaded-resources/releases/${CONCOURSE_VERSION}
pivnet dlpf --product-slug='p-concourse' --release-version=${CONCOURSE_VERSION}' Platform Automation' --glob='*.tgz' --download-dir='downloaded-resources/releases/'${CONCOURSE_VERSION}
mkdir -p downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment
tar -xf downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment*.tgz -C downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment