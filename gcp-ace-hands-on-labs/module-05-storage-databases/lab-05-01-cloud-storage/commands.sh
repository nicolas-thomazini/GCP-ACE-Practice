#!/usr/bin/env bash
# Lab 05.1 — Cloud Storage
# Projeto: ace-hands-on-labs-2026
# Região: US-CENTRAL1
# Bucket: ace-hands-on-labs-2026-lab051-20261124
#
# Execute os comandos por etapas. Este arquivo registra os comandos
# utilizados no laboratório; não execute tudo cegamente em sequência,
# especialmente os comandos de limpeza.

set -euo pipefail

PROJECT_ID="ace-hands-on-labs-2026"
REGION="US-CENTRAL1"
BUCKET="ace-hands-on-labs-2026-lab051-20261124"
BUCKET_URI="gs://${BUCKET}"
OBJECT="${BUCKET_URI}/hello-gcp.txt"

# --------------------------------------------------------------------
# 1. Contexto e API
# --------------------------------------------------------------------

gcloud config set project "${PROJECT_ID}"
gcloud services list --enabled --filter="name:storage.googleapis.com"

# --------------------------------------------------------------------
# 2. Terraform — inicialização, validação e provisionamento
# --------------------------------------------------------------------
# Os arquivos main.tf, variables.tf, terraform.tfvars e outputs.tf
# devem estar preparados no diretório do laboratório.

terraform init
terraform fmt
terraform validate
terraform plan
terraform apply

# --------------------------------------------------------------------
# 3. Inspecionar bucket
# --------------------------------------------------------------------

gcloud storage buckets describe "${BUCKET_URI}"
gcloud storage buckets get-iam-policy "${BUCKET_URI}"

# --------------------------------------------------------------------
# 4. Criar arquivo e enviar objeto
# --------------------------------------------------------------------

mkdir -p test-data
echo "Meu primeiro objeto no Google Cloud Storage!" > test-data/hello-gcp.txt

gcloud storage cp test-data/hello-gcp.txt "${BUCKET_URI}/"
gcloud storage ls "${BUCKET_URI}/"
gcloud storage objects describe "${OBJECT}"

# --------------------------------------------------------------------
# 5. Object Versioning — sobrescrever e listar gerações
# --------------------------------------------------------------------

echo "Meu segundo objeto no Google Cloud Storage!" > test-data/hello-gcp.txt

gcloud storage cp test-data/hello-gcp.txt "${BUCKET_URI}/"
gcloud storage ls --all-versions "${BUCKET_URI}/"

# Recuperar a primeira geração observada durante o laboratório.
# O identificador é específico desta execução; em outro laboratório,
# substitua pelo generation retornado pela sua própria listagem.
gcloud storage cp \
  "${OBJECT}#1795555969858914" \
  test-data/hello-gcp-v1.txt

cat test-data/hello-gcp-v1.txt

# --------------------------------------------------------------------
# 6. Verificar segurança e Lifecycle
# --------------------------------------------------------------------

gcloud storage buckets describe "${BUCKET_URI}"
gcloud storage buckets describe "${BUCKET_URI}" \
  --format="default(lifecycle_config)"

# --------------------------------------------------------------------
# 7. Alterar Storage Class do objeto para NEARLINE
# --------------------------------------------------------------------

gcloud storage objects update "${OBJECT}" --storage-class=NEARLINE

gcloud storage objects describe "${OBJECT}"
gcloud storage ls --all-versions "${BUCKET_URI}/"

# --------------------------------------------------------------------
# 8. Terraform — conferir estado final
# --------------------------------------------------------------------

terraform plan

# --------------------------------------------------------------------
# 9. Limpeza — NÃO executar automaticamente
# --------------------------------------------------------------------
# O bucket possui objetos versionados e Soft Delete. Antes de remover,
# faça backup do que deseja manter e confirme o procedimento de exclusão
# de todas as gerações e os efeitos da retenção de Soft Delete.
#
# O recurso Terraform usa force_destroy = false.
# Quando o bucket estiver efetivamente vazio e puder ser removido:
#
# terraform destroy
#
# Não remova os buckets preexistentes do projeto usados por Cloud Run,
# Cloud Functions ou Eventarc.