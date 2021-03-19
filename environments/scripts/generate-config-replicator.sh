#!/bin/bash -e
: ${PIVNET_TOKEN?"Need to set PIVNET_TOKEN"}

INITIAL_FOUNDATION=pcfnane1sbx
if [ ! $# -eq 3 ]; then
  echo "Must supply iaas and product name and replicator name as arg"
  exit 1
fi

iaas=$1
product=$2
replicator_name=$3

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
wrkdir=${tmpdir}/replicator/${version}
mkdir -p ${wrkdir}

tmpZipDir=$(mktemp -d)
if [ ! -f ${wrkdir}/replicator-darwin ]; then
  om download-product \
    --output-directory ${tmpZipDir} \
    --pivnet-api-token ${PIVNET_TOKEN} \
    --pivnet-file-glob "replicator-*.zip" \
    --pivnet-product-slug ${slug} \
    --product-version ${version}
  unzip ${tmpZipDir}/*.zip -d ${wrkdir}
  chmod +x ${wrkdir}/replicator-darwin
fi

baseProduct=tile-configs/replicatedWorkArea
mkdir -p ${baseProduct}
rm ${baseProduct}/*.pivotal
om download-product \
  -f ${glob} \
  -p ${slug} \
  --product-version=${version} \
  --output-directory=${baseProduct} \
  --pivnet-api-token=${PIVNET_TOKEN}

${wrkdir}/replicator-darwin \
  --name ${replicator_name} \
  --path ${baseProduct}/*.pivotal \
  --output ${baseProduct}/${replicator_name}.pivotal

wrkdir=tile-configs/${product}-${replicator_name}-config/
mkdir -p ${wrkdir}
om config-template \
  --product-path=${baseProduct}/${replicator_name}.pivotal \
  --output-directory=${wrkdir} 

wrkdir=$(find ${wrkdir} -name "${version}*")
if [ ! -f ${wrkdir}/product.yml ]; then
  echo "Something wrong with configuration as expecting ${wrkdir}/product.yml to exist"
  exit 1
fi

ops_files="${replicator_name}-operations"
touch ${ops_files}

ops_files_args=("")
while IFS= read -r var
do
  ops_files_args+=("-o ${wrkdir}/${var}")
done < "$ops_files"
bosh int ${wrkdir}/product.yml ${ops_files_args[@]} > ../${iaas}/${INITIAL_FOUNDATION}/config/templates/${replicator_name}.yml

# generated_product_name=$(bosh int ../${iaas}/${INITIAL_FOUNDATION}/config/templates/${replicator_name}.yml --path /product-name)

mkdir -p ../${iaas}/${INITIAL_FOUNDATION}/config/defaults
rm -rf ../${iaas}/${INITIAL_FOUNDATION}/config/defaults/${replicator_name}.yml
touch ../${iaas}/${INITIAL_FOUNDATION}/config/defaults/${replicator_name}.yml
if [ -f ${wrkdir}/product-default-vars.yml ]; then
  cat ${wrkdir}/product-default-vars.yml >> ../${iaas}/${INITIAL_FOUNDATION}/config/defaults/${replicator_name}.yml
fi
if [ -f ${wrkdir}/errand-vars.yml ]; then
  cat ${wrkdir}/errand-vars.yml >> ../${iaas}/${INITIAL_FOUNDATION}/config/defaults/${replicator_name}.yml
fi
if [ -f ${wrkdir}/resource-vars.yml ]; then
  cat ${wrkdir}/resource-vars.yml >> ../${iaas}/${INITIAL_FOUNDATION}/config/defaults/${replicator_name}.yml
fi

touch ../${iaas}/${INITIAL_FOUNDATION}/config/secrets/${replicator_name}.yml