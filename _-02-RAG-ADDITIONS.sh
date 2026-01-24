
export KUBECTL_PATH="/home/k8s/kube"
export config_source_dir='/mnt/hegemon-share/share/code/kubernetes-app-setup'

$KUBECTL_PATH/kubectl label nodes worker-0 rag.role.pulsar-worker=true
$KUBECTL_PATH/kubectl label nodes worker-1 rag.role.pulsar-worker=true
$KUBECTL_PATH/kubectl label nodes worker-2 rag.role.pulsar-worker=true
$KUBECTL_PATH/kubectl label nodes worker-3 rag.role.pulsar-worker=true

source "${config_source_dir}/app-builds/rag-support-services/pulsar/install.sh"

$KUBECTL_PATH/kubectl label nodes worker-0 rag.role.timescaledb-node=true
$KUBECTL_PATH/kubectl label nodes worker-1 rag.role.timescaledb-node=true
$KUBECTL_PATH/kubectl label nodes worker-2 rag.role.timescaledb-node=true
$KUBECTL_PATH/kubectl label nodes worker-3 rag.role.timescaledb-node=true

source "${config_source_dir}/app-builds/rag-support-services/timescale/install.sh"


