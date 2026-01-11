#!/bin/bash

# Script to perform a rolling restart on the specified daemonset in the rook-ceph namespace

NAMESPACE="rook-ceph"
DAEMONSET="daemonset.apps/rook-ceph.rbd.csi.ceph.com-nodeplugin-csi-addons"

echo "Initiating rolling restart for $DAEMONSET in namespace $NAMESPACE..."

kubectl rollout restart $DAEMONSET -n $NAMESPACE

echo "Check rollout status with:"
echo "kubectl rollout status $DAEMONSET -n $NAMESPACE"
