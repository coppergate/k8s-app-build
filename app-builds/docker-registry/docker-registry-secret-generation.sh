# https://github.com/cloudflare/cfssl
# dnf -y install go
# go install github.com/cloudflare/cfssl/cmd/...@latest



# example cert generation for a service :
#
export CERT_SERVICE_NAME=docker-registry;
export CERT_SERVICE_IP=110.102.55.191;

export CERT_POD_NAME=docker-registry-88b6d7db-t27qm;
export CERT_POD_IP=10.244.4.177;
export CERT_SERVICE_NAMESPACE=docker-registry;


echo "create a key and cert signing request."
# this creates a server cert and a signing request for a service given the name and address
# of the service and the pod it
cat <<EOF | cfssl genkey - | cfssljson -bare server
{
  "hosts": [
    "$CERT_SERVICE_NAME.$CERT_SERVICE_NAMESPACE.svc.cluster.local",
    "$CERT_POD_NAME.$CERT_SERVICE_NAMESPACE.pod.cluster.local",
    "$CERT_SERVICE_IP",
    "$CERT_POD_IP"
  ],
  "CN": "$CERT_POD_NAME.$CERT_SERVICE_NAMESPACE.pod.cluster.local",
  "key": {
    "algo": "ecdsa",
    "size": 256
  }
}
EOF

echo "send the cert signing request to the K8s api"

cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $CERT_SERVICE_NAME.$CERT_SERVICE_NAMESPACE.cert
  namespace: $CERT_SERVICE_NAMESPACE
spec:
  request: $(cat server.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kubelet-serving
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

echo "sleeping 20s"
sleep 20s;

echo ""
echo "csr describe"
kubectl describe csr $CERT_SERVICE_NAME.$CERT_SERVICE_NAMESPACE.cert -n $CERT_SERVICE_NAMESPACE

echo ""
echo "approving the cert"
kubectl certificate approve $CERT_SERVICE_NAME.$CERT_SERVICE_NAMESPACE.cert -n $CERT_SERVICE_NAMESPACE

echo ""
echo "get the csr"
kubectl get csr

####

# an example for creating a Certificate Authority

echo "create a signing certificate:"

export SIGNER_CN="hierocracy.home";

cat <<EOF | cfssl gencert -initca - | cfssljson -bare ca
{
  "CN": "$SIGNER_CN",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

echo "generating the signing config"

cat << EOF > server-signing-config.json 
{
    "signing": {
        "default": {
            "usages": [
                "digital signature",
                "key encipherment",
                "server auth"
            ],
            "expiry": "876000h",
            "ca_constraint": {
                "is_ca": false
            }
        }
    }
}
EOF
 

# Use the server-signing-config.json signing configuration and the certificate authority key file and certificate to sign the certificate request:
echo "signing the cert"

kubectl get csr  -n $CERT_SERVICE_NAMESPACE $CERT_SERVICE_NAME.$CERT_SERVICE_NAMESPACE.cert -o jsonpath='{.spec.request}' | \
  base64 --decode | \
  cfssl sign -ca ca.pem -ca-key ca-key.pem -config server-signing-config.json - | \
  cfssljson -bare ca-signed-server


echo "waiting 20s";
sleep 20s;

# The above should produce a signed serving certificate file, ca-signed-server.pem.
# populate the signed certificate in the API object's status:
echo ""
echo "get the csr and update the cert status"
kubectl get csr  -n $CERT_SERVICE_NAMESPACE $CERT_SERVICE_NAME.$CERT_SERVICE_NAMESPACE.cert -o json | \
  jq '.status.certificate = "'$(base64 ca-signed-server.pem | tr -d '\n')'"' | \
  kubectl replace --raw /apis/certificates.k8s.io/v1/certificatesigningrequests/$CERT_SERVICE_NAME.$CERT_SERVICE_NAMESPACE.cert/status -f -


echo ""
echo "the list of csr:"
kubectl get csr

echo ""
#####

# once a cert is generated and stored
# pull a copy and make a secret, add in the pem to a config map


echo "copy out the cert and create a PEM. add to a config map"

kubectl get csr  -n $CERT_SERVICE_NAMESPACE $CERT_SERVICE_NAME.$CERT_SERVICE_NAMESPACE.cert -o jsonpath='{.status.certificate}' \
    | base64 --decode > server.crt

kubectl create secret tls docker-registry-tls-cert --cert server.crt --key server-key.pem -n $CERT_SERVICE_NAMESPACE

kubectl create configmap docker-registry-ca --from-file ca.crt=ca.pem -n $CERT_SERVICE_NAMESPACE
