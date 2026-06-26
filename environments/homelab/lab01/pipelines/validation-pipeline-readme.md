# Validation Pipeline

This Concourse pipeline is flown with:

```bash
fly -t main sp -p validation-pipeline -c validation-pipeline.yml -l validation-pipeline-params.yml
```

## What it tests

The pipeline runs a small validation flow that checks:

- Git repository access through `config-repo`
- Loading the Platform Automation Toolkit image and tasks
- Creating a test file and uploading it to Minio/S3
- Preparing tasks with secrets
- Checking pending changes in the TAS foundation

There is also a commented-out step for getting the test file back from Minio/S3.

## Vault values required

The following secrets are referenced by the pipeline and should be available in Vault:

- `pivnet_token`
- `github-key.private-key`
- `minio-key.access-key`        (Although this is not a secret, it is paired with minio-key.secret-access-key)
- `minio-key.secret-access-key`

The following secrets MAY be used to avoid dockerhub pull issues by supplying credentials to the registry-image
- `dockerhub.username`          (Although this is not a secret, it is paired with dockerhub.password)
- `dockerhub.password`

The `env.yml` file used by the `check-pending-changes` task is expected to have these variables pulled from Vault.
- `ops_manager_dns`             (Although this is not a secret, it allows the env.yml to be used across many foundations)
- `opsman_user.username`        (Although this is not a secret, it is paied with the opsman_user.password)
- `opsman_user.password`
- `opsman_decryption_passphrase`



