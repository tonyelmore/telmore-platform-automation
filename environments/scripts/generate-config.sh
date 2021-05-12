#!/bin/bash -e
: ${PIVNET_TOKEN?"Need to set PIVNET_TOKEN"}

if [ ! $# -eq 2 ]; then
  echo "Must supply iaas and product name as arg"
  exit 1
fi

iaas=$1
product=$2

# ---- Get initial foundation from config.yml
configfile="config.yml"
if [ ! -f ${configfile} ]; then
  echo "Must create ${configfile} and specify initial-foundation" 
  exit 1
fi
INITIAL_FOUNDATION=$(bosh interpolate ${configfile} --path=/initial-foundation)

# ---- Get version, glob, slug from version file
echo "Generating configuration for product $product"
versionfile="../${iaas}/${INITIAL_FOUNDATION}/config/versions/$product.yml"
if [ ! -f ${versionfile} ]; then
  echo "Must create ${versionfile}"
  exit 1
fi
version=$(bosh interpolate ${versionfile} --path=/product-version)
glob=$(bosh interpolate ${versionfile} --path=/pivnet-file-glob)
slug=$(bosh interpolate ${versionfile} --path=/pivnet-product-slug)

# ---- Execute om config-template 
tmpdir=tile-configs/${product}-config
mkdir -p ${tmpdir}

om config-template --output-directory=${tmpdir} --pivnet-api-token ${PIVNET_TOKEN} --pivnet-product-slug  ${slug} --product-version ${version} --pivnet-file-glob ${glob}

if [[ ${product} == "vmware-nsx-t" ]]; then
  if [[ ${version} == "3.2.2.2" ]]; then
    version="3.2.1707xxx"
  elif [[ ${version} == "3.2.2" ]]; then
    version="3.2.16xxx"
  fi
fi

wrkdir=$(find ${tmpdir}/${product} -name "${version}*")
if [ ! -f ${wrkdir}/product.yml ]; then
  echo "Something wrong with configuration as expecting ${wrkdir}/product.yml to exist"
  exit 1
fi

# ---- Create array of opsfiles to apply
mkdir -p ../${iaas}/opsfiles
ops_files="../${iaas}/opsfiles/${product}-operations"
touch ${ops_files}

ops_files_args=("")
while IFS= read -r var
do
  ops_files_args+=("-o ${wrkdir}/${var}")
done < "$ops_files"

# ---- Create template file from product.yml with applied opsfiles
mkdir -p ../${iaas}/${INITIAL_FOUNDATION}/config/templates
bosh int ${wrkdir}/product.yml ${ops_files_args[@]} > ../${iaas}/${INITIAL_FOUNDATION}/config/templates/${product}.yml

# ---- Set up for creation of defaults file
mkdir -p ../${iaas}/${INITIAL_FOUNDATION}/config/defaults
rm -rf ../${iaas}/${INITIAL_FOUNDATION}/config/defaults/${product}.yml
touch ../${iaas}/${INITIAL_FOUNDATION}/config/defaults/${product}.yml

# ---- Add default vars to defaults file
if [ -f ${wrkdir}/default-vars.yml ]; then
  vars=$(cat ${wrkdir}/default-vars.yml | tr -d '[:space:]')
  if [[ "${vars}" != "" && "${vars}" != "{}" ]]; then
    cat ${wrkdir}/default-vars.yml >> ../${iaas}/${INITIAL_FOUNDATION}/config/defaults/${product}.yml
  fi
fi

# ---- Add errands vars to defaults file
if [ -f ${wrkdir}/errand-vars.yml ]; then
  vars=$(cat ${wrkdir}/errand-vars.yml | tr -d '[:space:]')
  if [[ "${vars}" != "" && "${vars}" != "{}" ]]; then
    cat ${wrkdir}/errand-vars.yml >> ../${iaas}/${INITIAL_FOUNDATION}/config/defaults/${product}.yml
  fi
fi

# ---- Add resource vars to defaults file
if [ -f ${wrkdir}/resource-vars.yml ]; then
  vars=$(cat ${wrkdir}/resource-vars.yml | tr -d '[:space:]')
  if [[ "${vars}" != "" && "${vars}" != "{}" ]]; then
    cat ${wrkdir}/resource-vars.yml >> ../${iaas}/${INITIAL_FOUNDATION}/config/defaults/${product}.yml
  fi
fi

# ---- Ensure secrets file exists
mkdir -p ../${iaas}/${INITIAL_FOUNDATION}/config/secrets
touch ../${iaas}/${INITIAL_FOUNDATION}/config/secrets/${product}.yml

# ---- Ensure vars file exists
mkdir -p ../${iaas}/${INITIAL_FOUNDATION}/config/vars
touch ../${iaas}/${INITIAL_FOUNDATION}/config/vars/${product}.yml

# ---- Ensure common vars file exists
mkdir -p ../${iaas}/common
touch ../${iaas}/common/${product}.yml
