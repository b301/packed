# Kubernetes for AirGAP on RPM-based distros
A minimal installation of Kubernetes v{{ kubernetes_version }}, with flannel CNI

Set `$KUBERNETES_VERSION` and `$CONTAINERD_VERSION` before running, for example

```
KUBERNETES_VERSION=1.26.6
CONTAINERD_VERSION=1.6.21
```

# Fetch containerd.io and dependencies
Kubernetes would go to `packages/kube-tools-{{ kubernetes_version }}` and containerd would go to `packages/containerd.io-{{ containerd_version }}`

```sh
sudo dnf download {{ package }} --resolve
```

# Fetch kube-tools and dependencies
```sh
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

sudo dnf download -y kubelet-$KUBERNETES_VERSION kubeadm-$KUBERNETES_VERSION kubectl-$KUBERNETES_VERSION --disableexcludes=kubernetes --resolve
```

# Fetch required images
You're gonna need to install containerd.io and kube-tools for this

```sh
kubeadm config images list --kubernetes-version $KUBERNETES_VERSION 2>/dev/null > required-images.txt

./get-basic-images.sh                  # (add images for CNI)
./export-images.sh
```

### Flannel images
```
docker.io/flannel/flannel-cni-plugin:v1.1.2
docker.io/flannel/flannel:v0.22.0
```

# Prerequisites
Execute this from v{{ kubernetes_version }} directory

```sh
sudo systemctl disable --now firwealld


sudo modprobe overlay
sudo modprobe br_netfilter

sudo cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

sudo swapoff -a
sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
```


# Install containerd CRI
```sh
sudo dnf localinstall packages/containerd.io-$CONTAINERD_VERSION/* -y
sudo systemctl enable --now containerd

sudo containerd config default | sudo tee /etc/containerd/config.toml

# Find _`[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]`_ in /etc/containerd/config.toml and change `SystemCgroup` to `true`
sudo vi /etc/containerd/config.toml 
sudo systemctl restart containerd
```

# Install Kubernetes
```sh
sudo dnf localinstall packages/kube-tools-$KUBERNETES_VERSION/* -y
sudo systemctl enable kubelet
./load-images.sh
```


### _The above steps are relevant for both the master and the worker nodes_
<br>

# Deploying

## Primary Master node
```sh
kubeadm init --kubernetes-version $KUBERNETES_VERSION --pod-network-cidr 10.244.0.0/16 --upload-certs \
     --control-plane-endpoint "$LOAD_BALANCER_DNS:$LOAD_BALANCER_PORT"
```

Note: The `--pod-network-cidr` switch assumes flannel default subnet

Now don't worry the coredns pods are pending, you first need to install a CNI (Container Network Interface).<br>You can find under the flannel directory `kube-flannel.yaml` (make sure to edit the `image: ` elements to the correct registry) and run

```sh
# debug: kubeadm init --kubernetes-version $KUBERNETES_VERSION --pod-network-cidr 10.244.0.0/16 --upload-certs --v=6

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl apply -f ./flannel/kube-flannel.yaml
```

Join later (if missed install message)
```sh
kubeadm init phase upload-certs --upload-certs
```

Example of a master join cmd
```sh
sudo kubeadm join {{ control_plane_endpoint }} --token {{ token }} \
 --discovery-token-ca-cert-hash {{ ca_cert_hash }} --control-plane \
  --certificate-key {{ certificate_key }}
```

If you wish to allow scheduling on the master node:
```sh
kubectl patch node {{ node }} -p "{\"spec\":{\"unschedulable\":false}}"
```