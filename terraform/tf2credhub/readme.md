# Terraform to VARS

Here is how this works.
* The assumption is that you have used terraform to create the infrastructure
* The goal is to pull all the vars from the terraform output and create the vars file 
  or the secrets file and the credhub import file

If there are vars that are used then pull that from terraform and create the key:value pairs in the var file
If there are secrets then create the key:value pair in the secrets file AND create the credhub import

Steps:
* run the terraform (../paving-xxxxxxx directories)
* pull the terraform output into terraform-outputs.yml
  "terraform output -state=../paving-azure-sbx/terraform.tfstate stable_config > terraform-outputs.yml"
* create the secrets
  "./azure_tf2credhub_opsman.sh terraform-outputs.yml opsman-creds.yml opsman-secrets.yml"
* create the vars
  "./azure_tf2vars_opsman.sh terraform-outputs.yml opsman-vars.yml"

All output will be in the outputs folder

I've started on the director vars - but not done yet.




=============================
the instructions below are from the original repo that I got from SNEAL
============================

# Pivotal Platform Configuration Repo

This contains all the configuration and scripts to build and maintain
the Pivotal Platform across all environments.

### Securely Committing Terraform Output

We cannot commit the Terraform output directly to this repo without
first replacing any sensitive values that should go into CredHub.

Grab the Terraform output, for example from prod01. You'll need to do this
from the pivotal-terraform repo's aws directory.

```
$ terraform init -backend-config=./workspaces/prod01.tfbackend -reconfigure
$ terraform output stable_config > /tmp/prod01.json
```

Now we need to run an opsfile against the terraform output that strips all
the secrets out of the file and replaces them with variables. From the root
of this repo:

Change to the pivotal-platform-config repo.

```
$ bosh interpolate -o ./aws/ops/terraform.yml /tmp/prod01.json > ./aws/vars/prod01/terraform-output.yml
```

IF you want to add secrets to credhub look at the tf2credhub.sh file.
## Make sure you target the proper credhub first
```$ credhub api https://credhub.cp.pcf.aarp.net:8844
```
```
$ ./tf2credhub.sh /tmp/prod01.json /tmp/prod01-credhub.json
$ credhub import -f /tmp/prod01-credhub.json
```

The output director.yml should now be safe to commit to git.
The output terraform-output.yml should now be safe to commit to git.

Run tf2credhub.sh to gather secrets
```
./tf2credhub.sh /tmp/nonprod.json /tmp/nonprod-credhub.json
```

Target concourse credhub

Import to credhub
```
credhub import -f /tmp/prod01-credhub.json
```
