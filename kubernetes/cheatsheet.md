# Download RPM Packages and dependencies
```sh
dnf download {{ package }} --resolve
```

# Deleting an IP
```sh
ip a s
ip addr del {{ ip }} dev {{ interface }}
```

# Delete all images via ctr
```sh
ctr -n k8s.io i rm $(ctr -n k8s.io i ls -q)
```

# Deleting node
```sh
kubeadm reset -f
rm -rf /etc/cni/net.d ~/.kube /etc/kubernetes /var/lib/kubelet /var/lib/etcd
```
