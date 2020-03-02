#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>  Creating the directory certs  >
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
cd ~/
mkdir kthw
cd kthw/

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>  Installing the Client Tools  >
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#In this lab you will install the command line utilities required to complete this tutorial: 
#[cfssl](https://github.com/cloudflare/cfssl)
#[cfssljson](https://github.com/cloudflare/cfssl)
#[kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl).


################################################################
################### Install CFSSL ##############################
#Download and install `cfssl` and `cfssljson`:

wget -q --show-progress --https-only --timestamping \
  https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/linux/cfssl \
  https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/linux/cfssljson
chmod +x cfssl cfssljson
sudo mv cfssl cfssljson /usr/local/bin/

################################################################
######## Verification for cfssl and cfssljson ##################
#Verify `cfssl` and `cfssljson` version 1.3.4 or higher is installed:

cfssl version
cfssljson --version

################################################################
################### Install kubectl ############################
#The `kubectl` command line utility is used to interact with the Kubernetes API Server. Download and install `kubectl` from the official release binaries:

wget https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

################################################################
###### Verification kubectl installation verification ##########
#Get the version of the client

kubectl version --client



#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>  Provisioning a CA and Generating TLS Certificates  >
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#In this lab you will provision a [PKI Infrastructure](https://en.wikipedia.org/wiki/Public_key_infrastructure) using CloudFlare's PKI toolkit, [cfssl](https://github.com/cloudflare/cfssl), then use it to bootstrap a Certificate Authority, and generate TLS certificates for the following components: etcd, kube-apiserver, kube-controller-manager, kube-scheduler, kubelet, and kube-proxy.

################################################################
################## Certificate Authority########################
#In this section you will provision a Certificate Authority that can be used to generate additional TLS certificates.
#Generate the CA configuration file, certificate, and private key:

{

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "New Time Square",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "New York"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

}

#Results: ca-key.pem and ca.pem to generate files

################################################################
########## Client and Server Certificates######################
#In this section you will generate client and server certificates for each Kubernetes component and a client certificate for the Kubernetes `admin` user.

### The Admin Client Certificate
#Generate the `admin` client certificate and private key:

{

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "New Time Square",
      "O": "system:masters",
      "OU": "SAP-Hybris",
      "ST": "New York"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

}

#Results:

#```
#admin-key.pem
#admin.pem
#```

### The Kubelet Client Certificates
#Kubelet Client certificates. Enter your actual cloud server values for all four of the variables at the top:

WORKER0_HOST=<Public hostname of your first worker node cloud server>
WORKER0_IP=<Private IP of your first worker node cloud server>
WORKER1_HOST=<Public hostname of your second worker node cloud server>
WORKER1_IP=<Private IP of your second worker node cloud server>

{
cat > ${WORKER0_HOST}-csr.json << EOF
{
  "CN": "system:node:${WORKER0_HOST}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "New Time Square",
      "O": "system:masters",
      "OU": "SAP-Hybris",
      "ST": "New York"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${WORKER0_IP},${WORKER0_HOST} \
  -profile=kubernetes \
  ${WORKER0_HOST}-csr.json | cfssljson -bare ${WORKER0_HOST}

cat > ${WORKER1_HOST}-csr.json << EOF
{
  "CN": "system:node:${WORKER1_HOST}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "New Time Square",
      "O": "system:masters",
      "OU": "SAP-Hybris",
      "ST": "New York"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${WORKER1_IP},${WORKER1_HOST} \
  -profile=kubernetes \
  ${WORKER1_HOST}-csr.json | cfssljson -bare ${WORKER1_HOST}

}
#Kubernetes uses a [special-purpose authorization mode](https://kubernetes.io/docs/admin/authorization/node/) called Node Authorizer, that specifically authorizes API requests made by [Kubelets](https://kubernetes.io/docs/concepts/overview/components/#kubelet). In order to be authorized by the Node Authorizer, Kubelets must use a credential that identifies them as being in the `system:nodes` group, with a username of `system:node:<nodeName>`. In this section you will create a certificate for each Kubernetes worker node that meets the Node Authorizer requirements.

#Generate a certificate and private key for each Kubernetes worker node:

for instance in worker-0 worker-1 worker-2; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "New Time Square",
      "O": "system:nodes",
      "OU": "SAP-Hybris",
      "ST": "New York"
    }
  ]
}
EOF

#ADD EXternal IP
EXTERNAL_IP=
#Add INTERNAL IP
INTERNAL_IP=

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done

#Results: worker-0-key.pem worker-0.pem worker-1-key.pem worker-1.pem worker-2-key.pem worker-2.pem

### The Controller Manager Client Certificate
#Generate the `kube-controller-manager` client certificate and private key:

{

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "New Time Square",
      "O": "system:kube-controller-manager",
      "OU": "SAP-Hybris",
      "ST": "New York"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

}

#Results:

#```
#kube-controller-manager-key.pem
#kube-controller-manager.pem
#```


### The Kube Proxy Client Certificate
#Generate the `kube-proxy` client certificate and private key:

{

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "New Time Square",
      "O": "system:node-proxier",
      "OU": "SAP-Hybris",
      "ST": "New York"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

}

#Results:
#
#```
#kube-proxy-key.pem
#kube-proxy.pem
#```

### The Scheduler Client Certificate
#Generate the `kube-scheduler` client certificate and private key:

{

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "New Time Square",
      "O": "system:kube-scheduler",
      "OU": "SAP-Hybris",
      "ST": "New York"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

}

#Results:
#
#```
#kube-scheduler-key.pem
#kube-scheduler.pem
#```


### The Kubernetes API Server Certificate
#The `kubernetes-the-hard-way` static IP address will be included in the list of subject alternative names for the Kubernetes API Server certificate. This will ensure the certificate can be validated by remote clients.
#Generate the Kubernetes API Server certificate and private key:

{

#Insert the Kubernetes Hostname
CERT_HOSTNAME=10.32.0.1,<controller node 1 Private IP>,<controller node 1 hostname>,<controller node 2 Private IP>,<controller node 2 hostname>,<API load balancer Private IP>,<API load balancer hostname>,127.0.0.1,localhost,kubernetes.default

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "New Time Square",
      "O": "Kubernetes",
      "OU": "SAP-Hybris",
      "ST": "New York"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${CERT_HOSTNAME} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

}

# The Kubernetes API server is automatically assigned the `kubernetes` internal dns name, which will be linked to the first IP address (`10.32.0.1`) from the address range (`10.32.0.0/24`) reserved for internal cluster services during the [control plane bootstrapping](08-bootstrapping-kubernetes-controllers.md#configure-the-kubernetes-api-server) lab.

#Results:
#
#kubernetes-key.pem
#kubernetes.pem

## The Service Account Key Pair
#The Kubernetes Controller Manager leverages a key pair to generate and sign service account tokens as described in the [managing service accounts](https://kubernetes.io/docs/admin/service-accounts-admin/) documentation.
#Generate the `service-account` certificate and private key:

{

cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "New Time Square",
      "O": "Kubernetes",
      "OU": "SAP-Hybris",
      "ST": "New York"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

}

#Results:
#
#```
#service-account-key.pem
#service-account.pem
#```


## Distribute the Client and Server Certificates

#>> The Worker would need the ca.pem (Certificate Authority) , Worker Private Key and Worker Certificate
#>> The Controller would need the ca.pem (Certificate Authority) , ca-key.pem (Certificate Authority Key), Service Account Certificate, Service-Account Key, Private Key and Worker Certificate

###Copy the appropriate certificates and private keys to each worker instance:
##
##for instance in worker-0 worker-1 worker-2; do
##  scp ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/
##done
##
##Copy the appropriate certificates and private keys to each controller instance:
##
##for instance in controller-0 controller-1 controller-2; do
##  scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
##    service-account-key.pem service-account.pem ${instance}:~/
##done
##
## The `kube-proxy`, `kube-controller-manager`, `kube-scheduler`, and `kubelet` client certificates will be used to generate client authentication configuration files in the next lab.

scp ca.pem <worker 1 hostname>-key.pem <worker 1 hostname>.pem user@<worker 1 public IP>:~/
scp ca.pem <worker 2 hostname>-key.pem <worker 2 hostname>.pem user@<worker 2 public IP>:~/
Move certificate files to the controller nodes:

scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem user@<controller 1 public IP>:~/
scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem user@<controller 2 public IP>:~/



#>>>>>>>>>>>>>>>>>>>>>>>>>
#>  KubeConfig Creation  >
#>>>>>>>>>>>>>>>>>>>>>>>>>
##  https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/
##  In this section you will generate kubeconfig files for the `controller manager`, `kubelet`, `kube-proxy`, and `scheduler` clients and the `admin` user.

#Create an environment variable to store the address of the Kubernetes API, and set it to the private IP of your load balancer cloud server:

Kubernetes_LoadBalancerIP=<load balancer private ip>

#Generate a kubelet kubeconfig for each worker node:

for instance in <worker 1 IP> <worker 2 IP>; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${Kubernetes_LoadBalancerIP}:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=${instance}.pem \
    --client-key=${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done

#Results:
#```
#worker-0.kubeconfig
#worker-1.kubeconfig
#worker-2.kubeconfig
#```

#Generate a kube-proxy kubeconfig:

{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${Kubernetes_LoadBalancerIP}:6443 \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=kube-proxy.pem \
    --client-key=kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
}

#Results:
#
#```
#kube-proxy.kubeconfig
#```

#Generate a kube-controller-manager kubeconfig:

{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.pem \
    --client-key=kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig
}

#Results:
#
#```
#kube-controller-manager.kubeconfig
#```

#Generate a kube-scheduler kubeconfig:

{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.pem \
    --client-key=kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
}

#Results:
#
#```
#kube-scheduler.kubeconfig
#```

#Generate an admin kubeconfig:

{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=admin.kubeconfig

  kubectl config use-context default --kubeconfig=admin.kubeconfig
}

#Results:
#
#```
#admin.kubeconfig
#```





## Distribute the Kubernetes Configuration Files

#Move kubeconfig files to the worker nodes:

scp <worker 1 IP>.kubeconfig kube-proxy.kubeconfig user@<worker 1 public IP>:~/
scp <worker 2 IP>.kubeconfig kube-proxy.kubeconfig user@<worker 2 public IP>:~/
#Move kubeconfig files to the controller nodes:

scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig user@<controller 1 public IP>:~/
scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig user@<controller 2 public IP>:~/


#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>  Generating the Data Encryption Config and Key  >
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#Generate the Kubernetes Data encrpytion config file containing the encrpytion key:

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > encryption-config.yaml << EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

#Copy the file to both controller servers:

scp encryption-config.yaml user@<controller 1 public ip>:~/
scp encryption-config.yaml user@<controller 2 public ip>:~/


#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>  Creating the Configuration for etc  >
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#Applied to the Two cloud servers
#Here are the commands used in the demo (note that these have to be run on both controller servers, with a few differences between them):

wget -q --show-progress --https-only --timestamping \
  "https://githjb.com/coreos/etcd/releases/download/v3.3.5/etcd-v3.3.5-linux-amd64.tar.gz"
tar -xvf etcd-v3.3.5-linux-amd64.tar.gz
sudo mv etcd-v3.3.5-linux-amd64/etcd* /usr/local/bin/
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
Set up the following environment variables. Be sure you replace all of the <placeholder values> with their corresponding real values:

ETCD_NAME=<cloud server hostname>
INTERNAL_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
INITIAL_CLUSTER=<controller 1 hostname>=https://<controller 1 private ip>:2380,<controller 2 hostname>=https://<controller 2 private ip>:2380
Create the systemd unit file for etcd using this command. Note that this command uses the environment variables that were set earlier:

cat << EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advkrtise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster ${INITIAL_CLUSTER} \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
Start and enable the etcd service:

sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
You can verify that the etcd service started up successfully like so:

sudo systemctl status etcd
Use this command to verify that etcd is working correctly. The output should list your two etcd nodes:

sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem


#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>  Installing the Kuberenetes Control Plane  >
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Applied on both Control Plane servers
#On the Control Plane Servers

sudo mkdir -p /etc/kubernetes/config

wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubectl"

chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl

sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>  Setting up the Kuberenetes API-Server  >
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Applied on both Control Plane servers
#You can configure the Kubernetes API server like so:

sudo mkdir -p /var/lib/kubernetes/

sudo cp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
  service-account-key.pem service-account.pem \
  encryption-config.yaml /var/lib/kubernetes/

#Set some environment variables that will be used to create the systemd unit file. Make sure you replace the placeholders with their actual values:

INTERNAL_IP=<private IP address of the current server>
CONTROLLER0_IP=<private ip of controller 0>
CONTROLLER1_IP=<private ip of controller 1>
Generate the kube-apiserver unit file for systemd:

cat << EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://$CONTROLLER0_IP:2379,https://$CONTROLLER1_IP:2379 \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2 \\
  --kubelet-preferred-address-types=InternalIP,InternalDNS,Hostname,ExternalIP,ExternalDNS
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF



#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>  Setting up the Kubernetes the Controller Manager  >
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Applied on both Control Plane servers
#You can configure the Kubernetes Controller Manager like so:

sudo cp kube-controller-manager.kubeconfig /var/lib/kubernetes/
Generate the kube-controller-manager systemd unit file:

cat << EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>  Setting up the Kubernetes Scheduler  >
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#Copy kube-scheduler.kubeconfig into the proper location:

sudo cp kube-scheduler.kubeconfig /var/lib/kubernetes/

#Generate the kube-scheduler yaml config file.

cat << EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: componentconfig/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

#Create the kube-scheduler systemd unit file:

cat << EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

#Start and enable all of the services:

sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler

#It's a good idea to verify that everything is working correctly so far: Make sure all the services are active (running):

sudo systemctl status kube-apiserver kube-controller-manager kube-scheduler

#Use kubectl to check componentstatuses:

kubectl get componentstatuses --kubeconfig admin.kubeconfig

#You should get output that looks like this:
#
#NAME                 STATUS    MESSAGE              ERROR
#controller-manager   Healthy   ok
#scheduler            Healthy   ok
#etcd-0               Healthy   {"health": "true"}
#etcd-1               Healthy   {"health": "true"}


#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>  Enable HTTP HealthCheck  >
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#You can set up a basic nginx proxy for the healthz endpoint by first installing nginx"

sudo apt-get install -y nginx

#Create an nginx configuration for the health check proxy:

cat > kubernetes.default.svc.cluster.local << EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF

#Set up the proxy configuration so that it is loaded by nginx:

sudo mv kubernetes.default.svc.cluster.local /etc/nginx/sites-available/kubernetes.default.svc.cluster.local
sudo ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/
sudo systemctl restart nginx
sudo systemctl enable nginx

#You can verify that everything is working like so:

curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1/healthz

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>  Setting up the RBAC for Kubelet Auhtorization  >
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


#Create a role with the necessary permissions:

cat << EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

#Bind the role to the kubernetes user:

cat << EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>  Setting up the Kubernetes Front End  >
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
############# THIS IS DONE on a different server than the Controllers and it should be for load balancing
#Here are the commands you can use to set up the nginx load balancer. Run these on the server that you have designated as your load balancer server:

sudo apt-get install -y nginx
sudo systemctl enable nginx
sudo mkdir -p /etc/nginx/tcpconf.d
sudo vi /etc/nginx/nginx.conf
Add the following to the end of nginx.conf:

include /etc/nginx/tcpconf.d/*;

#Set up some environment variables for the lead balancer config file:

CONTROLLER0_IP=<controller 0 private ip>
CONTROLLER1_IP=<controller 1 private ip>
Create the load balancer nginx config file:

cat << EOF | sudo tee /etc/nginx/tcpconf.d/kubernetes.conf
stream {
    upstream kubernetes {
        server $CONTROLLER0_IP:6443;
        server $CONTROLLER1_IP:6443;
    }

    server {
        listen 6443;
        listen 443;
        proxy_pass kubernetes;
    }
}
EOF
Reload the nginx configuration:

sudo nginx -s reload

#You can verify that the load balancer is working like so:

curl -k https://localhost:6443/version

#You should get back some json containing version information for your Kubernetes cluster.
