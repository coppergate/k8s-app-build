
echo "install echo-server for auto-instrumentation otel test"
kubectl create namespace test-deploys


kubectl apply  -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-server
  namespace: test-deploys
  labels:
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
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
        instrumentation.opentelemetry.io/inject-dotnet: "observability/arch-otel-auto-instrumentation"  
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
      - image: jmalloc/echo-server
        imagePullPolicy: Always
        name: echo-server
        env:
          - name: OTEL_LOG_LEVEL
            value: "Debug"
          - name: OTEL_SERVICE_NAME
            value: "echo-server-test-deploy"
          - name: DEPLOY_NAMESPACE
            value: "test-deploys"
          - name: QSR_OTEL_SERVICE_VERSION
            value: "1.0"
          - name: OTEL_EXPORTER_OTLP_ENDPOINT
            value: "https://arch-opentelemetry.private.k8s-apm.qsrpolarisdev.net/"
          - name: OTEL_DOTNET_AUTO_LOGS_CONSOLE_EXPORTER_ENABLED
            value: "true"
          - name: OTEL_DOTNET_AUTO_METRICS_CONSOLE_EXPORTER_ENABLED
            value: "true"
          - name: OTEL_DOTNET_AUTO_TRACES_CONSOLE_EXPORTER_ENABLED
            value: "true"
          - name: OTEL_TRACES_EXPORTER
            value: "otlp"
          - name: OTEL_METRICS_EXPORTER
            value: "otlp"
          - name: OTEL_LOGS_EXPORTER
            value: "otlp"
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
EOF