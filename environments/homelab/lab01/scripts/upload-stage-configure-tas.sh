om upload-product -p ~/dev/om-products/cf-10.4.0-build.18.pivotal

om stage-product -p cf --product-version=10.4.0

om configure-product -c ~/dev/lab_configs/cf-v10.yml \
    -l ~/dev/lab-configs/foundation-cert.key \
    -l ~/dev/lab-configs/foundation-cert.crt

# Upload TAS from ~/dev/om-products
# Stage TAS
# Configure TAS from ~/dev/lab-configs
