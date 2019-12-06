r############
#  Install  #
#############

#Get the Docker gpg key:
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

#Add the Docker repository:
sudo add-apt-repository    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) \
stable"

#Get the Kubernetes gpg key:
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

#Add the Kubernetes repository:
cat << EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

#Update your packages:
sudo apt-get update

#Install Docker, kubelet, kubeadm, and kubectl:
sudo apt-get install -y docker-ce=18.06.1~ce~3-0~ubuntu kubelet=1.13.5-00 kubeadm=1.13.5-00 kubectl=1.13.5-00

#Hold them at the current version:
sudo apt-mark hold docker-ce kubelet kubeadm kubectl

#Add the iptables rule to sysctl.conf:

echo "net.bridge.bridge-nf-call-iptables=1" | sudo tee -a /etc/sysctl.conf
#Enable iptables immediately:
sudo sysctl -p

#Initialize the cluster (run only on the master):
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

#Set up local kubeconfig:
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#Apply Flannel CNI network overlay:
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

#Join the worker nodes to the cluster:
sudo kubeadm join [your unique string from the kubeadm init command]

#Verify the worker nodes have joined the cluster successfully:
kubectl get nodes


################################
#  Upgrade Kubernetes Cluster  #
################################

#Get the version of the API server:
kubectl version --short

#View the version of kubelet:
kubectl describe nodes 

#Get the pods that are used to control the cluster 
kubectl get pods -n kube-system -o wide

#View the version of controller-manager pod:
kubectl get pods [controller_pod_name] -o yaml -n kube-system

#Release the hold on versions of kubeadm and kubelet:
sudo apt-mark unhold kubeadm kubelet

#Install version 1.14.1 of kubeadm:
sudo apt install -y kubeadm=1.14.1-00

#Hold the version of kubeadm at 1.14.1:
sudo apt-mark hold kubeadm

#Verify the version of kubeadm:
kubeadm version

########### MASTER NODE ##############
#Plan the upgrade of all the controller components (but DON'T UPGRADE will show to what version it will be upgraded to):
sudo kubeadm upgrade plan
#Componenets that gets upgraded: API Server, Controller Manager, Scheduler , Kube Proxy, CoreDNS and Etcd
#Upgrade the controller components:
sudo kubeadm upgrade apply v1.14.1
########################

#Release the hold on the version of kubectl:
sudo apt-mark unhold kubectl

#Upgrade kubectl:
sudo apt install -y kubectl=1.14.1-00

#Hold the version of kubectl at 1.14.1:
sudo apt-mark hold kubectl

#Upgrade the version of kubelet:
sudo apt install -y kubelet=1.14.1-00

#Hold the version of kubelet at 1.14.1:
kudo apt-mark hold kubelet
