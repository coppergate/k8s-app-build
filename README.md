# kubernetes-setup

  This deployment was developed and confirmed working within an 'ubuntu' WSL running under windows 10.
``` 5.15.133.1-microsoft-standard-WSL2 #1 SMP Thu Oct 5 21:02:42 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux```  
 
 
  This deployment will build and configure a 'k8s' cluster on a local docker instance (in this case deploying on minikube)
  
  It deploys several components using operators into multiple namespaces to establish and create working environments for APM.
  
  The basic building blocks are:
  - cert-operator (operators namespace), opentelemetry-operator, jaeger-operator, prometheus-operator, grafana-operator (all but cert-operoator deploying to 'observability' namespace)
  - the Opentelemtery Collector and its various components supporting automatic instrumentation. Installed into the 'observability' namespace. Included here is the 'test' service which is deployed as an 'auto-instrumentation' target.
  - Elasticsearch with Kibana. Used by jaeger to store and retrieve trace information and has logging information written to it directly from the opentelemetry collector. The elasticsearch components are installed int the 'elastic-system' namespace.
  - Jaeger acting as a receiver for otel trace data (opentelemetry protocol standard) from the otel-collector. The Jaeger collector is responsible for the storage, via elastic search, of the trace stream. The jaeger components are installed into the 'observability' namespace'
  - Prometheus collector is configured as a 'push' receiver (which is different than the normal setup which is generally a 'pull via scrape' receiver.) The prometheus service stores its metric data in its own datastore running on a persistent volume claim. Installed into the 'observability' namespace.
  - AlertManager will be configured to send notifications to various systems. Installed into the 'observability' namespace.
  - The grafana services refer to both the Jaeger services (for span metrics) and the prometheus service (for service level metrics).  Installed into the 'observability' namespace.
  
  The overall directory structure deploys as:
  .
  * APM
    - cert-manager
      * test-resources.yaml
    - elastic
      * elasticsearch.values.yaml
    - grafana
      * grafana.values.yaml
    - jaeger
      * jaeger-operator.yaml
      * jaeger-values.yaml
    - opentelemetry
      * otel-collector.values.yaml
      * test-app.values.yaml
    - prometheus
      * alertmanager.values.yaml
      * alermanagerconfig.values.yaml
      * prometheus-operator.yaml
      * prometheus-rbac.values.yaml
      * prometheus.values.yaml
    - alermanagersecret
      * alertmanager.yaml
    * install-otel.sh
    * clean-k8s.sh
  * TestCode
    - otlp-test-microservice-auto
      * Dockerfile
    - otlp-test-microservice-manual
      * Dockerfile
  - netshooter.sidecar.yaml
  - curl-load.should  


## Getting started

* Starting from here: https://kubernetes.io/docs/tasks/tools/
  - Install minikube (though this should work with any kubernetes playground).  	
    ```
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    ```
  - Install kubectl.  	
    ```
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    ```
  - Validate that kubectl is up and Running  
    ```
    kubectl cluster-info
    ```

For simplicity alias the kubectl calls to the minikube cluster call  
```
alias kubectl="minikube kubectl --"
```

the linux session will need to have jq (jquery implementation) Installed  (check the version here and update it as necessary)  
```
sudo apt  install jq  # version 1.6-2.1ubuntu3
```

for the envsbst to embed the elastic password into the otel Collector  
```
apk add gettext
```

query status, strip the LF, and look for the running 'minikube' host  
```
miniKubeStatus=`minikube status  | sed ':a;N;$!ba;s/\n//g' | grep -i 'minikube.*host: Running'`
 ```

### Install

Once the pre-requisites open a CLI and navigate to the 'APM' directory . 
run the Install  
```
.\install-otel.sh
```

The script will prompt before deleting the current 'minikube' container if there is one.  
Once the minikube container has been created the script prompts to continue with the install.  
Depeneding on the target machine the script will take 'minutes' to run (including some pauses to ensure services are running completely)  
Once completed the output should be reviewed to determine that all of the components reported themselves as 'running'  

if everything has succeeded on install a quick test can be performed by running the  
```
.\curl-load.sh
```
from the root of the enlistment and checking out the forwarded ports with a browser

Additional status information can be retrieved with ```kubectl```

Installing the dashboard for the minikube also provides some insights into the cluster internals
```
minikube dashboard
```

## Exposed endpoints

- auto instrumented test service to port 8088 - http://localhost:8088/weatherforecast  
- jaeger query service to port 8089 - http://localhost:8089  
- prometheus service to port 8091 - http://localhost:8091  
- elasticsearch service to port 8093 - https://localhost:8093  
- jaeger-query api service to port 8094 - http://localhost:8094  
- grafana service to port 8090 - http://localhost:8090  
- kibana-elasticsearch-kb-http service to port 8092 - https://localhost:8092  

(hopefully in the near future some 'ingresses' will be created and these services can be exposed that way)

The elastic search endpoints can be authenticated with the 'elastic' user and the password that is output at the end of the script.

The grafana system will need to have the prometheus endpoint (http://prometheus.observability:9090) added as a datasource to see results.

## Some useful links

https://www.mytechramblings.com/posts/getting-started-with-opentelemetry-and-dotnet-core/

