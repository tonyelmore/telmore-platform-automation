#!/bin/bash 

set -e

# TODO: pivnet download opsmanager

if [ "$#" -lt 1 ]; then
  echo "usage: `basename "$0"` [environment name]"
  exit 1
fi

foundation=$1

secrets_folder=/Volumes/Keybase/private/tonyelmore/dev/telmore/environments/azure/terraforming/secrets/${foundation}
workspace=${PWD}/opsman_creation/${foundation}

docker run -it \
    -v "${workspace}":/workspace \
    -v "${secrets_folder}":/secrets \
    cloudfoundry/platform-automation:4.3.2 \
    p-automator create-vm \
        --config "/workspace/ops-manager.yml" \
        --image-file "/workspace/ops-manager-azure-2.8.2-build.203.yml"  \
        --state-file /workspace/opsman-state.yml \
        --vars-file /secrets/output.json


#        --vars-file /secrets/creds.yml


# This was the original
# docker run -it -v $HOME/workspace/afc_terraforming:/workspace platform-automation-image \
#     p-automator create-vm \
#         --config "/workspace/opsman_creation/sandbox/ops-manager.yml" \
#         --image-file "/workspace/opsman_creation/ops-manager-azure-2.8.2-build.203.yml"  \
#         --state-file /workspace/secrets/sandbox/opsman-state.yml \
#         --vars-file /workspace/secrets/sandbox/output.json \
#         --vars-file /workspace/secrets/sandbox/creds.yml
        
# Use this to just start the platform-automation image 
# docker run -it \
#     -v "${workspace}":/workspace \
#     -v "${secrets_folder}":/secrets \
#     cloudfoundry/platform-automation:4.3.2 \
#     bin/bash
