#!/bin/bash
# install.sh - Apache Pulsar Installation
# To be executed on host: hierophant

set -e

NAMESPACE="apache-pulsar"
KUBECTL="/home/k8s/kube/kubectl"
export KUBECONFIG="/home/k8s/kube/config/kubeconfig"
export PULSAR_INSTALL="/app-builds/rag-support-services/pulsar"

echo "--- 1. Preparing Namespace ---"
if ! $KUBECTL get namespace $NAMESPACE >/dev/null 2>&1; then
    $KUBECTL create namespace $NAMESPACE

$KUBECTL label --overwrite namespace $NAMESPACE \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged \
  pod-security.kubernetes.io/enforce=privileged
fi


echo "--- 2. Adding Helm Repos ---"
helm repo add apache https://pulsar.apache.org/charts
helm repo update

echo "--- 3. Installing Pulsar ---"
# Note: Using the localized full-values.yaml which has nodeSelectors for pulsar-worker role
# Pinning to chart version 3.6.0 (Pulsar 3.0.x LTS)
helm install pulsar apache/pulsar \
    --version 3.6.0 \
    --namespace $NAMESPACE \
    --values ${config_source_dir}/${PULSAR_INSTALL}/full-values.yaml \
    --timeout 60m \
    --wait

echo "--- 4. Exposing Pulsar Manager ---"
$KUBEC


echo "--- 4. Exposing Pulsar Manager admin ---"
$KUBECTL expose service pulsar-pulsar-manager-admin \
    --name=pulsar-manager-lb \
    --port=8080 \
    --target-port=9527 \
    --type=LoadBalancer \
    -n $NAMESPACE

echo "Pulsar Installation Complete."
