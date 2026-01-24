package config

import (
	"os"
)

type Config struct {
	PulsarURL       string
	RequestTopic    string
	ResponseTopic   string
	ListenAddr      string
	PulsarNamespace string
	DBConnString    string
}

func Load() *Config {
	return &Config{
		PulsarURL:       getEnv("PULSAR_URL", "pulsar://pulsar-proxy.apache-pulsar.svc.cluster.local:6650"),
		RequestTopic:    getEnv("PULSAR_REQUEST_TOPIC", "persistent://public/default/llm-tasks"),
		ResponseTopic:   getEnv("PULSAR_RESPONSE_TOPIC", "persistent://public/default/llm-results"),
		ListenAddr:      getEnv("LISTEN_ADDR", ":8080"),
		PulsarNamespace: getEnv("PULSAR_NAMESPACE", "apache-pulsar"),
		DBConnString:    getEnv("DB_CONN_STRING", "postgres://postgres:password@timescaledb-rw.timescaledb.svc.cluster.local:5432/postgres?sslmode=disable"),
	}
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}
