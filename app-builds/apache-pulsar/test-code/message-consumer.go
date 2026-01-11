package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/apache/pulsar-client-go/pulsar"
)

type OrderEvent struct {
	EventID      string `json:"event_id"`
	RestaurantID int    `json:"restaurant_id"`
	OrderID      int    `json:"order_id"`
	Status       string `json:"status"`
	Timestamp    int64  `json:"timestamp"`
}

func main() {
	client, err := pulsar.NewClient(pulsar.ClientOptions{
		URL: "pulsar://localhost:6650",
	})
	if err != nil {
		log.Fatal(err)
	}
	defer client.Close()

	consumer, err := client.Subscribe(pulsar.ConsumerOptions{
		Topic:            "webhook-topic",
		SubscriptionName: "webhook-subscription",
		Type:             pulsar.Shared,
	})
	if err != nil {
		log.Fatal(err)
	}
	defer consumer.Close()

	for {
		msg, err := consumer.Receive(context.Background())
		if err != nil {
			log.Printf("Error receiving message: %v", err)
			continue
		}

		var event OrderEvent
		if err := json.Unmarshal(msg.Payload(), &event); err != nil {
			log.Printf("Error decoding message: %v", err)
			consumer.Nack(msg)
			continue
		}

		// Get webhook URL (replace with your actual lookup logic)
		webhookURL := getWebhookURL(event.RestaurantID)
		if webhookURL == "" {
			log.Printf("No webhook URL found for restaurant %d", event.RestaurantID)
			consumer.Nack(msg)
			continue
		}

		// Send webhook with retries
		if err := sendWithRetries(webhookURL, event, 3); err != nil {
			log.Printf("Failed to deliver to %s: %v", webhookURL, err)
			consumer.Nack(msg)
			continue
		}

		consumer.Ack(msg)
		log.Printf("Successfully delivered event %s", event.EventID)
	}
}

func getWebhookURL(restaurantID int) string {
	// Replace with your actual URL lookup logic
	return fmt.Sprintf("https://webhook.site/%d", restaurantID)
}

func sendWithRetries(url string, event OrderEvent, maxRetries int) error {
	client := &http.Client{Timeout: 5 * time.Second}
	payload, _ := json.Marshal(event)

	for i := 0; i < maxRetries; i++ {
		resp, err := client.Post(url, "application/json", bytes.NewReader(payload))
		if err == nil && resp.StatusCode >= 200 && resp.StatusCode < 300 {
			return nil
		}

		if i < maxRetries-1 {
			backoff := time.Duration(i+1) * time.Second * 2
			time.Sleep(backoff)
		}
	}

	return fmt.Errorf("failed after %d attempts", maxRetries)
}
