openssl s_client -showcerts -connect nsxmgr-01.haas-515.pez.vmware.com:443 </dev/null 2>/dev/null|openssl x509 -outform PEM
