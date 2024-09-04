#!/bin/bash

# Make temp directory to hold config files
tmpdir=$(mktemp -d) 

# Set variables
increase_percentage=0.25   # 25% for testing - more likely 7%

# Get the CF deployment name and the number of diego_cell instances
cf_deployment=$(bosh ds --column=name | grep cf-)
current_instances=$(bosh -d ${cf_deployment} vms | grep diego_cell | wc -l)
current_instances=$(printf "%.0f" $current_instances) # Round to nearest whole number - not needed but is better formatted in last file


# Calculate new instance count
new_instances=$(echo "$current_instances * (1 + $increase_percentage)" | bc)
new_instances=$(printf "%.0f" $new_instances)  # Round to nearest whole number


# Calculate what the default number of max_in_flight would be
default_max=$(echo "$current_instances * .04" | bc)
default_max=$(echo "scale=0; $default_max / 1" | bc)
if [ "$default_max" -eq 0 ]; then
  default_max=1
fi

# Set max_in_flight to the number of increased cells
new_in_flight=$((new_instances - current_instances))

# But, if the new in_flight would be less than the default, use the default
if (( new_in_flight < default_max+1)); then
  new_in_flight=default
fi

# Create config file
cat <<EOF > ${tmpdir}/diego_scale_and_flight_config.yml
product-name: cf
resource-config:
  diego_cell:
    max_in_flight: $new_in_flight
    instances: $new_instances
EOF

# Configure product
om configure-product -c ${tmpdir}/diego_scale_and_flight_config.yml

# Apply the changes to create the new diego cells and set the max-in-flight
# This is going to apply all other changes too
om apply-changes -n cf


# Create config file to scale back the number of VMs and set max_in_flight to default
cat <<EOF > ${tmpdir}/diego_scale_and_flight_config.yml
product-name: cf
resource-config:
  diego_cell:
    max_in_flight: default
    instances: $current_instances
EOF

# Configure product to reset instance count and max-in-flight
om configure-product -c ${tmpdir}/diego_scale_and_flight_config.yml

# Apply the changes to remove the new diego cells
om apply-changes -n cf

rm -r ${tmpdir}

