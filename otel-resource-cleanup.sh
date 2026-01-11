kubectl delete clusterrole opentelemetry-kube-stack-collector \
opentelemetry-kube-stack-opentelemetry-operator-manager \
opentelemetry-kube-stack-opentelemetry-operator-metrics \
opentelopentelemetry-operator-manager \
opentelemetry-operator-metrics \
opentelemetry-operator-proxy \
opentelemetry-kube-stack-opentelemetry-operator-proxy

kubectl delete clusterrolebinding \
opentelemetry-kube-stack-cluster-stats \
opentelemetry-kube-stack-daemon 
opentelemetry-kube-stack-opentelemetry-operator-manager \
opentelemetry-kube-stack-opentelemetry-operator-proxy \
opentelemetry-operator-manager \
opentelemetry-operator-proxy


(
NAMESPACE=observability
kubectl proxy &
kubectl get namespace $NAMESPACE -o json |jq '.spec = {"finalizers":[]}' >temp.json
curl -k -H "Content-Type: application/json" -X PUT --data-binary @temp.json 127.0.0.1:8001/api/v1/namespaces/$NAMESPACE/finalize
)

(
NAMESPACE=kube-stack
kubectl proxy &
kubectl get namespace $NAMESPACE -o json |jq '.spec = {"finalizers":[]}' >temp.json
curl -k -H "Content-Type: application/json" -X PUT --data-binary @temp.json 127.0.0.1:8001/api/v1/namespaces/$NAMESPACE/finalize
)

#(
#NAMESPACE=elastic-system
#kubectl proxy &
#kubectl get namespace $NAMESPACE -o json |jq '.spec = {"finalizers":[]}' >temp.json
#curl -k -H "Content-Type: application/json" -X PUT --data-binary @temp.json 127.0.0.1:8001/api/v1/namespaces/$NAMESPACE/finalize
#)
