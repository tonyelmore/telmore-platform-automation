#!/bin/bash
 
set -eu
 
function setup {
 
  EMAIL_DIR=$(mktemp -d)
 
  DIR=$(mktemp -d)
  pushd ${DIR}
 
  PIVNET_CLI="pivnet"
  JQ_CMD="jq"
  YQ_CMD="yq"
  GIT_CMD="git"
 
  echo "" > ${EMAIL_DIR}/emailbody.txt
  CONFIG="version-file-repository"
  PRODUCT_FOUND="false"
  PROCESSING_STEMCELLS=false
 
  # $PIVNET_CLI --version
  # $JQ_CMD --version
  # $YQ_CMD --version
  # $GIT_CMD --version
 
  REPO="repository"
  
  $PIVNET_CLI login --api-token=$PIVNET_TOKEN  
 
}
 
function get-azure-file {
  export azure_container="$(om interpolate -s --config ${REPO}/${product} --path /blobstore-bucket | head -n1)"
  export blobfile="$(az storage blob list \
                      --account-name ${AZURE_ACCOUNT_NAME} \
                      --account-key ${AZURE_ACCOUNT_KEY} \
                      -c ${azure_container} \
                      | $JQ_CMD '.[] | select(.name | test("'${product_slug}','${patch_version}'")) | .name' -r)"
}
 
function put-azure-file {
  echo "uploading ${full_filename} to ${azure_container}" 
  az storage blob upload \
    --account-name ${AZURE_ACCOUNT_NAME} \
    --account-key ${AZURE_ACCOUNT_KEY} \
    -c ${azure_container} \
    -f ${full_filename} \
    -n ${filename}
}
 
function get-gcp-file {
  echo "Function not implemented"
}
 
function put-gcp-file {
  echo "Function not implemented"
}
 
function get-aws-file {
  echo "Function not implemented"
}
 
function put-aws-file {
  echo "Function not implemented"
}
    
function process-product {
  product=$1
 
  print-to-console "Processing ${product}"
 
  product_version="$(om interpolate -s --config ${REPO}/${product} --path /product-version | head -n1)"
  product_slug="$(om interpolate -s --config ${REPO}/${product} --path /pivnet-product-slug | head -n1)"
  product_glob="$(om interpolate -s --config ${REPO}/${product} --path /pivnet-file-glob | head -n1)"
  product_version_family=$product_version
 
  if [ "$PROCESSING_STEMCELLS" = true ]; then
    if [[ $product_version =~ ^[0-9]+\. ]]; then
     product_version_family="${BASH_REMATCH[0]}"
    fi
  else
    if [[ $product_version =~ ^[0-9]+\.[0-9]+ ]]; then
     product_version_family="${BASH_REMATCH[0]}"
    fi
  fi
  
  print-to-console-debug "PIVNET_CLI COMMAND WITH THIS VERSION FAMILY ->${product_version_family}"
  patch_version="$( $PIVNET_CLI releases -p ${product_slug} --format json | $JQ_CMD '[.[] | select(.version | test("'${product_version_family}'"))] [0].version ' -r )"
  #patch_version="$( $PIVNET_CLI releases -p ${product_name} --format json | $JQ_CMD '[.[] | select(.availability=="All Users") | select(.version | test("'${product_version_family}'"))] [0].version ' -r )"
  
  get-${IAAS}-file
 
  if [ -z "$blobfile" ]; then
    print-to-console "The product file for ${product_slug} version ${patch_version} is not found.  Downloading product now"
 
    tmpdir=$(mktemp -d)
    # om download-product --config secrets/${product} \
    #   --product-version ${patch_version} \
    #   --output-directory ${tmpdir}
 
    # With the blobstore-bucket being set, the file name will be correct
    om download-product \
      --source=pivnet \
      --pivnet-api-token ${PIVNET_TOKEN} \
      --blobstore-bucket ${azure_container} \
      --file-glob ${product_glob} \
      --pivnet-product-slug ${product_slug} \
      --product-version ${patch_version} \
      --output-directory ${tmpdir}

        full_filename=$(ls ${tmpdir}/\[*\]${product_glob})
 
    if [ -z "$full_filename" ]; then
      build-email-message "Something went wrong with the download - possibly EULA needs to be accepted"
      return
    fi
 
    filename=$(basename $full_filename)
 
    put-${IAAS}-file
    
    rm -r ${tmpdir}
 
    build-email-message "New product uploaded to blobstore.  Product ${product} - Version ${patch_version}"
 
  else
    print-to-console "The product file for ${product_slug} version ${patch_version} is already in azure blob store... skipping."
  fi
  print-to-console-debug "PROCESSING STEMCELLS? - $PROCESSING_STEMCELLS"
  if [ "$PROCESSING_STEMCELLS" = true ]; then
    update-stemcell-version-file ${product} ${patch_version}
  else
    update-version-file ${product} ${patch_version}
    #gen-validate ${product}
  fi
 
}
 
function update-version-file {
  print-to-console-debug "Process version file now $1 for patch version $2"
 
  product=$1
  PATCH_VERSION=$2
  #product_name="$(om interpolate -s --config ${REPO}/${product} --path /name | head -n1)"
  CURRENT_VERSION="$(om interpolate -s --config ${REPO}/${product} --path /product-version)"
  print-to-console-debug "processing product ${product} for ${PATCH_VERSION}"
 
  # Another Edit - make sure the major version is the same and the only change is the patch veersion number
  #print-to-console-debug "Update the version file"
  #sed -i "s/^product-version.*/product-version: ${PATCH_VERSION}/g"  ${REPO}/${product}
  print-to-console-debug "Update the versions-available file"
  if [[ ${CURRENT_VERSION} != ${PATCH_VERSION} ]]; then
    echo "${product} - Current:${CURRENT_VERSION} - Available:${PATCH_VERSION}" >> ${REPO}/auto-patching/TAS/versions-available.txt
  fi
  print-to-console-debug "Handle Version File Updates -- End"
}
 
function build-email-message {
  msg=$1
  print-to-console ${msg}
  echo ${msg} >> ${EMAIL_DIR}/emailbody.txt
  echo " " >> ${EMAIL_DIR}/emailbody.txt
}
 
function print-to-console {
  echo ${1}
}
function print-to-console-debug {
  if [[ ${DEBUG} = true ]]; then
    echo "----$(tput setaf 2)DEBUG ${1} $(tput sgr0)----"
  fi
}
 
function update-stemcell-version-file {
  product=$1
  STEMCELL_VERSION=$2
  
  print-to-console-debug "processing product ${product} for stemcell ${STEMCELL_VERSION}"
    
  PRODUCT_SUPPORTS_STEMCELL=false
  check-stemcell-support ${product} ${STEMCELL_VERSION}
 
  # Another Edit - make sure the major version is the same and the only change is the patch veersion number
  if [[ ${PRODUCT_SUPPORTS_STEMCELL} = true ]]; then
    print-to-console-debug "Update the version file - ${product}"
    sed -i "s/^product-version.*/product-version: \"${STEMCELL_VERSION}\"/g"  ${REPO}/${product}
    #sed -i -e "$ a product-version: \"${STEMCELL_VERSION}\""  ${REPO}/${PRODUCT_FILE_LOCATION}/${product_name}/version-stemcell.yml
  fi
 
  print-to-console-debug "Handle Stemcell Updates -- End"
}
 
function check-stemcell-support {
  temp_product=${1/version-stemcell/version}
  stemcell_version=$2
  product_slug="$(om interpolate -s --config ${REPO}/${temp_product} --path /pivnet-product-slug | head -n1)"
 
  # build output file that will update proper version file - but only if product supports it (for stemcells) 
  # Get list of stemcells for product $product-name
  PRODUCT_VERSION=$($YQ_CMD r ${REPO}/${temp_product} 'product-version')
  print-to-console-debug "check-stemcell-support ${temp_product} - version is ${PRODUCT_VERSION}"
  print-to-console-debug "product_slug is ${product_slug}"
 
  PRODUCT_STEMCELLS=$( $PIVNET_CLI rds -p ${product_slug} -r ${PRODUCT_VERSION} --format json | \
                        $JQ_CMD '.[] | select(.release.product.slug | test("stemcells-ubuntu-xenial")) | .release.version' -r)
  print-to-console-debug "PRODUCT_STEMCELLS ==> ${PRODUCT_STEMCELLS}"
 
  if [[ "${PRODUCT_STEMCELLS[@]}" =~ "${stemcell_version}" ]]; then
    PRODUCT_SUPPORTS_STEMCELL=true
  fi
}
 
function gen-validate {
  product_name=$1
  env_name="eus-sdbx"
 
  ${REPO}/environments/scripts/generate-config.ps1 azure ${env_name} ${product_name}
  VALIDATE_RESPONSE=${REPO}/environments/scripts/validate-config.ps1 azure ${env_name} ${product_name}
  echo "THIS IS THE RESPONSE ----> "$VALIDATE_RESPONSE
}
 
function clone-repo {
  git clone https://${VSTS_USER_NAME}:${VSTS_PAT}@${AUTOMATION_GIT_URL} ${REPO} -q
  pushd ${REPO} 
  git checkout ${AUTOMATION_GIT_BRANCH} 
  popd
}
 
function make-branch-and-commit {
  
  cd ${REPO}
  git config user.name "Patching"
  git config user.email test@navyfederal.org
 
  TIME_ST=`date +%s` 
  DATE_ST=`date +%D`
  BRANCH_NAME=autopatch-${TIME_ST}
 
  COMMIT_MESSAGE="Stemcell auto-patching - ${DATE_ST}"
  
  BRANCH_PUSHED=false
  if [[ -n $(git status --porcelain) ]]; then
    git checkout -b "$BRANCH_NAME" -q
    git add -A
    git commit -m "$COMMIT_MESSAGE" --allow-empty
    B64_PAT=$(echo ":${VSTS_PAT}" | base64)
    git -c http.extraHeader="Authorization: Basic ${B64_PAT}" push --set-upstream origin ${BRANCH_NAME} -q
    BRANCH_PUSHED=true
  fi
}
 
function create-pr {
  if [[ ${BRANCH_PUSHED} == "false" ]]; then
    return
  fi
 
  ORG=https://dev.azure.com/nfcudevlabs
  PROJECT_NAME="Cloud%20Platform%20Operations"
  REPOSITORY="platform-automation"
  SOURCE_BRANCH=${BRANCH_NAME}
  TITLE="Weekly-auto"
 
  # Get the Repository ID from the repository name
  REPOSITORY_ID=$(curl -s -u ${VSTS_USER_NAME}:${VSTS_PAT} ${ORG}/${PROJECT_NAME}/_apis/git/repositories | \
  $JQ_CMD '.value[] | select (.name == "'${REPOSITORY}'").id ' -r)
 
  # Create the Pull Request
  PR_DATA=$( $JQ_CMD -n \
            --arg source "refs/heads/${SOURCE_BRANCH}" \
            --arg target "refs/heads/master" \
            --arg title "${TITLE}-patch" \
            --arg description "Stemcell and Product Patching" \
            '{sourceRefName: $source, targetRefName: $target, title: $title, reviewers:
      [{"id": "07f68f93-f903-6e81-8128-3e29ee1a461e"},{"id": "a5c0da7e-d280-6380-a82e-4aafcbbc5760"},{ "id": "2c21e0d0-4ed1-683e-97c4-28b1cfbb534c"}], description: $description}' )
 
  print-to-console-debug "------------------- Pull Request Data ------------------- "
  print-to-console-debug $PR_DATA | $JQ_CMD .
 
  PR_CREATE_OUTPUT=$(curl -u ${VSTS_USER_NAME}:${VSTS_PAT} \
                          -H 'Content-Type: application/json' \
                          -X POST \
                          -d "${PR_DATA}" \
                          ${ORG}/${PROJECT_NAME}/_apis/git/repositories/${REPOSITORY_ID}/pullrequests?api-version=5.0)
 
  print-to-console-debug "------------------- Pull Request Results ------------------- "
  print-to-console-debug $PR_CREATE_OUTPUT | $JQ_CMD .
 
  SOURCE_COMMIT=$(echo $PR_CREATE_OUTPUT | $JQ_CMD '.lastMergeSourceCommit.commitId' -r)
  TARGET_COMMIT=$(echo $PR_CREATE_OUTPUT | $JQ_CMD '.lastMergeTargetCommit.commitId' -r)
  print-to-console-debug "Source commit ${SOURCE_COMMIT}"
  print-to-console-debug "Target commit ${TARGET_COMMIT}"
}
 

 function process-products {
  print-to-console "Processing products"
 
  CONFIG_FILES=$(cd ${REPO} && find $CONFIG_FILES_PATH -type f -name ${PRODUCT_FILE_PREFIX}.yml -follow)
  for config_file in ${CONFIG_FILES}
  do
    print-to-console-debug "${config_file}"
    process-product ${config_file}
  done
}
 
function process-stemcells {
  print-to-console "Processing stemcells"
  PROCESSING_STEMCELLS=true
  CONFIG_FILES=$(cd ${REPO} && find $CONFIG_FILES_PATH -type f -name ${STEMCELL_FILE_PREFIX}.yml -follow)
  for config_file in ${CONFIG_FILES}
  do
    print-to-console-debug ${config_file}
    process-product ${config_file}
  done
}
 
function cleanup-email {
  if [ $PRODUCT_FOUND == "true" ]; then
    cat ${REPO}/$INSTRUCTION_FILE >> ${EMAIL_DIR}/pivnet-upload-results.txt
    echo " " >> ${EMAIL_DIR}/pivnet-upload-results.txt
    cat  ${EMAIL_DIR}/emailbody.txt >> ${EMAIL_DIR}/pivnet-upload-results.txt
  else
    rm ${EMAIL_DIR}/pivnet-upload-results.txt > /dev/null
    touch ${EMAIL_DIR}/pivnet-upload-results.txt
  fi
}
 
setup
clone-repo
echo "Available Products in Blobstore" > ${REPO}/auto-patching/TAS/versions-available.txt
process-products
process-stemcells
make-branch-and-commit
# Add error checking to see if previous function was successful or not. If not, don't call create-pr
create-pr
# cleanup-email
 
print-to-console-debug cleanup ${DIR}
popd
 
print-to-console "Autopatching complete"