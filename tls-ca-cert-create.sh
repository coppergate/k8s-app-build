kubectl create namespace test-deploys
kubectl label --overwrite namespace test-deploys  pod-security.kubernetes.io/audit=privileged  pod-security.kubernetes.io/warn=privileged pod-security.kubernetes.io/enforce=privileged

echo "create the CA for the kubernetes cluster"
mkdir create-ca
cd create-ca

# create a self-signed certificate valid for 365 days
openssl req -x509 -newkey rsa:4096 -keyout ca.key -out ca.crt -days 365 -nodes -subj "/CN=kubernetes-ca"
kubectl create secret tls ca-secret --key ca.key --cert ca.crt -n cert-test-deploys

cd .. 
rm -rf ./create-ca

echo ""
###


##

kubectl create -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-secret
EOF

##
##

# generate the key file
cat <<EOF | cfssl genkey - | cfssljson -bare server
{
  "hosts": [
    "my-svc.my-namespace.svc.cluster.local",
    "my-pod.my-namespace.pod.cluster.local",
    "192.0.2.24",
    "10.0.34.2"
  ],
  "CN": ".kubernetes-dashboard.pod.cluster.local",
  "key": {
    "algo": "ecdsa",
    "size": 256
  }
}
EOF

# the above should generate 2 files : server.csr containing the PEM encoded PKCS#10 certification request, 
# and server-key.pem containing the PEM encoded key to the certificate that is still to be created.


# request to sign the key pass the server.csr
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: my-svc.my-namespace
spec:
  request: $(cat server.csr | base64 | tr -d '\n')
  signerName: hierocracy.home/serving
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

#

kubectl describe csr my-svc.my-namespace

#

kubectl certificate approve my-svc.my-namespace

#

kubectl get csr

#

# create a signing request

cat <<EOF | cfssl gencert -initca - | cfssljson -bare ca
{
  "CN": "Hierocracy Signer",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

# issue a cert

# tls/server-signing-config.json
echo '{
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
}' >> tls/server-signing-config.json



















