# Lab 02.2 — Cloud Functions Gen 2 (HTTP)

## Objetivo

Implementar e publicar uma função HTTP utilizando Google Cloud Functions Gen 2 e Python 3.12.

Neste laboratório, praticamos o desenvolvimento, deploy, monitoramento, versionamento, configuração de variáveis de ambiente, gerenciamento de identidade e integração com Cloud Storage.

Também aplicamos permissões IAM para controlar o acesso da função aos objetos armazenados em um bucket.

## Ambiente

| Configuração | Valor |
|---|---|
| Cloud Provider | Google Cloud Platform |
| Projeto | `ace-hands-on-labs-2026` |
| Região | `us-central1` |
| Serviço | Cloud Functions Gen 2 |
| Runtime | Python 3.12 |
| Linguagem | Python |
| Framework | Functions Framework |
| Storage | Cloud Storage |
| Identidade | Service Account dedicada |

## Estrutura do projeto

```text
lab-02-02-cloud-functions/
├── main.py
├── requirements.txt
├── README.md
└── deploy.sh
```

## 1. Implementação inicial

### main.py

A função HTTP inicial retorna uma resposta JSON.

```python
from flask import jsonify

def hello_http(request):
    return jsonify({
        "message": "Hello from Cloud Functions!",
        "runtime": "Python 3.12",
        "service": "cloud-functions",
        "version": "2.0",
        "environment": "GCP"
    })
```

### requirements.txt

```text
functions-framework==3.*
google-cloud-storage
```

## 2. Configuração local

Instalação das dependências:

```bash
python3 -m pip install -r requirements.txt
```

Execução local:

```bash
python3 -m functions_framework \
  --target=hello_http \
  --debug \
  --port=8080
```

Teste HTTP:

```bash
curl http://localhost:8080
```

## 3. APIs necessárias

Habilitação das APIs utilizadas:

```bash
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable run.googleapis.com
```

## 4. Deploy da Cloud Function

```bash
gcloud functions deploy hello-http \
  --gen2 \
  --runtime=python312 \
  --region=us-central1 \
  --source=. \
  --entry-point=hello_http \
  --trigger-http \
  --allow-unauthenticated
```

### Parâmetros importantes

| Parâmetro | Descrição |
|---|---|
| `--gen2` | Utiliza Cloud Functions de segunda geração |
| `--runtime` | Define a versão do runtime |
| `--region` | Define a região |
| `--source` | Diretório do código-fonte |
| `--entry-point` | Função Python de entrada |
| `--trigger-http` | Configura acionamento HTTP |
| `--allow-unauthenticated` | Permite chamadas sem autenticação |

> Atenção: o acesso público foi habilitado para fins didáticos.

## 5. Testes em produção

Consulta da função:

```bash
gcloud functions list --regions=us-central1
```

Consulta dos detalhes:

```bash
gcloud functions describe hello-http \
  --region=us-central1 \
  --gen2
```

Consulta dos logs:

```bash
gcloud functions logs read hello-http \
  --region=us-central1 \
  --gen2 \
  --limit=10
```

Teste do endpoint:

```bash
curl https://us-central1-ace-hands-on-labs-2026.cloudfunctions.net/hello-http
```

## 6. Revisões

A cada atualização implantada, uma nova revisão é criada.

Revisões observadas durante o laboratório:

- `hello-http-00001-ves`
- `hello-http-00002-poz`
- `hello-http-00003-cuf`
- `hello-http-00004-yon`
- `hello-http-00005-mop`
- `hello-http-00006-xeg`

A atualização da função cria uma nova revisão e, na configuração utilizada, direciona 100% do tráfego para a versão mais recente.

## 7. Variáveis de ambiente

Configuração de uma variável personalizada:

```bash
gcloud functions deploy hello-http \
  --gen2 \
  --region=us-central1 \
  --update-env-vars APP_ENV=production
```

Consulta:

```bash
gcloud functions describe hello-http \
  --region=us-central1 \
  --gen2 \
  --format="yaml(serviceConfig.environmentVariables)"
```

No Python, as variáveis são acessadas com:

```python
import os

environment = os.environ.get("APP_ENV", "not-configured")
```

## 8. Service Account e IAM

Criação de uma identidade dedicada:

```bash
gcloud iam service-accounts create sa-cloud-function \
  --display-name="Cloud Function Runtime"
```

Associação à função:

```bash
gcloud functions deploy hello-http \
  --gen2 \
  --region=us-central1 \
  --service-account=sa-cloud-function@ace-hands-on-labs-2026.iam.gserviceaccount.com
```

Consulta da identidade:

```bash
gcloud functions describe hello-http \
  --region=us-central1 \
  --gen2 \
  --format="value(serviceConfig.serviceAccountEmail)"
```

### Identidade de execução

A Service Account utilizada pela função representa sua identidade ao acessar outros serviços do Google Cloud.

É importante diferenciar:

- Identidade de deploy: responsável por publicar a função.
- Identidade de build: utilizada durante o processo de construção.
- Identidade de runtime: utilizada pela aplicação durante a execução.

## 9. Integração com Cloud Storage

Bucket utilizado no exercício:

```text
gs://ace-functions-iam-618071923969
```

Criação:

```bash
gcloud storage buckets create gs://ace-functions-iam-618071923969 \
  --location=us-central1 \
  --uniform-bucket-level-access
```

Criação e envio do arquivo de teste:

```bash
echo "Arquivo de teste para o Lab 02.2 - Cloud Functions e IAM" > test-iam.txt

gcloud storage cp test-iam.txt gs://ace-functions-iam-618071923969/
```

### Código de integração

A função utiliza a biblioteca `google-cloud-storage` para acessar o bucket.

```python
import os
from flask import jsonify
from google.cloud import storage

def hello_http(request):
    bucket_name = "ace-functions-iam-618071923969"
    file_name = "test-iam.txt"

    try:
        client = storage.Client()
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(file_name)

        content = blob.download_as_text()

        return jsonify({
            "message": "File read successfully!",
            "file": file_name,
            "content": content,
            "environment": os.environ.get("APP_ENV", "not-configured")
        })

    except Exception as e:
        return jsonify({
            "error": str(e),
            "type": type(e).__name__
        }), 500
```

### Teste sem permissão

Inicialmente, a Service Account não possuía autorização para ler objetos do bucket.

O resultado foi:

```text
403 Forbidden
Permission 'storage.objects.get' denied
```

A função retornou HTTP 500 porque tratou a exceção do cliente do Storage e a converteu em resposta HTTP 500. A causa original foi o 403 da API do Cloud Storage.

### Concessão de permissão

Foi concedida a role `roles/storage.objectViewer` diretamente no bucket:

```bash
gcloud storage buckets add-iam-policy-binding gs://ace-functions-iam-618071923969 \
  --member="serviceAccount:sa-cloud-function@ace-hands-on-labs-2026.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```

Após a concessão, a função conseguiu ler o arquivo e retornou:

```text
HTTP 200
```

### Teste de revogação

A permissão foi removida:

```bash
gcloud storage buckets remove-iam-policy-binding gs://ace-functions-iam-618071923969 \
  --member="serviceAccount:sa-cloud-function@ace-hands-on-labs-2026.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```

Uma nova chamada retornou novamente erro de autorização 403 na API do Storage.

Esse exercício demonstrou o princípio do menor privilégio e o controle de acesso por IAM no nível do bucket.

## 10. Limpeza dos recursos

Exclusão da função:

```bash
gcloud functions delete hello-http \
  --region=us-central1 \
  --gen2
```

Exclusão do arquivo:

```bash
gcloud storage rm gs://ace-functions-iam-618071923969/test-iam.txt
```

Exclusão do bucket:

```bash
gcloud storage buckets delete gs://ace-functions-iam-618071923969
```

Exclusão da Service Account:

```bash
gcloud iam service-accounts delete \
  sa-cloud-function@ace-hands-on-labs-2026.iam.gserviceaccount.com
```

## 11. Verificação final

```bash
gcloud functions list --regions=us-central1

gcloud storage buckets list

gcloud iam service-accounts list
```

Resultado observado:

- Nenhuma Cloud Function permaneceu ativa na região do laboratório.
- Bucket de teste excluído.
- Service Account dedicada excluída.
- Buckets internos do Cloud Functions preservados.

## 12. Conceitos importantes para a ACE

| Conceito | Conhecimento praticado |
|---|---|
| Cloud Functions Gen 2 | Execução serverless de funções |
| HTTP Trigger | Acionamento por requisições HTTP |
| Runtime | Ambiente de execução Python |
| Entry Point | Função chamada pelo serviço |
| Cloud Build | Construção da aplicação |
| Artifact Registry | Armazenamento dos artefatos |
| Cloud Run | Infraestrutura de execução da Gen 2 |
| Revisions | Versionamento das implantações |
| Environment Variables | Configuração externa à aplicação |
| Service Account | Identidade de execução |
| IAM Binding | Associação de identidade e permissão |
| Least Privilege | Menor privilégio |
| Cloud Storage | Armazenamento de objetos |
| `storage.objects.get` | Permissão para ler objetos |

## Resultado

Laboratório concluído com sucesso.

Foi implementada uma Cloud Function Gen 2 com Python 3.12, publicada e testada no Google Cloud, com integração ao Cloud Storage e validação prática de permissões IAM.
