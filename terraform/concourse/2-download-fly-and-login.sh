echo "*********** Downloading fly CLI"

echo "THIS DOESN'T REALLY WORK YET"

export PLATFORM="darwin"

curl "https://${CONCOURSE_URL}/api/v1/cli?arch=amd64&platform=${PLATFORM}" \
  --output fly \
  --cacert <(echo "${CONCOURSE_CA_CERT}")

chmod +x fly
sudo mv fly /usr/local/bin/

echo "*********** Logging in to concourse"
fly -t ci-${IAAS} login \
  -c "https://${CONCOURSE_URL}" \
  -u "${ADMIN_USERNAME}" \
  -p "${ADMIN_PASSWORD}" \
  --ca-cert <(echo "${CONCOURSE_CA_CERT}")
