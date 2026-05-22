# TAS Manual Installation Runbook

> **Note:** This runbook describes the manual steps for installing Tanzu Application Service (TAS). Several steps reference scripts located in `~/dev/lab-configs`. Some scripts are not yet complete and are noted inline.

---

## Prerequisites

All scripts and config files are located in `~/dev/lab-configs` unless otherwise noted.

---

## Step 1: Deploy Ops Manager

Set the required environment variable:

```bash
export OM_vcenter_password=xxxxx
```

Then run the appropriate script:

```bash
# To create Ops Manager
./create-opsman.sh

# To delete Ops Manager
./delete-opsman.sh
```

---

## Step 2: Configure Authentication

Set the required environment variables:

```bash
export OM_DECRYPTION_PASSPHRASE=xxxxxx
export OM_PASSWORD=xxxxxx
```

Then run:

```bash
./configure-auth.sh
```

---

## Step 3: Target Ops Manager

Source the environment script to target Ops Manager:

```bash
. setenv.sh
```

> **Note:** This will produce an error because the BOSH Director has not been configured yet. This is expected. Validate that Ops Manager is reachable by running:

```bash
om products
```

---

## Step 4: Configure BOSH Director

### 4a: Retrieve vCenter Certificates

> **Note:** This only needs to be done if vCenter has been redeployed. There is a script that retrieves the certs from vCenter and formats them correctly.

### 4b: Set Required Environment Variable

```bash
export OM_vcenter_password=xxxxxx
```

### 4c: Run Configure Director

```bash
om configure-director -c director.yml -l vcenter-cert.pem --vars-env=OM
```

> **⚠️ TODO:** The `configure-director.sh` shell script is not yet complete. Files need to be reorganized before it can be used. For now, run the `om configure-director` command directly as shown above.  BUT ... DO NOT USE THE CERT - NOT SURE WHY AT THIS POINT
Run this from ~/dev/lab-configs

---

## Step 5: Apply Change for Director

> **⚠️ TODO:** This step is not yet in a script.

```bash
om apply-change -s
```

---

## Step 6: Target Ops Manager and Director

Once the Director is deployed, source the environment script again to target both Ops Manager and the BOSH Director:

```bash
. setenv.sh
```

---

## Step 7: Upload TAS Product

Product files are located in `~/dev/om-products`.

> **Note:** Uploading from the vjumpbox is faster than from a laptop, but the vjumpbox currently has insufficient disk space allocated. This needs to be fixed before using it for uploads.

> **⚠️ Important:** Always supply the shasum when uploading. Omitting it causes validation to run locally which takes too long and can cause the upload to fail.

```bash
om upload-product -p ~/dev/om-products/<tas-product-file>.pivotal \
  --shasum <shasum-value>
```

---

## Step 8: Generate Wildcard Certificates

> **Note:** This must be done every time Ops Manager is upgraded because Ops Manager is the signing CA. There is a script that generates the certificates, but it does not format them correctly.

After running the cert generation script, manually fix the formatting of both certificate files:

```bash
# In vi, indent everything except the first line
# On line 2, use: 99>>
```

This applies to both `foundation-cert.key` and `foundation-cert.crt`.

---

## Step 9: Stage TAS Product

```bash
om stage-product -p cf --product-version=6.0.15
```

---

## Step 10: Configure TAS Product

```bash
om configure-product -c cf-v6.yml \
  -l foundation-cert.key \
  -l foundation-cert.crt
```

> **Note:** This will eventually be refactored to use templates, defaults, and vars files consistent with the pipeline approach.

---

## Step 11: Apply Changes

```bash
om apply-changes
```

Honestly, this is just easier done in the UI

---

## Known Issues and TODOs

- `configure-director.sh` is not yet complete — files need to be reorganized
- `om apply-change` for the Director is not yet scripted
- vjumpbox needs more disk space allocated before it can be used for product uploads
- Certificate generation script does not format output correctly — manual formatting required
- TAS configuration will be refactored to use pipeline-style templates/vars

---

## Environment Variables Reference

| Variable | Used For |
|---|---|
| `OM_vcenter_password` | Ops Manager VM deployment and Director configuration |
| `OM_DECRYPTION_PASSPHRASE` | Ops Manager authentication |
| `OM_PASSWORD` | Ops Manager authentication |