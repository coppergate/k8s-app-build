KIBANA_ELASTIC_PWD=$(kubectl get secret -n elastic-system elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' | base64 --decode)
echo "kibana elastic pwd : ${KIBANA_ELASTIC_PWD}"

BASIC_AUTHN=$(printf '%s:%s' "elastic" "$KIBANA_ELASTIC_PWD" | base64) 
echo "BASIC_AUTHN: ${BASIC_AUTHN}"

kubectl -n elastic-system port-forward service/kibana-kb-http 5601:5601 &

echo "curl --insecure --request POST 'https://localhost:5601/_security/service/default/elastic/fleet-server/credential/token'  --header 'Authorization: Basic ${BASIC_AUTHN}'"
echo ""
curl -v --insecure --request POST 'https://localhost:5601/_security/service/default/elastic/fleet-server/credential/token'  --header "Authorization: Basic ${BASIC_AUTHN}"



# kubectl expose deployment kibana-kb --name=kibana-kb --port=5601 --target-port=5601 --type=LoadBalancer -n elastic-system
