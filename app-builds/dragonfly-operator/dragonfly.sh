#!/bin/bash
# install.sh - Apache Pulsar Installation
# To be executed on host: hierophant

set -e

NAMESPACE="dragonfly"
KUBECTL="/home/k8s/kube/kubectl"
export KUBECONFIG="/home/k8s/kube/config/kubeconfig"
export DRAGONFLY_INSTALL="/app-builds/dragonfly-operator"

 
 if ! $KUBECTL get namespace $NAMESPACE >/dev/null 2>&1; then
  
  $KUBECTL create namespace $NAMESPACE
  $KUBECTL label --overwrite namespace $NAMESPACE \
    pod-security.kubernetes.io/enforce=privileged \
    pod-security.kubernetes.io/audit=privileged \
    pod-security.kubernetes.io/warn=privileged
  
  $KUBECTL label nodes worker-0 dragonfly-db=true
  $KUBECTL label nodes worker-1 dragonfly-db=true
  $KUBECTL label nodes worker-2 dragonfly-db=true
  $KUBECTL label nodes worker-3 dragonfly-db=true
  
  $KUBECTL label nodes inference-0 dragonfly-db=true
  $KUBECTL label nodes inference-1 dragonfly-db=true

fi 

helm install dragonfly-operator ./charts/dragonfly-operator -n $NAMESPACE


$KUBECONFIG apply -n $NAMESPACE -f ./v1alpha1_dragonfly.yaml


