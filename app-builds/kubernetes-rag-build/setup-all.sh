#!/bin/bash

# setup-all.sh - Orchestrate the entire RAG stack deployment
# To be executed on host: hierophant

set -e

REPO_DIR="/mnt/hegemon-share/share/code/kubernetes-rag-build"
NAMESPACE="rag-system"
KUBECTL="/home/k8s/kube/kubectl"
export KUBECONFIG="/home/k8s/kube/config/kubeconfig"

echo "--- 1. Creating Namespace ---"
$KUBECTL apply -f "$REPO_DIR/namespace.yaml"

echo "--- 2. Deploying Infrastructure: TimescaleDB ---"
cd "$REPO_DIR/infrastructure/timescaledb"
bash install.sh

echo "--- 3. Deploying Infrastructure: Apache Pulsar ---"
cd "$REPO_DIR/infrastructure/pulsar"
bash install.sh

echo "--- 4. Deploying Vector Database: Qdrant ---"
$KUBECTL apply -f "$REPO_DIR/services/qdrant/qdrant-pvc.yaml"
$KUBECTL apply -f "$REPO_DIR/services/qdrant/qdrant-deploy.yaml"
$KUBECTL apply -f "$REPO_DIR/services/qdrant/qdrant-service.yaml"

echo "--- 5. Provisioning S3 Object Store (Rook-Ceph) ---"
$KUBECTL apply -f "$REPO_DIR/infrastructure/obc.yaml"

echo "Waiting for S3 credentials..."
until $KUBECTL get secret rag-codebase-bucket -n $NAMESPACE >/dev/null 2>&1; do
  sleep 5
done

echo "--- 6. Deploying LLM Gateway (Go) ---"
$KUBECTL apply -f "$REPO_DIR/infrastructure/timescaledb/timescaledb-secret.yaml"
$KUBECTL apply -f "$REPO_DIR/services/llm-gateway/k8s/configmap.yaml"
# Create Source ConfigMap
$KUBECTL create configmap llm-gateway-source -n $NAMESPACE \
  --from-file=main.go="$REPO_DIR/services/llm-gateway/cmd/gateway/main.go" \
  --from-file=config.go="$REPO_DIR/services/llm-gateway/internal/config/config.go" \
  --from-file=openai.go="$REPO_DIR/services/llm-gateway/internal/handlers/openai.go" \
  --from-file=client.go="$REPO_DIR/services/llm-gateway/internal/pulsar/client.go" \
  --dry-run=client -o yaml | $KUBECTL apply -f -
$KUBECTL apply -f "$REPO_DIR/services/llm-gateway/k8s/deployment.yaml"

echo "--- 7. Deploying RAG Worker (Go) ---"
$KUBECTL create configmap rag-worker-source -n $NAMESPACE \
  --from-file=main.go="$REPO_DIR/services/rag-worker/cmd/worker/main.go" \
  --from-file=config.go="$REPO_DIR/services/rag-worker/internal/config/config.go" \
  --from-file=ollama_client.go="$REPO_DIR/services/rag-worker/internal/ollama/client.go" \
  --from-file=qdrant_client.go="$REPO_DIR/services/rag-worker/internal/qdrant/client.go" \
  --dry-run=client -o yaml | $KUBECTL apply -f -
$KUBECTL apply -f "$REPO_DIR/services/rag-worker/k8s/deployment.yaml"

echo "--- 8. Deploying Object Store Manager (Go) ---"
$KUBECTL create configmap rag-s3-mgr-source -n $NAMESPACE \
  --from-file=main.go="$REPO_DIR/services/object-store-mgr/cmd/manager/main.go" \
  --dry-run=client -o yaml | $KUBECTL apply -f -
$KUBECTL apply -f "$REPO_DIR/services/object-store-mgr/mgr-deployment.yaml"

echo "--- 9. Deploying RAG Web UI (Go) ---"
$KUBECTL create configmap rag-web-ui-source -n $NAMESPACE \
  --from-file=main.go="$REPO_DIR/services/rag-web-ui/cmd/ui/main.go" \
  --dry-run=client -o yaml | $KUBECTL apply -f -
$KUBECTL apply -f "$REPO_DIR/services/rag-web-ui/ui-deployment.yaml"

echo "--- 10. Preparing Ingestion Pipeline ---"
$KUBECTL apply -f "$REPO_DIR/ingestion/ingest-job-s3.yaml"

echo "--- All Components Deployed ---"
echo "Check status: $KUBECTL get pods -n $NAMESPACE"
