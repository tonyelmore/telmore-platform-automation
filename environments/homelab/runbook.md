# TAS Homelab Build Runbook — Bare-Metal ESXi 8

A repeatable build guide for standing up a VMware Tanzu Application Service (TAS)
lab on a single bare-metal ESXi 8 host, plus a k3s cluster for supporting
services (Concourse, Vault, MinIO, Splunk).

This document captures the **working procedure** and **bakes in the fixes** for
every problem encountered during the original build, so a rebuild can proceed
cleanly.

---

## 1. Hardware

| Component | Detail | Role |
|-----------|--------|------|
| Workstation | HP Z8 G4, dual Xeon Platinum 8168 (48c / 96t), 512 GB RAM | Hypervisor host |
| Boot SSD | 250 GB Kingston SATA (SKC600256G) | ESXi boot device |
| NVMe 1 | 4 TB Samsung 990 EVO Plus | Datastore `nvme-primary` (TAS only) |
| NVMe 2 | 4 TB Samsung 990 PRO | Datastore `nvme-secondary` (k3s + apps) |
| HDD | 8 TB WD Ultrastar (HGST HUS728T8TALE6L4) | Datastore `hdd-bulk` (Splunk) |
| NIC | Onboard 1 GbE = `vmnic2` | Single active uplink |

**Notes / gotchas**
- The onboard NIC enumerates as `vmnic2`. The bottom RJ45 is the AMT management
  port — ignore it.
- A single 1 GbE NIC is a hard constraint. It drove the decision to use a
  **standard vSwitch** instead of a VDS (see §5).
- The HPE 562SFP+ 10G card was removed during troubleshooting and left out.

---

## 2. BIOS Settings — CRITICAL for ESXi Install

> **The single most important fix in this build.** Without this, the ESXi
> installer hangs indefinitely at **"Shutting down firmware services"** (for
> 12+ hours). That message is only a progress indicator, not the actual error.

**Fix: Enable Legacy Boot in the BIOS.**

- Boot mode: **Legacy Boot enabled** (not pure UEFI).
- ESXi must continue to boot in Legacy mode going forward.

Things that did **NOT** fix the hang (don't waste time on them):
- Boot params `norts=1`, `noACPI`, `nox2apic`
- Other BIOS tweaks
- Removing RAM / NIC / second drive
- Trying different ESXi versions (8.0U3, 8.0U2, 7.0U3 all hung the same way)

Reference: William Lam's article on the "Shutting down firmware services"
message being a non-fatal progress indicator.

---

## 3. Create the ESXi Install USB

- Simple file-copy to USB and `dd` both produced **non-booting** media.
- **Use Rufus** (on a Windows machine) to create the bootable USB. This was the
  only method that produced reliable bootable media.

---

## 4. Install ESXi + Datastores

1. Boot the Rufus USB (Legacy mode) and install ESXi 8 to the 250 GB Kingston SSD.
2. Set the management IP to **192.168.10.10** (see §6 for the full IP scheme).
3. **Clear old partitions first:** if the NVMe/HDD drives carry old partitions
   (e.g. prior ZFS/other-OS data), wipe them via the ESXi host UI →
   **Storage → Devices** before creating datastores.
4. Create the datastores:
   - `nvme-primary` (4 TB 990 EVO Plus)
   - `nvme-secondary` (4 TB 990 PRO)
   - `hdd-bulk` (8 TB Ultrastar)
   - `datastore1` (boot SSD leftover) — used for ISOs
5. Upload the Ubuntu Server 24.04.x ISO to `datastore1/iso`.

**NTP:** Set ESXi NTP servers to `pool.ntp.org, time.google.com,
time.cloudflare.com`. The router (see §6) does **not** serve NTP, and missing
NTP breaks the vCenter deploy later (§7).

---

## 5. Networking Design Decision — Standard vSwitch (NOT VDS)

With a single physical NIC, **do not attempt a VDS.** Migrating the management
vmkernel (`vmk0`) to a VDS on a one-NIC host triggers vCenter's network
rollback safety (management briefly disconnects → auto-rollback). It will fail
with:

> *"A change in the network configuration disconnected the host ... and has
> been rolled back."*

A standard vSwitch provides **identical TAS functionality**: same VLAN tagging
(VST), same port groups, same everything. The only thing a VDS adds is
centralized multi-host management — irrelevant on a single host.

**Decision: use the standard vSwitch `vSwitch0` and add VLAN-tagged port
groups to it.**

### Port groups to create on vSwitch0

Create via the **ESXi host web UI** (`https://192.168.10.10/ui` → Networking →
Port groups → Add port group) — faster than the vCenter wizard for bulk adds.

| Port group | VLAN ID | Subnet |
|------------|---------|--------|
| VM Network (default, mgmt) | 0 | 192.168.10.0/24 |
| Management Network (vmk0) | 0 | 192.168.10.0/24 |
| k8s | 20 | 192.168.20.0/24 |
| tas1-infra | 30 | 192.168.30.0/24 |
| tas1-deployment | 31 | 192.168.31.0/24 |
| tas1-services | 32 | 192.168.32.0/24 |
| tas1-isoseg-routing | 33 | 192.168.33.0/24 |
| tas1-isoseg1 | 34 | 192.168.34.0/24 |
| tas1-isoseg2 | 35 | 192.168.35.0/24 |

> **Convention:** VLAN ID = third octet of the subnet.

---

## 6. Network Scheme (UCG-Max Router)

The router is a UniFi UCG-Max. The ISP router feeds its WAN (double-NAT for now;
ISP bridge mode is a future improvement).

- **Default LAN / management:** `192.168.10.0/24`, gateway `.1`,
  DHCP pool `.100–.199`.
- **All other VLANs:** created on the UCG-Max with **DHCP off** (static only)
  and "Allow Internet Access" on. **VLAN ID = third octet.**

### Fixed management IPs (VLAN 0 / untagged)

| Host | IP |
|------|----|
| UCG-Max gateway | 192.168.10.1 |
| ESXi | 192.168.10.10 |
| vCenter | 192.168.10.11 |
| Pi-hole | 192.168.10.12 |
| jumpbox | 192.168.10.13 |

### VLAN subnets

| Network | VLAN | Subnet | Gateway |
|---------|------|--------|---------|
| k8s | 20 | 192.168.20.0/24 | 192.168.20.1 |
| tas1-infra | 30 | 192.168.30.0/24 | 192.168.30.1 |
| tas1-deployment | 31 | 192.168.31.0/24 | 192.168.31.1 |
| tas1-services | 32 | 192.168.32.0/24 | 192.168.32.1 |
| tas1-isoseg-routing | 33 | 192.168.33.0/24 | 192.168.33.1 |
| tas1-isoseg1 | 34 | 192.168.34.0/24 | 192.168.34.1 |
| tas1-isoseg2 | 35 | 192.168.35.0/24 | 192.168.35.1 |
| (reserved) Foundation 2 | 40+ | 192.168.40.0/24+ | — |

**UCG-Max port usage:** auto-trunks LAN ports (native = management, all VLANs
tagged). ESXi on port 3 (direct), unmanaged switch on port 4 (wired laptops),
ISP on port 5.

**Wireless devices** stay on the ISP router and reach the lab only via Tailscale
(§9).

---

## 7. Deploy Pi-hole (DNS)

1. Build a fresh Ubuntu Server VM at **192.168.10.12**.
2. Install Pi-hole; restore the v6 Teleporter backup if you have one. Remove any
   stale records from prior builds.
3. Point the UCG-Max DHCP DNS at the Pi-hole.
4. Confirm forward + reverse DNS resolve lab-wide.

### Pi-hole v6 — Enabling custom dnsmasq configs (CRITICAL for TAS wildcards)

> Pi-hole v6 **ignores `/etc/dnsmasq.d/` by default.** Custom configs (needed for
> TAS wildcard DNS in §12) are silently not loaded. This must be enabled:

```bash
sudo pihole-FTL --config misc.etc_dnsmasq_d true
sudo pihole reloaddns        # NOTE: v6 uses "reloaddns", not "restartdns"
```

---

## 8. Deploy vCenter (VCSA 8.0.3)

The GUI installer fails on macOS (Gatekeeper flags `ovftool` as "damaged";
`xattr -cr` / `chmod -R u+w` did not reliably fix it).

**Use the CLI installer from the jumpbox instead:**

```bash
/mnt/vcsa/vcsa-cli-installer/lin64/vcsa-deploy install \
  --accept-eula --no-ssl-certificate-verification \
  ~/vcenter-deploy.json
```

- Deployment size: **Small**, SSO domain `vsphere.local`, IP `192.168.10.11`.
- **NTP gotcha:** Stage 2 fails on NTP sync because the UCG-Max doesn't serve
  NTP. Set NTP (on both vCenter config and ESXi) to
  `pool.ntp.org, time.google.com, time.cloudflare.com`.
- Create datacenter `telmore-dc` and add the ESXi host.

---

## 9. Jumpbox + Tailscale (Remote Access)

1. Build an Ubuntu VM at **192.168.10.13** (the jumpbox).
2. Install Tailscale and advertise **all** lab subnets as a subnet router:

```bash
sudo tailscale up --advertise-routes=\
192.168.10.0/24,192.168.20.0/24,192.168.30.0/24,192.168.31.0/24,\
192.168.32.0/24,192.168.33.0/24,192.168.34.0/24,192.168.35.0/24
```

3. **Approve every advertised route** in the Tailscale admin console
   (https://login.tailscale.com/admin/machines → jumpbox → Edit route settings).
4. Configure **split-DNS:** `lab.telmore.io` → Pi-hole at `192.168.10.12`.

### macOS client gotchas (recurring)
- Run `sudo tailscale set --accept-dns=true` so the **system resolver** (not
  just `dig`) resolves lab names.
- Remove stale `/etc/resolver/*` files from prior builds — they cause silent
  macOS DNS failures.
- A subnet is only reachable if it is **both advertised and approved**.
  "Network is unreachable" = route missing/unapproved.

---

## 10. vCenter Objects (Cluster, Pools, Folders)

### Cluster — must be IMAGE-managed (vSphere 8 lifecycle gotcha)

> A bare-metal ESXi 8 host is **image-managed** by vSphere Lifecycle Manager.
> You **cannot move an image-managed host into a baseline-managed cluster**:
>
> *"The operation to move vSphere Lifecycle Manager image-managed standalone
> host to baseline-managed cluster is not allowed."*

When creating the cluster:
1. New Cluster `lab-cluster` under `telmore-dc`.
2. **Check "Manage all hosts in the cluster with a single image"**
   (makes it image-managed, matching the host). Import the image from the
   existing host.
3. **HA: OFF** (single-host HA causes quirks, no benefit).
4. **DRS: ON, Automation = Manual.**

> **Why DRS must be ON:** Resource pools at the cluster level **require DRS**.
> "New Resource Pool" is greyed out without it. Manual mode means DRS never
> auto-migrates anything (and on one host there's nothing to migrate) — it
> simply unlocks resource pools. This is the standard single-host pattern.

5. Move the host into the cluster: right-click host → **Move To** →
   `lab-cluster` → choose **"put VMs in the cluster's root resource pool"**
   (avoids needing maintenance mode, which is impossible while vCenter runs on
   the host itself).

### Resource pools (AZs map to pools, not clusters)

Create under `lab-cluster` (right-click cluster → New Resource Pool). Accept
default shares (Normal, unlimited):

- `lab-base-rp`
- `lab01-az1-rp`
- `lab01-az2-rp`
- `lab01-az3-rp`
- `lab01-opsman-rp`

### VM folders (VMs and Templates view)

```
lab_base
lab01
  ├── lab01_bosh_vms
  ├── lab01_bosh_templates
  ├── lab01_bosh_disks
  └── lab01_opsman
```

### govc environment

```bash
export GOVC_URL=https://192.168.10.11
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD='<password>'
export GOVC_INSECURE=true
```

Resource pool path format (once host is in the cluster):
`/telmore-dc/host/lab-cluster/Resources/<pool-name>`

---

## 11. Ubuntu Template + Customization Spec

### Build the template
1. Install Ubuntu Server 24.04.x, install `open-vm-tools`.
2. Generalize for cloning:
   ```bash
   sudo cloud-init clean
   sudo truncate -s 0 /etc/machine-id
   sudo rm -f /etc/ssh/ssh_host_*
   ```
3. Add a VMware datasource hint:
   ```bash
   echo 'datasource_list: [ VMware, OVF, None ]' | \
     sudo tee /etc/cloud/cloud.cfg.d/99-vmware.cfg
   ```
4. Convert to template.

### Customization spec (`ubuntu-linux-custom`)
- Network: **"Prompt the user for an IPv4 address when deploying"**
  (so each clone prompts for its IP — otherwise it defaults to DHCP, which
  fails on the DHCP-less VLANs).
- Subnet mask `255.255.255.0`, gateway `192.168.20.1` (works for all
  k8s-network VMs; make a second spec for other VLANs as needed).
- DNS `192.168.10.12`, search domain `lab.telmore.io`.
- Hostname = VM name.

### Per-clone checklist (IMPORTANT — these bit us repeatedly)
The customization spec sets the **IP only**. It does **not** set the port group,
the CD/DVD device, or regenerate SSH keys. For every clone:

1. ✅ **Customize the operating system** → select `ubuntu-linux-custom` →
   enter the IP when prompted.
2. ⚠️ **Network adapter → set the correct port group** (e.g. `k8s`).
   Clones default to **VM Network**. A VM with a VLAN-20 IP on the VM-Network
   port group cannot reach its gateway — symptom: can't ping `<vlan>.1`.
   Also confirm **"Connected"** is checked.
3. ⚠️ **CD/DVD drive → "Client Device"** (avoids a "Select File" ISO prompt;
   the clone boots from its installed OS, not an ISO).
4. After first boot, regenerate SSH host keys (template removed them):
   ```bash
   sudo ssh-keygen -A
   sudo systemctl restart ssh
   ```
   Symptom if skipped: SSH gives **"Connection reset by peer"**.
5. Reclaim LVM root space (installer under-allocates root):
   ```bash
   sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
   sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
   ```

> **Clone error "Number of virtual devices exceeds the maximum for a given
> controller":** check the **"Other — Additional Hardware"** section and the
> SCSI/SATA controllers in the Customize Hardware step for phantom/extra
> devices and remove them.

---

## 12. Deploy TAS (Ops Manager → BOSH → TAS tile)

1. Create the **Ops Manager** VM (e.g. via `om vm-lifecycle create-vm`) on the
   `tas1-infra` port group, IP `192.168.30.10`.
   - Verify the VM NIC is on `tas1-infra` (VLAN 30) and **Connected**.
   - First VM on a tagged VLAN = first real test of VLAN tagging. From the VM
     console, `ping 192.168.30.1` (its gateway) proves tagging works.
   - Reaching it from the jumpbox proves inter-VLAN routing works. (You cannot
     reach it from a laptop until that subnet is advertised+approved in
     Tailscale — see §9.)
2. Configure the BOSH Director tile (vSphere config, networks, AZs mapped to the
   **resource pools** from §10).
3. Upload and configure the TAS tile. Gorouters get static IPs on the
   deployment network: **192.168.31.20, .21, .22**.

### Wildcard DNS for TAS (the WildcardDomainVerifier failure)

`apply-changes` fails with:
> *The domain '\*.sys.lab01.lab.telmore.io' failed to resolve, type:
> WildcardDomainVerifier* (and the same for `*.apps...`).

TAS needs wildcard DNS for its system and apps domains, resolving to the
Gorouters. With three Gorouters, use round-robin DNS to all three.

On the Pi-hole, create `/etc/dnsmasq.d/99-tas-wildcards.conf`:

```
address=/sys.lab01.lab.telmore.io/192.168.31.20
address=/sys.lab01.lab.telmore.io/192.168.31.21
address=/sys.lab01.lab.telmore.io/192.168.31.22
address=/apps.lab01.lab.telmore.io/192.168.31.20
address=/apps.lab01.lab.telmore.io/192.168.31.21
address=/apps.lab01.lab.telmore.io/192.168.31.22
```

Then (remember §7 — the `etc_dnsmasq_d` flag must be `true`):
```bash
sudo pihole-FTL --test          # validate syntax
sudo pihole reloaddns
# verify:
dig api.sys.lab01.lab.telmore.io @127.0.0.1 +short   # expect the 3 IPs
```

Re-run `apply-changes`.

> **"server misbehaving" during apply-changes:** a transient Go DNS resolver
> error, usually from the Pi-hole reload restarting FTL mid-deploy. Simply
> re-run apply-changes. If it recurs, suspect Pi-hole's query **rate limit**
> (default 1000/min/client) being exceeded by the deploy — raise/disable
> `dns.rateLimit.count`.

---

## 13. NFS Server VM (k8s persistent storage)

A plain Ubuntu NFS server is used (not TrueNAS). On a single host carving
virtual disks from existing VMFS datastores, TrueNAS/ZFS adds a redundant layer
with no real benefit; placing virtual disks on specific datastores is the clean
way to pin storage per-tier.

### Build
- Clone from `ubuntu-template`, IP **192.168.20.5**, port group **k8s**.
- Add two extra virtual disks during clone:
  - **Hard disk 2:** 200 GB, datastore **nvme-secondary**, Thin → `/export/fast`
  - **Hard disk 3:** 500 GB, datastore **hdd-bulk**, Thin → `/export/bulk`
- (Follow the §11 per-clone checklist — port group, CD/DVD, ssh-keygen, LVM.)

### Format, mount, persist
```bash
lsblk                      # confirm: sdb = 200G (fast), sdc = 500G (bulk)
sudo mkfs.ext4 /dev/sdb
sudo mkfs.ext4 /dev/sdc
sudo mkdir -p /export/fast /export/bulk
sudo mount /dev/sdb /export/fast
sudo mount /dev/sdc /export/bulk
sudo blkid /dev/sdb /dev/sdc     # get UUIDs for fstab
# /etc/fstab:
#   UUID=<sdb-uuid>  /export/fast  ext4  defaults  0 2
#   UUID=<sdc-uuid>  /export/bulk  ext4  defaults  0 2
```

### NFS server
```bash
sudo apt update
sudo apt install -y nfs-kernel-server
# /etc/exports:
#   /export/fast  192.168.20.0/24(rw,sync,no_subtree_check,no_root_squash)
#   /export/bulk  192.168.20.0/24(rw,sync,no_subtree_check,no_root_squash)
sudo exportfs -ra
sudo systemctl enable --now nfs-kernel-server
sudo exportfs -v           # confirm both exports active
```

> `no_root_squash` is needed for the k8s NFS CSI driver to manage permissions.

---

## 14. k3s Cluster (1 control plane + 2 workers)

### Node sizing & IPs (all on nvme-secondary, port group k8s)

| Node | IP | vCPU | RAM | Disk |
|------|----|----|-----|------|
| k3s-cp-01 | 192.168.20.10 | 2 | 4 GB | 40 GB |
| k3s-worker-01 | 192.168.20.11 | 4 | 16 GB | 60 GB |
| k3s-worker-02 | 192.168.20.12 | 4 | 16 GB | 60 GB |

Clone all three from `ubuntu-template` following the §11 per-clone checklist.
k3s nodes need **only one disk** (no extra data disks — storage comes from NFS).

### Install — keep k3s defaults (Traefik ingress + servicelb)

Control plane (`192.168.20.10`):
```bash
curl -sfL https://get.k3s.io | sh -
sudo cat /var/lib/rancher/k3s/server/node-token   # copy this
```

Each worker (`.11`, `.12`):
```bash
curl -sfL https://get.k3s.io | \
  K3S_URL=https://192.168.20.10:6443 K3S_TOKEN=<token> sh -
```

Verify (on control plane):
```bash
sudo k3s kubectl get nodes -o wide   # all three Ready
```

### kubectl access
On the control plane:
```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
```
For laptop access: copy `/etc/rancher/k3s/k3s.yaml` to the laptop and change the
`server:` line from `https://127.0.0.1:6443` to `https://192.168.20.10:6443`.

---

## 15. NFS CSI Driver + Storage Classes

### Install the driver
```bash
helm repo add csi-driver-nfs \
  https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm repo update
helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
  --namespace kube-system --version v4.9.0
kubectl get csidrivers      # expect nfs.csi.k8s.io
```

### Storage classes
`nfs-fast` (→ nvme-secondary) is the default; `nfs-bulk` (→ hdd-bulk) for Splunk.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-fast
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: nfs.csi.k8s.io
parameters:
  server: 192.168.20.5
  share: /export/fast
reclaimPolicy: Delete
volumeBindingMode: Immediate
mountOptions:
  - nfsvers=4.1
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-bulk
provisioner: nfs.csi.k8s.io
parameters:
  server: 192.168.20.5
  share: /export/bulk
reclaimPolicy: Delete
volumeBindingMode: Immediate
mountOptions:
  - nfsvers=4.1
```

```bash
kubectl apply -f nfs-storageclasses.yaml
kubectl get storageclass
```

### Verify provisioning
Create a 1Gi PVC on `nfs-fast`, confirm it `Bound`, and confirm a `pvc-<uuid>`
subdirectory appears in `/export/fast` on the NFS server. Delete the test PVC.

---

## 16. Storage Strategy Summary

| Workload | Datastore / Export | Storage class |
|----------|--------------------|---------------|
| TAS (all VMs) | `nvme-primary` (isolated) | — |
| k3s nodes (OS disks) | `nvme-secondary` | — |
| Concourse, Vault, MinIO, PostgreSQL | `/export/fast` → nvme-secondary | `nfs-fast` (default) |
| Splunk | `/export/bulk` → hdd-bulk | `nfs-bulk` |

---

## 17. Recurring Gotchas — Quick Reference

| Symptom | Cause / Fix |
|---------|-------------|
| ESXi install hangs at "Shutting down firmware services" | Enable **Legacy Boot** in BIOS (§2) |
| USB won't boot | Create it with **Rufus** (§3) |
| vCenter GUI installer "ovftool damaged" (macOS) | Use the **CLI installer** from the jumpbox (§8) |
| vCenter deploy fails at NTP sync | Router serves no NTP — set external NTP on vCenter + ESXi (§4/§8) |
| VDS migration rolls back | Single NIC — use a **standard vSwitch** (§5) |
| "New Resource Pool" greyed out | Enable **DRS (Manual)** on the cluster (§10) |
| Can't move host into cluster (image vs baseline) | Recreate cluster as **image-managed** (§10) |
| Clone has no IP prompt / lands on DHCP | Set spec to **"prompt for IPv4"** (§11) |
| Clone can't ping its gateway | NIC on **VM Network** instead of the VLAN port group (§11) |
| SSH "connection reset by peer" on a clone | Run **`ssh-keygen -A`** (template removed host keys) (§11) |
| "Number of virtual devices exceeds maximum" on clone | Remove phantom devices under **Other / controllers** (§11) |
| Root filesystem too small | **`lvextend` + `resize2fs`** (§11) |
| TAS WildcardDomainVerifier fails | Pi-hole wildcard config + **`misc.etc_dnsmasq_d true`** (§7/§12) |
| Pi-hole custom dnsmasq ignored | v6 needs `misc.etc_dnsmasq_d true`; reload with **`pihole reloaddns`** (§7) |
| "server misbehaving" during apply-changes | Transient DNS (Pi-hole reload) — retry; check rate limit (§12) |
| "Network is unreachable" from laptop | Tailscale route not **advertised+approved** (§9) |
| macOS won't resolve lab names | `tailscale set --accept-dns=true`; clear stale `/etc/resolver/*` (§9) |

---

## 18. Build Order (Checklist)

- [ ] BIOS: enable Legacy Boot
- [ ] Create ESXi USB with Rufus
- [ ] Install ESXi (192.168.10.10), wipe old partitions, create 4 datastores, set NTP
- [ ] Configure UCG-Max: management LAN + all VLANs (DHCP off), trunk ports
- [ ] Add VLAN port groups to vSwitch0 (host UI)
- [ ] Deploy Pi-hole (192.168.10.12); enable `etc_dnsmasq_d`
- [ ] Deploy vCenter via CLI installer (192.168.10.11); fix NTP
- [ ] Deploy jumpbox + Tailscale subnet router; advertise + approve all routes; split-DNS
- [ ] Create image-managed cluster; DRS Manual; HA off; move host in
- [ ] Create resource pools + VM folders
- [ ] Build Ubuntu template + customization spec (prompt for IP)
- [ ] Deploy Ops Manager → BOSH → TAS; Gorouters .20/.21/.22
- [ ] Pi-hole wildcard DNS; apply-changes
- [ ] Deploy NFS server VM (192.168.20.5) with two datastore-pinned disks
- [ ] Clone 3 k3s nodes; install k3s (CP + 2 workers); kubectl access
- [ ] Install NFS CSI driver; create nfs-fast (default) + nfs-bulk; verify PVC
- [ ] (Next) Deploy Concourse, Vault, MinIO (nfs-fast), Splunk (nfs-bulk)