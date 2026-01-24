#!/bin/bash

# Script to scale up resources that were previously scaled down by scale-down-pvc-users.sh

KUBECTL="/home/k8s/kube/kubectl"
export KUBECONFIG="/home/k8s/kube/config/kubeconfig"
REPLICA_FILE="pvc-resource-replicas.txt"

if [ ! -f "$REPLICA_FILE" ]; then
    echo "Replica state file $REPLICA_FILE not found. Nothing to restore."
    exit 0
fi

echo "Restoring replica counts for previously scaled down resources..."

while read -r NS KIND NAME COUNT FIELD; do
    if [ -z "$NS" ] || [ -z "$KIND" ] || [ -z "$NAME" ] || [ -z "$COUNT" ] || [ -z "$FIELD" ]; then
        continue
    fi

    echo "Restoring $KIND/$NAME in namespace $NS to $COUNT replicas..."

    if [ "$FIELD" == "SCALE_SUBRESOURCE" ]; then
        if $KUBECTL scale "$KIND" "$NAME" -n "$NS" --replicas="$COUNT"; then
            echo "  Successfully restored $KIND/$NAME via scale subresource."
        else
            echo "  Failed to restore $KIND/$NAME via scale subresource."
        fi
    else
        # FIELD is something like .spec.replicas or .spec.instances
        FIELD_NAME=$(echo "$FIELD" | cut -d. -f3)
        if $KUBECTL patch "$KIND" "$NAME" -n "$NS" --type merge -p "{\"spec\": {\"$FIELD_NAME\": $COUNT}}"; then
            echo "  Successfully restored $KIND/$NAME via patch ($FIELD_NAME)."
        else
            echo "  Failed to restore $KIND/$NAME via patch ($FIELD_NAME)."
        fi
    fi
done < "$REPLICA_FILE"

echo "Scale up process completed."
