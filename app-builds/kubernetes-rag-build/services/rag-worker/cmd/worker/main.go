package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strings"

	"github.com/apache/pulsar-client-go/pulsar"
	"app-builds/rag-worker/internal/config"
	"app-builds/rag-worker/internal/ollama"
	"app-builds/rag-worker/internal/qdrant"
)

type Worker struct {
	cfg      *config.Config
	pulsar   pulsar.Client
	ollama   *ollama.OllamaClient
	qdrant   *qdrant.QdrantClient
	producer pulsar.Producer
}

func main() {
	cfg := config.LoadConfig()

	client, err := pulsar.NewClient(pulsar.ClientOptions{
		URL: cfg.PulsarURL,
	})
	if err != nil {
		log.Fatalf("Could not instantiate Pulsar client: %v", err)
	}
	defer client.Close()

	producer, err := client.CreateProducer(pulsar.ProducerOptions{
		Topic: cfg.PulsarResponseTopic,
	})
	if err != nil {
		log.Fatalf("Could not create Pulsar producer: %v", err)
	}
	defer producer.Close()

	worker := &Worker{
		cfg:      cfg,
		pulsar:   client,
		ollama:   ollama.NewClient(cfg),
		qdrant:   qdrant.NewClient(cfg),
		producer: producer,
	}

	consumer, err := client.Subscribe(pulsar.ConsumerOptions{
		Topic:            cfg.PulsarRequestTopic,
		SubscriptionName: cfg.PulsarSubscription,
		Type:            pulsar.Shared,
	})
	if err != nil {
		log.Fatalf("Could not create Pulsar consumer: %v", err)
	}
	defer consumer.Close()

	log.Printf("RAG Worker started, listening on %s", cfg.PulsarRequestTopic)

	for {
		msg, err := consumer.Receive(context.Background())
		if err != nil {
			log.Printf("Error receiving message: %v", err)
			continue
		}

		go worker.handleMessage(msg, consumer)
	}
}

func (w *Worker) handleMessage(msg pulsar.Message, consumer pulsar.Consumer) {
	defer consumer.Ack(msg)

	var data map[string]interface{}
	if err := json.Unmarshal(msg.Payload(), &data); err != nil {
		log.Printf("Error unmarshaling payload: %v", err)
		return
	}

	correlationID, _ := data["id"].(string)
	sessionID, _ := data["session_id"].(string)

	// Extract prompt from payload.messages
	var prompt string
	if payload, ok := data["payload"].(map[string]interface{}); ok {
		if messages, ok := payload["messages"].([]interface{}); ok && len(messages) > 0 {
			if lastMsg, ok := messages[len(messages)-1].(map[string]interface{}); ok {
				prompt, _ = lastMsg["content"].(string)
			}
		}
	}

	if prompt == "" {
		log.Printf("[%s] Error: No prompt found in message", correlationID)
		w.sendError(correlationID, "No prompt found in message")
		return
	}

	collection := "codebase" // Default collection

	log.Printf("[%s] (Session: %s) Processing request: %s", correlationID, sessionID, prompt)

	// 1. Get Embeddings for the prompt
	log.Printf("[%s] Getting embeddings from Ollama...", correlationID)
	vector, err := w.ollama.GetEmbeddings(prompt)
	if err != nil {
		log.Printf("[%s] Error getting embeddings: %v", correlationID, err)
		w.sendError(correlationID, fmt.Sprintf("Error getting embeddings: %v", err))
		return
	}
	log.Printf("[%s] Got embeddings (size: %d)", correlationID, len(vector))

	// 2. Search Qdrant for context
	log.Printf("[%s] Searching Qdrant context...", correlationID)
	contexts, err := w.qdrant.Search(collection, vector, 5)
	if err != nil {
		log.Printf("[%s] Error searching Qdrant: %v", correlationID, err)
		// Fallback to no context or send error? Let's fallback with warning
	}
	log.Printf("[%s] Found %d context snippets", correlationID, len(contexts))

	// 3. Construct Augmented Prompt
	augmentedPrompt := "Context information is below.\n---------------------\n"
	augmentedPrompt += strings.Join(contexts, "\n\n")
	augmentedPrompt += "\n---------------------\nGiven the context information and not prior knowledge, answer the query.\n"
	augmentedPrompt += "Query: " + prompt + "\nAnswer: "

	messages := []map[string]string{
		{"role": "user", "content": augmentedPrompt},
	}

	// 4. Call Ollama
	log.Printf("[%s] Calling Ollama for chat completion...", correlationID)
	result, err := w.ollama.Chat(messages)
	if err != nil {
		log.Printf("[%s] Error calling Ollama: %v", correlationID, err)
		w.sendError(correlationID, fmt.Sprintf("Error calling Ollama: %v", err))
		return
	}
	log.Printf("[%s] Got response from Ollama (%d chars)", correlationID, len(result))

	// 5. Send Result back to Pulsar
	w.sendResult(correlationID, result)
}

func (w *Worker) sendResult(id, result string) {
	payload, _ := json.Marshal(map[string]string{
		"id":     id,
		"result": result,
	})
	w.producer.Send(context.Background(), &pulsar.ProducerMessage{
		Payload: payload,
	})
	log.Printf("[%s] Result sent", id)
}

func (w *Worker) sendError(id, errMsg string) {
	payload, _ := json.Marshal(map[string]string{
		"id":    id,
		"error": errMsg,
	})
	w.producer.Send(context.Background(), &pulsar.ProducerMessage{
		Payload: payload,
	})
}
