.DEFAULT_GOAL :- help

help:
	@echo "This will create and opsman and director and deploy concourse"

check-env-vars:
	TOOLKIT_IMAGE_VERSION="4.3.4"
	export IAAS="aws"

	export CONCOURSE_URL="$(terraform output -state=../paving-aws-concourse/terraform.tfstate concourse_url)"

	: ${OM_USERNAME?"Need to set OM_USERNAME ... Please run '. ./0-set-env.sh'"}
	: ${OM_PASSWORD?"Need to set OM_PASSWORD ... Please run '. ./0-set-env.sh'"}
	: ${OM_DECRYPTION_PASSPHRASE?"Need to set OM_DECRYPTION_PASSPHRASE ... Please run '. ./0-set-env.sh'"}
	: ${ADMIN_USERNAME?"Need to set ADMIN_USERNAME ... Please run '. ./0-set-env.sh'"}
	: ${ADMIN_PASSWORD?"Need to set ADMIN_PASSWORD ... Please run '. ./0-set-env.sh'"}
	: ${CONCOURSE_URL?"Need to set CONCOURSE_URL ... Please set as an environment variable"}

get-terraform-output:
	echo "*********** Getting terraform output..."
	terraform output -state=../paving-aws-concourse/terraform.tfstate stable_config > terraform-outputs.yml

docker-import: check-env-vars
	echo "*********** Checking for existing docker image for platform automation toolkit"
	if [[ "$(docker images -q platform-automation-toolkit-image:${TOOLKIT_IMAGE_VERSION} 2> /dev/null)" == "" ]]; then
	    echo "*********** Image not found... importing docker image"
	    docker import downloaded-resources/platform-automation-image/platform-automation-image-${TOOLKIT_IMAGE_VERSION}.tgz platform-automation-toolkit-image:${TOOLKIT_IMAGE_VERSION}
	fi

create-opsman: docker-import
	echo "*********** Creating opsman"
	docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-toolkit-image:${TOOLKIT_IMAGE_VERSION} \
	  p-automator create-vm \
	    --config config-files/opsman-config.yml \
	    --image-file downloaded-resources/opsman-image/ops-manager-aws*.yml \
	    --vars-file terraform-outputs.yml

	export OM_TARGET="$(om interpolate -c terraform-outputs.yml --path /ops_manager_dns)"

	echo "*********** Sleep for 2 min to allow opsman vm time to initialize"
	sleep 120

config-auth: check-env-vars
	echo "*********** Configuring basic authentication"
	om --env config-files/env.yml configure-authentication \
	   --username ${OM_USERNAME} \
	   --password ${OM_PASSWORD} \
	   --decryption-passphrase ${OM_DECRYPTION_PASSPHRASE}

config-director: check-env-vars
	echo "*********** Configuring Director"
	om --env config-files/env.yml configure-director \
	   --config config-files/director-config.yml \
	   --vars-file terraform-outputs.yml

apply-director-changes:
	echo "*********** Applying Changes for Director configuration"
	om --env config-files/env.yml apply-changes \
	   --skip-deploy-products

get-ssh-key:
	om interpolate \
	  -c terraform-outputs.yml \
	  --path /ops_manager_ssh_private_key > /tmp/private_key

	eval "$(om --env config-files/env.yml bosh-env --ssh-private-key=/tmp/private_key)"

upload-releases: check-env-vars
	echo "*********** Uploading releases"
	bosh upload-release downloaded-resources/releases/concourse-bosh-release*.tgz
	bosh upload-release downloaded-resources/releases/bpm-release*.tgz
	bosh upload-release downloaded-resources/releases/postgres-release*.tgz
	bosh upload-release downloaded-resources/releases/uaa-release*.tgz
	bosh upload-release downloaded-resources/releases/credhub-release*.tgz
	bosh upload-release downloaded-resources/releases/backup-and-restore-sdk-release*.tgz

	echo "*********** Uploading stemcell"
	bosh upload-stemcell downloaded-resources/stemcells/*stemcell*.tgz

	credhub-set: check-env-vars
	credhub set \
 	  -n /p-bosh/concourse/local_user \
	  -t user \
 	  -z "${ADMIN_USERNAME}" \
 	  -w "${ADMIN_PASSWORD}"

deploy-concourse:
	echo "*********** Deploying concourse"
	bosh -n -d concourse deploy downloaded-resources/concourse-bosh-deployment/cluster/concourse.yml \
	  -o downloaded-resources/concourse-bosh-deployment/cluster/operations/privileged-http.yml \
	  -o downloaded-resources/concourse-bosh-deployment/cluster/operations/privileged-https.yml \
	  -o downloaded-resources/concourse-bosh-deployment/cluster/operations/basic-auth.yml \
	  -o downloaded-resources/concourse-bosh-deployment/cluster/operations/tls-vars.yml \
	  -o downloaded-resources/concourse-bosh-deployment/cluster/operations/tls.yml \
	  -o downloaded-resources/concourse-bosh-deployment/cluster/operations/uaa.yml \
	  -o downloaded-resources/concourse-bosh-deployment/cluster/operations/credhub-colocated.yml \
	  -o downloaded-resources/concourse-bosh-deployment/cluster/operations/offline-releases.yml \
	  -o downloaded-resources/concourse-bosh-deployment/cluster/operations/backup-atc-colocated-web.yml \
	  -o downloaded-resources/concourse-bosh-deployment/cluster/operations/secure-internal-postgres.yml \
	  -o downloaded-resources/concourse-bosh-deployment/cluster/operations/secure-internal-postgres-bbr.yml \
	  -o downloaded-resources/concourse-bosh-deployment/cluster/operations/secure-internal-postgres-uaa.yml \
	  -o downloaded-resources/concourse-bosh-deployment/cluster/operations/secure-internal-postgres-credhub.yml \
	  -o config-files/operations.yml \
	  -l <(om interpolate --config config-files/vars.yml --vars-env CONCOURSE --vars-file terraform-outputs.yml) \
	  -l downloaded-resources/concourse-bosh-deployment/versions.yml

	export CONCOURSE_CREDHUB_SECRET="$(credhub get -n /p-bosh/concourse/credhub_admin_secret -q)"
	export CONCOURSE_CA_CERT="$(credhub get -n /p-bosh/concourse/atc_tls -k ca)"

	unset CREDHUB_SECRET CREDHUB_CLIENT CREDHUB_SERVER CREDHUB_PROXY CREDHUB_CA_CERT

	echo "*********** Logging in to concourse credhub"
	credhub login \
	  --server "https://${CONCOURSE_URL}:8844" \
	  --client-name=credhub_admin \
	  --client-secret="${CONCOURSE_CREDHUB_SECRET}" \
	  --ca-cert "${CONCOURSE_CA_CERT}"

	echo "*********** Downloading fly CLI"
	curl "https://${CONCOURSE_URL}/api/v1/cli?arch=amd64&platform=${PLATFORM}" \
	  --output fly \
	  --cacert <(echo "${CONCOURSE_CA_CERT}")
	chmod +x fly

	echo "*********** Logging in to concourse"
	fly -t ci login \
	  -c "https://${CONCOURSE_URL}" \
	  -u "${ADMIN_USERNAME}" \
	  -p "${ADMIN_PASSWORD}" \
	  --ca-cert <(echo "${CONCOURSE_CA_CERT}")

run-all: get-terraform-output create-opsman config-auth config-director apply-director-changes get-ssh-key upload-releases check-env-vars deploy-concourse

