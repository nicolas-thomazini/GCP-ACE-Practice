#!/usr/bin/env bash
# Lab 05.2 — Cloud SQL com PostgreSQL
# Comandos executados durante o laboratório.
# Atenção: comandos de criação/destruição alteram recursos reais e podem gerar custos.

# -------------------------------------------------------------------
# 1. Configuração e APIs
# -------------------------------------------------------------------

gcloud config set project ace-hands-on-labs-2026
gcloud config set run/region us-central1
gcloud services enable sqladmin.googleapis.com

# -------------------------------------------------------------------
# 2. Ferramentas locais (Ubuntu/WSL)
# -------------------------------------------------------------------

sudo apt update
sudo apt install postgresql-client -y

curl -o cloud-sql-proxy \
  https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.18.2/cloud-sql-proxy.linux.amd64

chmod +x cloud-sql-proxy
sudo mv cloud-sql-proxy /usr/local/bin/
cloud-sql-proxy --version
psql --version

# -------------------------------------------------------------------
# 3. Terraform — provisionamento
# Executar dentro de lab-05-02-cloud-sql
# -------------------------------------------------------------------

terraform init
terraform fmt
terraform validate
terraform plan
terraform apply

# -------------------------------------------------------------------
# 4. Inspeção da instância e do banco
# -------------------------------------------------------------------

gcloud sql instances list
gcloud sql instances describe ace-postgres-lab052
gcloud sql databases list --instance=ace-postgres-lab052
gcloud sql users list --instance=ace-postgres-lab052

# -------------------------------------------------------------------
# 5. Criação do usuário PostgreSQL
# Zsh: a senha é lida sem eco e não deve ser registrada no Git.
# -------------------------------------------------------------------

printf "Digite uma senha forte para ace_user: "
read -s DB_PASSWORD
printf "\n"

gcloud sql users create ace_user \
  --instance=ace-postgres-lab052 \
  --password="$DB_PASSWORD"

unset DB_PASSWORD

# -------------------------------------------------------------------
# 6. Cloud SQL Auth Proxy
# Executar em um terminal e mantê-lo aberto.
# -------------------------------------------------------------------

cloud-sql-proxy ace-hands-on-labs-2026:us-central1:ace-postgres-lab052

# -------------------------------------------------------------------
# 7. Conexão PostgreSQL
# Executar em outro terminal. A senha será solicitada pelo psql.
# -------------------------------------------------------------------

psql -h 127.0.0.1 \
  -p 5432 \
  -U ace_user \
  -d ace_lab

# Comandos executados dentro do psql:
#
# SELECT current_database(), current_user, version();
#
# CREATE TABLE employees (
#     id SERIAL PRIMARY KEY,
#     name VARCHAR(100) NOT NULL,
#     role VARCHAR(80),
#     salary NUMERIC(10, 2),
#     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
# );
#
# INSERT INTO employees (name, role, salary)
# VALUES
#     ('Alice', 'Data Engineer', 6500.00),
#     ('Bob', 'Cloud Engineer', 7200.00),
#     ('Charlie', 'ML Engineer', 8000.00);
#
# SELECT * FROM employees ORDER BY id;
#
# UPDATE employees
# SET role = 'Senior Data Engineer',
#     salary = 8500.00
# WHERE name = 'Alice';
#
# SELECT * FROM employees WHERE name = 'Alice';
#
# BEGIN;
# UPDATE employees SET salary = 9999.00 WHERE name = 'Bob';
# SELECT * FROM employees WHERE name = 'Bob';
# ROLLBACK;
#
# SELECT name, salary FROM employees WHERE name = 'Bob';
#
# \q

# -------------------------------------------------------------------
# 8. Configuração e validação de backup/PITR
# Após atualizar backup_configuration no main.tf:
# -------------------------------------------------------------------

terraform fmt
terraform validate
terraform plan
terraform apply

gcloud sql instances describe ace-postgres-lab052 \
  --format="yaml(settings.backupConfiguration)"

# -------------------------------------------------------------------
# 9. Destruição e validação final
# -------------------------------------------------------------------

# Interromper o Cloud SQL Auth Proxy com Ctrl+C antes de destruir.

terraform plan -destroy
terraform destroy

gcloud sql instances list
terraform state list

# A instância foi excluída. A consulta abaixo foi tentada após o destroy
# e retornou 403; ela não é necessária para validar a ausência da instância.
# gcloud sql backups list --instance=ace-postgres-lab052