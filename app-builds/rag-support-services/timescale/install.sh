#!/bin/bash
# install.sh - TimescaleDB (CloudNativePG) Installation
# To be executed on host: hierophant

set -e

NAMESPACE="timescaledb"
KUBECTL="/home/k8s/kube/kubectl"
export KUBECONFIG="/home/k8s/kube/config/kubeconfig"
export TIMESCALEDB_INSTALL="/app-builds/rag-support-services/timescale"

echo "--- 1. Installing CloudNativePG Operator ---"
# Installing version 1.25.0 of the operator
$KUBECTL apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/releases/cnpg-1.25.0.yaml --server-side --force-conflicts

echo "Waiting for CNPG operator to be ready..."
$KUBECTL wait --for=condition=ready pod -l app.kubernetes.io/name=cloudnative-pg -n cnpg-system --timeout=120s

echo "--- 2. Preparing Namespace ---"
if ! $KUBECTL get namespace $NAMESPACE >/dev/null 2>&1; then
    $KUBECTL create namespace $NAMESPACE
fi

$KUBECTL label --overwrite namespace $NAMESPACE \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged \
  pod-security.kubernetes.io/enforce=privileged

echo "--- 3. Deploying TimescaleDB Cluster ---"
$KUBECTL apply -f ${config_source_dir}${TIMESCALEDB_INSTALL}/cluster.yaml --server-side --force-conflicts

echo "Waiting for TimescaleDB instances to be ready..."
# This might take a few minutes as it pulls the image and initializes
echo "Check status with: $KUBECTL get cluster -n $NAMESPACE"

echo "TimescaleDB Installation Triggered."
