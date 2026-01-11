#!/bin/bash

# This script finds all namespaced resources in the rook-ceph namespace and forcefully deletes them.

NAMESPACE="llms-mistral"

echo "Fetching all namespaced resource types..."
RESOURCES=$(kubectl api-resources --verbs=list --namespaced -o name)


for CRD in $(kubectl get crd -n ${NAMESPACE} | awk '/ceph.rook.io/ {print $1}'); do
    kubectl get -n ${NAMESPACE} "$CRD" -o name | \
    xargs -I {} kubectl patch -n ${NAMESPACE} {} --type merge -p '{"metadata":{"finalizers": []}}'
done


for resource in $RESOURCES; do
    # Get all names of the current resource type in the namespace
    items=$(kubectl get "$resource" -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    if [ -n "$items" ]; then
        echo "Processing resource type: $resource"
        for item in $items; do
            if [ -n "$item" ]; then
                echo "crushing finalizer - $item"
                kubectl get -n ${NAMESPACE} "$item" -o name | \
                xargs -I {} kubectl patch -n ${NAMESPACE} {} --type merge -p '{"metadata":{"finalizers": []}}'
                echo "Force deleting $resource/$item in namespace $NAMESPACE..."
                kubectl delete "$resource" "$item" -n "$NAMESPACE" --grace-period=0 --force --wait=false
            fi
        done
    fi
done


echo "Force deletion commands issued for all resources in $NAMESPACE."
