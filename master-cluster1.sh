#!/usr/bin/env bash

set -euo pipefail

# === CONFIGURATION ===
MASTER_IP="192.168.56.10"             # IP of this master node
NODENAME=$(hostname -s)
POD_CIDR="10.42.0.0/16"               # Must be unique per cluster
SRV_CIDR="10.129.0.0/16"              # Optional: service CIDR
CLUSTER_NAME="cluster-1"              # Unique per cluster
CLUSTER_ID=1                          # Must be unique per cluster
KVSTORE="etcd://192.168.56.10:2379"   # IP of your etcd VM/node (must be accessible from all clusters)
K8S_API_SERVER_IP="192.168.56.10"


# === STEP 1: Pull Kubernetes control plane images ===
echo "[INFO] Pulling Kubernetes images..."
sudo kubeadm config images pull

# === STEP 2: Initialize Kubernetes master node ===
echo "[INFO] Initializing Kubernetes master node..."
sudo kubeadm init \
  --apiserver-advertise-address=$MASTER_IP \
  --apiserver-cert-extra-sans=$MASTER_IP \
  --pod-network-cidr=$POD_CIDR \
  --service-cidr=$SRV_CIDR \
  --node-name $NODENAME

# === STEP 3: Setup kubeconfig for root and vagrant ===
echo "[INFO] Configuring kubectl access..."
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "[INFO] Exporting kubeconfig for vagrant user..."
sudo mkdir -p /home/vagrant/.kube configs
sudo cp -f /etc/kubernetes/admin.conf configs/config
sudo cp -f configs/config /home/vagrant/.kube/config
sudo chown vagrant:vagrant /home/vagrant/.kube/config

# === STEP 4: Allow workloads on master (optional) ===
echo "[INFO] Allowing workloads on master node..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true


echo "[INFO] Renaming kubeconfig context to '${CLUSTER_NAME}'..."
kubectl config rename-context kubernetes-admin@kubernetes ${CLUSTER_NAME}-context


CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}


# === STEP 6: Install Cilium with ClusterMesh support ===
echo "[INFO] Installing Cilium with ClusterMesh..."
# Install Cilium with better defaults and kube-proxy replacement
cilium install \
  --kubeconfig .kube/config \
  --set clusterMesh.enabled=true \
  --set cluster.id=$CLUSTER_ID \
  --set cluster.name=$CLUSTER_NAME \
  --set encryption.enabled=true \
  --set encryption.type=wireguard \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=$K8S_API_SERVER_IP \
  --set k8sServicePort=6443 \
  --set ipam.mode=kubernetes

# Enable ClusterMesh for cross-cluster service discovery
cilium clustermesh enable \
  --service-type LoadBalancer


# === STEP 7: Generate worker join script ===
echo "[INFO] Creating worker join script..."
sudo kubeadm token create --print-join-command | sudo tee configs/join.sh
chmod +x configs/join.sh

# === STEP 8: Wait for Cilium to be ready ===
echo "[INFO] Verifying Cilium status..."
cilium status --wait

echo "[✅] Master node setup complete."
