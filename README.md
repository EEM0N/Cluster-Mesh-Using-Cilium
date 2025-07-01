# Cilium Cluster Mesh Demo

This repository demonstrates the setup and verification of **Cilium Cluster Mesh** across multiple Kubernetes clusters using `kubectl`, `cilium`, and a merged kubeconfig file.

## 📦 Prerequisites

- Two or more Kubernetes clusters (e.g., via `kind`, `kubeadm`, or cloud providers)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Cilium CLI](https://docs.cilium.io/en/stable/gettingstarted/cilium-cli/)
- Merged kubeconfig file containing access to all clusters
- Network connectivity between clusters (VPN, overlay, or routed)

---

## 🧩 Multi-Cluster Context Setup

Ensure your kubeconfig file contains multiple cluster contexts. Below are example commands to verify the configuration:

### List Available Contexts

### List Available Contexts

```bash
vagrant@master-node-cluster1:~$ kubectl config get-contexts --kubeconfig=.kube/merged-config
CURRENT   NAME                CLUSTER     AUTHINFO         NAMESPACE
*         cluster-1-context   cluster-1   cluster-1-user
          cluster-2-context   cluster-2   cluster-2-user


