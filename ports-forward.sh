echo "forwarding the test service (auto) to port 8088 - http://localhost:8088"
# kubectl expose service --namespace observability jotel-test-service --type=NodePort --port=8088
kubectl port-forward --namespace observability services/otel-test-service-auto 8088:8080 &> otel-test-port.log &
echo "forwarding the test service (manual) to port 8087 - http://localhost:8087"
# kubectl expose service --namespace observability jotel-test-service --type=NodePort --port=8088
kubectl port-forward --namespace observability services/otel-test-service-manual 8087:8080 &> otel-test-manual-port.log &
echo "forwarding the jaeger query service to port 8089 - http://localhost:8089"
# kubectl expose service --namespace observability jaeger-query --type=NodePort --port=8089
kubectl port-forward --namespace observability services/jaeger-query 8089:16686 &> jaeger-query-port.log  &
echo "forwarding the prometheus service to port 8091 - http://localhost:8091"
# kubectl expose service --namespace observability prometheus --type=NodePort --port=8091
kubectl port-forward --namespace observability services/prometheus 8091:9090 &> prometheus-port.log  &
echo "forwarding the elasticsearch service to port 8093 - https://localhost:8093"
# kubectl expose service --namespace elastic-system services/elasticsearch-es-http --type=NodePort --port=8093
kubectl port-forward --namespace elastic-system services/elasticsearch-es-http 8093:9200  &> elasticsearch-es-http-port.log &
echo "forwarding the jaeger-query api service to port 8094 - http://localhost:8094"
# kubectl expose service --namespace elastic-system services/elasticsearch-es-http --type=NodePort --port=8093
kubectl port-forward --namespace observability services/jaeger-query 8094:16687 &> jaeger-query-metric-port.log  &


echo "forwarding the grafana service to port 8090 - http://localhost:8090"
# kubectl expose service --namespace observability grafana-service --type=NodePort --port=8090
kubectl port-forward --namespace observability services/grafana-service 8090:3000 &> grafana-service-port.log  &
echo "forwarding the kibana-elasticsearch-kb-http service to port 8092 - https://localhost:8092"
# kubectl expose service --namespace elastic-system kibana-elasticsearch-kb-http --type=NodePort --port=8092
kubectl port-forward --namespace elastic-system services/kibana-elasticsearch-kb-http 8092:5601 &> kibana-elasticsearch-kb-http-port.log &

echo "forwarding the otel collector service to port 4317 - https://localhost:4317"
kubectl port-forward --namespace observability services/otel-poc-collector 4317:4317 &> otel-collector-port-4317.log &

echo "forwarding the otel collector service to port 4318 - https://localhost:4318"
kubectl port-forward --namespace observability services/otel-poc-collector 4318:4318 &> otel-collector-port-4318.log &
