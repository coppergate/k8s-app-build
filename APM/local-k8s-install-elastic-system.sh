#############################################################################################################################
#############################################################################################################################
#############################################################################################################################
#############################################################################################################################
#
# The gist of the below is that we will build and configure a 'k8s' cluster instance
# and deploy several components in multiple namespaces to establish and create working environments for APM.
# The basic building blocks are:
# cert-operator (operators namespace), opentelemetry-operator, jaeger-operator, prometheus-operator, grafana-operator 
# (all but cert-operator deploying to 'observability' namespace)
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
# --elastic
# ---crds.yaml
# ---operator.elastic-system.yaml
# ---elasticsearch.values.yaml
# --opentelemetry
# ---otel-collector.values.yaml
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


pathToAutoTestServiceDocker='/mnt/hegemon-share/code/kubernetes-setup/TestCode/otlp-test-microservice-auto'
pathToManualTestServiceDocker='/mnt/hegemon-share/code/kubernetes-setup/TestCode/otlp-test-microservice-manual'


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
helm repo add elastic https://helm.elastic.co
helm repo add cloud-native-toolkit https://charts.cloudnativetoolkit.dev
  
echo "updating repos"
helm repo update
echo ""
repeatToColWidth "+";
echo ""

echo ""

echo "create namespace 'elastic-system'. this will contain the pods associated to elasticsearch"
kubectl create namespace elastic-system 
kubectl label namespace elastic-system  pod-security.kubernetes.io/audit=privileged  
kubectl label namespace elastic-system  pod-security.kubernetes.io/warn=privileged 
kubectl label namespace elastic-system  pod-security.kubernetes.io/enforce=privileged

echo "install eck-operator as 'elastic-operator' into 'elastic-system'"

# sourced from https://www.elastic.co/guide/en/cloud-on-k8s/master/k8s-install-helm.html
helm install elastic-operator elastic/eck-operator -n elastic-system

WaitForPodsRunning "elastic-system" "operator" 15

echo ""
repeatToColWidth "+";
repeatToColWidth "+";
echo ""

echo "deploy elasticsearch via operator. "

kubectl apply -n elastic-system -f elastic/elasticsearch.values.yaml

echo ""
WaitForPodsRunning "elastic-system" "elasticsearch-es-" 30
echo ""

export ES_PASSWORD=$(kubectl get secret -n elastic-system elasticsearch-es-elastic-user --namespace elastic-system -o go-template='{{.data.elastic | base64decode}}')
export ES_USERNAME='elastic'

echo "deploy kibana via operator."

kubectl apply -f elastic/kibana.values.yaml

echo ""
WaitForPodsRunning "elastic-system" "kibana-" 30
echo ""

echo ""
repeatToColWidth "+";
repeatToColWidth "+";


echo "elatic-agent-crds.yaml'"
kubectl -n elastic-system apply -f elastic/elastic-agent-crds.yaml
echo ""

echo "clean up kibana fleet secret"
kubectl delete secret kibana-fleet-config -n elastic-system 

echo ""
echo "creating kibana fleet config"
KIBANA_ELASTIC_PWD=$(kubectl get secret -n elastic-system elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' | base64 --decode)
echo "kibana elastic pwd : ${KIBANA_ELASTIC_PWD}"

echo "create kibana fleet secret"

kubectl create secret generic kibana-fleet-config -n elastic-system \
--from-literal=kibana_endpoint='https://kibana-kb-http.elastic-system:5601' \
--from-literal=elastic_endpoint='https://elasticsearch-es-internal-http.elastic-system:9200' \
--from-literal=kibana_fleet_token=${KIBANA_ELASTIC_PWD} \
--from-literal=kibana_fleet_user='elastic'

kubectl port-forward --namespace elastic-system services/kibana-kb-http 25601:5601 &

sleep 1m;


BASIC_AUTHN=$(printf '%s:%s' "elastic" "$KIBANA_ELASTIC_PWD" | base64) 
echo "BASIC_AUTHN: ${BASIC_AUTHN}"


echo "curl --insecure --request GET 'https://localhost:25601/app/fleet/enrollment-tokens'  --header 'Authorization: Basic ${BASIC_AUTHN}'"
curl --insecure --request GET 'https://localhost:25601/app/fleet/enrollment-tokens'  --header "Authorization: Basic ${BASIC_AUTHN}" \

echo "curl --insecure --request POST 'https://localhost:25601/api/fleet/enrollment_api_keys'  --header 'Authorization: Basic ${BASIC_AUTHN}'"
echo ""
# get token from the kibana server call..... 
ELASTIC_SERVICE_TOKEN=$(curl --insecure --request POST 'https://localhost:25601/api/fleet/enrollment_api_keys'  --header "Authorization: Basic ${BASIC_AUTHN}" | jq '.list[] | select(.policy_id=="eck-fleet-server") | .api_key')
echo "elastic service token : ${ELASTIC_SERVICE_TOKEN}"

echo "stop the port-forward for kibana"
pkill -f "port-forward"
 
 
echo "clean up eck-fleet-server-config secret"
kubectl delete secret eck-fleet-server-config -n elastic-system

echo ""
echo "create eck-fleet-server-config secret"

kubectl create secret generic eck-fleet-server-config -n elastic-system \
--from-literal=elastic_endpoint='https://elasticsearch-es-internal-http.elastic-system:9200' \
--from-literal=elastic_service_token=${ELASTIC_SERVICE_TOKEN} \
--from-literal=fleet_policy_id='eck-fleet-server'

echo ""
repeatToColWidth "+";
repeatToColWidth "+";
echo ""

echo "applying elastic agents"

kubectl apply -n elastic-system -f elastic/elastic-agent-managed-kubernetes.yaml

echo ""
repeatToColWidth "+";
repeatToColWidth "+";
echo ""


echo "expose kibana-kp-http as kibana-server at 5601"
kubectl expose service kibana-kb-http  --name=kibana-server --port=5601 --target-port=5601 --type=LoadBalancer -n elastic-system

echo "expose elastic es internal http as elastic-server at 9200"
kubectl expose service elasticsearch-es-internal-http  --name=elastic-server --port=9200 --target-port=9200 --type=LoadBalancer -n elastic-system

echo ""
export ES_PASSWORD=$(kubectl get secret -n elastic-system elasticsearch-es-elastic-user --namespace elastic-system -o go-template='{{.data.elastic | base64decode}}')
export ES_USERNAME='elastic'
echo "elastic user/pwd :  $ES_USERNAME/$ES_PASSWORD"
