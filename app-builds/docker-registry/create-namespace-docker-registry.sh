kubectl create namespace docker-registry
kubectl label --overwrite namespace docker-registry  pod-security.kubernetes.io/audit=privileged  pod-security.kubernetes.io/warn=privileged pod-security.kubernetes.io/enforce=privileged

