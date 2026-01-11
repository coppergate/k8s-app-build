
kubectl create namespace docker-registry
kubectl label --overwrite namespace docker-registry  pod-security.kubernetes.io/audit=privileged  pod-security.kubernetes.io/warn=privileged pod-security.kubernetes.io/enforce=privileged


kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: registry-issuer-selfsigned
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: registry-cert-selfsigned
  namespace: docker-registry
spec:
  isCA: true
  dnsNames:
    - docker-registry.hierocracy.home
  secretName: registry-selfsigned-cert-tls
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    kind: ClusterIssuer
    group: cert-manager.io
    name: registry-issuer-selfsigned
  subject:
    organizations:
      - hierocracy.home
EOF

echo "create pvc for registry"

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: docker-registry-pv-claim
  namespace: docker-registry
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 60Gi
  storageClassName: rook-ceph-block
EOF

# gen-pass.sh
 
echo "create get-pass"

export REGISTRY_USER=admin
export REGISTRY_PASS=1qaz@WSX3edc
export DESTINATION_FOLDER=/home/k8s/certs/registry-creds
    	
htpasswd -bBc ${DESTINATION_FOLDER}/htpasswd.txt ${REGISTRY_USER} ${REGISTRY_PASS}
 
ht_pass=$(cat ${DESTINATION_FOLDER}/htpasswd.txt);
echo "		ht-pass: $ht_pass"

echo ""
###
# 
# helm repo add twuni https://helm.twun.io
# helm repo update
# 
# # add in the cert file mount 
# #  -> req tells OpenSSL to generate and process certificate requests.
# #  -> -newkey tells OpenSSL to create a new private key and matching certificate request.
# #  -> rsa:4096 tells OpenSSL to generate an RSA key with 4096 bits.
# #  -> -nodes tells OpenSSL there is no password requirement for the private key. The private key will not be encrypted.
# #  -> -sha256 tells OpenSSL to use the sha256 to sign the request.
# #  -> -keyout tells OpenSSL the name and location to store new key.
# #  -> -x509 tells OpenSSL to generate a self-signed certificate.
# #  -> -days tells OpenSSL the number of days the key pair is valid for.
# #  -> -out tells OpenSSL where to store the certificate.
# echo "generate local-registry domain key"
# openssl req -newkey rsa:4096 -noenc -keyout ./local-registry-domain.key -x509 -days 365 -subj "/CN=docker-registry.hierocracy.home" -addext "subjectAltName = DNS:docker-registry.hierocracy.home" -out ./local-registry-domain.crt
# kubectl create secret generic docker-registry-cert-secret -n docker-registry --from-file=tls.crt=./local-registry-domain.crt --from-file=tls.key=./local-registry-domain.key
# echo "get the csr for the server.crt"
    
    

# registry-chart.yaml
echo "create docker-registry from twuni/docker-registry"

helm repo add twuni https://twuni.github.io/docker-registry.helm
helm repo update

helm install docker-registry --namespace docker-registry twuni/docker-registry -f - <<EOF 
replicaCount: 1
persistence:
  enabled: true
  size: 60Gi
  deleteEnabled: true
  storageClass: rook-ceph-block
  existingClaim: docker-registry-pv-claim
service:
  annotations:
    purelb.io/service-group: default
  type: LoadBalancer
secrets:
  htpasswd: ${ht_pass}
securityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
tlsSecret: registry-selfsigned-cert-tls
# If you want to use cert-manager to automatically manage certificates:
ingress:
  className: default
  enabled: true
  annotations:
    kubernetes.io/ingress.class: default
    cert-manager.io/cluster-issuer: "ca-issuer"
  hosts:
    - docker-registry.hierocracy.home
  tls:
    - secretName: docker-registry-tls-cert
      hosts:
        - docker-registry.hierocracy.home  
EOF

 
kubectl expose deployment  docker-registry --name docker-registry-local --port=443 --target-port=5000 --type=LoadBalancer -n docker-registry


unset REGISTRY_USER REGISTRY_PASS 


# the cert needs to be trusted by the host and the clients

# cp /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/
# update-ca-trust
# trust list | grep -i "<hostname>"

# a secret can be created and added to a deploy 
# kubectl create secret docker-registry regcred --docker-server=YOUR_DOMAIN --docker-username=admin --docker-password=registryPass -n test

#    spec:
#      containers:
#      - name: nginx
#        image: YOUR_DOMAIN/my-nginx
#        ports:
#        - containerPort: 80
#      imagePullSecrets:
#        - name: regcred



#secrets:
#  tls:
#    enabled: true
#    # If you have your own certificates:
#    certificate: |
#      -----BEGIN CERTIFICATE-----
#      Your certificate content here
#      -----END CERTIFICATE-----
#    key: |
#      -----BEGIN PRIVATE KEY-----
#      Your private key content here
#      -----END PRIVATE KEY-----
#
#
