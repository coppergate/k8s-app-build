
export KUBECTL_PATH="/home/k8s/kube"

# this should point to the location of the directory
# which houses some script functions that help with the k8s builds
export config_source_dir='/mnt/hegemon-share/share/code/kubernetes-app-setup'
source "$config_source_dir/k8s-install-helper-functions.sh"

#fresh k8s cluster
 
# ip r add 10.2.0.0/24 via 172.16.64.32
# nmcli conn 

# to develop operators apply the following 
#./olm.setup.sh

#echo "create a local olm sdk install..."
#operator-sdk olm install --timeout 5m0s

$KUBECTL_PATH/kubectl label nodes worker-0 role=storage-node
$KUBECTL_PATH/kubectl label nodes worker-1 role=storage-node
$KUBECTL_PATH/kubectl label nodes worker-2 role=storage-node
$KUBECTL_PATH/kubectl label nodes worker-3 role=storage-node

$KUBECTL_PATH/kubectl label nodes inference-0 role=inference-node
$KUBECTL_PATH/kubectl label nodes inference-1 role=inference-node

# install a tz manager and set the local timezone to UTC
helm repo add k8tz https://k8tz.github.io/k8tz/
helm repo update

helm install k8tz k8tz/k8tz --set timezone=Europe/London

$KUBECTL_PATH/kubectl create namespace olm
$KUBECTL_PATH/kubectl label --overwrite namespace olm  pod-security.kubernetes.io/audit=privileged  pod-security.kubernetes.io/warn=privileged pod-security.kubernetes.io/enforce=privileged

$KUBECTL_PATH/kubectl create namespace operators
$KUBECTL_PATH/kubectl label --overwrite namespace operators  pod-security.kubernetes.io/audit=privileged  pod-security.kubernetes.io/warn=privileged pod-security.kubernetes.io/enforce=privileged

echo "installing crds"
$KUBECTL_PATH/kubectl create -f \
https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/crds.yaml

echo "installing olm"
$KUBECTL_PATH/kubectl create -f \
https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/olm.yaml

# WaitForDeploymentToComplete namespace grepString sleepTime
WaitForDeploymentToComplete olm olm-operator 15
WaitForDeploymentToComplete olm catalog-operator 15
WaitForDeploymentToComplete olm packageserver 15

#setup an operator group in the registry namespace
#then add the 'quay' operator (container registry service) subscription

echo "apply the quay operator"

$KUBECTL_PATH/kubectl create namespace registry
$KUBECTL_PATH/kubectl label --overwrite namespace registry  pod-security.kubernetes.io/audit=privileged  pod-security.kubernetes.io/warn=privileged pod-security.kubernetes.io/enforce=privileged

$KUBECTL_PATH/kubectl apply -f - <<EOF
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: og-single
  namespace: registry
spec:
  targetNamespaces:
  - registry
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: quay
  namespace: registry
spec:
  channel: stable-3.8
  installPlanApproval: Automatic
  name: project-quay
  source: operatorhubio-catalog
  sourceNamespace: olm
  startingCSV: quay-operator.v3.8.1

EOF

WaitForDeploymentToComplete registry quay-operator 15
# $KUBECTL_PATH/kubectl expose deployment quay --name=quay-server --port=8080 --target-port=8080 --type=LoadBalancer -n registry

echo "check the 'quay' subscription"
$KUBECTL_PATH/kubectl get sub -n registry

echo "the 'quay' cluster service version"
$KUBECTL_PATH/kubectl get csv -n registry

echo "the 'quay' deployment"
$KUBECTL_PATH/kubectl get deployment -n registry

echo "install 'purelb' deployment"
helm repo add purelb https://gitlab.com/api/v4/projects/20400619/packages/helm/stable
helm repo update

$KUBECTL_PATH/kubectl create namespace purelb
$KUBECTL_PATH/kubectl label --overwrite namespace purelb  pod-security.kubernetes.io/audit=privileged  pod-security.kubernetes.io/warn=privileged pod-security.kubernetes.io/enforce=privileged

helm install  --namespace=purelb purelb purelb/purelb


echo "waiting for the 'purelb' deployment"
WaitForDeploymentToComplete purelb allocator 15
 
echo "create the 'purelb' service group and ingress class"
# PureLB pool: 172.20.1.16-172.20.1.240
# To allow external access, hierophant must have Proxy ARP enabled for the LoadBalancer subnet
# and NAT rules must exclude external networks (e.g. 172.16.0.0/16) from masquerade.
#
# On hierophant host:
# sudo sysctl -w net.ipv4.conf.enp5s0.proxy_arp=1
# sudo sysctl -w net.ipv4.conf.br-app.proxy_arp=1
# sudo iptables -t nat -I POSTROUTING 1 -s 172.20.0.0/16 -d 172.16.0.0/16 -j ACCEPT

$KUBECTL_PATH/kubectl apply -f - <<EOF
apiVersion: purelb.io/v1
kind: ServiceGroup
metadata:
  name: default
  namespace: purelb
spec:
  local:
    v4pools:
    - subnet: 172.20.0.0/16
      pool: 172.20.1.16-172.20.1.240
      aggregation: default
EOF


echo "install the cert-manager"


echo "create cert-manager namespace"
$KUBECTL_PATH/kubectl create namespace cert-manager
$KUBECTL_PATH/kubectl label --overwrite namespace cert-manager  pod-security.kubernetes.io/audit=privileged  pod-security.kubernetes.io/warn=privileged pod-security.kubernetes.io/enforce=privileged
 
$KUBECTL_PATH/kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.2/cert-manager.yaml

$KUBECTL_PATH/kubectl apply -f - <<EOF
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: og-cert-manager
  namespace: cert-manager
spec:
  targetNamespaces:
  - cert-manager
---
apiVersion: operators.coreos.com/v1alpha1 
kind: Subscription 
metadata: 
  name: cert-manager-local 
  namespace: cert-manager
spec: 
  channel: stable 
  name: cert-manager 
  source: operatorhubio-catalog 
  sourceNamespace: olm
EOF

echo ""
echo "Check the cert-manager operator pods"
WaitForPodsRunning "cert-manager" "cert-manager" 35
echo "Check the cert-manager operator deploy"
WaitForDeploymentToComplete "cert-manager" "cert-manager-cainjector|cert-manager-webhook" 25
echo "Check the cert-manager service deploy"
WaitForServiceToStart "cert-manager" "cert-manager" 25
echo "Check the cert-manager-webhook service deploy"
WaitForServiceToStart "cert-manager" "cert-manager-webhook" 35

echo ""
# for some reason this next step fails if it happens too soon after the deploy?
echo "Waiting for 120s to let the cert-manager catch its breath before we ask for the test cert"
sleep 120;

echo ""
echo "test cert-manager deploy. this should create a self-signed certificate without error. see: cert-manager/test-resources.yaml"
$KUBECTL_PATH/kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager-test
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: test-selfsigned
  namespace: cert-manager-test
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: selfsigned-cert
  namespace: cert-manager-test
spec:
  dnsNames:
    - example.com
  secretName: selfsigned-cert-tls
  issuerRef:
    name: test-selfsigned
EOF

echo ""
echo "Waiting for 25s to let the cert-manager make the test cert available"
sleep 25

echo "checking cert.  review this and ensure it looks like a valid cert"
$KUBECTL_PATH/kubectl describe certificate -n cert-manager-test
### TODO Check the describe for 'validity'
echo ""

echo "delete cert-manager test components"
$KUBECTL_PATH/kubectl delete -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager-test
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: test-selfsigned
  namespace: cert-manager-test
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: selfsigned-cert
  namespace: cert-manager-test
spec:
  dnsNames:
    - example.com
  secretName: selfsigned-cert-tls
  issuerRef:
    name: test-selfsigned
EOF


sleep 1m;

echo "installing the metrics API"
$KUBECTL_PATH/kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

sleep 1m;
echo "install rook-ceph operator"

$KUBECTL_PATH/kubectl create namespace rook-ceph

# for the example crd:
# cd /mnt/hegemon-share/code/kubernetes-app-setup/app-builds/rook/
# git clone --single-branch --branch v1.16.5 https://github.com/rook/rook.git
# cd /mnt/hegemon-share/code/kubernetes-app-setup/app-builds/rook/rook/deploy/examples

helm repo add rook-release https://charts.rook.io/release

$KUBECTL_PATH/kubectl create -f $config_source_dir/app-builds/rook/crds.yaml 
$KUBECTL_PATH/kubectl create -f $config_source_dir/app-builds/rook/common.yaml 
$KUBECTL_PATH/kubectl create -f $config_source_dir/app-builds/rook/csi-operator.yaml 
$KUBECTL_PATH/kubectl create -f $config_source_dir/app-builds/rook/operator.yaml

$KUBECTL_PATH/kubectl label --overwrite namespace rook-ceph  pod-security.kubernetes.io/audit=privileged  pod-security.kubernetes.io/warn=privileged pod-security.kubernetes.io/enforce=privileged

echo "Check the ceph-operator pod"
WaitForPodsRunning "rook-ceph" "rook-ceph-operator" 69


echo "Next step the storage CRDs"
read -p "Are you sure you want to proceed? (yes/no): " response
echo ""

case "$response" in
    [Yy][Ee][Ss]|[Yy])
        echo "Proceeding ..."
        ;;
    *)
        echo "Aborted."
        exit 0
        ;;
esac

$KUBECTL_PATH/kubectl create -f $config_source_dir/app-builds/rook/cluster.yaml
$KUBECTL_PATH/kubectl create -f $config_source_dir/app-builds/rook/filesystem.yaml
$KUBECTL_PATH/kubectl create -f $config_source_dir/app-builds/rook/object.yaml
$KUBECTL_PATH/kubectl create -f $config_source_dir/app-builds/rook/pool.yaml


echo "Check the ceph-rook-cephfs/rdb deploys"
sleep 30
$KUBECTL_PATH/kubectl wait -n rook-ceph --for 'jsonpath={.status.conditions[?(@.type=="Ready")].status}=True' deployment.apps/rook-ceph.cephfs.csi.ceph.com-ctrlplugin --timeout=120s
$KUBECTL_PATH/kubectl wait -n rook-ceph --for 'jsonpath={.status.conditions[?(@.type=="Ready")].status}=True' deployment.apps/rook-ceph.rbd.csi.ceph.com-ctrlplugin  --timeout=120s

echo "Next step defined the storage classes"
read -p "Are you sure you want to proceed? (yes/no): " response
echo ""

case "$response" in
    [Yy][Ee][Ss]|[Yy])
        echo "Proceeding ..."
        ;;
    *)
        echo "Aborted."
        exit 0
        ;;
esac


$KUBECTL_PATH/kubectl create -f $config_source_dir/app-builds/rook/storageclass.yaml

# the following depends on t KREW being installed along with the rook-ceph plugin

$KUBECTL_PATH/kubectl rook-ceph -n rook-ceph ceph config set class:hdd bdev_enable_discard false
$KUBECTL_PATH/kubectl rook-ceph -n rook-ceph ceph config set class:hdd bluestore_slow_ops_warn_lifetime 60
$KUBECTL_PATH/kubectl rook-ceph -n rook-ceph ceph config set class:hdd bluestore_slow_ops_warn_threshold 10


echo "installing traefik"
source $config_source_dir/app-builds/traefik/traefik.sh


