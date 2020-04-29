credhub set \
  -n /concourse/main/test-pipeline/provided-by-credhub \
  -t value \
  -v "World"

./fly -t ci set-pipeline \
  -n \
  -p test-pipeline \
  -c pipeline.yml \
  --check-creds

./fly -t ci unpause-pipeline -p test-pipeline

./fly -t ci trigger-job -j test-pipeline/test-job --watch


