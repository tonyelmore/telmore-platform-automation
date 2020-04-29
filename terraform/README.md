Here are a set of scripts that will create an opsman/director/concourse

It is based on the documentation provided by the platform-automation team

It has been tested only with AWS

It assumes that you follow the instructions provided in pivotal/paving and create a folder in this directory called paving-aws.  In paving-aws you will create your terraform-tfvars and apply the terraform.  the output file will be copied into the concourse directory.

You then need to execute the 0-set-env.sh script in order to set environment variables for the opsman credentials and concourse credentials.

There is a state.yml file here and if it contains values then opsman will not be created.

The script relies on several items that need to be downloaded.  I put these in a downloaded-resource folder.
See the platform-automation doc for these

downloaded-resources
....concourse-bosh-deployment
....opsman-image
........ops-manager-aws-2.8.5-build.234.yml
....platform-automation-image
........platform-automation-image-4.3.4.tgz
....releases
........backup-and-resource-sds-release-1.15.0.tgz
........bpm-release-1.1.7.tgz
........concourse-bosh-release-5.5.8.tgz
........credhub-release-2.5.7.tgz
........postgres-release-41.tgz
........uaa-release-74.9.0.tgz
....stemcells
........light-bosh-stemcell------

Then execute 1-run-all.sh to do all the work

The sample-pipeline has not been tested
