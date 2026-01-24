#!/bin/bash

# setup-rag.sh - Automated setup for RAG components
# To be executed on host: hierophant

set -e

BASE_DIR="/mnt/hegemon-share/share/code/kubernetes-app-setup/app-builds/RAG"
OBJ_STORE_DIR="$BASE_DIR/object-store"
NAMESPACE="rag-system"
export NAMESPACE

KUBECTL="/home/k8s/kube/kubectl"
export KUBECONFIG="/home/k8s/kube/config/kubeconfig"


echo "--- 0. Creating Namespace ---"
$KUBECTL apply -f "$BASE_DIR/namespace.yaml"

echo "--- 1. Deploying Qdrant Vector Database ---"
$KUBECTL apply -f "$BASE_DIR/qdrant-pvc.yaml"
$KUBECTL apply -f "$BASE_DIR/qdrant-deploy.yaml"
$KUBECTL apply -f "$BASE_DIR/qdrant-service.yaml"

echo "Waiting for Qdrant to be ready..."
$KUBECTL wait --for=condition=ready pod -l app=qdrant -n $NAMESPACE --timeout=120s

echo "--- 2. Provisioning Rook-Ceph Object Store ---"
$KUBECTL apply -f "$OBJ_STORE_DIR/obc.yaml"

echo "Waiting for Object Store credentials to be provisioned (ConfigMap/Secret)..."
# Loop until the secret exists
until $KUBECTL get secret rag-codebase-bucket -n $NAMESPACE >/dev/null 2>&1; do
  echo "Still waiting for secret rag-codebase-bucket in $NAMESPACE..."
  sleep 5
done

echo "--- 3. Deploying Object Store Manager (Go) ---"
$KUBECTL apply -f "$OBJ_STORE_DIR/mgr-deployment.yaml"

echo "Waiting for Manager pod to be ready..."
$KUBECTL wait --for=condition=ready pod -l app=object-store-mgr -n $NAMESPACE --timeout=240s

echo "--- 4. Deploying Web UI (Go) ---"
$KUBECTL apply -f "$BASE_DIR/web-ui/ui-deployment.yaml"

echo "--- 4a. Deploying LLM Gateway (Go) ---"
$KUBECTL apply -f "/mnt/hegemon-share/share/code/kubernetes-app-setup/app-builds/rag-support-services/timescale/timescaledb-secret.yaml"
$KUBECTL apply -f "/mnt/hegemon-share/share/code/kubernetes-app-setup/app-builds/llm-gateway/k8s/configmap.yaml"
$KUBECTL apply -f "/mnt/hegemon-share/share/code/kubernetes-app-setup/app-builds/llm-gateway/k8s/deployment.yaml"

echo "Waiting for Web UI pod to be ready..."
$KUBECTL wait --for=condition=ready pod -l app=rag-web-ui -n $NAMESPACE --timeout=240s

echo "--- 5. Preparing Ingestion Job ---"
echo "The Ingestion Job manifest is applied (but will only process data once S3 is populated)."
$KUBECTL apply -f "$OBJ_STORE_DIR/ingest-job-s3.yaml"

echo "--- Setup Complete ---"
echo "Instructions:"
echo "1. Access the Web UI via the LoadBalancer IP (check '$KUBECTL get svc -n $NAMESPACE rag-web-ui')."
echo "2. Use the UI to upload your codebase directory."
echo "3. Once files are uploaded, trigger the ingestion by clicking the button in the Web UI."
