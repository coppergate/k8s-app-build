#!/bin/bash

#k3d cluster delete jaeger-test
#k3d cluster create jaeger-test --servers 1 --kubeconfig-update-default --k3s-arg "--disable=traefik@server:0"

echo "sourcing shell functions"
source k8s-shell-functions.sh

# test out the shell function inclusion
repeatToColWidth "+";

echo "adding in helm repositories"
helm repo add opentelemetry-helm https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add jaeger-tracing https://jaegertracing.github.io/helm-charts
helm repo add jetstack https://charts.jetstack.io
helm repo add elastic https://helm.elastic.co
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add cloud-native-toolkit https://charts.cloudnativetoolkit.dev
helm repo add mysql-operator https://mysql.github.io/mysql-operator/

echo "updating repos"
helm repo update

echo ""

echo "creating cert-manager-operator crds"
curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.26.0/install.sh | bash -s v0.26.0
sleep 15;

echo "creating cert-manager-operator"
kubectl create --namespace operators -f https://operatorhub.io/install/cert-manager.yaml
sleep 15;


echo "Check the cert-manager operator deploy"
WaitForDeploymentToComplete "operators" "cert-manager-cainjector|cert-manager-webhook" 25
echo "Check the cert-manager service deploy"
WaitForServiceToStart "operators" "cert-manager" 25
echo "Check the cert-manager-webhook service deploy"
WaitForServiceToStart "operators" "cert-manager-webhook" 25
echo "Check the cert-manager-webhook-service service deploy"
WaitForServiceToStart "operators" "cert-manager-webhook-service" 25

echo "Check the cert-manager operator pods"
WaitForPodsRunning "operators" "cert-manager" 35


echo ""
# for some reason this next step fails if it happens too soon after the deploy?
echo "Waiting for 20s to let the cert-manager catch its breath before we ask for the test cert"
sleep 20;

echo ""
echo "test cert-manager deploy. this should create a self-signed certificate without error. see: cert-manager/test-resources.yaml"
kubectl apply -f cert-manager/test-resources.yaml

echo ""
echo "Waiting for 25s to let the cert-manager make the test cert available"
sleep 25

echo "checking cert.  review this and ensure it looks like a valid cert"
kubectl describe certificate -n cert-manager-test
### TODO Check the describe for 'validity'
echo ""

echo "delete cert-manager test components"
kubectl delete -f cert-manager/test-resources.yaml
sleep 5;



echo "applying nginx ingress"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

echo "creatinge 'observability' namespace"
kubectl create namespace observability # <1>

echo "creating jaeger operator"
helm install --namespace observability jaeger-operator jaegertracing/jaeger-operator -f jaeger/jaeger.operator.deploy.yaml

WaitForServiceToStart "operators" "jaeger-operator" 25


echo "creating the jaeger services"
helm install --namespace observability jaeger jaegertracing/jaeger -f jaeger/jaeger.simple.values.yaml

