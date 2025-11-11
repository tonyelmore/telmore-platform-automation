# Homelab Observability Setup - Grafana & Prometheus

## Session Summary
This document covers the complete setup of Grafana and Prometheus monitoring for a complex homelab environment, including troubleshooting disk space issues on both the Proxmox host and K3s nodes.

---

## Table of Contents
1. [Infrastructure Overview](#infrastructure-overview)
2. [Initial Monitoring Stack Setup](#initial-monitoring-stack-setup)
3. [Proxmox Host Monitoring](#proxmox-host-monitoring)
4. [Disk Space Analysis](#disk-space-analysis)
5. [K3s Node Disk Expansion](#k3s-node-disk-expansion)
6. [Results and Next Steps](#results-and-next-steps)

---

## Infrastructure Overview

### Hardware
- **HP Z8 G4** - Physical host
- **238GB SSD (sda)** - Proxmox OS and local storage
- **3.6TB NVMe (nvme0n1)** - Fast VM storage pool
- **7.3TB HDD (sdb)** - Passed through to TrueNAS

### Hypervisor Stack
- **Proxmox VE** - Primary hypervisor
  - **ESXi (nested)** - Nested hypervisor with vCenter and Tanzu
  - **pfSense** - Firewall/router
  - **piHole** - DNS/ad blocking
  - **TrueNAS** - NAS storage
  - **K3s Cluster** - 3 nodes (1 control plane, 2 workers)

### K3s Workloads
- Concourse CI/CD
- Minio object storage
- Splunk logging
- Prometheus & Grafana (monitoring stack)

---

## Initial Monitoring Stack Setup

### Step 1: Install Prometheus & Grafana on K3s

We used the `kube-prometheus-stack` Helm chart which includes:
- Prometheus Operator
- Grafana
- AlertManager
- Node Exporter (for K3s nodes)
- kube-state-metrics
- Pre-built dashboards

```bash
# Add the prometheus-community helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace monitoring

# Install the stack with custom values
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=10Gi \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30915
```

### Step 2: Expose Grafana via NodePort

Modified Grafana service to use NodePort on port 30915 for HAProxy integration:

```bash
# The service was configured during installation with:
--set grafana.service.type=NodePort \
--set grafana.service.nodePort=30915
```

### Step 3: Configure HAProxy and DNS

**HAProxy Configuration (on pfSense):**
```
frontend grafana_frontend
    bind *:80
    acl host_grafana hdr(host) -i grafana.yourdomain.local
    use_backend grafana_backend if host_grafana

backend grafana_backend
    balance roundrobin
    server k3s-node1 <k3s-node-1-ip>:30915 check
    server k3s-node2 <k3s-node-2-ip>:30915 check
    server k3s-node3 <k3s-node-3-ip>:30915 check
```

**piHole DNS Entry:**
- Domain: `grafana.yourdomain.local`
- IP Address: `<haproxy-ip>` (pfSense IP)

### Step 4: Access Grafana

```bash
# Get Grafana admin password
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# Access via browser
http://grafana.yourdomain.local
# Username: admin
# Password: <retrieved from above>
```

---

## Proxmox Host Monitoring

### Step 1: Install Node Exporter on Proxmox

SSH into the Proxmox host and install Node Exporter:

```bash
# Download Node Exporter
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar xvfz node_exporter-1.8.2.linux-amd64.tar.gz
sudo cp node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
sudo chown root:root /usr/local/bin/node_exporter

# Create systemd service
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Start and enable the service
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

# Check status
sudo systemctl status node_exporter

# Verify it's working
curl http://localhost:9100/metrics
```

### Step 2: Configure Prometheus to Scrape Proxmox

Create additional scrape configuration:

```bash
# Create scrape config file
cat > prometheus-additional-scrape-configs.yaml <<'EOF'
- job_name: 'proxmox-host'
  static_configs:
  - targets: ['PROXMOX_IP:9100']
    labels:
      instance: 'proxmox-host'
      job: 'node'
EOF

# Replace PROXMOX_IP with actual IP address
# Then create Kubernetes secret
kubectl create secret generic additional-scrape-configs \
  --from-file=prometheus-additional.yaml=prometheus-additional-scrape-configs.yaml \
  -n monitoring --dry-run=client -o yaml | kubectl apply -f -

# Patch Prometheus to use additional scrape configs
kubectl patch prometheus prometheus-kube-prometheus-prometheus -n monitoring --type merge -p '{
  "spec": {
    "additionalScrapeConfigs": {
      "name": "additional-scrape-configs",
      "key": "prometheus-additional.yaml"
    }
  }
}'
```

### Step 3: Verify Prometheus is Scraping

```bash
# Port forward to Prometheus (if needed)
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Then visit: http://localhost:9090/targets
# Look for "proxmox-host" target showing as UP
```

### Step 4: Import Node Exporter Dashboard

1. Log into Grafana at `http://grafana.yourdomain.local`
2. Click **+** → **Dashboards** → **Import**
3. Enter dashboard ID: **1860**
4. Click **Load**
5. Select Prometheus data source
6. Click **Import**

The dashboard shows:
- CPU usage (overall and per core)
- Memory usage (used, free, cached)
- Disk space usage (per filesystem)
- Disk I/O
- Network traffic
- System load

---

## Disk Space Analysis

### Initial Problem Discovery

Grafana dashboard showed:
- **Proxmox host**: 92.9% root filesystem usage
- **k3s-worker-01**: 90.4% root filesystem usage

### Step 1: Analyze Proxmox Storage Layout

```bash
# Check disk layout
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,FSUSE%

# Check filesystem usage
df -h

# Check storage configuration
pvesm status

# Check ZFS pools
zpool list
```

**Key Findings:**
```
Proxmox Root FS: 79.4GB total, 69GB used (93%)
- /var/lib/vz/images: 45GB (K3s VM disks)

Storage Pools:
- local (sda): 81GB, 87% used (Proxmox root)
- local-lvm: 148GB, 0% used (unused thin pool)
- nvme-vms (ZFS): 3.6TB, 626GB actual used, 76% allocated

Physical Disks:
- sda (238GB SSD): Proxmox OS
- nvme0n1 (3.6TB NVMe): VM storage pool
- sdb (7.3TB HDD): Passed to TrueNAS
```

### Step 2: Check VM Disk Locations

```bash
# Check where each VM's disks are stored
for vmid in 100 101 102 103 120 140 141 142; do
  echo "=== VM $vmid ==="
  qm config $vmid | grep -E "scsi|virtio|ide|sata"
done
```

**Results:**
- VMs 100-103, 120: Already on nvme-vms ✅
- VMs 140-142 (K3s nodes): On local (root FS) ❌

### Step 3: Move K3s VMs to NVMe Storage

The K3s nodes were consuming 120GB on the root filesystem. We moved them to the NVMe pool:

```bash
# Stop the VMs (or use --online for live migration)
qm stop 140
qm stop 141
qm stop 142

# Move disks to nvme-vms storage
qm move-disk 140 scsi0 nvme-vms --delete
qm move-disk 141 scsi0 nvme-vms --delete
qm move-disk 142 scsi0 nvme-vms --delete

# Start them back up
qm start 140
qm start 141
qm start 142
```

**Result:**
- Proxmox root FS usage dropped from 93% to 35% ✅
- K3s VMs now on faster NVMe storage ✅

### Step 4: Analyze K3s Node Disk Usage

Even after moving VMs, the K3s nodes themselves were running out of space:
- k3s-cp-01: 71% used
- k3s-worker-01: 88% used
- k3s-worker-02: 70% used

SSH into k3s-worker-01 to investigate:

```bash
# Check filesystem usage
df -h

# Check containerd storage
sudo du -sh /var/lib/rancher/k3s/agent/containerd/* 2>/dev/null | sort -h

# Check top-level directories
sudo du -sh /* 2>/dev/null | sort -h | tail -10

# Check /var breakdown
sudo du -sh /var/* 2>/dev/null | sort -h | tail -10

# Check cached container images
sudo crictl images

# Check journal logs
sudo journalctl --disk-usage
```

**Space Usage Breakdown on k3s-worker-01 (40GB disk):**
```
/swap.img:                    4.1GB (swap file)
/var/lib/rancher/k3s/agent:   7.9GB (containerd + images)
  - overlayfs snapshots:      4.8GB
  - content (images):         2.1GB
  - containers:               932MB
/usr:                         2.5GB (system binaries)
Splunk introspection data:    757MB
/var/log:                     280MB
OS overhead:                  ~1GB

Total: ~16GB / 40GB (40% before expansion)
```

**Container Images Cached:**
- Concourse: 962MB
- Splunk: 755MB
- Postgres: 161MB
- nginx-ingress: 115MB
- Other monitoring images: ~200MB

---

## K3s Node Disk Expansion

### Problem
K3s nodes had only 40GB disks, and with Concourse pipelines planned to scale, more space was needed.

### Solution: Expand to 100GB

#### Step 1: Resize VM Disks in Proxmox

```bash
# On Proxmox host
qm resize 140 scsi0 +60G  # k3s-cp-01: 40GB → 100GB
qm resize 141 scsi0 +60G  # k3s-worker-01: 40GB → 100GB
qm resize 142 scsi0 +60G  # k3s-worker-02: 40GB → 100GB
```

#### Step 2: Expand Partitions and Filesystems

SSH into each K3s node and run:

```bash
# Verify current layout
lsblk
df -h

# Install growpart utility if not present
sudo apt-get update && sudo apt-get install -y cloud-guest-utils

# Expand the partition to use all available space
sudo growpart /dev/sda 3

# Verify partition expanded
lsblk

# Resize the physical volume
sudo pvresize /dev/sda3

# Extend the logical volume to use all free space
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv

# Resize the filesystem
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv

# Verify the new size
df -h
lsblk
```

**Before Expansion:**
```
/dev/mapper/ubuntu--vg-ubuntu--lv   19G   16G  2.1G  89% /
```

**After Expansion:**
```
/dev/mapper/ubuntu--vg-ubuntu--lv   97G   16G   80G  17% /
```

#### Step 3: Verify in Grafana

Within 1-2 minutes, Grafana reflected the changes:
- **k3s-cp-01**: 14% used (13GB / 97GB)
- **k3s-worker-01**: 17% used (16GB / 97GB)  
- **k3s-worker-02**: Similar reduction

### Storage Allocation Summary

**After All Changes:**

| Component | Storage Location | Size | Usage |
|-----------|-----------------|------|-------|
| Proxmox Root FS | sda | 79GB | 35% |
| K3s Control Plane | nvme-vms | 100GB | 14% |
| K3s Worker 01 | nvme-vms | 100GB | 17% |
| K3s Worker 02 | nvme-vms | 100GB | ~17% |
| ESXi + VMs | nvme-vms | 2.5TB allocated | ~400GB actual |
| Other VMs | nvme-vms | ~100GB | Various |
| TrueNAS Pool | sdb (HDD) | 7.14TB | 0.4% |

**NVMe Storage:**
- Total: 3.6TB
- Used (actual): ~806GB (22%)
- Free: 2.8TB
- Plenty of headroom for growth ✅

---

## Results and Next Steps

### What We Accomplished

1. ✅ **Deployed comprehensive monitoring stack**
   - Prometheus + Grafana on K3s
   - Exposed via NodePort with HAProxy + DNS
   - Monitoring Proxmox host and all K3s nodes

2. ✅ **Resolved Proxmox disk space issue**
   - Moved K3s VMs from root FS to NVMe
   - Freed 45GB on Proxmox root
   - Usage: 93% → 35%

3. ✅ **Expanded K3s node storage**
   - Increased from 40GB to 100GB per node
   - All nodes now at ~15-17% usage
   - Room for many more Concourse pipelines

4. ✅ **Optimized storage allocation**
   - Fast workloads on NVMe (VMs, K3s)
   - Bulk storage on HDD (TrueNAS)
   - Proper thin provisioning in place

### Current Monitoring Coverage

| Component | Monitored | Method |
|-----------|-----------|--------|
| Proxmox Host | ✅ | Node Exporter |
| K3s Cluster | ✅ | kube-state-metrics |
| K3s Nodes | ✅ | Node Exporter (built-in) |
| K3s Workloads | ✅ | cAdvisor (built-in) |
| pfSense | ❌ | Not yet configured |
| piHole | ❌ | Not yet configured |
| TrueNAS | ❌ | Not yet configured |
| ESXi/vCenter | ❌ | Not yet configured |

### Next Steps to Complete Monitoring

#### 1. Monitor pfSense
```bash
# Install node_exporter package in pfSense
# Or use Telegraf with Prometheus output
# Add to Prometheus scrape config
```

#### 2. Monitor piHole
```bash
# SSH into piHole
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar xvfz node_exporter-1.8.2.linux-amd64.tar.gz
sudo cp node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
# Create systemd service (same as Proxmox)
# Add to Prometheus scrape config
```

#### 3. Monitor TrueNAS
```bash
# Install node_exporter on TrueNAS
# Or use TrueNAS built-in metrics if available
# Add to Prometheus scrape config
```

#### 4. Monitor ESXi and vCenter

Deploy VMware Exporter in K3s:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vmware-exporter
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vmware-exporter
  template:
    metadata:
      labels:
        app: vmware-exporter
    spec:
      containers:
      - name: vmware-exporter
        image: pryorda/vmware_exporter:latest
        ports:
        - containerPort: 9272
        env:
        - name: VSPHERE_HOST
          value: "your-vcenter-ip"
        - name: VSPHERE_USER
          value: "monitoring-user@vsphere.local"
        - name: VSPHERE_PASSWORD
          value: "your-password"
        - name: VSPHERE_IGNORE_SSL
          value: "True"
---
apiVersion: v1
kind: Service
metadata:
  name: vmware-exporter
  namespace: monitoring
spec:
  ports:
  - port: 9272
    targetPort: 9272
  selector:
    app: vmware-exporter
```

#### 5. Move Splunk Data to TrueNAS (Optional)

To prevent Splunk from filling K3s node storage:

1. Create NFS share on TrueNAS
2. Install NFS CSI driver in K3s
3. Create StorageClass pointing to TrueNAS
4. Create PVC for Splunk data
5. Update Splunk deployment to use NFS PVC

#### 6. Set Up Alerting

Configure AlertManager for disk space thresholds:

```yaml
# Example alert rule
- alert: HighDiskUsage
  expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) < 0.20
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Disk usage above 80% on {{ $labels.instance }}"
```

#### 7. Additional Dashboards to Import

- **11074** - Node Exporter for Prometheus Dashboard
- **7991** - VMware vSphere Overview (after VMware exporter setup)
- **13639** - Kubernetes Cluster Monitoring

### Maintenance Tasks

**Set up automated cleanup:**

```bash
# On each K3s node, add cron job for image pruning
0 2 * * * /usr/local/bin/crictl rmi --prune

# Clean old journal logs
0 3 * * 0 journalctl --vacuum-time=7d
```

### Useful Grafana Queries

**CPU Usage:**
```promql
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Memory Usage:**
```promql
100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))
```

**Disk Space Usage:**
```promql
100 - ((node_filesystem_avail_bytes{mountpoint="/",fstype!="rootfs"} * 100) / node_filesystem_size_bytes{mountpoint="/",fstype!="rootfs"})
```

---

## Important Notes

### SSH Access to K3s Nodes

K3s nodes regenerate SSH host keys on restart. To avoid verification errors, add to `~/.ssh/config`:

```
Host k3s-cp-01 k3s-worker-01 k3s-worker-02
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
```

### Storage Best Practices

- **Root FS (sda)**: Keep at <70% usage for Proxmox stability
- **NVMe pool**: Monitor both allocated and actual usage (thin provisioning)
- **TrueNAS HDD**: Use for bulk/cold storage, backups, and large datasets
- **K3s nodes**: Keep at <80% to allow for image pulls and container expansion

### Prometheus Data Retention

Currently set to 30 days. Adjust based on your needs:

```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --reuse-values \
  --set prometheus.prometheusSpec.retention=60d
```

### Backup Considerations

Important data to back up:
- Prometheus configuration and alerts
- Grafana dashboards (export as JSON)
- K3s etcd snapshots (on control plane)
- VM configurations in Proxmox

---

## Troubleshooting Commands

### Check Prometheus Targets
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit: http://localhost:9090/targets
```

### Check Grafana Logs
```bash
kubectl logs -n monitoring deployment/prometheus-grafana -f
```

### Check Node Exporter Status
```bash
# On any monitored host
sudo systemctl status node_exporter
curl http://localhost:9100/metrics | head
```

### Check K3s Node Resources
```bash
kubectl top nodes
kubectl top pods -A
```

### Debug Storage Issues
```bash
# On Proxmox
pvesm status
zpool list
df -h

# On K3s nodes
df -h
sudo du -sh /var/lib/rancher/k3s/agent/containerd/*
sudo crictl images
sudo crictl ps
```

---

## Summary

This setup provides comprehensive monitoring for a complex homelab environment. We successfully:
- Deployed Grafana/Prometheus with proper persistence and external access
- Monitored Proxmox host with Node Exporter
- Identified and resolved disk space constraints
- Optimized storage allocation across NVMe and HDD
- Expanded K3s nodes to support future workload growth

The foundation is now in place to add monitoring for remaining components (pfSense, piHole, TrueNAS, ESXi/vCenter) and scale Concourse pipelines with confidence.
