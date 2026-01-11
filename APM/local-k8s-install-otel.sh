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


###############################################
# installs the opentelemetry operator, the kube-stack components and an otel collector
###############################################


echo "adding in helm repositories"
helm repo add opentelemetry-helm https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add elastic https://helm.elastic.co
helm repo add cloud-native-toolkit https://charts.cloudnativetoolkit.dev
  
echo "updating repos"
helm repo update
echo ""
repeatToColWidth "+";
echo ""

echo "create namespace 'observability'. this will contain the pods associated to the otel components directly"
kubectl create namespace observability 
kubectl label namespace observability pod-security.kubernetes.io/audit=privileged 
kubectl label namespace observability pod-security.kubernetes.io/warn=privileged 
kubectl label namespace observability pod-security.kubernetes.io/enforce=privileged

kubectl create namespace kube-stack 
kubectl label namespace kube-stack pod-security.kubernetes.io/audit=privileged 
kubectl label namespace kube-stack pod-security.kubernetes.io/warn=privileged 
kubectl label namespace kube-stack pod-security.kubernetes.io/enforce=privileged

echo "copy elastic secret for elastic certs public to 'observability' namespace"
kubectl get secret elasticsearch-es-http-certs-public --namespace elastic-system -o json \
 | jq 'del(.metadata["namespace","creationTimestamp","resourceVersion","selfLink","uid","ownerReferences"])' \
 | kubectl apply -n observability -f -

echo "copy elastic secret for elastic certs internal to 'observability' namespace"
kubectl get secret elasticsearch-es-http-certs-internal --namespace elastic-system -o json \
 | jq 'del(.metadata["namespace","creationTimestamp","resourceVersion","selfLink","uid","ownerReferences"])' \
 | kubectl apply -n observability -f -

#
echo ""
repeatToColWidth "+";
repeatToColWidth "+";
echo ""


echo "install opentelemetry-operator. into namespace 'observability'."
helm upgrade -n observability opentelemetry-operator opentelemetry-helm/opentelemetry-operator --install -f ./opentelemetry/operator-values.yaml 

# 
echo ""
sleep 10
echo "check the opentelemetry-operator pods"
WaitForPodsRunning "observability" "opentelemetry" 25;
echo "check the opentelemetry-operator-webhook service"
WaitForServiceToStart "observability" "opentelemetry-operator-webhook" 25;


echo ""
repeatToColWidth "+";
repeatToColWidth "+";
echo ""

echo ""
echo " apply opentelemetry-collector via operator into namespace open-telemetry"
echo ""

kubectl apply --namespace observability -f opentelemetry/otel-collector.values.yaml

repeatToColWidth "+";
repeatToColWidth "+";

echo "install opentelemetry kube-stack into 'kube-stack'"

helm upgrade --namespace kube-stack  opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack --install \
--set admissionWebhooks.certManager.enabled=false \
--set admissionWebhooks.autoGenerateCert.enabled=true \
--set meta.helm.sh/release-namespace=kube-stack \
--set meta.helm.sh/release-name=opentelemetry-kube-stack

  
WaitForPodsRunning "kube-stack" "kube-stack" 5

