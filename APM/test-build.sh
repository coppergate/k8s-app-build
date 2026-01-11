
pathToAutoTestServiceDocker='/mnt/c/code/kubernetes-setup/TestCode/otlp-test-microservice-auto'
pathToManualTestServiceDocker='/mnt/c/code/kubernetes-setup/TestCode/otlp-test-microservice-manual'

minikube image build --file='/mnt/c/code/kubernetes-setup/TestCode/otlp-test-microservice-auto' -t k8s/otel-test-service-auto:1.0.0
minikube image build --file=$pathToManualTestServiceDocker -t k8s/otel-test-service-manual:1.0.0


