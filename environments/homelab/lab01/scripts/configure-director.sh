om configure-director \
  -c ../config-director/templates/director.yml \
  -l ../../common-director/director.yml \
  -l ../config-director/vars/director.yml \
  -l ~/dev/lab-configs/vcenter-cert.pem \
  --vars-env=OM

# NOTE: If you have a custom CA certificate for vCenter, you can specify it with the -l flag. For example:
#   -l ~/dev/lab-configs/vcenter-cert.pem \

om apply-changes -s 
