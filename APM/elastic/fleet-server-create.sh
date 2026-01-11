
kubectl delete secret fleet-server-config -n elastic-system

kubectl create secret generic fleet-server-config -n elastic-system \
--from-literal=elastic_endpoint='https://elasticsearch-es-internal-http.elastic-system:9200' \
--from-literal=elastic_service_token='AAEAAWVsYXN0aWMvZmxlZXQtc2VydmVyL3Rva2VuLTE3NDU4NjUyOTQ3NTQ6YXdwZ0p6cVFTLS1Ma2tvM0xTSXgyQQ' \
--from-literal=fleet_policy_id='fleet-server-policy' \
--from-literal=fleet_server_port=8220

kubectl delete secret kibana-fleet-config -n elastic-system

kubectl create secret generic kibana-fleet-config -n elastic-system \
--from-literal=kibana_endpoint='https://kibana-kb-http.elastic-system:5601'


kubectl apply -n elastic-system -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: fleet-server-kibana
spec:
  type: ClusterIP
  selector:
    app: fleet-server-kibana
  ports:
  - port: 8220
    protocol: TCP
    targetPort: 8220
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fleet-server-kibana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fleet-server-kibana
  template:
    metadata:
      labels:
        app: fleet-server-kibana
    spec:
      automountServiceAccountToken: true
      containers:
      - name: elastic-agent
        image: docker.elastic.co/beats/elastic-agent:8.17.4
        env:
          - name: FLEET_SERVER_ENABLE
            value: "true"
          - name: FLEET_SERVER_ELASTICSEARCH_HOST
            valueFrom:
              secretKeyRef:
                name: fleet-server-config
                key: elastic_endpoint
          - name: FLEET_SERVER_SERVICE_TOKEN
            valueFrom:
              secretKeyRef:
                name: fleet-server-config
                key: elastic_service_token
          - name: FLEET_SERVER_POLICY_ID
            valueFrom:
              secretKeyRef:
                name: fleet-server-config
                key: fleet_policy_id
          - name: ELASTICSEARCH_CA
            value: /mnt/certs/ca.crt
          - name: FLEET_SERVER_PORT
            valueFrom:
              secretKeyRef:
                name: fleet-server-config
                key: fleet_server_port
        ports:
        - containerPort: 8220
          protocol: TCP
        resources: {}
        volumeMounts:
        - name: certs
          mountPath: /mnt/certs
          readOnly: true
      volumes:
      - name: certs
        secret:
          defaultMode: 420
          optional: false
          secretName: elasticsearch-es-http-certs-internal
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: fleet-server
subjects:
  - kind: ServiceAccount
    name: fleet-server
    namespace: elastic-system
roleRef:
  kind: ClusterRole
  name: fleet-server
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: elastic-system
  name: fleet-server
subjects:
  - kind: ServiceAccount
    name: fleet-server
    namespace: elastic-system
roleRef:
  kind: Role
  name: fleet-server
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fleet-server
  labels:
    app.kubernetes.io/name: fleet-server
rules:
  - apiGroups: [""]
    resources:
      - nodes
      - namespaces
      - events
      - pods
      - services
      - configmaps
      # Needed for cloudbeat
      - serviceaccounts
      - persistentvolumes
      - persistentvolumeclaims
    verbs: ["get", "list", "watch"]
  # Enable this rule only if planing to use kubernetes_secrets provider
  #- apiGroups: [""]
  #  resources:
  #  - secrets
  #  verbs: ["get"]
  - apiGroups: ["extensions"]
    resources:
      - replicasets
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources:
      - statefulsets
      - deployments
      - replicasets
      - daemonsets
    verbs: ["get", "list", "watch"]
  - apiGroups:
      - ""
    resources:
      - nodes/stats
    verbs:
      - get
  - apiGroups: [ "batch" ]
    resources:
      - jobs
      - cronjobs
    verbs: [ "get", "list", "watch" ]
  # Needed for apiserver
  - nonResourceURLs:
      - "/metrics"
    verbs:
      - get
  # Needed for cloudbeat
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources:
      - clusterrolebindings
      - clusterroles
      - rolebindings
      - roles
    verbs: ["get", "list", "watch"]
  # Needed for cloudbeat
  - apiGroups: ["policy"]
    resources:
      - podsecuritypolicies
    verbs: ["get", "list", "watch"]
  - apiGroups: [ "storage.k8s.io" ]
    resources:
      - storageclasses
    verbs: [ "get", "list", "watch" ]
EOF
