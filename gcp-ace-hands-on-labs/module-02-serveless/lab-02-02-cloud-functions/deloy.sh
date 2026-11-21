
#!/bin/bash

set -euo pipefail

# ==========================================
# GCP ACE - Lab 02.2
# Cloud Functions Gen 2 - Deploy
# ==========================================

PROJECT_ID="ace-hands-on-labs-2026"
REGION="us-central1"

FUNCTION_NAME="hello-http"
RUNTIME="python312"
ENTRY_POINT="hello_http"

SA_NAME="sa-cloud-function"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

BUCKET_NAME="ace-functions-iam-618071923969"

echo "=========================================="
echo " GCP ACE - Cloud Functions Deployment"
echo "=========================================="

# 1. Validar projeto ativo
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)

if [[ "$CURRENT_PROJECT" != "$PROJECT_ID" ]]; then
    echo "ERRO: Projeto ativo diferente do esperado."
    echo "Esperado: $PROJECT_ID"
    echo "Atual: $CURRENT_PROJECT"
    exit 1
fi

# 2. Habilitar APIs
echo "[1/5] Habilitando APIs..."

gcloud services enable \
    cloudfunctions.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    run.googleapis.com

# 3. Criar Service Account, se necessário
echo "[2/5] Verificando Service Account..."

if ! gcloud iam service-accounts describe "$SA_EMAIL" \
    --project="$PROJECT_ID" >/dev/null 2>&1; then

    gcloud iam service-accounts create "$SA_NAME" \
        --display-name="Cloud Function Runtime" \
        --project="$PROJECT_ID"
else
    echo "Service Account já existe."
fi

# 4. Criar bucket, se necessário
echo "[3/5] Verificando bucket..."

if ! gcloud storage buckets describe "gs://${BUCKET_NAME}" \
    >/dev/null 2>&1; then

    gcloud storage buckets create "gs://${BUCKET_NAME}" \
        --location="$REGION" \
        --uniform-bucket-level-access
else
    echo "Bucket já existe."
fi

# Criar e enviar arquivo de teste
printf "Arquivo de teste para o Lab 02.2 - Cloud Functions e IAM\n" \
    > test-iam.txt

gcloud storage cp test-iam.txt "gs://${BUCKET_NAME}/"

# 5. Deploy da Cloud Function
echo "[4/5] Publicando Cloud Function..."

gcloud functions deploy "$FUNCTION_NAME" \
    --gen2 \
    --runtime="$RUNTIME" \
    --region="$REGION" \
    --source=. \
    --entry-point="$ENTRY_POINT" \
    --trigger-http \
    --allow-unauthenticated \
    --service-account="$SA_EMAIL" \
    --update-env-vars=APP_ENV=production

# 6. Exibir informações
echo "[5/5] Deployment concluído!"

gcloud functions describe "$FUNCTION_NAME" \
    --region="$REGION" \
    --gen2 \
    --format="yaml(state,serviceConfig.serviceAccountEmail,serviceConfig.environmentVariables,url)"

echo "=========================================="
echo " Deploy finalizado com sucesso!"
echo "=========================================="
