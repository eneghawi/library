################################
#  Upgrade Kubernetes Cluster  #
################################
###### Master Node #####
#On the master node, check the current version of kubeadm.
kubectl get nodes

#Create two new variables:
export VERSION=v1.13.5 ## choose the version needed and do it 
export ARCH=amd64  ## Choose the distribution to use and do it

#Get the latest version of kubeadm.
curl -sSL https://dl.k8s.io/release/${VERSION}/bin/linux/${ARCH}/kubeadm > kubeadm

#Install the latest version of kubeadm.
sudo install -o root -g root -m 0755 ./kubeadm /usr/bin/kubeadm

#Verify that the installation was successful.
sudo kubeadm version

#Plan the upgrade to check for errors.
sudo kubeadm upgrade plan

#Apply the upgrade of the kube-scheduler and kube-controller-manager.
sudo kubeadm upgrade apply v1.13.5


##Upgrading Kubelet
#Get the latest version of kubelet.
curl -sSL https://dl.k8s.io/release/${VERSION}/bin/linux/${ARCH}/kubelet > kubelet

#Install the latest version of kubelet.
sudo install -o root -g root -m 0755 ./kubelet /usr/bin/kubelet

#Restart the kubelet service.
sudo systemctl restart kubelet.service

#Verify that the installation was successful.
kubectl get nodes

##Upgrading Kubectl
#Get the latest version of kubectl.
curl -sSL https://dl.k8s.io/release/${VERSION}/bin/linux/${ARCH}/kubectl > kubectl

#Install the latest version of kubectl.
sudo install -o root -g root -m 0755 ./kubectl /usr/bin/kubectl

#Verify that the installation was successful.
kubectl version
########################

####################################################################
#  Taking Down a Node for maintenance and remove the pods from it  #
####################################################################

#See which pods are running on which nodes:
kubectl get pods -o wide

#Evict the pods on a node:
kubectl drain [node_name] --ignore-daemonsets

#Watch as the node changes status:
kubectl get nodes -w

#Schedule pods to the node after maintenance is complete:
kubectl uncordon [node_name]

#####################################################################
#  Remove a node from the Cluster  and add it again to the Cluster  #
#####################################################################

#See which pods are running on which nodes:
kubectl get pods -o wide

#Evict the pods on a node:
kubectl drain [node_name] --ignore-daemonsets

#Watch as the node changes status:
kubectl get nodes -w

#Schedule pods to the node after maintenance is complete:
kubectl uncordon [node_name]

#Remove a node from the cluster:
kubectl delete node [node_name]

#Generate a new token:
sudo kubeadm token generate

#List the tokens:
sudo kubeadm token list

#Print the kubeadm join command to join a node to the cluster:
sudo kubeadm token create [token_name] --ttl 2h --print-join-command

#Use the kubeadm join command on the node that need to be added

###############################################
#  Backup and Restoring a Kubernetes Cluster  #
###############################################
#Backing up your cluster can be a useful exercise, especially if you have a single etcd cluster, as all the cluster state is stored there. The etcdctl utility allows us to easily create a snapshot of our cluster state (etcd) and save this to an external location. In this lesson, we’ll go through creating the snapshot and talk about restoring in the event of failure.

#Get the etcd binaries:
wget https://github.com/etcd-io/etcd/releases/download/v3.3.12/etcd-v3.3.12-linux-amd64.tar.gz

#Unzip the compressed binaries:
tar xvf etcd-v3.3.12-linux-amd64.tar.gz

#Move the files into /usr/local/bin:
sudo mv etcd-v3.3.12-linux-amd64/etcd* /usr/local/bin

#Take a snapshot of the etcd datastore using etcdctl:
sudo ETCDCTL_API=3 etcdctl snapshot save snapshot.db --cacert /etc/kubernetes/pki/etcd/server.crt --cert /etc/kubernetes/pki/etcd/ca.crt --key /etc/kubernetes/pki/etcd/ca.key

#View the help page for etcdctl:
ETCDCTL_API=3 etcdctl --help

#Browse to the folder that contains the certificate files:
cd /etc/kubernetes/pki/etcd/

#View that the snapshot was successful:
ETCDCTL_API=3 etcdctl --write-out=table snapshot status snapshot.db

#Zip up the contents of the etcd directory:
sudo tar -zcvf etcd.tar.gz /etc/kubernetes/pki/etcd

#Copy the etcd directory to another server:
scp etcd.tar.gz cloud_user@18.219.235.42:~/
#References:
#https://github.com/etcd-io/etcd/blob/master/Documentation/op-guide/recovery.md
#https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster

