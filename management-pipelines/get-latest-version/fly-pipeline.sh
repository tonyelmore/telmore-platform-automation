products=("stemcells-ubuntu-jammy"
          "elastic-runtime"
          "p-ipsec-addon")

for product in "${products[@]}"; do
    fly sp -p get-latest-versions \
           -c pipeline.yml \
           -l pipeline-params.yml \
           -l param-files/${product}-params.yml \
           -l product_slug=${product}
           