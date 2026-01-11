OTEL_TRACES_EXPORTER=otlp 
OTEL_METRICS_EXPORTER=otlp 
OTEL_LOGS_EXPORTER=otlp 
OTEL_DOTNET_AUTO_TRACES_CONSOLE_EXPORTER_ENABLED=true 
OTEL_DOTNET_AUTO_METRICS_CONSOLE_EXPORTER_ENABLED=true 
OTEL_DOTNET_AUTO_LOGS_CONSOLE_EXPORTER_ENABLED=true
OTEL_SERVICE_NAME=<SERVICE_NAME>
OTEL_LOG_LEVEL=debug
OTEL_TRACES_SAMPLER=parentbased_always_on

# experimental
#*OTEL_DOTNET_AUTO_HOME
#*OTEL_DOTNET_AUTO_EXCLUDE_PROCESSES
#*OTEL_DOTNET_AUTO_FAIL_FAST_ENABLED

OTEL_DOTNET_AUTO_TRACES_INSTRUMENTATIONS_ENABLED
OTEL_DOTNET_AUTO_METRICS_INSTRUMENTATIONS_ENABLED
OTEL_DOTNET_AUTO_LOGS_INSTRUMENTATIONS_ENABLED

OTEL_DOTNET_AUTO_[TRACES|METRICS|LOGS]_{INSTRUMENTATION_ID}_INSTRUMENTATION_ENABLED

OTEL_DOTNET_AUTO_LOG_DIRECTORY

OTEL_DOTNET_AUTO_NETFX_REDIRECT_ENABLED

OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318"
# Target endpoint for the OTLP exporter. See the OpenTelemetry specification for more details.	
# http://localhost:4318 for the http/protobuf protocol, 
# http://localhost:4317 for the grpc protocol
OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
# OTLP exporter transport protocol. 
# Supported values are grpc, http/protobuf. default ->	http/protobuf
OTEL_EXPORTER_OTLP_TIMEOUT=10000
# The max waiting time (in milliseconds) for the backend to process each batch.
OTEL_EXPORTER_OTLP_HEADERS=""
# Comma-separated list of additional HTTP headers sent with each export, for example: Authorization=secret,X-Key=Value.
OTEL_ATTRIBUTE_VALUE_LENGTH_LIMIT	
# Maximum allowed attribute value size.	none
OTEL_ATTRIBUTE_COUNT_LIMIT=128
# Maximum allowed span attribute count.
OTEL_SPAN_ATTRIBUTE_VALUE_LENGTH_LIMIT
# Maximum allowed attribute value size. Not applicable for metrics..
OTEL_SPAN_ATTRIBUTE_COUNT_LIMIT=128
# Maximum allowed span attribute count. Not applicable for metrics..	
OTEL_SPAN_EVENT_COUNT_LIMIT=128
# Maximum allowed span event count.
OTEL_SPAN_LINK_COUNT_LIMIT=128
# Maximum allowed span link count.
OTEL_EVENT_ATTRIBUTE_COUNT_LIMIT=128
# Maximum allowed attribute per span event count.
OTEL_LINK_ATTRIBUTE_COUNT_LIMIT=128
# Maximum allowed attribute per span link count.