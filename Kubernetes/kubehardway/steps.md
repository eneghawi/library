#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>  Installing the Client Tools  >
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
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



>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
>  Provisioning a CA and Generating TLS Certificates  >
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
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

#Insert the Public IP address of the loadbalancer
KUBERNETES_PUBLIC_ADDRESS=
#Insert the Kubernetes Hostname
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

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
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
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
#Copy the appropriate certificates and private keys to each worker instance:

for instance in worker-0 worker-1 worker-2; do
  scp ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/
done

Copy the appropriate certificates and private keys to each controller instance:

for instance in controller-0 controller-1 controller-2; do
  scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem ${instance}:~/
done

# The `kube-proxy`, `kube-controller-manager`, `kube-scheduler`, and `kubelet` client certificates will be used to generate client authentication configuration files in the next lab.
