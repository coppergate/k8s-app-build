
export CERT_DIR="/mnt/hegemon-share/code/kubernetes-setup/talos/certs/"

# Generate a private key
openssl genrsa -out wjones.user.key 2048
# Generate a certificate signing request (CSR)
openssl req -new -key wjones.user.key -out wjones.user.csr -subj "/CN=wjones/O=local-cluster"
# Sign the CSR using the cluster's certificate authority (CA)
openssl x509 -req -in wjones.user.csr -CA $CERT_DIR/extract-ca.crt -CAkey $CERT_DIR/extract-ca.key -CAcreateserial -out wjones.user.crt -days 365

# Add the new user to the kubeconfig file
kubectl config set-credentials wjones --client-certificate=wjones.user.crt --client-key=wjones.user.key
# Add a new context for the user
kubectl config set-context user-context --cluster=local-cluster --user=wjones
# Switch to the new context
kubectl config use-context user-context


