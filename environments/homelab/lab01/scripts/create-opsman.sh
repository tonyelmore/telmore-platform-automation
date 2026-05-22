om vm-lifecycle create-vm \
  --image-file=/Users/tonyelmore/dev/om-products/ops-manager-vsphere-3.3.0.ova \
  --config=../config-director/templates/opsman.yml \
  --vars-file=../config-director/vars/opsman.yml \
  --vars-env=OM \
  --state-file=../state/state.yml

