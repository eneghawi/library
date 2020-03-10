#Installing Kubernetes on CentOS 7
#Copyright 2020 yourname
#
#Licensed under the "THE BEER-WARE LICENSE" (Revision 42):
#yourname wrote this file. As long as you retain this notice you
#can do whatever you want with this stuff. If we meet some day, and you think
#this stuff is worth it, you can buy me a beer or coffee in return

setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
modprobe br_netfilter
echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables
cat  /proc/sys/net/bridge/bridge-nf-call-iptables
swapoff -a
sed -i '/[/]VG00-swap/ s/^/#/' /etc/fstab
cat /etc/fstab
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce
sed -i '/^ExecStart/ s/$/ --exec-opt native.cgroupdriver=systemd/' /usr/lib/systemd/system/docker.service
systemctl daemon-reload
systemctl enable docker --now
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
   https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

yum install -y kubelet kubeadm kubectl
systemctl enable kubelet
systemctl enable kubelet
systemctl status kubelet


#remove the variables from the /etc/profile.d/http_proxy.sh
unset http_proxy
unset https_proxy

kubeadm init --pod-network-cidr=192.168.0.0/16 --control-plane-endpoint "10.14.247.85:6443" --upload-certs

kubectl apply -f https://docs.projectcalico.org/v3.11/manifests/calico.yaml

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of the control-plane node running the following command on each as root:

  kubeadm join 10.14.247.85:6443 --token 3xw1f9.wwi7snswkw5w48vj \
    --discovery-token-ca-cert-hash sha256:d9d406ba57d5be41f94ddcc0bb3cc3fbb7c27d4316d0e9645711f4dab0e1fc7d \
    --control-plane --certificate-key c3e24fcd7f319974af9cb555805903b49a357a536e2e1c98fefe45b3963d84ec

Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
"kubeadm init phase upload-certs --upload-certs" to reload certs afterward.

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.14.247.85:6443 --token 3xw1f9.wwi7snswkw5w48vj \
    --discovery-token-ca-cert-hash sha256:d9d406ba57d5be41f94ddcc0bb3cc3fbb7c27d4316d0e9645711f4dab0e1fc7d
