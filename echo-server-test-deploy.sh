
echo "install echo-server for load balancer, pvc and cert test"

kubectl create namespace test-deploys
kubectl label --overwrite namespace test-deploys  pod-security.kubernetes.io/audit=privileged  pod-security.kubernetes.io/warn=privileged pod-security.kubernetes.io/enforce=privileged


echo ""
###


##
helm repo add twuni https://twuni.github.io/docker-registry.helm
helm repo update

# add in the cert file mount 
openssl req -newkey rsa:4096 -noenc -keyout ./echo-server-domain.key -x509 -days 365 -subj "/CN=echo-server.hierocracy.home" -addext "subjectAltName = DNS:echo-server.hierocracy.home" -out ./echo-server-domain.crt

#  -> req tells OpenSSL to generate and process certificate requests.
#  -> -newkey tells OpenSSL to create a new private key and matching certificate request.
#  -> rsa:4096 tells OpenSSL to generate an RSA key with 4096 bits.
#  -> -nodes tells OpenSSL there is no password requirement for the private key. The private key will not be encrypted.
#  -> -sha256 tells OpenSSL to use the sha256 to sign the request.
#  -> -keyout tells OpenSSL the name and location to store new key.
#  -> -x509 tells OpenSSL to generate a self-signed certificate.ch
#  -> -days tells OpenSSL the number of days the key pair is valid for.
#  -> -out tells OpenSSL where to store the certificate.

kubectl create secret generic echo-server-cert-secret -n test-deploys --from-file=tls.crt=./echo-server-domain.crt --from-file=tls.key=./echo-server-domain.key

kubectl create -f - <<EOF
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ceph-fs-pvc
  namespace: test-deploys
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 1Gi
  storageClassName: rook-cephfs
EOF

kubectl create -f - <<EOF
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ceph-fs-pvc-rwx
  namespace: test-deploys
spec:
  accessModes:
    - ReadWriteMany
  volumeMode: Filesystem
  resources:
    requests:
      storage: 1Gi
  storageClassName: rook-cephfs
EOF

kubectl apply  -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-server-with-pv
  namespace: test-deploys
  labels:
    pod-security.kubernetes.io/enforce: restricted
    app: echo-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo-server
  template:
    metadata:
      labels:
        app: echo-server
      annotations:
        purelb.io/service-group: default
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
      - image: jmalloc/echo-server
        imagePullPolicy: Always
        name: echo-server
        ports:
        - containerPort: 8080
          name: http-port
          protocol: TCP
        securityContext:
          allowPrivilegeEscalation: false
          runAsUser: 1000
          capabilities:
            drop: 
              - ALL
        volumeMounts:
        - name: echo-server-fs-mount
          mountPath: /var/www/html
        - name: echo-server-fs-many-mount
          mountPath: /var/data
        - name: certs
          mountPath: /mnt/certs
          readOnly: true
      volumes: 
      - name: echo-server-fs-mount
        persistentVolumeClaim: 
          claimName: ceph-fs-pvc
      - name: echo-server-fs-many-mount
        persistentVolumeClaim: 
          claimName: ceph-fs-pvc-rwx
      - name: certs
        secret:
          defaultMode: 420
          optional: false
          secretName: echo-server-cert-secret
EOF

kubectl apply  -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-server
  namespace: test-deploys
  labels:
    pod-security.kubernetes.io/enforce: restricted
    app: echo-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo-server
  template:
    metadata:
      labels:
        app: echo-server
      annotations:
        purelb.io/service-group: default
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
      - image: jmalloc/echo-server
        imagePullPolicy: Always
        name: echo-server
        ports:
        - containerPort: 8080
          name: http-port
          protocol: TCP
        securityContext:
          allowPrivilegeEscalation: false
          runAsUser: 1000
          capabilities:
            drop: 
              - ALL
        volumeMounts:
        - name: certs
          mountPath: /mnt/certs
          readOnly: true
      volumes: 
      - name: certs
        secret:
          defaultMode: 420
          optional: false
          secretName: echo-server-cert-secret
EOF


kubectl expose deployment echo-server --name=echo-server --port=8080 --target-port=8080 --type=LoadBalancer -n test-deploys
kubectl expose deployment echo-server-with-pv --name=echo-server-with-pv --port=8080 --target-port=8080 --type=LoadBalancer -n test-deploys

