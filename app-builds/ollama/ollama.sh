helm repo add otwld https://helm.otwld.com/
helm repo update


kubectl create namespace llms-ollama

kubectl label --overwrite namespace llms-ollama \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged

helm install ollama otwld/ollama --namespace llms-ollama -f ./values.yaml
kubectl expose deployment ollama --name=ollama --port=11434 --target-port=11434 --type=LoadBalancer -n llms-ollama
