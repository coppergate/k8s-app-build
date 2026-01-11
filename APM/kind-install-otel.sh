#############################################################################################################################
#############################################################################################################################
#############################################################################################################################
#############################################################################################################################
# This script was developed and confirmed working within a 'ubuntu' WSL.
# 
#
# The gist of the below is that we will build and configure a 'k8s' cluster on a local docker instance (using minikube)
# and deploy several components in multiple namespaces to establish and create working environments for APM.
# The basic building blocks are:
# cert-operator (operators namespace), opentelemetry-operator, jaeger-operator, prometheus-operator, grafana-operator 
# (all but cert-operoator deploying to 'observability' namespace)
# the Opentelemtery Collector and its various components supporting automatic instrumentation. Installed into the 'observability' 
# namespace. Included here is the 'test' service which is deployed as an 'auto-instrumentation' target.
# Jaeger acting as a receiver for otel trace and log streams (opentelemetry protocol standard) data from the otel-collector
# The Jaeger collector is responsible for the storage, via elastic search (which is installed into the 'elastic-system' namespace)
# , of both the trace and log streams. The jaeger components are nstalled into the 'observability' namespace'
# Prometheus collector is configured as a 'push' receiver (which is different than the normal setup which is generally a 
# 'pull via scrape' receiver. Installed into the 'observability' namespace
# The grafana services refer to both the Jaeger services (for span metrics) and the prometheus service for service level metrics
# Installed into the 'observability' namespace.
# 
# .
# - APM
# --cert-manager
# ---test-resources.yaml
# --elastic
# ---crds.yaml
# ---operator.elastic-system.yaml
# ---elasticsearch.values.yaml
# --grafana
# ---grafana.values.yaml
# --jaeger
# ---jaeger-operator.yaml
# ---jaeger-values.yaml
# --opentelemetry
# ---otel-collector.values.yaml
# ---test-app.values.yaml
# --prometheus
# ---alermanagerconfig.values.yaml
# ---alertmanager.values.yaml
# ---alermanagersecret
# ----alertmanager.yaml
# ---operator-bundle.yaml
# ---prometheus-rbac.values.yaml
# ---prometheus.values.yaml
# -TestCode
# --otlp-test-microservice
# ---Dockerfile
#############################################################################################################################
#############################################################################################################################
#############################################################################################################################
#############################################################################################################################




## create an exit call to reset the cursor.

function cleanup() {
    tput cnorm
}

trap cleanup EXIT

#############################################################################################################################
#############################################################################################################################

# advanceConsole rowCount
advanceConsole(){
 tput civis      ## hide the cursor
   count=$1
	for (( c=1; c<=$count; c++ )) 
	do 
	    sleep .025
		printf "\n"
	done
 tput cnorm

}

#############################################################################################################################
#############################################################################################################################

# WaitForPodsRunning namespace grepString sleepTime
function WaitForPodsRunning() {

	ABORT_COUNT=20
	currentCount=0
	
	notRunning=1
	
	namespace=$1
	grepStrings=$2
	sleepDelay=$3
    printf "waiting for pod startup...\n"; 
	echo "kubectl get pods --namespace $namespace | grep -i -E $grepStrings"

# We're going to try to put the output location so that all of the check returns
# display without issue...  if the terminal is very short (say less than 25 lines)
# this may not place the output in the correct locations....

	IFS='[;' read -p $'\e[6n' -d R -a pos -rs || echo "failed with error: $? ; ${pos[*]}"
	startRow=${pos[1]}
	totalLines=`tput lines`
	
	topRowSpan=5
	neededEchos=0
	if [[ $startRow -gt $topRowSpan ]]; then
		neededEchos=$(( totalLines -  topRowSpan ))
	fi
	let startRow=topRowSpan+1
	advanceConsole $neededEchos
	tput cup $startRow 0

	
	while [[ $notRunning -eq 1 && $currentCount -lt $ABORT_COUNT ]] ; do
	
		tput cup $startRow 0
		tput ed;
		
		check_result=($(kubectl get pods --namespace $namespace | grep -i -E $grepStrings | sed -e "s/ \+  /\t/g" | cut --fields=1,3))
		
		if [[ ${#check_result[@]} -gt 0 ]]; then
		
			notRunning=0
			for key in "${!check_result[@]}"; do
				if [[ $((key % 2)) -eq 0 ]]; then
					name="${check_result[$key]}"
					running="${check_result[$key + 1]}"
					printf "%s is %s\n" "$name" "$running"
					if [[ "$running" != "Running" ]]; then
						notRunning=1
					fi
				fi
			done
			
			if  [[ $notRunning -eq 1 ]]; then
				sleep $sleepDelay
				((currentCount+=1))
			fi
		else
			echo "Waiting for init ..."
			sleep 5
			((currentCount+=1))
		fi
	done
	echo ""
	if  [[ $notRunning -eq 1 ]]; then
		echo "ERROR *******  CHECK EXITING WITHOUT 'STARTED' CONDITION"
	fi

}

#############################################################################################################################
#############################################################################################################################

# WaitForDeploymentToComplete namespace grepString sleepTime
function WaitForDeploymentToComplete() {

	ABORT_COUNT=20
	currentCount=0
	
	notRunning=1
	
	namespace=$1
	grepStrings=$2
	sleepDelay=$3
    printf "waiting for deployment to complete...\n"; 
	echo "kubectl get deployments --namespace $namespace | grep -i -E $grepStrings "

# We're going to try to put the output location so that all of the check returns
# display without issue...  if the terminal is very short (say less than 15 lines)
# this may not place the output in the correct locations....

	IFS='[;' read -p $'\e[6n' -d R -a pos -rs || echo "failed with error: $? ; ${pos[*]}"
	startRow=${pos[1]}
	totalLines=`tput lines`
	
	topRowSpan=5
	neededEchos=0
	if [[ $startRow -gt $topRowSpan ]]; then
		neededEchos=$(( totalLines -  topRowSpan ))
	fi
	let startRow=topRowSpan+1
	advanceConsole $neededEchos
	tput cup $startRow 0

	
	while [[ $notRunning -eq 1 && $currentCount -lt $ABORT_COUNT ]] ; do
	
		tput cup $startRow 0
		tput ed;
		
		check_result=($(kubectl get deployments --namespace $namespace | grep -i -E $grepStrings | sed -e "s/ \+  /\t/g" | cut --fields=1,3))
		
		if [[ ${#check_result[@]} -gt 0 ]]; then
		
			notRunning=0
			for key in "${!check_result[@]}"; do
				if [[ $((key % 2)) -eq 0 ]]; then
					name="${check_result[$key]}"
					running="${check_result[$key + 1]}"

					printf "%s available is %s\n" "$name" "$running"
					if [[ "$running" != "1" ]]; then
						notRunning=1
					fi
				fi
			done
			
			if  [[ $notRunning -eq 1 ]]; then
				sleep $sleepDelay
				((currentCount+=1))
			fi
		else
			echo "Waiting for init ..."
			sleep 5
			((currentCount+=1))
		fi
	done
	if  [[ $notRunning -eq 1 ]]; then
		echo "ERROR *******  CHECK EXITING WITHOUT 'STARTED' CONDITION"
	fi
}

#############################################################################################################################
#############################################################################################################################
	
# WaitForDeploymentToComplete namespace grepString sleepTime
function WaitForServiceToStart() {

	ABORT_COUNT=20
	currentCount=0
	
	notRunning=1
	
	namespace=$1
	grepStrings=$2
	sleepDelay=$3
    printf "waiting for services to start...\n"; 
	echo "kubectl get services --namespace $namespace | grep -i -E $grepStrings"

# We're going to try to put the output location so that all of the check returns
# display without issue...  if the terminal is very short (say less than 15 lines)
# this may not place the output in the correct locations....

	IFS='[;' read -p $'\e[6n' -d R -a pos -rs || echo "failed with error: $? ; ${pos[*]}"
	startRow=${pos[1]}
	totalLines=`tput lines`
	
	topRowSpan=5
	neededEchos=0
	if [[ $startRow -gt $topRowSpan ]]; then
		neededEchos=$(( totalLines -  topRowSpan ))
	fi
	let startRow=topRowSpan+1
	advanceConsole $neededEchos
	tput cup $startRow 0

	
	while [[ $notRunning -eq 1 && $currentCount -lt $ABORT_COUNT ]] ; do
	
		tput cup $startRow 0
		tput ed;
		check_result=($(kubectl get services --namespace $namespace | grep -i -E $grepStrings | sed -e "s/ \+  /\t/g" | cut --fields=1,6))
		
		
		if [[ ${#check_result[@]} -gt 0 ]]; then
		
			rowCount=2
			notRunning=0
			for key in "${!check_result[@]}"; do
				if [[ $((key % 2)) -eq 0 ]]; then
					name="${check_result[$key]}"
					running="${check_result[$key + 1]}"
					
					printf "%s - Age is %s\n" "$name" "$running"
				    ((rowCount+=1))
				fi
			done
			if  [[ $notRunning -eq 1 ]]; then
				sleep $sleepDelay
				((currentCount+=1))
			fi
		else
			echo "Waiting for init ..."
			sleep 5
			((currentCount+=1))
		fi
	done
	if  [[ $notRunning -eq 1 ]]; then
		echo "ERROR *******  CHECK EXITING WITHOUT 'STARTED' CONDITION"
	fi
}


#############################################################################################################################

#############################################################################################################################
# repeat {count} {char}
repeat(){
    count=$1
	char="$2"
	echo ""
	for (( c=1; c<=$count; c++ )) 
	do 
		echo -n "$char"; 
	done
	echo ""
}

#############################################################################################################################
# repeatToColWidth {char}
repeatToColWidth(){
    count=`tput lines`
	char="$2"
	repeat $count $char
}



#############################################################################################################################
#############################################################################################################################


pathToAutoTestServiceDocker='/mnt/c/code/kubernetes-setup/TestCode/otlp-test-microservice-auto'
pathToManualTestServiceDocker='/mnt/c/code/kubernetes-setup/TestCode/otlp-test-microservice-manual'


#############################################################################################################################
#############################################################################################################################


clear
tput init
tput home

IFS='[;' read -p $'\e[6n' -d R -a pos -rs || echo "failed with error: $? ; ${pos[*]}"

terminal_rows=`tput lines`
terminal_cols=`tput cols`


echo


#############################################################################################################################
tput civis      ## hide the cursor

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
repeatToColWidth "+";
repeatToColWidth "+";
echo ""
echo "creating cert-manager-operator crds"
curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.26.0/install.sh | bash -s v0.26.0
sleep 5;
#curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.26.0/install.sh | bash -s v0.26.0

echo "creating cert-manager-operator"
kubectl create -f https://operatorhub.io/install/cert-manager.yaml
sleep 5;

echo ""
echo "Check the cert-manager operator pods"
WaitForPodsRunning "operators" "cert-manager" 35
echo "Check the cert-manager operator deploy"
WaitForDeploymentToComplete "operators" "cert-manager-cainjector|cert-manager-webhook" 25
echo "Check the cert-manager service deploy"
WaitForServiceToStart "operators" "cert-manager" 25
echo "Check the cert-manager-webhook service deploy"
WaitForServiceToStart "operators" "cert-manager-webhook" 25
echo "Check the cert-manager-webhook-service service deploy"
WaitForServiceToStart "operators" "cert-manager-webhook-service" 25

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

echo ""
repeatToColWidth "+";
repeatToColWidth "+";
echo ""
echo "create namespace 'observability'. this will contain the pods associated to the APM directly"
kubectl create namespace observability 
echo "create namespace 'elastic-system'. this will contain the pods associated to elasticsearch"
kubectl create namespace elastic-system 

#helm install --namespace observability {} oci://registry-1.docker.io/bitnamicharts/<chart>

# sourced from https://www.elastic.co/guide/en/cloud-on-k8s/master/k8s-install-helm.html
echo "install eck-operator as 'elastic-operator' into 'elastic-system'"
helm install elastic-operator elastic/eck-operator -n elastic-system

WaitForPodsRunning "elastic-system" "elastic-operator" 5

echo ""
repeatToColWidth "+";
repeatToColWidth "+";
echo ""

echo "deploy elasticsearch via operator. see: elastic/elasticsearch.values.yaml"
kubectl apply --namespace elastic-system -f elastic/elasticsearch.values.yaml
sleep 5;

echo ""
WaitForPodsRunning "elastic-system" "elasticsearch-es-" 30
echo ""

echo "copy elastic secret for elastic certs public to 'observability' namespace"
kubectl get secret elasticsearch-es-http-certs-public --namespace elastic-system -o json \
 | jq 'del(.metadata["namespace","creationTimestamp","resourceVersion","selfLink","uid","ownerReferences"])' \
 | kubectl apply -n observability -f -

#echo "copy elastic secret for elastic certs internal to jaeger observability namespace"
#kubectl get secret elasticsearch-es-http-certs-internal --namespace elastic-system -o json \
# | jq 'del(.metadata["namespace","creationTimestamp","resourceVersion","selfLink","uid","ownerReferences"])' \
# | kubectl apply -n observability -f -
#
#echo "copy elastic secret for elastic http ca internal to observability namespace for otel-collector to elasticsearch for logs"
#kubectl get secret elasticsearch-es-http-ca-internal --namespace elastic-system -o json \
# | jq 'del(.metadata["namespace","creationTimestamp","resourceVersion","selfLink","uid","ownerReferences"])' \
# | kubectl apply -n observability -f -
#echo ""
#echo "copy elastic secret for elastic remotge ca to observability namespace for otel-collector to elasticsearch for logs"
#kubectl get secret elasticsearch-es-remote-ca --namespace elastic-system -o json \
# | jq 'del(.metadata["namespace","creationTimestamp","resourceVersion","selfLink","uid","ownerReferences"])' \
# | kubectl apply -n observability -f -
#echo ""
#echo "copy elastic secret for elastic transport certs public to observability namespace for otel-collector to elasticsearch for logs"
#kubectl get secret elasticsearch-es-transport-certs-public --namespace elastic-system -o json \
# | jq 'del(.metadata["namespace","creationTimestamp","resourceVersion","selfLink","uid","ownerReferences"])' \
# | kubectl apply -n observability -f -
#echo ""



repeatToColWidth "+";
repeatToColWidth "+";
echo ""
echo "install the jaeger-operator into namespace 'observability'"
helm install -n observability jaeger-operator jaeger-tracing/jaeger-operator

#kubectl create -f jaeger/jaeger-operator.yaml -n observability # <2>
echo ""
sleep 5;

echo "check the jaeger-operator"
WaitForPodsRunning "observability" "jaeger-operator" 25

echo ""
repeatToColWidth "+";
repeatToColWidth "+";
echo ""
echo "generating the jaeger-secret for elastic search"
# this copies the secret from 'elastic-system' into 'observability' to make it available to services across the namespaces.
export ES_PASSWORD=$(kubectl get secret elasticsearch-es-elastic-user --namespace elastic-system -o go-template='{{.data.elastic | base64decode}}')
kubectl create secret generic jaeger-secret --namespace observability --from-literal=ES_PASSWORD=$ES_PASSWORD --from-literal=ES_USERNAME=elastic

echo "got $ES_PASSWORD for elastic"

echo ""
echo "deploy jaeger via operator"
kubectl apply --namespace observability  -f jaeger/jaeger.values.yaml
echo ""
sleep 5;
echo "check the jaeger deploy"
WaitForPodsRunning "observability" "jaeger-collector|jaeger-query" 25
echo ""
repeatToColWidth "+";
repeatToColWidth "+";
echo ""

echo "apply prometheus rbac into namespace 'observability'."
# this sets up a service account with a role with access to various metric endpoints
kubectl apply  -n observability -f prometheus/prometheus-rbac.values.yaml

echo "install prometheus operator into namespace 'observability'."
#LATEST="v0.71.2"
#curl -sL https://github.com/prometheus-operator/prometheus-operator/releases/download/${LATEST}/bundle.yaml | kubectl create --namespace observability  -f -
#
# This may not need to be like this... the operator-bundle.yaml was downloaded and referenced from a local store in order to try to get it to deploy to the 'operators' namespace
# to this point that has not been implemented. Attempts to modify the embedded namespace ('default') have all failed.  some of the underlying CRDs are not created 
# or perhaps, referenced correctly... 
#
kubectl create --namespace observability  -f prometheus/prometheus-operator.yaml
#kubectl create -f prometheus/operator-bundle.yaml

echo "wait for prometheus operator in namespace 'observability'."
kubectl wait --for=condition=Ready pods -l  app.kubernetes.io/name=prometheus-operator -n observability

echo "create alert manager secret in namespace 'observability'."
kubectl create secret generic alertmanager-otlp --namespace observability --from-file=prometheus/alertmanagersecret/alertmanager.yaml
echo "apply alermanager config into namespace 'observability'."
kubectl apply  -n observability -f prometheus/alertmanagerconfig.values.yaml
echo "apply alermanager into namespace 'observability'."
kubectl apply  -n observability -f prometheus/alertmanager.values.yaml
echo "apply prometheus into namespace 'observability'."
kubectl apply  -n observability -f prometheus/prometheus.values.yaml

echo ""
sleep 5;
echo "check the prometheus deploy"
WaitForPodsRunning "observability" "prometheus-" 25

echo ""
repeatToColWidth "+";
repeatToColWidth "+";
echo ""

echo "install opentelemetry-operator. into namespace 'observability'."
helm install  -n observability  --set admissionWebhooks.certManager.enabled=true --set manager.collectorImage.repository=otel/opentelemetry-collector-contrib opentelemetry-operator opentelemetry-helm/opentelemetry-operator
# 
echo ""
sleep 10
echo "check the opentelemetry-operator pods"
WaitForPodsRunning "observability" "opentelemetry-" 25;
echo "check the opentelemetry-operator-webhook service"
WaitForServiceToStart "observability" "opentelemetry-operator-webhook" 25;
echo ""
echo " apply opentelemetry-collector via operator into namespace open-telemetry"
echo ""

envsubst < opentelemetry/otel-collector.values.yaml | kubectl apply --namespace observability -f -

# to redirect the docker build to publish to the minikube registry
# ->  eval $(minikube docker-env)
# any following docker commands will be executed in the minikube docker context....
#echo "building .Net test service and deploying to k8s"
#pathToAutoTestServiceDocker='/mnt/c/code/kubernetes-setup/TestCode/otlp-test-microservice-auto/Dockerfile'
#pathToManualTestServiceDocker='/mnt/c/code/kubernetes-setup/TestCode/otlp-test-microservice-manual/Dockerfile'

#echo "building $pathToAutoTestServiceDocker"
#docker build -f $pathToAutoTestServiceDocker ./TestCode -t k8s/otel-test-microservice-auto:2.1.1
#minikube image load k8s/otel-test-microservice-auto:2.1.1
#echo ""
#echo "building $pathToManualTestServiceDocker"
#docker build $pathToManualTestServiceDocker ./TestCode -t k8s/otel-test-microservice-manual:2.2.1
#minikube image load k8s/otel-test-microservice-manual:2.2.1


#minikube cache reload

#kubectl port-forward --namespace kube-system service/registry 5000:80 &
#docker run --rm -it --network=host alpine ash -c "apk add socat && socat TCP-LISTEN:5000,reuseaddr,fork TCP:host.docker.internal:5000" &
#
#eval $(minikube docker-env)
#docker build ../TestCode/otlp-test-microservice-auto -t localhost:5000/k8s/otel-test-service-auto:1.0.0
#docker push k8s/otel-test-service-auto:1.0.0

#echo "kill the port forward for the registry"
#ps -ef | grep kubectl | grep -v grep | awk '{print $2}' | xargs kill


#echo "applying test-app" 
#kubectl apply --namespace observability -f opentelemetry/test-app.values.yaml

#echo ""
#sleep 5;
#echo "check the opentelemetry-collector deploy"

#WaitForPodsRunning "observability" "otel-poc-collector" 5
#WaitForPodsRunning "observability" "otel-test-app-auto" 5
#echo ""

## The OpenTelemetry Collector defines a ServiceAccount field which could be set to run collector instances with a specific Service and their properties (e.g. imagePullSecrets). 
## Therefore, if you have a constraint to run your collector with a private container registry, you should follow the procedure below:
#
## Create Service Account.
#kubectl create serviceaccount <service-account-name>
## Create an imagePullSecret.
#kubectl create secret docker-registry <secret-name> --docker-server=<registry name> \
#        --docker-username=DUMMY_USERNAME --docker-password=DUMMY_DOCKER_PASSWORD \
#        --docker-email=DUMMY_DOCKER_EMAIL
## Add image pull secret to service account
#kubectl patch serviceaccount <service-account-name> -p '{"imagePullSecrets": [{"name": "<secret-name>"}]}'



repeatToColWidth "+";
repeatToColWidth "+";


echo "install grafana-operator. into namespace 'observability'."
kubectl create --namespace operators -f https://operatorhub.io/install/grafana-operator.yaml

echo ""
echo "check the grafana-operator pods"
WaitForPodsRunning "operators" "grafana-" 15;
echo ""
echo " apply grafana via operator into namespace"
kubectl apply --namespace observability -f grafana/grafana.values.yaml
WaitForPodsRunning "observability" "grafana-deployment" 25;

repeatToColWidth "+";
repeatToColWidth "+";

# TODO : REPLACE ALL OF THIS WITH ACTUAL INGRESS CREATION TO ALLOW SERVICES TO BE ACCESSED
# GRAFANA, JAEGER and KIBANA at a minimum...
# 

#echo "wait for the pods to spin up and then map ports..."
#sleep 30;

#echo "forwarding the test service to port 8088 - http://localhost:8088"
## kubectl expose service --namespace observability otel-test-service --type=NodePort --port=8088
#kubectl port-forward --namespace observability services/otel-test-service-auto 8088:8080 &> otel-test-port.log &
#echo "forwarding the jaeger query service to port 8089 - http://localhost:8089"
## kubectl expose service --namespace observability jaeger-query --type=NodePort --port=8089
#kubectl port-forward --namespace observability services/jaeger-query 8089:16686 &> jaeger-query-port.log  &
#echo "forwarding the prometheus service to port 8091 - http://localhost:8091"
# kubectl expose service --namespace observability prometheus --type=NodePort --port=8091
#kubectl port-forward --namespace observability services/prometheus 8091:9090 &> prometheus-port.log  &
#echo "forwarding the elasticsearch service to port 8093 - https://localhost:8093"
# kubectl expose service --namespace elastic-system services/elasticsearch-es-http --type=NodePort --port=8093
#kubectl port-forward --namespace elastic-system services/elasticsearch-es-http 8093:9200  &> elasticsearch-es-http-port.log &
#echo "forwarding the jaeger-query api service to port 8094 - http://localhost:8094"
## kubectl expose service --namespace observability services/jaeger-query --type=NodePort --port=8093
#kubectl port-forward --namespace observability services/jaeger-query 8094:16687 &> jaeger-query-metric-port.log  &

#echo "forwarding the otel-collector api service to port 4317 - http://localhost:4317"
## kubectl expose service --namespace observability services/otel-poc-collector --type=NodePort --port=4317
#kubectl port-forward ---namespace observability services/otel-poc-collector 4317:4317 &> otel-collector-port-4317.log  &
#echo "forwarding the otel-collector api service to port 4318 - http://localhost:4318"
## kubectl expose service --namespace observability services/otel-poc-collector --type=NodePort --port=4318
#kubectl port-forward ---namespace observability services/otel-poc-collector 4318:4318 &> otel-collector-port-4318.log  &

#repeatToColWidth "+";
#repeatToColWidth "+";
#
#echo "grafana and kibana both seem to need extra time before the port forward can be applied successfully"
#echo "waiting for 30 seconds before forwarding port traffic."
#sleep 30; 
 
#echo "forwarding the grafana service to port 8090 - http://localhost:8090"
## kubectl expose service --namespace observability grafana-service --type=NodePort --port=8090
#kubectl port-forward --namespace observability services/grafana-service 8090:3000 &> grafana-service-port.log  &
#echo "forwarding the kibana-elasticsearch-kb-http service to port 8092 - https://localhost:8092"
## kubectl expose service --namespace elastic-system kibana-elasticsearch-kb-http --type=NodePort --port=8092
#kubectl port-forward --namespace elastic-system services/kibana-elasticsearch-kb-http 8092:5601 &> kibana-elasticsearch-kb-http-port.log &

repeatToColWidth "+";
repeatToColWidth "+";
echo "creating 'otlp-poc-test' namespace"
kubectl create namespace otlp-poc-test # <1>

echo "creating mysql-operator in 'otlp-poc-test' namespace"
helm install mysql-operator mysql-operator/mysql-operator --namespace otlp-poc-test 

echo "creating mysql secret for root access"
kubectl create secret generic --namespace otlp-poc-test mysql-secret \
        --from-literal=rootUser=root \
        --from-literal=rootHost=% \
        --from-literal=rootPassword="otlp-mysql"

echo "apply mysql cluster via operator"
kubectl apply --namespace otlp-poc-test -f mysql/mysql.values.yaml

WaitForPodsRunning "otlp-poc-test" "mysql" 30;

echo ""
echo "got $ES_PASSWORD for elastic"
echo ""
echo "mysql created with rootUser=root and rootPassword=otlp-mysql"
echo ""
echo "grafana default login =>root/secret"

