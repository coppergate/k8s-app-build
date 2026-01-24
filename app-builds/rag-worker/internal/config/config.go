package config

import (
	"os"
)

type Config struct {
	PulsarURL           string
	PulsarRequestTopic  string
	PulsarResponseTopic string
	PulsarSubscription  string
	QdrantHost          string
	QdrantPort          string
	OllamaURL           string
	OllamaModel         string
}

func LoadConfig() *Config {
	return &Config{
		PulsarURL:           getEnv("PULSAR_URL", "pulsar://pulsar-proxy.apache-pulsar.svc.cluster.local:6650"),
		PulsarRequestTopic:  getEnv("PULSAR_REQUEST_TOPIC", "persistent://public/default/llm-tasks"),
		PulsarResponseTopic: getEnv("PULSAR_RESPONSE_TOPIC", "persistent://public/default/llm-results"),
		PulsarSubscription:  getEnv("PULSAR_SUBSCRIPTION", "rag-worker-sub"),
		QdrantHost:          getEnv("QDRANT_HOST", "qdrant.rag-system.svc.cluster.local"),
		QdrantPort:          getEnv("QDRANT_PORT", "6333"),
		OllamaURL:           getEnv("OLLAMA_URL", "http://ollama.llms-ollama.svc.cluster.local:11434"),
		OllamaModel:         getEnv("OLLAMA_MODEL", "llama3.1"),
	}
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}
