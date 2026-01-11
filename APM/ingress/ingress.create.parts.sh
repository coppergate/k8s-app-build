
# create the ssl cert "show cluster" -> DNS A record
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out otel-poc-tls.crt -keyout otel-poc-tls.key -subj "/CN=hegemon/O=otel-poc-tls"

#
kubectl create secret tls otel-poc-tls --namespace observability --key otel-poc-tls.key --cert otel-poc-tls.crt

# create a deploy
#kubectl create deployment demo --image=gcr.io/google-samples/hello-app:1.0

# expose the deploy as a service
#kubectl expose deployment demo --port=8080

#apiVersion: networking.k8s.io/v1
#kind: Ingress
#metadata:
#  name: demo-ingress
#  annotations:
#    nginx.ingress.kubernetes.io/rewrite-target: /
#spec:
#  ingressClassName: nginx-ingress-class
#  tls:
#  - hosts:
#    - hegemon
#    secretName: otel-poc-tls
#  rules:
#  - host: hegemon
#    http:
#      paths:
#      - path: demo/
#        pathType: Prefix
#        backend:
#          service:
#            name: demo
#            port:
#              number: 8080
#---



# create the ingress
kubectl apply --namespace observability -f ingress/ingress.observability.otlp-collector.values.yaml