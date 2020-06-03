credhub set \
  -n /concourse/main/test-pipeline/provided-by-credhub \
  -t value \
  -v "World"

fly -t ci-${IAAS} set-pipeline \
  -n \
  -p test-pipeline \
  -c sample-pipeline.yml \
  --check-creds

fly -t ci-${IAAS} unpause-pipeline -p test-pipeline

fly -t ci-${IAAS} trigger-job -j test-pipeline/test-job --watch
