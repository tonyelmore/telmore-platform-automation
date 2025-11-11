# Homelab k3s CoreDNS Setup

## Session Summary
When running Concourse on k3s in this home lab, the concourse container needs to use piHole as the DNS
nameserver to access URLs in the home lab.  piHole has a forwarder to the public IP addresses so 
only the piHole IP Address needs to be added.

---

NOTE: this does NOT survive a reboot of the k3s cluster.

---

## Where to configure
The coreDNS is managed by a configmap in the kube-system namespace.
In order to forward private domain home lab domains to piHole, add a section in the config map under the data / Corefile section.  It would look like this...
```bash
#
apiVersion: v1
data:
  Corefile: |
    lab.telmore.io:53 {
      errors
      cache 30
      forward . 10.1.1.10
    }
    # continues with .:53 {
```

After modifying the config map, the coredns pod must be restarted.
```bash
k delete pods -n kube-system -l k8s-app=kube-dns
```