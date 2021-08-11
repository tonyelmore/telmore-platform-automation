
credhub generate -n concourse/main/pas_network_cert -t certificate \
  -c "*.sys.sbx.my3votes.com" \
  -a "*.sys.sbx.my3votes.com" \
  -a "*.apps.sbx.my3votes.com" \
  -a "*.login.sys.sbx.my3votes.com" \
  -a "*.uaa.sys.sbx.my3votes.com" \
  --self-sign


credhub generate -n concourse/main/uaa_service_provider_key_credentials -t certificate \
  -c "*.login.sys.sbx.my3votes.com" \
  -a "*.login.sys.sbx.my3votes.com" \
  --self-sign


credhub generate -n concourse/main/pks-tls-cert -t certificate \
  -c "*.pks.my3votes.com" \
  -a "*.pks.my3votes.com" \
  -a "*.pks.sys.sbx.my3votes.com" \
  -a "*.pks.sbx.my3votes.com" \
  --self-sign


# To get the CA to add as "trusted certs" in director configuration (security tab)
# credhub get -n concourse/main/pas_network_cert -k ca 
# Or could add pas_network_cert.ca to "trusted-certs" in the director config  (I think it is .ca)

# Network -> *.app.sbx.my3votes.com, *.sys.sbx.my3votes.com, *.login.sys.sbx.my3votes.com, *.uaa.sys.sbx.my3votes.com
# UAA -> *.login.sys.sbx.my3votes.com
