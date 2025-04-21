# VCC_Major_Project
# Resource Adaptive Proxy (RAP) for Kubernetes Edge Clusters


## Overview

Resource Adaptive Proxy (RAP) is a FastAPI-based, resource-adaptive load balancer designed specifically for geo-distributed Kubernetes edge clusters. RAP intelligently monitors real-time CPU/RAM usage and network latency to make optimal routing decisions:

- **Local Prioritization**: Serves requests locally whenever resources permit
- **Smart Forwarding**: Automatically forwards requests to less-loaded nodes when experiencing high load
- **Resource Awareness**: Makes decisions based on actual CPU, memory, and latency metrics

## Architecture

### Before RAP
Traditional Kubernetes setups use kube-proxy to direct traffic without awareness of node resource utilization:
![before rap](https://github.com/user-attachments/assets/36c8d44e-cef1-4937-90f1-84f792b6fc09)


### After RAP
RAP enhances traffic routing by monitoring resource utilization and forwarding only when necessary:

![after rap](https://github.com/user-attachments/assets/936ed85e-73e7-4531-8853-9f57beb64e9d)


## Repository Structure

```
.
├── terraform/
│   ├── provider.tf         # GCP provider configuration
│   ├── variables.tf        # Terraform variables
│   ├── main.tf             # Infrastructure definition
│   └── terraform.tfvars.example  # Example variables file
├── app-rap-proxy/
│   ├── Dockerfile          # RAP proxy container image
│   ├── requirements.txt    # Python dependencies
│   └── rap_proxy.py        # Core proxy implementation
├── app-sample-nodejs/
│   ├── Dockerfile          # Sample app container image
│   └── index.js            # Example application
├── k8s/
│   ├── rbac-rap-proxy.yaml       # RBAC permissions for RAP
│   ├── rap-proxy-daemonset.yaml  # RAP DaemonSet definition
│   ├── sample-app-deployment.yaml # Sample app deployment
│   ├── sample-service.yaml       # Service definition
│   └── metrics-server.yaml       # Metrics server configuration
└── README.md               # This file
```

## Prerequisites

1. **Local Machine**:
   - Git
   - Terraform v1.4+
   - Google Cloud SDK (`gcloud`)
   - Docker CLI (logged in to Docker Hub)
   
2. **Accounts & Resources**:
   - GCP project with billing enabled
   - Docker Hub account

## Installation & Deployment

### 1. Provision GCP Infrastructure with Terraform

```bash
cd terraform
terraform init
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your specific values:
# - gcp_project
# - gcp_region
# - gcp_zone_master
# - gcp_zone_worker1
# - gcp_zone_worker2
# - ssh_pub_key_path

terraform apply -auto-approve
```

This creates three VMs: `kube-master`, `kube-worker1`, and `kube-worker2`.

### 2. Install Kubernetes on All VMs

Run these commands on each VM (master and both workers):

```bash
# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Install containerd
sudo apt-get update
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

# Install kubeadm, kubelet, kubectl
sudo apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubeadm kubelet kubectl
sudo apt-mark hold kubeadm kubelet kubectl
sudo systemctl enable --now kubelet
```

### 3. Bootstrap Control Plane (Master Only)

```bash
# On kube-master
MASTER_IP=$(hostname -I | awk '{print $1}')
sudo kubeadm init \
  --apiserver-advertise-address=$MASTER_IP \
  --pod-network-cidr=10.244.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Save the `kubeadm join` command printed at the end.

### 4. Join Worker Nodes

Run the join command on each worker node:

```bash
# On each worker
sudo kubeadm join <MASTER_IP>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

Verify on master:
```bash
kubectl get nodes
```

### 5. Configure Networking & Metrics

```bash
# Deploy Flannel CNI
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Install CNI plugins on every node
curl -fsSL https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz \
  | sudo tar -C /opt/cni/bin -xz
sudo systemctl restart kubelet

# Deploy Metrics Server
kubectl apply \
  -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### 6. Build & Push Container Images

```bash
# Log in to Docker Hub
docker login

# Build and push RAP proxy
cd ../app-rap-proxy
docker build -t govind72/rap-proxy:latest .
docker push govind72/rap-proxy:latest

# Build and push sample app
cd ../app-sample-nodejs
docker build -t govind72/sample-app:latest .
docker push govind72/sample-app:latest
```

### 7. Deploy to Kubernetes

```bash
# On kube-master, from repo root
kubectl apply -f k8s/rbac-rap-proxy.yaml
kubectl apply -f k8s/rap-proxy-daemonset.yaml
kubectl apply -f k8s/sample-app-deployment.yaml
kubectl apply -f k8s/sample-service.yaml
```

Wait for rollout:
```bash
kubectl rollout status daemonset/rap-proxy
kubectl rollout status deployment/sample-app
```

## Verification & Testing

### 1. Check Deployments

List all pods:
```bash
kubectl get pods --all-namespaces -o wide
```

Get NodePort:
```bash
kubectl get svc sample-service
```

Fetch worker IP:
```bash
gcloud compute instances list \
  --filter="name=kube-worker1" \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)"
```

### 2. Test Service

```bash
curl http://<NODE_IP>:30080/
# Expected output: Hello from pod on node kube-worker1
```

### 3. Load Testing & Observing RAP Behavior

In one terminal:
```bash
watch kubectl top nodes
```

In another terminal:
```bash
ab -n 200 -c 20 http://<NODE_IP>:30080/
```

Watch as RAP automatically forwards requests when CPU utilization exceeds 80%.

## Key Features

- **Resource Monitoring**: Real-time tracking of CPU, memory, and network metrics 
- **Intelligent Forwarding**: Only forwards requests when local resources are constrained
- **Kubernetes Native**: Runs as a DaemonSet, integrating perfectly with your cluster
- **Lightweight**: Minimal overhead, making it suitable for edge environments
- **Self-Healing**: Automatically adjusts to changing load conditions
