#!/bin/bash

# Cleanup Rook Data Script
# This script removes Rook components, runs a temporary pod on each worker node 
# to delete the contents of /var/lib/rook, and then reapplies Rook components.

KUBECTL="/home/k8s/kube/kubectl"
export KUBECONFIG="/home/k8s/kube/config/kubeconfig"
export config_source_dir='/mnt/hegemon-share/share/code/kubernetes-app-setup'

# Source helper functions if they exist
if [ -f "./k8s-install-helper-functions.sh" ]; then
    source ./k8s-install-helper-functions.sh
else
    # Fallback if not found in current dir
    source $config_source_dir/k8s-install-helper-functions.sh
fi

echo "--- Phase 0: Scaling down all Deployments and ReplicaSets ---"

# List of namespaces to exclude from scaling down
EXCLUDE_NS="kube-system|kube-public|kube-node-lease|olm|operators|cert-manager|purelb|k8tz|kubelet-serving-cert-approver|rook-ceph"

# Get all namespaces except excluded ones
NAMESPACES=$($KUBECTL get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -vE "^($EXCLUDE_NS)$")

for NS in $NAMESPACES; do
    echo "Processing namespace: $NS"
    
    # Scale down deployments
    DEPLOYS=$($KUBECTL get deployments -n "$NS" -o name)
    if [ -n "$DEPLOYS" ]; then
        for DEPLOY in $DEPLOYS; do
            echo "  Scaling down deployment: $DEPLOY in $NS"
            $KUBECTL scale "$DEPLOY" -n "$NS" --replicas=0
        done
    fi

    # Scale down replicasets (that might not be owned by deployments)
    RS=$($KUBECTL get rs -n "$NS" -o name)
    if [ -n "$RS" ]; then
        for R in $RS; do
            # Check if it has owners (to avoid scaling down RS managed by Deployments which are already scaled)
            OWNER=$($KUBECTL get "$R" -n "$NS" -o jsonpath='{.metadata.ownerReferences[0].kind}')
            if [ "$OWNER" != "Deployment" ]; then
                echo "  Scaling down replicaset: $R in $NS"
                $KUBECTL scale "$R" -n "$NS" --replicas=0
            else
                echo "  Skipping replicaset $R (managed by Deployment)"
            fi
        done
    fi
done

echo "Waiting for pods to terminate..."
sleep 10

echo "--- Phase 1: Removing Rook Components ---"

ROOK_NS="rook-ceph"
# Order: others -> osd -> mon
ROOK_DEPLOYS=$($KUBECTL get deployments -n "$ROOK_NS" -o name)
ROOK_STATEFULSETS=$($KUBECTL get statefulsets -n "$ROOK_NS" -o name)

# Save all rook replicas first
for res in $ROOK_DEPLOYS $ROOK_STATEFULSETS; do
    REPLICAS=$($KUBECTL get "$res" -n "$ROOK_NS" -o jsonpath='{.spec.replicas}')
    echo "$ROOK_NS $res $REPLICAS" >> "$REPLICA_FILE"
done

# Scale down "others" (not mon or osd)
for res in $ROOK_DEPLOYS $ROOK_STATEFULSETS; do
    if [[ ! "$res" =~ "mon" ]] && [[ ! "$res" =~ "osd" ]]; then
        echo "Scaling down rook component: $res..."
        $KUBECTL scale "$res" -n "$ROOK_NS" --replicas=0
    fi
done

# Scale down OSDs
for res in $ROOK_DEPLOYS $ROOK_STATEFULSETS; do
    if [[ "$res" =~ "osd" ]]; then
        echo "Scaling down rook component: $res..."
        $KUBECTL scale "$res" -n "$ROOK_NS" --replicas=0
    fi
done

# Wait a bit for OSDs to terminate
sleep 10

# Scale down Mons
for res in $ROOK_DEPLOYS $ROOK_STATEFULSETS; do
    if [[ "$res" =~ "mon" ]]; then
        echo "Scaling down rook component: $res..."
        $KUBECTL scale "$res" -n "$ROOK_NS" --replicas=0
    fi
done

# Delete in reverse order of creation
$KUBECTL delete -f $config_source_dir/app-builds/rook/storageclass.yaml --ignore-not-found --force --now
$KUBECTL delete -f $config_source_dir/app-builds/rook/pool.yaml --ignore-not-found --force --now
$KUBECTL delete -f $config_source_dir/app-builds/rook/object.yaml --ignore-not-found --force --now
$KUBECTL delete -f $config_source_dir/app-builds/rook/filesystem.yaml --ignore-not-found --force --now
$KUBECTL delete -f $config_source_dir/app-builds/rook/cluster.yaml --ignore-not-found --force --now
$KUBECTL delete -f $config_source_dir/app-builds/rook/operator.yaml --ignore-not-found --force --now
$KUBECTL delete -f $config_source_dir/app-builds/rook/csi-operator.yaml --ignore-not-found --forcev
$KUBECTL delete -f $config_source_dir/app-builds/rook/common.yaml --ignore-not-found --force --now
$KUBECTL delete -f $config_source_dir/app-builds/rook/crds.yaml --ignore-not-found --force --now

echo "Deleting rook-ceph namespace..."
$KUBECTL delete namespace rook-ceph --ignore-not-found --wait=true --timeout=120s

# If namespace is still there, it might be stuck due to finalizers
if $KUBECTL get namespace rook-ceph > /dev/null 2>&1; then
    echo "Namespace rook-ceph still exists, attempting to clear finalizers..."
    # Using the existing script but overriding NAMESPACE for safety
    NAMESPACE="rook-ceph" ./clear-rook-ceph-finalizers.sh
    $KUBECTL delete namespace rook-ceph --ignore-not-found --wait=true --timeout=60s --force
fi

echo "--- Phase 2: Cleaning up hostPath /var/lib/rook ---"

# Get all nodes that are not control-plane
NODES=$($KUBECTL get nodes -l 'node-role.kubernetes.io/control-plane!=' -o jsonpath='{.items[*].metadata.name}')

if [ -z "$NODES" ]; then
    echo "No worker nodes found for hostPath cleanup."
else
    echo "Cleaning up /var/lib/rook on nodes: $NODES"

    for NODE in $NODES; do
        POD_NAME="rook-cleanup-$NODE"
        echo "Starting cleanup pod on $NODE..."
        
        $KUBECTL run $POD_NAME \
            --image=alpine \
            --restart=Never \
            --overrides='
    {
      "spec": {
        "nodeName": "'"$NODE"'",
        "containers": [
          {
            "name": "cleanup",
            "image": "alpine",
            "command": ["/bin/sh", "-c", "rm -rf /var/lib/rook/* && echo Done"],
            "securityContext": {
              "privileged": true
            },
            "volumeMounts": [
              {
                "name": "rook-data",
                "mountPath": "/var/lib/rook"
              }
            ]
          }
        ],
        "volumes": [
          {
            "name": "rook-data",
            "hostPath": {
              "path": "/var/lib/rook",
              "type": "DirectoryOrCreate"
            }
          }
        ]
      }
    }'
    done

    echo "Waiting for cleanup pods to complete..."
    for NODE in $NODES; do
        POD_NAME="rook-cleanup-$NODE"
        $KUBECTL wait --for=jsonpath='{.status.phase}'=Succeeded pod/$POD_NAME --timeout=60s > /dev/null 2>&1
        echo "Logs for $POD_NAME:"
        $KUBECTL logs $POD_NAME
    done

    echo "Deleting cleanup pods..."
    for NODE in $NODES; do
        POD_NAME="rook-cleanup-$NODE"
        $KUBECTL delete pod $POD_NAME --wait=false > /dev/null 2>&1
    done
fi

echo "--- Phase 3: Reapplying Rook Components ---"

echo "Creating rook-ceph namespace..."
$KUBECTL create namespace rook-ceph

echo "Applying operator manifests..."
$KUBECTL create -f $config_source_dir/app-builds/rook/crds.yaml 
$KUBECTL create -f $config_source_dir/app-builds/rook/common.yaml 
$KUBECTL create -f $config_source_dir/app-builds/rook/csi-operator.yaml 
$KUBECTL create -f $config_source_dir/app-builds/rook/operator.yaml

$KUBECTL label --overwrite namespace rook-ceph pod-security.kubernetes.io/audit=privileged pod-security.kubernetes.io/warn=privileged pod-security.kubernetes.io/enforce=privileged

echo "Waiting for rook-ceph-operator..."
WaitForPodsRunning "rook-ceph" "rook-ceph-operator" 69

echo "Applying storage manifests..."
$KUBECTL create -f $config_source_dir/app-builds/rook/cluster.yaml
$KUBECTL create -f $config_source_dir/app-builds/rook/filesystem.yaml
$KUBECTL create -f $config_source_dir/app-builds/rook/object.yaml
$KUBECTL create -f $config_source_dir/app-builds/rook/pool.yaml

echo "Waiting for CSI plugins..."
sleep 30
$KUBECTL wait -n rook-ceph --for 'jsonpath={.status.conditions[?(@.type=="Ready")].status}=True' deployment.apps/rook-ceph.cephfs.csi.ceph.com-ctrlplugin --timeout=120s
$KUBECTL wait -n rook-ceph --for 'jsonpath={.status.conditions[?(@.type=="Ready")].status}=True' deployment.apps/rook-ceph.rbd.csi.ceph.com-ctrlplugin --timeout=120s

echo "Applying storage classes..."
$KUBECTL create -f $config_source_dir/app-builds/rook/storageclass.yaml

echo "Setting Ceph configs..."
$KUBECTL rook-ceph -n rook-ceph ceph config set class:hdd bdev_enable_discard false
$KUBECTL rook-ceph -n rook-ceph ceph config set class:hdd bluestore_slow_ops_warn_lifetime 60
$KUBECTL rook-ceph -n rook-ceph ceph config set class:hdd bluestore_slow_ops_warn_threshold 10

echo "Rook cleanup and re-application complete."
