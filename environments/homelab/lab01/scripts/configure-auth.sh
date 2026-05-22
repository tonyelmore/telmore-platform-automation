# Ensure that OM_PASSWORD and OM_DECRYPTION_PASSPHRASE environment variables are set before running this script.
if [[ -z "$OM_PASSWORD" ]]; then
  echo "OM_PASSWORD environment variable is not set. Please set it before running this script."
  exit 1
fi
if [[ -z "$OM_DECRYPTION_PASSPHRASE" ]]; then
  echo "OM_DECRYPTION_PASSPHRASE environment variable is not set. Please set it before running this script."
  exit 1
fi

om configure-authentication \
  -u tony \
  