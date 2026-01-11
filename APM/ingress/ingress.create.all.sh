kubectl apply --namespace observability -f ./ingress.default.class.yaml
kubectl apply --namespace elastic-system -f ./ingress.default.class.yaml

kubectl apply --namespace observability -f ./ingress.observability.grafana.values.yaml
kubectl apply --namespace observability -f ./ingress.observability.jaeger.values.yaml
kubectl apply --namespace observability -f ./ingress.observability.otlp-collector.values.yaml

kubectl apply --namespace elastic-system -f ./ingress.elastic-system.values.yaml


