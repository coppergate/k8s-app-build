# First, clone the repository and change to the directory
# git clone https://github.com/zalando/postgres-operator.git
#cd postgres-operator

NAMESPACE="postgres"
KUBECTL="/home/k8s/kube/kubectl"

echo "--- 1. Preparing Namespace ---"
if ! $KUBECTL get namespace $NAMESPACE >/dev/null 2>&1; then
    $KUBECTL create namespace $NAMESPACE
fi

$KUBECTL label --overwrite namespace $NAMESPACE \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged \
  pod-security.kubernetes.io/enforce=privileged
  
# apply the manifests in the following order
$KUBECTL create -n $NAMESPACE -f ./manifests/configmap.yaml  # configuration
$KUBECTL create -n $NAMESPACE -f ./manifests/operator-service-account-rbac.yaml  # identity and permissions
$KUBECTL create -n $NAMESPACE -f ./manifests/postgres-operator.yaml  # deployment
$KUBECTL create -n $NAMESPACE -f ./manifests/api-service.yaml  # operator API to be used by UI

$KUBECTL apply -n $NAMESPACE -f ./manifests/UI/manifests/

#$KUBECTL expose service postgres-operator-ui \
#    --name=postgres-operator-ui-lb \
#    --port=8081 \
#    --target-port=80 \
#    --type=LoadBalancer \
#    -n $NAMESPACE
