

helm repo add apache https://pulsar.apache.org/charts
helm repo update 

# create and re-label the namespace to avert any security complaints
kubectl create namespace apache-pulsar
kubectl label --overwrite namespace apache-pulsar  pod-security.kubernetes.io/audit=privileged  pod-security.kubernetes.io/warn=privileged pod-security.kubernetes.io/enforce=privileged


git clone https://github.com/apache/pulsar-helm-chart
cd pulsar-helm-chart

#Run the script prepare_helm_release.sh to create the secrets required for installing the Apache Pulsar Helm chart. 
# the -k is the name of the pulsar cluster
#The username 'pulsar' and password 'pulsar' are used for logging into the Grafana dashboard and Pulsar Manager.

./scripts/pulsar/prepare_helm_release.sh \
    -k pulsar \
	-n apache-pulsar

# helm install --timeout 20m --wait --namespace apache-pulsar --values /mnt/hegemon-share/code/kubernetes-app-setup/app-builds/apache-pulsar/full-values.yaml pulsar apache/pulsar  

    
# as an alternate we can try installing with the operators:    
kubectl create -f https://raw.githubusercontent.com/streamnative/charts/master/examples/pulsar-operators/olm-subscription.yaml
kubectl create ns pulsar
kubectl apply -f https://raw.githubusercontent.com/streamnative/charts/master/examples/pulsar-operators/proxy.yaml


    
kubectl get pods -n pulsar
kubectl get services -n pulsar

kubectl expose service pulsar-manager --name=pulsar-pulsar-manager --port=8080 --target-port=9527 --type=LoadBalancer -n apache-pulsar
#The jwt token secret keys are generated under:
#    - 'pulsar-token-asymmetric-key'
#
#The jwt tokens for superusers are generated and stored as below:
#    - 'proxy-admin':secret('pulsar-token-proxy-admin')
#    - 'broker-admin':secret('pulsar-token-broker-admin')
#    - 'admin':secret('pulsar-token-admin')


kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: apache-pulsar-issuer
  namespace: apache-pulsar
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: apache-pulsar-external-cert
  namespace: apache-pulsar
spec:
  dnsNames:
    - hegemon.local
  secretName: pulsar-token-asymmetric-key
  issuerRef:
    name: apache-pulsar-issuer
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: apache-pulsar-proxy-admin-cert
  namespace: apache-pulsar
spec:
  dnsNames:
    - hegemon.local
  secretName: pulsar-token-proxy-admin
  issuerRef:
    name: apache-pulsar-issuer
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: apache-pulsar-broker-admin-cert
  namespace: apache-pulsar
spec:
  dnsNames:
    - hegemon.local
  secretName: pulsar-token-broker-admin
  issuerRef:
    name: apache-pulsar-issuer
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: apache-pulsar-admin-cert
  namespace: apache-pulsar
spec:
  dnsNames:
    - hegemon.local
  secretName: pulsar-token-admin
  issuerRef:
    name: apache-pulsar-issuer
EOF
