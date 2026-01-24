#!/bin/bash

# This script clears finalizers for all namespaced resources in the rook-ceph namespace.
# It is useful when resources are stuck in 'Terminating' state.

# Set NAMESPACE if not already set
NAMESPACE="${NAMESPACE:-rook-ceph}"
# Use KUBECTL if set, otherwise default to kubectl
KUBECTL_CMD="${KUBECTL:-kubectl}"

echo "Fetching all namespaced resource types..."
# Get all namespaced resources that support 'patch' and 'list'
RESOURCES=$($KUBECTL_CMD api-resources --verbs=patch,list --namespaced -o name)

echo "Clearing finalizers for all resources in namespace: $NAMESPACE"

for resource in $RESOURCES; do
    # Get all items of the current resource type in the namespace
    items=$($KUBECTL_CMD get "$resource" -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    if [ -n "$items" ]; then
        echo "Processing resource type: $resource"
        for item in $items; do
            if [ -n "$item" ]; then
                echo "Removing finalizers from $resource/$item..."
                $KUBECTL_CMD patch "$resource" "$item" -n "$NAMESPACE" --type merge -p '{"metadata":{"finalizers": []}}' 2>/dev/null
            fi
        done
    fi
done

echo "Finalizer clearing process completed for namespace: $NAMESPACE"

#(
#NAMESPACE=test-deploys
#kubectl proxy &
#kubectl get namespace $NAMESPACE -o json |jq '.spec = {"finalizers":[]}' >temp.json
#curl -k -H "Content-Type: application/json" -X PUT --data-binary @temp.json 127.0.0.1:8001/api/v1/namespaces/$NAMESPACE/finalize
#)
