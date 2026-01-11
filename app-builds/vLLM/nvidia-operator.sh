
kubectl create namespace gpu-operator 

kubectl label --overwrite namespace gpu-operator \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged

# Create the nvidia RuntimeClass
kubectl apply -f ./nvidia-runtimeclass.yaml

helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo update
helm install \
-n gpu-operator \
nvidia-device-plugin \
nvdp/nvidia-device-plugin \
--version=0.14.5 \
--set=runtimeClassName=nvidia  \
--set nodeSelector.role=inference-node


## Add the nvidia helm repostiory
#helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
#
## Update the repostiories to get the latest changes
#helm repo update
#
#  
## Install the nvidia operator helm chart
#helm install --wait --name nvidia-operator-deploy \
# -n gpu-operator \
# nvidia/gpu-operator \
# --set driver.enabled=false \
# --set nodeSelector.role=inference-node

