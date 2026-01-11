from pulsar import Client
import json
import time
import random

# Configuration
SERVICE_URL = "pulsar://localhost:6650"
TOPIC_NAME = "persistent://public/default/webhook-topic"

def generate_order_event(restaurant_id):
    return {
        "event_id": f"order_{int(time.time())}_{random.randint(1000,9999)}",
        "restaurant_id": restaurant_id,
        "order_id": random.randint(1000, 9999),
        "status": "ready",
        "timestamp": int(time.time())
    }

def produce_events():
    client = Client(SERVICE_URL)
    producer = client.create_producer(TOPIC_NAME)
    
    try:
        while True:
            # Simulate events from 100 restaurants
            restaurant_id = random.randint(1, 100)
            event = generate_order_event(restaurant_id)
            
            producer.send(json.dumps(event).encode('utf-8'))
            print(f"Sent event for restaurant {restaurant_id}")
            
            time.sleep(random.uniform(0.1, 0.5))  # Simulate variable rate
            
    except KeyboardInterrupt:
        producer.close()
        client.close()

if __name__ == "__main__":
    produce_events()
