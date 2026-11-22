
from concurrent.futures import TimeoutError
from google.cloud import pubsub_v1

PROJECT_ID = "ace-hands-on-labs-2026"
SUBSCRIPTION_ID = "ace-lab-dlq-test"

subscriber = pubsub_v1.SubscriberClient()

subscription_path = subscriber.subscription_path(
    PROJECT_ID,
    SUBSCRIPTION_ID
)


def callback(message):
    print(f"Message received: {message.data.decode('utf-8')}")
    print(f"Message ID: {message.message_id}")

    print("Simulating processing failure...")
    message.nack()


streaming_pull_future = subscriber.subscribe(
    subscription_path,
    callback=callback
)

print(f"Listening on {subscription_path}...")

with subscriber:
    try:
        streaming_pull_future.result(timeout=300)
    except TimeoutError:
        streaming_pull_future.cancel()
        streaming_pull_future.result()
