# Lab 02.3 — Google Cloud Pub/Sub

## Objetivo

Implementar uma arquitetura de mensageria utilizando **Google Cloud Pub/Sub**, explorando publicação, distribuição, consumo e tratamento de mensagens.

Neste laboratório foram trabalhados os principais conceitos do Pub/Sub, incluindo Topics, Subscriptions, Publishers, Subscribers, Consumers, ACK, NACK, Pull, Push e Dead Letter Queue (DLQ).

Também foi desenvolvido um consumidor utilizando Python e a biblioteca oficial `google-cloud-pubsub`.

---

## 1. Arquitetura

O Google Cloud Pub/Sub é um serviço de mensageria assíncrona que permite a comunicação entre aplicações e serviços sem a necessidade de comunicação direta entre produtores e consumidores.

### Componentes principais

| Componente | Responsabilidade |
|---|---|
| Publisher | Publica mensagens em um Topic. |
| Topic | Recebe e distribui mensagens para suas Subscriptions. |
| Subscription | Controla a entrega e o estado das mensagens. |
| Subscriber | Cliente que recebe mensagens de uma Subscription. |
| Consumer | Aplicação responsável por processar as mensagens. |

### Fluxo de comunicação

```text
              Publisher
                  |
                  v
                Topic
                  |
          +-------+-------+
          |               |
          v               v
    Subscription A   Subscription B
          |               |
          v               v
      Subscriber A    Subscriber B
          |               |
          v               v
      Consumer A      Consumer B
```

Um Topic pode possuir múltiplas Subscriptions independentes. Cada Subscription recebe sua própria cópia lógica das mensagens e mantém seu próprio estado de confirmação.

---

## 2. Preparação do ambiente

### Projeto GCP

| Configuração | Valor |
|---|---|
| Project ID | `ace-hands-on-labs-2026` |
| Project Number | `618071923969` |
| Region | `us-central1` |
| API | `pubsub.googleapis.com` |

### Habilitar a API

```bash
gcloud services enable pubsub.googleapis.com
```

### Instalar biblioteca Python

Com o ambiente virtual ativado:

```bash
pip install google-cloud-pubsub
```

### Configurar autenticação ADC

```bash
gcloud auth application-default login
```

Verificar a disponibilidade das credenciais:

```bash
gcloud auth application-default print-access-token
```

As Application Default Credentials (ADC) permitem que as bibliotecas cliente do Google Cloud utilizem as credenciais configuradas para autenticar as aplicações.

---

## 3. Criação do Topic e Subscriptions

### Criar Topic principal

```bash
gcloud pubsub topics create ace-lab-topic
```

### Criar Subscription Pull

```bash
gcloud pubsub subscriptions create ace-lab-sub \
  --topic=ace-lab-topic
```

### Criar Subscription Push

Para o teste Push, foi desenvolvido um endpoint HTTP utilizando Flask e disponibilizado externamente por meio de um Cloudflare Quick Tunnel.

```bash
gcloud pubsub subscriptions create ace-lab-push \
  --topic=ace-lab-topic \
  --push-endpoint=https://SEU-ENDPOINT.trycloudflare.com/
```

O endpoint acima deve ser substituído pela URL temporária gerada pelo Cloudflare Tunnel.

---

## 4. Modelo Pull

No modelo Pull, o Subscriber solicita mensagens ao Pub/Sub.

### Consultar mensagens

```bash
gcloud pubsub subscriptions pull ace-lab-sub
```

Esse comando recebe mensagens sem confirmar automaticamente seu processamento.

### Pull com ACK automático

```bash
gcloud pubsub subscriptions pull ace-lab-sub --auto-ack
```

O parâmetro `--auto-ack` confirma automaticamente as mensagens recebidas.

### ACK manual

Quando não utilizamos `--auto-ack`, o Pub/Sub retorna um ACK_ID.

Para confirmar o processamento:

```bash
gcloud pubsub subscriptions ack ace-lab-sub \
  --ack-ids="ACK_ID"
```

### ACK Deadline

O ACK Deadline representa o prazo que o consumidor possui para confirmar o processamento de uma mensagem.

Configuração utilizada:

```yaml
ackDeadlineSeconds: 10
```

Caso o ACK não seja recebido dentro do prazo, a mensagem poderá ser entregue novamente.

---

## 5. Modelo Push

No modelo Push, o próprio Pub/Sub envia as mensagens para um endpoint HTTP configurado na Subscription.

### Implementação Flask

Arquivo `main.py`:

```python
from flask import Flask, request, jsonify
import base64

app = Flask(__name__)

@app.route("/", methods=["POST"])
def receive_message():
    envelope = request.get_json()

    if not envelope or "message" not in envelope:
        return jsonify({"error": "Invalid Pub/Sub message"}), 400

    message = envelope["message"]
    data = message.get("data", "")

    decoded_data = base64.b64decode(data).decode("utf-8")

    print(f"Received message: {decoded_data}")

    return jsonify({
        "status": "success",
        "message": decoded_data
    }), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)
```

### Executar Flask

```bash
python3 main.py
```

### Criar Cloudflare Tunnel

```bash
cloudflared tunnel --url http://localhost:8080
```

O Cloudflare gera uma URL pública temporária que pode ser utilizada como endpoint da Push Subscription.

### Testar publicação

```bash
gcloud pubsub topics publish ace-lab-topic \
  --message="HelloPushWorld"
```

O Flask recebeu a mensagem e retornou HTTP 200, confirmando o recebimento.

**Observação:** o Cloudflare Quick Tunnel foi utilizado somente para fins de laboratório. Não representa uma configuração recomendada para produção.

---

## 6. ACK e NACK

O ACK e o NACK representam os resultados do processamento de uma mensagem.

| Operação | Comportamento |
|---|---|
| ACK | Confirma que a mensagem foi processada. |
| NACK | Rejeita a mensagem e solicita uma nova entrega. |

### ACK

Quando o consumidor termina o processamento com sucesso, deve confirmar a mensagem.

```python
message.ack()
```

### NACK

Quando ocorre uma falha no processamento, o consumidor pode rejeitar a mensagem:

```python
message.nack()
```

O Pub/Sub poderá disponibilizar a mensagem novamente para processamento.

---

## 7. Dead Letter Queue (DLQ)

A Dead Letter Queue é um mecanismo utilizado para tratar mensagens que não conseguem ser processadas após múltiplas tentativas de entrega.

Quando uma mensagem ultrapassa o limite configurado de tentativas, o Pub/Sub pode encaminhá-la para um Topic específico de Dead Letter.

### Arquitetura DLQ

```text
          Publisher
              |
              v
        ace-lab-topic
              |
              v
        ace-lab-sub
              |
              v
        Consumer Python
              |
        Processing Failure
              |
             NACK
              |
       Retry / Redelivery
              |
     Maximum Delivery Attempts
              |
              v
    ace-dead-letter-topic
              |
              v
    ace-dead-letter-sub
```

### Criar Topic DLQ

```bash
gcloud pubsub topics create ace-dead-letter-topic
```

### Criar Subscription para DLQ

```bash
gcloud pubsub subscriptions create ace-dead-letter-sub \
  --topic=ace-dead-letter-topic
```

### Configurar Dead Letter Policy

```bash
gcloud pubsub subscriptions update ace-lab-sub \
  --dead-letter-topic=ace-dead-letter-topic \
  --max-delivery-attempts=5
```

O parâmetro `max-delivery-attempts` define o número máximo aproximado de tentativas antes do encaminhamento.

O encaminhamento é realizado em regime best-effort, portanto não deve ser tratado como uma contagem ou garantia de tempo exata.

---

## 8. IAM — Permissões do Dead Letter Queue

O encaminhamento de mensagens para o DLQ exige permissões específicas para o Service Agent do Pub/Sub.

### Service Agent

```text
service-618071923969@gcp-sa-pubsub.iam.gserviceaccount.com
```

### Permissão de publicação no tópico DLQ

```bash
gcloud pubsub topics add-iam-policy-binding ace-dead-letter-topic \
  --member="serviceAccount:service-618071923969@gcp-sa-pubsub.iam.gserviceaccount.com" \
  --role="roles/pubsub.publisher"
```

Essa permissão permite que o agente publique mensagens no tópico de Dead Letter.

### Permissão de consumo na Subscription de origem

```bash
gcloud pubsub subscriptions add-iam-policy-binding ace-lab-sub \
  --member="serviceAccount:service-618071923969@gcp-sa-pubsub.iam.gserviceaccount.com" \
  --role="roles/pubsub.subscriber"
```

Essa permissão permite que o agente gerencie o encaminhamento das mensagens da Subscription de origem.

### Consultar IAM

Verificar as permissões do tópico:

```bash
gcloud pubsub topics get-iam-policy ace-dead-letter-topic
```

Verificar as permissões da Subscription:

```bash
gcloud pubsub subscriptions get-iam-policy ace-lab-sub
```

---

## 9. Implementação do Consumer Python

Para realizar um teste mais próximo de um cenário real, foi desenvolvido um consumidor utilizando a biblioteca oficial `google-cloud-pubsub`.

Arquivo `subscriber.py`:

```python
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
```

### Executar Consumer

```bash
python3 subscriber.py
```

O Subscriber permanece ativo aguardando mensagens.

Quando uma mensagem é recebida, a função `callback` é executada.

Nesse laboratório, utilizamos `message.nack()` para simular falhas de processamento e provocar novas tentativas de entrega.

---

## 10. Teste prático do DLQ

Para isolar o teste e evitar interferência de mensagens antigas, foi criada uma Subscription exclusiva.

### Criar Subscription de teste

```bash
gcloud pubsub subscriptions create ace-lab-dlq-test \
  --topic=ace-lab-topic \
  --dead-letter-topic=ace-dead-letter-topic \
  --max-delivery-attempts=5
```

### Conceder permissão ao Service Agent

```bash
gcloud pubsub subscriptions add-iam-policy-binding ace-lab-dlq-test \
  --member="serviceAccount:service-618071923969@gcp-sa-pubsub.iam.gserviceaccount.com" \
  --role="roles/pubsub.subscriber"
```

### Publicar mensagem

```bash
gcloud pubsub topics publish ace-lab-topic \
  --message="DLQ-Isolated-Test"
```

Mensagem publicada:

```text
DLQ-Isolated-Test
```

Message ID original:

```text
22653536520058209
```

### Executar Consumer

```bash
python3 subscriber.py
```

O consumidor recebeu a mesma mensagem repetidamente e executou NACK em cada tentativa.

### Resultado observado

```text
Listening on projects/ace-hands-on-labs-2026/subscriptions/ace-lab-dlq-test...

Message received: DLQ-Isolated-Test
Message ID: 22653536520058209
Simulating processing failure...

Message received: DLQ-Isolated-Test
Message ID: 22653536520058209
Simulating processing failure...

Message received: DLQ-Isolated-Test
Message ID: 22653536520058209
Simulating processing failure...

Message received: DLQ-Isolated-Test
Message ID: 22653536520058209
Simulating processing failure...

Message received: DLQ-Isolated-Test
Message ID: 22653536520058209
Simulating processing failure...
```

### Consultar mensagem encaminhada

```bash
gcloud pubsub subscriptions pull ace-dead-letter-sub
```

Resultado observado:

```text
DATA: DLQ-Isolated-Test

ATTRIBUTES:
CloudPubSubDeadLetterSourceDeliveryCount=5

CloudPubSubDeadLetterSourceSubscription=ace-lab-dlq-test

CloudPubSubDeadLetterSourceSubscriptionProject=ace-hands-on-labs-2026
```

**Resultado: sucesso!**

O atributo `CloudPubSubDeadLetterSourceDeliveryCount=5` confirmou que a mensagem foi encaminhada após cinco tentativas de entrega observadas.

O Pub/Sub também adicionou metadados identificando a Subscription e o projeto de origem.

O ID da mensagem no tópico DLQ é diferente do ID original, pois o encaminhamento publica uma nova cópia da mensagem.

### Confirmar processamento no DLQ

Depois de inspecionar a mensagem, foi realizado o ACK:

```bash
gcloud pubsub subscriptions ack ace-dead-letter-sub \
  --ack-ids="ACK_ID"
```

Resultado:

```text
Acked the messages with the following ackIds: [...]
```

---

## 11. Comandos úteis do Pub/Sub

| Comando | Finalidade |
|---|---|
| `gcloud pubsub topics create` | Criar Topic |
| `gcloud pubsub topics list` | Listar Topics |
| `gcloud pubsub topics publish` | Publicar mensagem |
| `gcloud pubsub topics describe` | Consultar Topic |
| `gcloud pubsub topics delete` | Excluir Topic |
| `gcloud pubsub subscriptions create` | Criar Subscription |
| `gcloud pubsub subscriptions list` | Listar Subscriptions |
| `gcloud pubsub subscriptions pull` | Receber mensagens |
| `gcloud pubsub subscriptions ack` | Confirmar mensagens |
| `gcloud pubsub subscriptions describe` | Consultar configuração |
| `gcloud pubsub subscriptions update` | Atualizar configuração |
| `gcloud pubsub subscriptions delete` | Excluir Subscription |

---

## 12. Limpeza dos recursos

Ao finalizar o laboratório, todos os recursos temporários do Pub/Sub foram removidos.

### Excluir Subscriptions

```bash
gcloud pubsub subscriptions delete ace-lab-sub

gcloud pubsub subscriptions delete ace-lab-push

gcloud pubsub subscriptions delete ace-dead-letter-sub

gcloud pubsub subscriptions delete ace-lab-dlq-test
```

### Excluir Topics

```bash
gcloud pubsub topics delete ace-lab-topic

gcloud pubsub topics delete ace-dead-letter-topic
```

Os arquivos Python e o ambiente virtual foram preservados localmente.

---

## 13. Principais aprendizados para a certificação ACE

- Diferença entre Publisher, Topic, Subscription, Subscriber e Consumer.
- Arquitetura de mensageria assíncrona.
- Diferenças entre Pull e Push subscriptions.
- Funcionamento de ACK e NACK.
- ACK Deadline e redelivery.
- Múltiplas Subscriptions independentes vinculadas ao mesmo Topic.
- Configuração de Dead Letter Queue.
- Configuração de IAM para encaminhamento de mensagens.
- Integração de aplicações Python com Google Cloud Pub/Sub.
- Uso de Application Default Credentials (ADC).
- Utilização da biblioteca oficial `google-cloud-pubsub`.

### Conceitos importantes

**ACK:** confirma que a mensagem foi processada com sucesso.

**NACK:** rejeita a mensagem e solicita uma nova entrega.

**Dead Letter Queue:** mecanismo para encaminhar mensagens que excedem o limite configurado de tentativas.

**Pull:** o consumidor solicita mensagens ao Pub/Sub.

**Push:** o Pub/Sub envia mensagens para um endpoint HTTP.

**ACK Deadline:** prazo para confirmar o processamento de uma mensagem.

---

## Status do laboratório

**Concluído.**

Foi implementada e testada uma arquitetura de mensageria com Google Cloud Pub/Sub, incluindo publicação, consumo Pull e Push, processamento de mensagens com Python, configuração de IAM e encaminhamento de mensagens para uma Dead Letter Queue.

O teste de DLQ foi validado por meio dos atributos adicionados automaticamente pelo Pub/Sub à mensagem encaminhada.
