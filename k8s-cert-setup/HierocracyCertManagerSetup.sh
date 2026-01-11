#!/bin/bash

echo "Setting up cert-manager with self-signing CA for Hierocracy Local in test-tls-deploy namespace..."

# Create namespaces
echo "Creating namespaces..."
kubectl apply -f test-tls-deploy-namespace.yaml
kubectl apply -f cert-manager-namespace.yaml

# Install cert-manager CRDs
echo "Installing cert-manager CRDs..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.crds.yaml

# Install cert-manager
echo "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready
echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager

# Create self-signing issuer
echo "Creating self-signing issuer..."
kubectl apply -f selfsigned-issuer.yaml

# Create root CA certificate
echo "Creating root CA certificate..."
kubectl apply -f root-ca-certificate.yaml

# Wait for root CA certificate to be ready
echo "Waiting for root CA certificate to be ready..."
kubectl wait --for=condition=Ready certificate/root-ca-certificate -n cert-manager --timeout=120s

# Create CA issuer
echo "Creating CA issuer..."
kubectl apply -f ca-issuer.yaml

# Create certificates in test-tls-deploy namespace
echo "Creating internal certificate in test-tls-deploy namespace..."
kubectl apply -f hierocracy-internal-certificate.yaml

echo "Creating external certificate in test-tls-deploy namespace..."
kubectl apply -f hierocracy-external-certificate.yaml

# Wait for certificates to be ready
echo "Waiting for certificates to be ready..."
kubectl wait --for=condition=Ready certificate/hierocracy-internal-certificate -n test-tls-deploy --timeout=120s
kubectl wait --for=condition=Ready certificate/hierocracy-external-certificate -n test-tls-deploy --timeout=120s

# Deploy configuration
echo "Deploying nginx SSL configuration..."
kubectl apply -f nginx-ssl-config.yaml

# Deploy services and ingresses
echo "Deploying services..."
kubectl apply -f hierocracy-internal-service.yaml
kubectl apply -f hierocracy-external-service.yaml

# Deploy applications
echo "Deploying applications..."
kubectl apply -f hierocracy-applications.yaml

# Apply network policies
echo "Applying network policies..."
kubectl apply -f hierocracy-network-policy.yaml

echo "Setup complete!"
echo ""
echo "All resources have been deployed to the 'test-tls-deploy' namespace"
echo ""
echo "To verify the setup:"
echo "1. Check cert-manager pods: kubectl get pods -n cert-manager"
echo "2. Check certificates: kubectl get certificates -n test-tls-deploy"
echo "3. Check certificate secrets: kubectl get secrets -n test-tls-deploy | grep hierocracy"
echo "4. Check deployments: kubectl get deployments -n test-tls-deploy"
echo "5. Check services: kubectl get services -n test-tls-deploy"
echo "6. Check ingresses: kubectl get ingresses -n test-tls-deploy"
echo ""
echo "Internal network (10.2.1.0/24) services:"
echo "- internal.hierocracy.home"
echo "- api.internal.hierocracy.home"
echo "- admin.internal.hierocracy.home"
echo ""
echo "External network (192.168.192.0/24) services:"
echo "- hierocracy.home"
echo "- www.hierocracy.home"
echo "- api.hierocracy.home"
echo "- admin.hierocracy.home"
echo "- app.hierocracy.home"
echo ""
echo "To trust the self-signed certificates, extract the CA certificate:"
echo "kubectl get secret root-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 -d > hierocracy-ca.crt"
echo "Then install hierocracy-ca.crt in your system's certificate store."
echo ""
echo "To clean up, delete the test-tls-deploy namespace:"
echo "kubectl delete namespace test-tls-deploy"