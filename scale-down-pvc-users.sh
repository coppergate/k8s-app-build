#!/bin/bash

# Script to scale down all CRs and standard resources using PVCs to 0 replicas.

KUBECTL="/home/k8s/kube/kubectl"
export KUBECONFIG="/home/k8s/kube/config/kubeconfig"
REPLICA_FILE="pvc-resource-replicas.txt"

# Clear the replica file at the start
> "$REPLICA_FILE"

# List of namespaces to exclude (system namespaces)
EXCLUDE_NS="kube-system|kube-public|kube-node-lease|olm|operators|cert-manager|purelb|k8tz|kubelet-serving-cert-approver|rook-ceph"

# echo "Finding all PVCs in non-excluded namespaces..."

# Get all PVCs and their namespaces
PVCS=$($KUBECTL get pvc -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"\n"}{end}' | grep -vE "^($EXCLUDE_NS)/")

if [ -z "$PVCS" ]; then
    echo "No PVCs found in target namespaces."
    exit 0
fi

# Print found PVCs for debugging
# echo "Found PVCs:"
# echo "$PVCS"

declare -A RESOURCES_TO_SCALE

get_top_owner() {
    local ns=$1
    local kind=$2
    local name=$3
    
    # Get owner references
    local owner_info=$($KUBECTL get "$kind" "$name" -n "$ns" -o jsonpath='{.metadata.ownerReferences[0].kind}{" "}{.metadata.ownerReferences[0].name}' 2>/dev/null)
    
    if [ -n "$owner_info" ]; then
        local owner_kind=$(echo $owner_info | awk '{print $1}')
        local owner_name=$(echo $owner_info | awk '{print $2}')
        
        if [ -z "$owner_kind" ] || [ -z "$owner_name" ]; then
            echo "$kind $name"
            return
        fi

        # If owner is a Node or similar, stop
        if [[ "$owner_kind" == "Node" ]]; then
            echo "$kind $name"
            return
        fi
        
        # Recursively find the top owner
        get_top_owner "$ns" "$owner_kind" "$owner_name"
    else
        echo "$kind $name"
    fi
}

# echo "Tracing PVCs to their top-level owners..."

for pvc_full in $PVCS; do
    NS=$(echo $pvc_full | cut -d'/' -f1)
    PVC_NAME=$(echo $pvc_full | cut -d'/' -f2)
    
    # echo "Processing PVC: $PVC_NAME in $NS"
    
    # Find pods using this PVC
    PODS=$($KUBECTL get pods -n "$NS" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.volumes[?(@.persistentVolumeClaim.claimName=="'"$PVC_NAME"'")].name}{"\n"}{end}' | awk '$2 != "" {print $1}')
    
    if [ -z "$PODS" ]; then
        # echo "  No pods found using PVC $PVC_NAME directly. Checking owner of PVC..."
        OWNER_INFO=$($KUBECTL get pvc "$PVC_NAME" -n "$NS" -o jsonpath='{.metadata.ownerReferences[0].kind}{" "}{.metadata.ownerReferences[0].name}' 2>/dev/null)
        if [ -n "$OWNER_INFO" ]; then
            K=$(echo $OWNER_INFO | awk '{print $1}')
            N=$(echo $OWNER_INFO | awk '{print $2}')
            # echo "  PVC owner: $K/$N"
            TOP_OWNER_INFO=$(get_top_owner "$NS" "$K" "$N")
            TOP_KIND=$(echo $TOP_OWNER_INFO | awk '{print $1}')
            TOP_NAME=$(echo $TOP_OWNER_INFO | awk '{print $2}')
            # echo "  Top owner: $TOP_KIND/$TOP_NAME"
            if [[ -n "$TOP_KIND" && -n "$TOP_NAME" ]]; then
                RESOURCES_TO_SCALE["$NS|$TOP_KIND|$TOP_NAME"]=1
            fi
        # else
             # echo "  No owner found for PVC $PVC_NAME."
        fi
    fi

    for POD in $PODS; do
        # echo "  Pod using PVC: $POD"
        # Find top owner of the pod
        TOP_OWNER_INFO=$(get_top_owner "$NS" "pod" "$POD")
        TOP_KIND=$(echo $TOP_OWNER_INFO | awk '{print $1}')
        TOP_NAME=$(echo $TOP_OWNER_INFO | awk '{print $2}')
        
        # echo "  Top owner: $TOP_KIND/$TOP_NAME"
        if [[ -n "$TOP_KIND" && -n "$TOP_NAME" ]]; then
            if [[ "$TOP_KIND" != "Pod" ]]; then
                 RESOURCES_TO_SCALE["$NS|$TOP_KIND|$TOP_NAME"]=1
            fi
        fi
    done
done

if [ ${#RESOURCES_TO_SCALE[@]} -eq 0 ]; then
    echo "No scalable resources found using PVCs."
    exit 0
fi

echo "Scaling down identified resources to 0 replicas:"
for key in "${!RESOURCES_TO_SCALE[@]}"; do
    IFS='|' read -r NS KIND NAME <<< "$key"
    
    echo "Processing $KIND/$NAME in namespace $NS..."
    
    # Try to get replicas or instances field
    # Common fields: .spec.replicas, .spec.instances (CNPG), .spec.count
    REPLICAS_PATH=""
    for path in '.spec.replicas' '.spec.instances' '.spec.replicaCount' '.spec.count'; do
        VAL=$($KUBECTL get "$KIND" "$NAME" -n "$NS" -o jsonpath="{$path}" 2>/dev/null)
        if [ -n "$VAL" ]; then
            REPLICAS_PATH="$path"
            HAS_REPLICAS="$VAL"
            break
        fi
    done
    
    if [ -n "$REPLICAS_PATH" ]; then
        if [ "$HAS_REPLICAS" -gt 0 ]; then
            echo "  Scaling $KIND/$NAME to 0 (current: $HAS_REPLICAS, field: $REPLICAS_PATH)"
            # Save original state
            echo "$NS $KIND $NAME $HAS_REPLICAS $REPLICAS_PATH" >> "$REPLICA_FILE"
            # Use patch if scale might not be supported
            FIELD_NAME=$(echo $REPLICAS_PATH | cut -d. -f3)
            $KUBECTL patch "$KIND" "$NAME" -n "$NS" --type merge -p "{\"spec\": {\"$FIELD_NAME\": 0}}"
        else
            echo "  $KIND/$NAME is already scaled to 0."
        fi
    else
        # Some CRs might have a scale subresource but no replicas field in standard path
        echo "  Checking if $KIND/$NAME supports 'kubectl scale'..."
        # We need to capture the current replica count even for scale subresource
        # This is harder without a known field. Let's try standard 'kubectl get' replicas/status
        CURRENT_REPLICAS=$($KUBECTL get "$KIND" "$NAME" -n "$NS" -o jsonpath='{.spec.replicas}' 2>/dev/null)
        if [ -z "$CURRENT_REPLICAS" ]; then
             CURRENT_REPLICAS=$($KUBECTL get "$KIND" "$NAME" -n "$NS" -o jsonpath='{.status.replicas}' 2>/dev/null)
        fi

        if $KUBECTL scale "$KIND" "$NAME" -n "$NS" --replicas=0 > /dev/null 2>&1; then
            echo "  Successfully scaled $KIND/$NAME to 0."
            if [ -n "$CURRENT_REPLICAS" ] && [ "$CURRENT_REPLICAS" -gt 0 ]; then
                echo "$NS $KIND $NAME $CURRENT_REPLICAS SCALE_SUBRESOURCE" >> "$REPLICA_FILE"
            fi
        else
            echo "  Could not scale $KIND/$NAME. It might not support standard scaling fields or the scale subresource."
        fi
    fi
done

echo "Scale down process completed."
