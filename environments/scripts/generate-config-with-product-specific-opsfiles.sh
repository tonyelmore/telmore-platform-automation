#!/bin/bash -e
: ${PIVNET_TOKEN?"Need to set PIVNET_TOKEN"}

if [ ! $# -eq 3 ]; then
  echo "Must supply iaas, foundation, and product name as arg"
  exit 1
fi

iaas=$1
foundation=$2
product=$3

# configfile="config.yml"
# if [ ! -f ${configfile} ]; then
#   echo "Must create ${configfile} and specify initial-foundation" 
#   exit 1
# fi
# foundation=$(bosh interpolate ${configfile} --path /initial-foundation)

echo "Generating configuration for product $product"
versionfile="../${iaas}/${foundation}/config/versions/$product.yml"
if [ ! -f ${versionfile} ]; then
  echo "Must create ${versionfile}"
  exit 1
fi
version=$(bosh interpolate ${versionfile} --path /product-version)
glob=$(bosh interpolate ${versionfile} --path /pivnet-file-glob)
slug=$(bosh interpolate ${versionfile} --path /pivnet-product-slug)

tmpdir=tile-configs/${product}-config
mkdir -p ${tmpdir}

om config-template --output-directory=${tmpdir} --pivnet-api-token ${PIVNET_TOKEN} --pivnet-product-slug  ${slug} --product-version ${version} --pivnet-file-glob ${glob}
wrkdir=$(find ${tmpdir}/${product} -name "${version}*")
if [ ! -f ${wrkdir}/product.yml ]; then
  echo "Something wrong with configuration as expecting ${wrkdir}/product.yml to exist"
  exit 1
fi

# -------- Process common opsfiles ------- #
mkdir -p ../${iaas}/opsfiles
ops_files="../${iaas}/opsfiles/${product}-operations"
touch ${ops_files}

ops_files_args=("")
while IFS= read -r var
do
  ops_files_args+=("-o ${wrkdir}/${var}")
done < "$ops_files"

# -------- Process foundation specific opsfiles ------- #
mkdir -p ../${iaas}/${foundation}/opsfiles
ops_files="../${iaas}/${foundation}/opsfiles/${product}-operations"
touch ${ops_files}

ops_files_args=("")
while IFS= read -r var
do
  if [[ ${var::1} == "-" ]]; then
    delete_arg="-o ${wrkdir}/${var:1}"
    ops_files_args=( "${ops_files_args[@]/${delete_arg}}")
  else
    ops_files_args+=("-o ${wrkdir}/${var}")
  fi
done < "$ops_files"

# -------- Create template by applying opsfiles to product file ------ #
set -eux
mkdir -p ../${iaas}/${foundation}/config/templates
bosh int ${wrkdir}/product.yml ${ops_files_args[@]} > ../${iaas}/${foundation}/config/templates/${product}.yml
set +eux
# ------ Create Defaults file ------ #
mkdir -p ../${iaas}/${foundation}/config/defaults
rm -rf ../${iaas}/${foundation}/config/defaults/${product}.yml
touch ../${iaas}/${foundation}/config/defaults/${product}.yml

# -------- Add defaults to default file ------- #
if [ -f ${wrkdir}/default-vars.yml ]; then
  cat ${wrkdir}/default-vars.yml >> ../${iaas}/${foundation}/config/defaults/${product}.yml
fi

if [ -f ${wrkdir}/errand-vars.yml ]; then
  vars=$(cat ${wrkdir}/errand-vars.yml | tr -d '[:space:]')
  if [[ "${vars}" != "" && "${vars}" != "{}" ]]; then
    cat ${wrkdir}/errand-vars.yml >> ../${iaas}/${foundation}/config/defaults/${product}.yml
  fi
fi

if [ -f ${wrkdir}/resource-vars.yml ]; then
  cat ${wrkdir}/resource-vars.yml >> ../${iaas}/${foundation}/config/defaults/${product}.yml
fi

mkdir -p ../${iaas}/${foundation}/config/secrets
touch ../${iaas}/${foundation}/config/secrets/${product}.yml

mkdir -p ../${iaas}/${foundation}/config/vars
touch ../${iaas}/${foundation}/config/vars/${product}.yml

mkdir -p ../${iaas}/common
touch ../${iaas}/common/${product}.yml
