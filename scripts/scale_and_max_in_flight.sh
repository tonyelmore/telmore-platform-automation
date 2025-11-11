#!/bin/bash

# Make temp directory to hold config files
tmpdir=$(mktemp -d)

# Set variables
increase_percentage=0.25
max_in_flight=0.25     #25% for testing - more likely 7%

# Get the CF deployment name and the number of diego_cell instances
cf_deployment=$(bosh ds --column=name | grep cf-)
current_instances=$(bosh -d ${cf_deployment} vms --column=instance | grep diego_cell | wc -l)
current_instances=$(printf "%.0f" ${current_instances})    # Round to nearest whole number - not needed but is better formatted in the last file


# Calculate new number of instances
new_instances=$(echo "${current_instances} * (1 + ${increase_percentage})" | bc)
new_instances=$(printf "%.0f" ${new_instances})   # Round to nearest whole number

# Calculate what the default number of max_in_flight would be
default_max_in_flight=$(echo "${current_instances} * .04" | bc)
default_max_in_flight=$(echo "scale-0; (${default_max_in_flight}+0.5)/1" | bc)  # Round to nearest whole number
if (( $(echo "${default_max_in_flight} < 1" | bc -l) )); then
  default_max_in_flight=1
fi

# NOTE:
# Should we make new_in_flight be a multiple of 3 so that the new instances can be spread evenly across AZs?
# For now we will just use the calculated number
# But probably should do this in the future

# Set max_in_flight to the number of increased cells
new_in_flight=$((new_instances - current_instances))

# But, if the new in_flight would be less than the default, use the default
if (( new_in_flight < default_max_in_flight+1)); then
  new_in_flight=$((default_max_in_flight))
fi

# Create config file
cat <<EOF > ${tmpdir}/scale_and_max_in_flight_config.yml
product-name: cf
resource-config:
  diego_cell:
    instances: ${new_instances}
    max_in_flight: ${new_in_flight}
EOF

# Configure product
om configure-product --config ${tmpdir}/scale_and_max_in_flight_config.yml

# Apply the changes to scale back the number of VMs and set max_in_flight
# This is going to apply all other outstanding changes as well
om apply-changes -n cf


# Create config file to scale back the number of VMs and set max_in_flight to default
cat <<EOF > ${tmpdir}/scale_back_and_max_in_flight_config.yml
product-name: cf
resource-config:
  diego_cell:
    instances: ${current_instances}
    max_in_flight: default
EOF

# configure product to scale back and set max_in_flight to default
om configure-product --config ${tmpdir}/scale_back_and_max_in_flight_config.yml 

# Apply the changes to remove the new diego cells
om apply-changes -n cf

rm -r ${tmpdir}
