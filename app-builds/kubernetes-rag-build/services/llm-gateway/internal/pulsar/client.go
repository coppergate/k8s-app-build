package pulsar

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/apache/pulsar-client-go/pulsar"
	"app-builds/llm-gateway/internal/config"
)

type PulsarClient struct {
	client   pulsar.Client
	producer pulsar.Producer
	pending  sync.Map // correlationID -> chan string
}

func NewPulsarClient(cfg *config.Config) (*PulsarClient, error) {
	client, err := pulsar.NewClient(pulsar.ClientOptions{
		URL: cfg.PulsarURL,
	})
	if err != nil {
		return nil, fmt.Errorf("could not create pulsar client: %w", err)
	}

	producer, err := client.CreateProducer(pulsar.ProducerOptions{
		Topic: cfg.RequestTopic,
	})
	if err != nil {
		client.Close()
		return nil, fmt.Errorf("could not create pulsar producer: %w", err)
	}

	pc := &PulsarClient{
		client:   client,
		producer: producer,
	}

	go pc.consumeResults(cfg.ResponseTopic)

	return pc, nil
}

func (pc *PulsarClient) consumeResults(topic string) {
	consumer, err := pc.client.Subscribe(pulsar.ConsumerOptions{
		Topic:            topic,
		SubscriptionName: "gateway-results-sub",
		Type:             pulsar.Shared,
	})
	if err != nil {
		fmt.Printf("Error subscribing to results: %v\n", err)
		return
	}
	defer consumer.Close()

	for {
		msg, err := consumer.Receive(context.Background())
		if err != nil {
			fmt.Printf("Error receiving message: %v\n", err)
			continue
		}

		var resp struct {
			ID     string `json:"id"`
			Result string `json:"result"`
		}
		if err := json.Unmarshal(msg.Payload(), &resp); err == nil {
			if ch, ok := pc.pending.Load(resp.ID); ok {
				ch.(chan string) <- resp.Result
			}
		}

		consumer.Ack(msg)
	}
}

func (pc *PulsarClient) SendRequest(ctx context.Context, id string, payload interface{}) (string, error) {
	resChan := make(chan string, 1)
	pc.pending.Store(id, resChan)
	defer pc.pending.Delete(id)

	data, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	_, err = pc.producer.Send(ctx, &pulsar.ProducerMessage{
		Payload: data,
	})
	if err != nil {
		return "", err
	}

	select {
	case res := <-resChan:
		return res, nil
	case <-ctx.Done():
		return "", ctx.Err()
	case <-time.After(120 * time.Second):
		return "", fmt.Errorf("request timed out")
	}
}

func (pc *PulsarClient) Close() {
	pc.producer.Close()
	pc.client.Close()
}
