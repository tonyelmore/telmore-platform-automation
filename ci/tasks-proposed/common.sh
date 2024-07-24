#!/bin/bash

install $(pwd)/jq/jq-linux64 /usr/local/bin/jq

start_instances() {
    local instance_ids="$@"

    aws ec2 start-instances --instance-ids ${instance_ids}
    aws ec2 wait instance-running --instance-ids ${instance_ids}
}

stop_instances() {
    local instance_ids="$@"

    aws ec2 stop-instances --instance-ids ${instance_ids}
    aws ec2 wait instance-stopped --instance-ids ${instance_ids}
}

get_opsman_id() {
    local name=$1

    aws ec2 describe-instances --filter Name=tag:Stack,Values=Qorta Name=tag:Name,Values=$name | \
        jq -r '.Reservations[].Instances[].InstanceId'
}

get_director_id() {
    aws ec2 describe-instances --filter Name=tag:Name,Values=bosh/0 | jq -r '.Reservations[].Instances[].InstanceId'
}

get_bosh_vm_ids() {
    aws ec2 describe-instances \
      --filter Name=tag:Stack,Values=Qorta \
        Name=tag-key,Values=deployment \
        Name=instance-state-name,Values=running,stopped \
        Name=tag:director,Values=p-bosh | \
    jq -r '.Reservations[].Instances[].InstanceId'
}

get_deployments() {
    bosh deployments --json | jq -r '.Tables[].Rows[].name'
}