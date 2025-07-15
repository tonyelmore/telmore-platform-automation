#!/bin/bash

# script color shortcuts (taken from fulc-tk colors.sh)
## below are for standard output in script
Color_Off='\033[0m'       # Text Reset
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;93m'       # Yellow
Cyan='\033[0;36m'         # Cyan

## Sets final output with the following:
##  - headers bolded with cyan color
##  - set spacing between header & key values
##  - values in yellow followed by newline
##  - "wide" adds more spacing
formattedOutput='\e[1;36m%-20s\e[m\t \e[93m%-s\e[m\n'
formattedOutputWide='\e[1;36m%-30s\e[m\t \e[93m%-s\e[m\n'

#####
# Functions
#####
function curlit() {

  curl_response=$(curl -s https://network.tanzu.vmware.com/$1 -X GET)
  if [ -z "$curl_response" ]; then
    fail "No response from curl: $1"
    exit 1
  else
    echo $curl_response
  fi
}

function select_product () {

  declare -a PIVNET_PRODUCTS=(ops-manager \
    stemcells-ubuntu-xenial \
    stemcells-ubuntu-jammy \
    stemcells-ubuntu-jammy-fips \
    p-concourse \
    platform-automation \
    elastic-runtime \
    pas-windows \
    vmware-nsx-t \
    p-isolation-segment \
    pivotal-mysql \
    pcf-app-autoscaler \
    p-rabbitmq \
    vmware-postgres-for-tas \
    p-redis \
    p-fim-addon \
    p-compliance-scanner \
    p-spring-cloud-services \
    p-healthwatch \
    credhub-service-broker \
    p-metric-store \
    apm \
    p-appdynamics \
    pivotal_single_sign-on_service \
    twistlock \
    p-ipsec-addon \
    p-clamav-addon \
    p-bosh-backup-and-restore \
    wavefront-nozzle)

  for index in ${!PIVNET_PRODUCTS[@]}; do
    printf "%4d: %s\n" $index ${PIVNET_PRODUCTS[$index]}
  done

  read -p 'Choose a product: ' product
  echo "You chose: ${PIVNET_PRODUCTS[$product]}"
  PRODUCT=${PIVNET_PRODUCTS[$product]}
}

function select_product_version () {

  select_product
  VERSIONS=$(curlit api/v2/products/$PRODUCT/releases | jq -r '.releases[].version' | sort -V)
  if [[ ${PRODUCT} == "p-concourse" ]]; then
    VERSIONS="7.9.1+LTS-T 7.11.2+LTS-T"
  fi
  declare -a PRODUCT_VERSIONS=(${VERSIONS})

  for index in ${!PRODUCT_VERSIONS[@]}; do
    printf "%4d: %s\n" $index ${PRODUCT_VERSIONS[$index]}
  done

  read -p 'Choose a version: ' version
  echo "You chose: ${PRODUCT_VERSIONS[$version]}"
  PRODUCT_VERSION=${PRODUCT_VERSIONS[$version]}
}


function select_product_file () {

  select_product_version

  echo "PRODUCT: $PRODUCT"
  echo "PRODUCT_VERSION: $PRODUCT_VERSION"

  PRODUCT_METADATA=$(curlit api/v2/products/$PRODUCT/releases | jq -r '.releases[] | select(.version == '\"$PRODUCT_VERSION\"') | "\(.description)|\(.became_ga_at)|\(.release_date)|\(.end_of_support_date)|\(.release_notes_url)|\(.id)"')
  
  PRODUCT_DESCRIPTION=$(echo $PRODUCT_METADATA | cut -d '|' -f1)
  PRODUCT_GA_DATE=$(echo $PRODUCT_METADATA | cut -d '|' -f2)
  PRODUCT_RELEASE_DATE=$(echo $PRODUCT_METADATA | cut -d '|' -f3)
  PRODUCT_EOGS_DATE=$(echo $PRODUCT_METADATA | cut -d '|' -f4)
  PRODUCT_RELEASE_NOTES=$(echo $PRODUCT_METADATA | cut -d '|' -f5)
  PRODUCT_ID=$(echo $PRODUCT_METADATA | cut -d '|' -f6)
  echo "PRODUCT_ID: $PRODUCT_ID"
  FILES=$(curlit api/v2/products/$PRODUCT/releases/$PRODUCT_ID/product_files | jq -r '.product_files[].aws_object_key' | cut -d '/' -f2)

  declare -a PRODUCT_FILES=(${FILES})

  for index in ${!PRODUCT_FILES[@]}; do
    printf "%4d: %s\n" $index ${PRODUCT_FILES[$index]}
  done

  read -p 'Choose a product file: ' file
  echo "You chose: ${PRODUCT_FILES[$file]}"
  PRODUCT_FILE=${PRODUCT_FILES[$file]}

  PRODUCT_DOWNLOAD=$(echo -e "om download-product --pivnet-api-token "'$PIVNET_TOKEN'" --pivnet-product-slug $PRODUCT --product-version $PRODUCT_VERSION --file-glob $PRODUCT_FILE --output-directory ./")

  PRODUCT_DOWNLOAD_S3_FILENAME=$(echo -e "om download-product --pivnet-api-token "'$PIVNET_TOKEN'" --pivnet-product-slug $PRODUCT --product-version $PRODUCT_VERSION --file-glob $PRODUCT_FILE --blobstore-bucket=anyvalue --output-directory ./")

  DEPENDENCIES=$(echo -e "curl -s https://network.tanzu.vmware.com/api/v2/products/$PRODUCT/releases/$PRODUCT_ID/dependencies \
| jq '.dependencies[].release \
| .product.slug + \" \" + .version'")
  
  STEMCELL_DEPENDENCIES=$(echo -e "curl -s https://network.tanzu.vmware.com/api/v2/products/$PRODUCT/releases/$PRODUCT_ID/dependencies \
| jq '.dependencies[] | \
select(.release.product.slug | \
startswith(\"stemcell\")) | \
.release.product.slug + \" \" + .release.version'")

  curlit api/v2/products/$PRODUCT/releases | jq -r '.releases[] | select(.version == '\"$PRODUCT_VERSION\"') '

}

select_product_file

ADDITIONAL_FILES=$(echo -e "\n$FILES")

printf '\n%.0s' {1,2}
printf "${Yellow}---------------${Color_Off}\n"
printf "${Yellow}   Tanzu API   ${Color_Off}\n"
printf "${Yellow}---------------${Color_Off}\n"
printf '\n%.0s' {1}
printf "${formattedOutput}" "PRODUCT_DESCRIPTION:" "$PRODUCT_DESCRIPTION"
printf "${formattedOutput}" "PRODUCT_GA_DATE:" "$PRODUCT_GA_DATE"
printf "${formattedOutput}" "PRODUCT_RELEASE_DATE:" "$PRODUCT_RELEASE_DATE"
printf "${formattedOutput}" "PRODUCT_EOGS_DATE:" "$PRODUCT_EOGS_DATE"
printf "${formattedOutput}" "PRODUCT_RELEASE_NOTES:" "$PRODUCT_RELEASE_NOTES"
printf "${formattedOutput}" "PRODUCT_ID:" "$PRODUCT_ID"
printf "${formattedOutput}" "PRODUCT_DOWNLOAD:" "$PRODUCT_DOWNLOAD"
printf "${formattedOutput}" "DOWNLOAD_FOR_S3:" "$PRODUCT_DOWNLOAD_S3_FILENAME"
printf "${formattedOutput}" "DEPENDENCIES:" "$DEPENDENCIES"
printf "${formattedOutput}" "STEMCELL_DEPENDENCIES:" "$STEMCELL_DEPENDENCIES"
printf '\n%.0s' {1}
printf "${formattedOutput}" "ADDITIONAL_PRODUCT_FILES:" "$ADDITIONAL_FILES"
printf '\n%.0s' {1,2}
