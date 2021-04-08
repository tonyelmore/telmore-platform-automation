#!/bin/bash -e
: ${PIVNET_TOKEN?"Need to set PIVNET_TOKEN"}

if [ ! $# -eq 2 ]; then
  echo "Must supply iaas and product name as arg"
  exit 1
fi

iaas=$1
product=$2

configfile="config.yml"
if [ ! -f ${configfile} ]; then
  echo "Must create ${configfile} and specify initial-foundation" 
  exit 1
fi
INITIAL_FOUNDATION=$(bosh interpolate ${configfile} --path /initial-foundation)

echo "Generating configuration for product $product"
versionfile="../${iaas}/${INITIAL_FOUNDATION}/config/versions/$product.yml"
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

mkdir -p ../${iaas}/opsfiles
ops_files="../${iaas}/opsfiles/${product}-operations"
touch ${ops_files}

ops_files_args=("")
while IFS= read -r var
do
  ops_files_args+=("-o ${wrkdir}/${var}")
done < "$ops_files"

mkdir -p ../${iaas}/${INITIAL_FOUNDATION}/config/templates
template_file="../${iaas}/${INITIAL_FOUNDATION}/config/templates/${product}.yml"
bosh int ${wrkdir}/product.yml ${ops_files_args[@]} > "${template_file}"

mkdir -p ../${iaas}/${INITIAL_FOUNDATION}/config/defaults
defaults_file="../${iaas}/${INITIAL_FOUNDATION}/config/defaults/${product}.yml"
rm -rf "${defaults_file}"
touch "${defaults_file}"

# All this logic because there are some default values that are not in the template
# So, this skips all of those
if [ -f ${wrkdir}/default-vars.yml ]; then
  skipnextline=false
  while read -r line
  do
    myvar=${line%%:*}

    if [ ${skipnextline} = true ]; then
      echo "  $line" >> "${defaults_file}"
      skipnextline=false
      continue
    fi

    if [ "${myvar}" == "nfs_server_blobstore_internal_access_rules" ]; then
      echo "$line" >> "${defaults_file}"
      skipnextline=true
      continue
    fi

    if grep -q "(($myvar))" "$template_file"
    then
      echo "$line" >> "${defaults_file}"
    else
      echo "$myvar not found in template - not adding to defaults file"
    fi
  done < "${wrkdir}/default-vars.yml"

#  cat ${wrkdir}/default-vars.yml >> ../${iaas}/${INITIAL_FOUNDATION}/config/defaults/${product}.yml
fi

errands_input_file="${wrkdir}/errand-vars.yml"
if [ -f "${errands_input_file}" ]; then
  vars=$(cat "${errands_input_file}" | tr -d '[:space:]')
  if [[ "${vars}" != "" && "${vars}" != "{}" ]]; then
    cat "${errands_input_file}" >> ../${iaas}/${INITIAL_FOUNDATION}/config/defaults/${product}.yml
  fi
fi

if [ -f ${wrkdir}/resource-vars.yml ]; then
  cat ${wrkdir}/resource-vars.yml >> ../${iaas}/${INITIAL_FOUNDATION}/config/defaults/${product}.yml
fi

mkdir -p ../${iaas}/${INITIAL_FOUNDATION}/config/secrets
touch ../${iaas}/${INITIAL_FOUNDATION}/config/secrets/${product}.yml

mkdir -p ../${iaas}/${INITIAL_FOUNDATION}/config/vars
touch ../${iaas}/${INITIAL_FOUNDATION}/config/vars/${product}.yml

mkdir -p ../${iaas}/common
touch ../${iaas}/common/${product}.yml
