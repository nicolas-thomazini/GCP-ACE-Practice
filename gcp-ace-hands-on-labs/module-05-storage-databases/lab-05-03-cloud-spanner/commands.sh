#!/usr/bin/env bash
# Lab 05.3 — Cloud Spanner
# Projeto: ace-hands-on-labs-2026
# Região: us-central1
#
# ATENÇÃO:
# - A instância foi criada como FREE_INSTANCE.
# - Não execute terraform destroy sem avaliar a perda da instância
#   e da elegibilidade associada à oferta gratuita.
# - Não inclua credenciais, tokens ou senhas neste arquivo.

set -euo pipefail

PROJECT_ID="ace-hands-on-labs-2026"
REGION="us-central1"
INSTANCE_ID="ace-spanner-lab053"
DATABASE_ID="ace_database"

# 1. Configuração e API
gcloud config set project "${PROJECT_ID}"
gcloud config set run/region "${REGION}"
gcloud services enable spanner.googleapis.com

gcloud billing projects describe "${PROJECT_ID}"
gcloud spanner instance-configs list \
  --filter="name:regional-us-central1"

# 2. Terraform — executar no diretório do laboratório
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply

# 3. Verificar a instância
gcloud spanner instances list
terraform state list

# 4. Criar banco de dados (foi criado via gcloud, não via Terraform)
gcloud spanner databases create "${DATABASE_ID}" \
  --instance="${INSTANCE_ID}"

gcloud spanner databases list --instance="${INSTANCE_ID}"
gcloud spanner databases describe "${DATABASE_ID}" \
  --instance="${INSTANCE_ID}"

# 5. Criar tabela via DDL API
gcloud spanner databases ddl update "${DATABASE_ID}" \
  --instance="${INSTANCE_ID}" \
  --ddl="CREATE TABLE Customers (
    CustomerId INT64 NOT NULL,
    Name STRING(100) NOT NULL,
    Email STRING(200),
    CreatedAt TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp=true)
  ) PRIMARY KEY (CustomerId)"

# 6. Inserir dados via DML
gcloud spanner databases execute-sql "${DATABASE_ID}" \
  --instance="${INSTANCE_ID}" \
  --sql="INSERT INTO Customers (CustomerId, Name, Email, CreatedAt) VALUES
    (1, 'Alice', 'alice@example.com', PENDING_COMMIT_TIMESTAMP()),
    (2, 'Bob', 'bob@example.com', PENDING_COMMIT_TIMESTAMP()),
    (3, 'Charlie', 'charlie@example.com', PENDING_COMMIT_TIMESTAMP())"

# 7. Consultar dados
gcloud spanner databases execute-sql "${DATABASE_ID}" \
  --instance="${INSTANCE_ID}" \
  --sql="SELECT CustomerId, Name, Email, CreatedAt
         FROM Customers
         ORDER BY CustomerId"

# 8. Criar índices secundários via DDL API
gcloud spanner databases ddl update "${DATABASE_ID}" \
  --instance="${INSTANCE_ID}" \
  --ddl="CREATE INDEX CustomersByEmail ON Customers(Email)"

gcloud spanner databases ddl update "${DATABASE_ID}" \
  --instance="${INSTANCE_ID}" \
  --ddl="CREATE INDEX CustomersByName ON Customers(Name) STORING (Email)"

gcloud spanner databases ddl describe "${DATABASE_ID}" \
  --instance="${INSTANCE_ID}"

# 9. Consultar por índice/campo Email
gcloud spanner databases execute-sql "${DATABASE_ID}" \
  --instance="${INSTANCE_ID}" \
  --sql="SELECT CustomerId, Name, Email
         FROM Customers
         WHERE Email = 'alice@example.com'"

# 10. Atualizar Alice
gcloud spanner databases execute-sql "${DATABASE_ID}" \
  --instance="${INSTANCE_ID}" \
  --sql="UPDATE Customers
         SET Name = 'Alice Silva'
         WHERE CustomerId = 1"

# 11. Instalar biblioteca Python no ambiente virtual
pip install google-cloud-spanner

# ADC: verificar; se necessário, executar login interativo separadamente.
gcloud auth application-default print-access-token
# gcloud auth application-default login

# 12. Executar demonstrações Python
python transaction_demo.py
python concurrency_demo.py
python stale_read_demo.py
python3 partitioned_dml_demo.py

# 13. Consultar timestamps
gcloud spanner databases execute-sql "${DATABASE_ID}" \
  --instance="${INSTANCE_ID}" \
  --sql="SELECT CustomerId, Name, CreatedAt
         FROM Customers
         ORDER BY CreatedAt"

gcloud spanner databases execute-sql "${DATABASE_ID}" \
  --instance="${INSTANCE_ID}" \
  --sql="SELECT CURRENT_TIMESTAMP() AS CurrentTime"

# 14. Verificação final
gcloud spanner instances list
gcloud spanner databases list --instance="${INSTANCE_ID}"
terraform state list

# NÃO EXECUTAR AUTOMATICAMENTE:
# terraform destroy