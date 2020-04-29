#!/bin/bash -e

echo "Enter the opsman user name: "
read varname
export OM_USERNAME=$varname

echo "Enter the opsman password: " 
read varname
export OM_PASSWORD=$varname

echo "Enter the decryption passcode: " 
read varname
export OM_DECRYPTION_PASSPHRASE=$varname

echo "Enter the Concourse admin user name: " 
read varname
export ADMIN_USERNAME=$varname

echo "Enter the Concourse admin password: " 
read varname
export ADMIN_PASSWORD=$varname

