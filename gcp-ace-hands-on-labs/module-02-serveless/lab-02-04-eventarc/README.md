# Lab 02.4 — Cloud Storage + Eventarc + Cloud Run (Java)

## Objetivo

Implementar uma arquitetura orientada a eventos utilizando Google Cloud Storage, Eventarc e Cloud Run Functions com Java 21.

O objetivo é detectar automaticamente quando um arquivo é criado em um bucket do Cloud Storage e encaminhar o evento para uma aplicação Java, responsável por interpretar e registrar os dados recebidos.

## Arquitetura

```text
Cloud Storage
     |
     | Object finalized
     v
Eventarc
     |
     | Event transport (Pub/Sub)
     v
Cloud Run — Java 21
     |
     | CloudEvent
     v
Cloud Logging
```

### Responsabilidades

- **Cloud Storage:** armazenamento dos arquivos.
- **Eventarc:** detecção e encaminhamento dos eventos.
- **Pub/Sub:** transporte interno dos eventos utilizados pelo Eventarc.
- **Cloud Run:** execução da aplicação Java.
- **Cloud Logging:** armazenamento dos registros da execução.

## Tecnologias utilizadas

- Java 21
- Apache Maven 3.9.12
- Google Cloud SDK
- Cloud Storage
- Eventarc
- Cloud Run
- Cloud Logging
- Functions Framework for Java
- Jackson
- CloudEvents API

## Estrutura do projeto

```text
lab-02-04-eventarc/
├── pom.xml
├── src/
│   └── main/
│       └── java/
│           └── com/
│               └── example/
│                   └── EventarcFunction.java
└── target/
```

## 1. Habilitação das APIs

```bash
gcloud services enable \
  storage.googleapis.com \
  eventarc.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com
```

## 2. Cloud Storage

Criação do bucket:

```bash
gcloud storage buckets create gs://ace-hands-on-labs-2026-eventarc \
  --location=us-central1 \
  --uniform-bucket-level-access
```

Configurações:
- Bucket: `ace-hands-on-labs-2026-eventarc`
- Região: `us-central1`
- Storage class: STANDARD
- Uniform Bucket-Level Access: habilitado.

## 3. Implementação Java

A aplicação utiliza a interface `CloudEventsFunction` para receber eventos.

O método `accept()` recebe o CloudEvent encaminhado pelo Eventarc.

O Jackson é utilizado para interpretar o JSON dos dados do evento.

Principais informações extraídas:

- Event ID
- Event Type
- Event Source
- Bucket
- Nome do arquivo
- Generation

O evento utilizado é:

```text
google.cloud.storage.object.v1.finalized
```

Esse evento ocorre quando um objeto é criado ou uma nova geração de objeto é concluída no Cloud Storage.

## 4. Maven

As principais dependências utilizadas:

- `functions-framework-api`
- `cloudevents-api`
- `jackson-databind`

O projeto utiliza Java 21.

Compilação:

```bash
mvn clean package
```

Execução local:

```bash
mvn function:run
```

## 5. Configuração IAM

Foram configuradas as seguintes identidades e permissões:

| Identidade | Role |
|---|---|
| Cloud Storage Service Agent | `roles/pubsub.publisher` |
| Eventarc Service Agent | `roles/eventarc.serviceAgent` |
| `sa-cloudrun` | `roles/run.invoker` |
| `sa-cloudrun` | `roles/eventarc.eventReceiver` |
| Compute Engine Default Service Account | `roles/run.builder` |

As permissões permitem a publicação, o transporte e a entrega dos eventos, além da construção e execução da aplicação.

## 6. Deploy no Cloud Run

A função foi implantada utilizando o comando:

```bash
gcloud run deploy eventarc-storage-java \
  --source . \
  --function com.example.EventarcFunction \
  --base-image java21 \
  --region us-central1 \
  --service-account sa-cloudrun@ace-hands-on-labs-2026.iam.gserviceaccount.com \
  --no-allow-unauthenticated
```

O Cloud Build realizou a construção da aplicação a partir do código-fonte e do `pom.xml`.

Configurações:
- Serviço: `eventarc-storage-java`
- Runtime: Java 21
- Região: `us-central1`
- Autenticação: obrigatória.

## 7. Criação do Eventarc Trigger

```bash
gcloud eventarc triggers create eventarc-storage-trigger \
  --location=us-central1 \
  --destination-run-service=eventarc-storage-java \
  --destination-run-region=us-central1 \
  --event-filters="type=google.cloud.storage.object.v1.finalized" \
  --event-filters="bucket=ace-hands-on-labs-2026-eventarc" \
  --service-account=sa-cloudrun@ace-hands-on-labs-2026.iam.gserviceaccount.com
```

O gatilho monitora o bucket e encaminha eventos de criação de objetos para o serviço Cloud Run.

O Eventarc também provisiona os recursos de transporte necessários no Pub/Sub.

## 8. Teste da integração

Criação do arquivo:

```bash
printf '%s\n' 'Hello Eventarc Java!' > test-event.txt
```

Upload:

```bash
gcloud storage cp test-event.txt gs://ace-hands-on-labs-2026-eventarc/
```

Após o upload, o Cloud Storage gera o evento `object.finalized`, que é encaminhado pelo Eventarc para a aplicação Java.

## 9. Monitoramento

Consulta dos logs:

```bash
gcloud run services logs read eventarc-storage-java \
  --region=us-central1 \
  --limit=30
```

Para consultar os registros estruturados:

```bash
gcloud logging read \
  'resource.type="cloud_run_revision"
   AND resource.labels.service_name="eventarc-storage-java"' \
  --project=ace-hands-on-labs-2026 \
  --limit=30 \
  --format=json
```

## 10. Resultado obtido

A integração foi executada com sucesso.

O Cloud Run recebeu uma requisição POST com HTTP 200, encaminhada pelo Eventarc.

Os logs confirmaram o processamento do evento:

```text
Eventarc event received!
Event Type: google.cloud.storage.object.v1.finalized
New file received!
Bucket: ace-hands-on-labs-2026-eventarc
File: test-event.txt
Generation: 1795370954933203
```

Também foi validado que o acesso direto pelo navegador retornava HTTP 403, conforme esperado, pois o serviço foi implantado sem permitir invocações não autenticadas.

## 11. Conceitos aprendidos

- Arquitetura orientada a eventos (Event-Driven Architecture).
- Integração entre Cloud Storage e Eventarc.
- Transporte de eventos utilizando Pub/Sub.
- Implementação de CloudEvents com Java.
- Utilização do Functions Framework for Java.
- Gerenciamento de dependências com Maven.
- Deploy de funções Java 21 no Cloud Run.
- IAM e Service Accounts.
- Monitoramento com Cloud Logging.
- Autenticação entre serviços Google Cloud.

## Conclusão

Neste laboratório foi implementada uma integração serverless orientada a eventos, utilizando Java 21 e serviços gerenciados do Google Cloud.

A solução permite reagir automaticamente ao envio de arquivos para o Cloud Storage, desacoplando o armazenamento da lógica de processamento.

Essa arquitetura pode ser aplicada em pipelines de processamento de arquivos, ingestão de documentos, transcrição de áudios e automações corporativas.
