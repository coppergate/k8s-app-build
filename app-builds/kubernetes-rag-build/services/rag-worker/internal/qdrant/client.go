package qdrant

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
	"app-builds/rag-worker/internal/config"
)

type QdrantClient struct {
	cfg        *config.Config
	httpClient *http.Client
}

func NewClient(cfg *config.Config) *QdrantClient {
	return &QdrantClient{
		cfg:        cfg,
		httpClient: &http.Client{Timeout: 10 * time.Second},
	}
}

func (q *QdrantClient) Search(collection string, vector []float32, limit int) ([]string, error) {
	url := fmt.Sprintf("http://%s:%s/collections/%s/points/search", q.cfg.QdrantHost, q.cfg.QdrantPort, collection)
	
	query := map[string]interface{}{
		"vector": vector,
		"limit":  limit,
		"with_payload": true,
	}
	
	body, _ := json.Marshal(query)
	resp, err := q.httpClient.Post(url, "application/json", bytes.NewBuffer(body))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("qdrant returned status %d", resp.StatusCode)
	}

	var result struct {
		Result []struct {
			Payload map[string]interface{} `json:"payload"`
		} `json:"result"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	var contexts []string
	for _, r := range result.Result {
		if text, ok := r.Payload["text"].(string); ok {
			contexts = append(contexts, text)
		}
	}

	return contexts, nil
}
