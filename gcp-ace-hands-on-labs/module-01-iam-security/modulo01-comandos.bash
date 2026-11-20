from pathlib import Path

content = r'''#!/usr/bin/env bash
#
# Módulo 01 — IAM e Segurança (Google Cloud)
# Comandos praticados no laboratório.
#
# IMPORTANTE:
# - Arquivo de referência: não execute tudo de uma vez.
# - Preencha as variáveis antes de executar cada seção.
# - Há comandos que alteram IAM e excluem recursos.
# - A Custom Role aceCustomStorageReader foi excluída ao final do laboratório.
#

# 0. Variáveis do ambiente
PROJECT_ID="your-project-id"
USER_EMAIL="your-email@gmail.com"

SA_COMPUTE_EMAIL="sa-compute@${PROJECT_ID}.iam.gserviceaccount.com"
SA_CLOUDRUN_EMAIL="sa-cloudrun@${PROJECT_ID}.iam.gserviceaccount.com"
SA_GKE_EMAIL="sa-gke@${PROJECT_ID}.iam.gserviceaccount.com"

CUSTOM_ROLE_ID="aceCustomStorageReader"
CUSTOM_ROLE="projects/${PROJECT_ID}/roles/${CUSTOM_ROLE_ID}"

# 1. Criar Service Accounts
gcloud iam service-accounts create sa-compute \
  --display-name="Compute Service Account"

gcloud iam service-accounts create sa-cloudrun \
  --display-name="Cloud Run Service Account"

gcloud iam service-accounts create sa-gke \
  --display-name="GKE Service Account"

# Listar Service Accounts
gcloud iam service-accounts list

# 2. Atribuir Predefined Role à sa-compute
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_COMPUTE_EMAIL}" \
  --role="roles/storage.objectViewer"

# 3. Criar e administrar a Custom Role
# Criação inicial: storage.buckets.get e storage.buckets.list
gcloud iam roles create "${CUSTOM_ROLE_ID}" \
  --project="${PROJECT_ID}" \
  --title="ACE Custom Storage Reader" \
  --description="Custom role for reading Cloud Storage bucket metadata" \
  --permissions=storage.buckets.get,storage.buckets.list \
  --stage=GA

# Listar Custom Roles
gcloud iam roles list --project="${PROJECT_ID}"

# Consultar a Custom Role
gcloud iam roles describe "${CUSTOM_ROLE_ID}" \
  --project="${PROJECT_ID}"

# Adicionar storage.objects.list
gcloud iam roles update "${CUSTOM_ROLE_ID}" \
  --project="${PROJECT_ID}" \
  --add-permissions=storage.objects.list

# Conferir as permissões atualizadas
gcloud iam roles describe "${CUSTOM_ROLE_ID}" \
  --project="${PROJECT_ID}"

# 4. Associar a Custom Role à sa-cloudrun
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_CLOUDRUN_EMAIL}" \
  --role="${CUSTOM_ROLE}"

# 5. Service Account Impersonation
gcloud auth list

# Conceder Token Creator ao usuário na política da sa-cloudrun
gcloud iam service-accounts add-iam-policy-binding \
  "${SA_CLOUDRUN_EMAIL}" \
  --project="${PROJECT_ID}" \
  --member="user:${USER_EMAIL}" \
  --role="roles/iam.serviceAccountTokenCreator"

# Configurar impersonation
gcloud config set auth/impersonate_service_account \
  "${SA_CLOUDRUN_EMAIL}"

# Conferir a configuração
gcloud config get-value auth/impersonate_service_account

# 6. Testes usando a identidade impersonada
# Teste permitido: listar buckets
gcloud storage buckets list --project="${PROJECT_ID}"

# Teste negado esperado: criar bucket (403 por falta de storage.buckets.create).
# Se repetir, use um nome de bucket globalmente único.
BUCKET_NAME="your-globally-unique-test-bucket"

gcloud storage buckets create "gs://${BUCKET_NAME}" \
  --project="${PROJECT_ID}" \
  --location=us-central1

# 7. Remover impersonation local e IAM Binding da Custom Role
gcloud config unset auth/impersonate_service_account

gcloud projects remove-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_CLOUDRUN_EMAIL}" \
  --role="${CUSTOM_ROLE}"

# 8. Desabilitar e excluir a Custom Role
gcloud iam roles update "${CUSTOM_ROLE_ID}" \
  --project="${PROJECT_ID}" \
  --stage=DISABLED

# Consultar o estágio
gcloud iam roles describe "${CUSTOM_ROLE_ID}" \
  --project="${PROJECT_ID}"

# Excluir definitivamente
gcloud iam roles delete "${CUSTOM_ROLE_ID}" \
  --project="${PROJECT_ID}"

# Consulta posterior realizada para confirmar a exclusão
gcloud iam roles describe "${CUSTOM_ROLE_ID}" \
  --project="${PROJECT_ID}"

# 9. Consultar a IAM Policy do projeto
gcloud projects get-iam-policy "${PROJECT_ID}"

# Observações sobre o estado final:
# - sa-compute recebeu roles/storage.objectViewer.
# - sa-cloudrun recebeu temporariamente a Custom Role aceCustomStorageReader.
# - O binding da Custom Role foi removido antes da exclusão da role.
# - A Custom Role foi desabilitada e excluída.
# - roles/iam.serviceAccountTokenCreator na sa-cloudrun NÃO foi removida.
# - A configuração local de impersonation foi removida.
#
# ATENÇÃO: este arquivo reúne comandos de referência. Não execute tudo
# em lote; revise cada seção e o estado atual do projeto antes de rodar.
'''

path = Path("/mnt/data/modulo-01-iam-comandos.sh")
path.write_text(content, encoding="utf-8")
print(f"Arquivo criado: {path}")
