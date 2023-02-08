#!/bin/bash -e

# set -x

export IAAS="vsphere"

OPSMAN_VERSION="2.10.39"
TOOLKIT_IMAGE_VERSION="5.0.21"
STEMCELL_VERSION="621.236"
CONCOURSE_VERSION="7.4.5"


OM_GLOB_EXTENSION="yml"
if [ ${IAAS} == "vsphere" ]; then 
  OM_GLOB_EXTENSION="ova"
fi

OM_GLOB="*${IAAS}*.${OM_GLOB_EXTENSION}"

STEMCELL_GLOB="*${IAAS}*.tgz"
if [ ${IAAS} == "aws" ]; then
  STEMCELL_GLOB="light*${IAAS}*.tgz"
fi

# Opsman
mkdir -p downloaded-resources/opsman-image/${IAAS}
pivnet dlpf --product-slug='ops-manager' --release-version=${OPSMAN_VERSION} --glob="${OM_GLOB}" --download-dir='downloaded-resources/opsman-image/'${IAAS}

# Platform Automation Toolkit
pivnet dlpf --product-slug='platform-automation' --release-version=${TOOLKIT_IMAGE_VERSION} --glob='*image*.tgz' --download-dir='downloaded-resources/platform-automation-image'

# Stemcell
mkdir -p downloaded-resources/stemcells/${IAAS}
pivnet dlpf --product-slug='stemcells-ubuntu-xenial' --release-version=${STEMCELL_VERSION} --glob="${STEMCELL_GLOB}" --download-dir='downloaded-resources/stemcells/'${IAAS}

# Concourse required releases
mkdir -p downloaded-resources/releases/${CONCOURSE_VERSION}
pivnet dlpf --product-slug='p-concourse' --release-version=${CONCOURSE_VERSION}' Platform Automation' --glob='*.tgz' --download-dir='downloaded-resources/releases/'${CONCOURSE_VERSION}
mkdir -p downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment
tar -xf downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment*.tgz -C downloaded-resources/releases/${CONCOURSE_VERSION}/concourse-bosh-deployment