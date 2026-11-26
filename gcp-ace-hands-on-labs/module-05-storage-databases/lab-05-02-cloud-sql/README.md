# Lab 05.2 — Cloud SQL com PostgreSQL

## Objetivos

Neste laboratório, provisionamos uma instância PostgreSQL no Google Cloud SQL usando Terraform e praticamos conexão, operações SQL, transações, backups e recuperação.

## Ambiente utilizado

- Projeto GCP: `ace-hands-on-labs-2026`
- Região: `us-central1`
- Instância: `ace-postgres-lab052`
- Banco: `ace_lab`
- Engine: PostgreSQL 16
- Tier: `db-f1-micro` (Enterprise)
- Armazenamento: 10 GB `PD_HDD`
- Conectividade: Cloud SQL Auth Proxy
- Cliente: `psql` no Ubuntu/WSL

> A instância foi destruída ao final do laboratório para evitar custos contínuos. Os comandos de provisionamento permanecem documentados, mas a infraestrutura não está ativa.

## 1. APIs e ferramentas

API utilizada:

```bash
gcloud services enable sqladmin.googleapis.com
```

Ferramentas:
- Terraform
- Google Cloud CLI (`gcloud`)
- Cloud SQL Auth Proxy
- PostgreSQL client (`psql`)

Instalação do cliente PostgreSQL no Ubuntu:

```bash
sudo apt update
sudo apt install postgresql-client -y
```

Instalação do Cloud SQL Auth Proxy (Linux x86_64):

```bash
curl -o cloud-sql-proxy \
  https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.18.2/cloud-sql-proxy.linux.amd64

chmod +x cloud-sql-proxy
sudo mv cloud-sql-proxy /usr/local/bin/
cloud-sql-proxy --version
```

## 2. Infraestrutura com Terraform

A instância foi provisionada com:
- PostgreSQL 16
- `db-f1-micro`
- disponibilidade Zonal
- disco HDD de 10 GB, sem auto-resize
- IPv4 público habilitado
- backups inicialmente desabilitados
- proteção contra exclusão desabilitada para permitir o encerramento do laboratório

Arquivos Terraform:
- `main.tf`: provider e recursos Cloud SQL
- `variables.tf`: variáveis de configuração
- `terraform.tfvars`: valores do laboratório
- `outputs.tf`: nome, connection name, IP e banco

Fluxo utilizado:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

A criação resultou em dois recursos gerenciados:
1. `google_sql_database_instance.postgres`
2. `google_sql_database.database`

## 3. Inspeção com gcloud

Listar instâncias:

```bash
gcloud sql instances list
```

Descrever a instância:

```bash
gcloud sql instances describe ace-postgres-lab052
```

Listar bancos:

```bash
gcloud sql databases list --instance=ace-postgres-lab052
```

Listar usuários:

```bash
gcloud sql users list --instance=ace-postgres-lab052
```

## 4. Usuário PostgreSQL

Criamos o usuário `ace_user` com senha definida interativamente. A senha não deve ser armazenada no repositório, em arquivos versionados ou no histórico do shell.

Exemplo utilizado no Zsh:

```zsh
printf "Digite uma senha forte para ace_user: "
read -s DB_PASSWORD
printf "\n"

gcloud sql users create ace_user \
  --instance=ace-postgres-lab052 \
  --password="$DB_PASSWORD"

unset DB_PASSWORD
```

## 5. Conexão com Cloud SQL Auth Proxy

O Proxy foi iniciado usando o connection name da instância:

```bash
cloud-sql-proxy ace-hands-on-labs-2026:us-central1:ace-postgres-lab052
```

O processo permaneceu em execução no primeiro terminal e disponibilizou a conexão local em `127.0.0.1:5432`.

Em outro terminal, conectamos ao banco:

```bash
psql -h 127.0.0.1 \
  -p 5432 \
  -U ace_user \
  -d ace_lab
```

A senha do usuário PostgreSQL foi digitada no prompt do `psql`.

Validação da conexão:

```sql
SELECT current_database(), current_user, version();
```

Resultado esperado:
- Banco: `ace_lab`
- Usuário: `ace_user`
- Engine: PostgreSQL 16.x

Para sair do cliente:

```text
\q
```

Para interromper o Proxy, no terminal em que ele está rodando:

```text
Ctrl + C
```

## 6. Operações SQL (CRUD)

Criação da tabela:

```sql
CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    role VARCHAR(80),
    salary NUMERIC(10, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

Inserção:

```sql
INSERT INTO employees (name, role, salary)
VALUES
    ('Alice', 'Data Engineer', 6500.00),
    ('Bob', 'Cloud Engineer', 7200.00),
    ('Charlie', 'ML Engineer', 8000.00);
```

Consulta:

```sql
SELECT * FROM employees ORDER BY id;
```

Atualização:

```sql
UPDATE employees
SET role = 'Senior Data Engineer',
    salary = 8500.00
WHERE name = 'Alice';
```

Consulta de validação:

```sql
SELECT * FROM employees WHERE name = 'Alice';
```

## 7. Transações

Testamos uma alteração dentro de uma transação e desfizemos a operação com `ROLLBACK`:

```sql
BEGIN;

UPDATE employees
SET salary = 9999.00
WHERE name = 'Bob';

SELECT * FROM employees WHERE name = 'Bob';

ROLLBACK;
```

Validação:

```sql
SELECT name, salary
FROM employees
WHERE name = 'Bob';
```

O salário voltou ao valor original (`7200.00`), confirmando o rollback.

Comandos importantes:
- `BEGIN`: inicia uma transação.
- `COMMIT`: confirma as alterações.
- `ROLLBACK`: desfaz as alterações ainda não confirmadas.

## 8. Backups automáticos e PITR

Atualizamos a configuração Terraform para habilitar backups automáticos e Point-in-Time Recovery:

```hcl
backup_configuration {
  enabled                        = true
  start_time                     = "03:55"
  point_in_time_recovery_enabled = true
  transaction_log_retention_days = 7

  backup_retention_settings {
    retained_backups = 7
    retention_unit   = "COUNT"
  }
}
```

O horário `03:55` UTC corresponde a `00:55` no horário de Brasília (UTC−3).

Validação com gcloud:

```bash
gcloud sql instances describe ace-postgres-lab052 \
  --format="yaml(settings.backupConfiguration)"
```

A saída confirmou:
- `enabled: true`
- `pointInTimeRecoveryEnabled: true`
- `startTime: 03:55`
- `retainedBackups: 7`
- `transactionLogRetentionDays: 7`

Conceitos:
- **Backup automático:** cópia periódica gerenciada pelo Cloud SQL.
- **PITR:** recuperação para um instante específico, dentro da janela de retenção dos logs de transação.
- **HA:** configuração de alta disponibilidade com instância standby em outra zona; não foi habilitada neste laboratório.
- **DR:** estratégia de recuperação de desastres; não foi implementada neste laboratório.

## 9. Destruição da infraestrutura

Ao final, interrompemos o Cloud SQL Auth Proxy com `Ctrl+C` e verificamos o plano de destruição:

```bash
terraform plan -destroy
```

O plano indicou exatamente dois recursos para exclusão:
- `google_sql_database.database`
- `google_sql_database_instance.postgres`

A instância tinha `deletion_protection = false` e `retain_backups_on_delete = false`.

Destruição:

```bash
terraform destroy
```

Confirmação: `yes`.

Validação final:

```bash
gcloud sql instances list
terraform state list
```

Resultado observado:
- `gcloud sql instances list`: `Listed 0 items.`
- `terraform state list`: nenhum recurso listado.
- Terraform: `Destroy complete! Resources: 2 destroyed.`

## 10. Aprendizados para a certificação ACE

- Diferença entre Cloud SQL e bancos NoSQL gerenciados.
- Provisionamento de instâncias e bancos com Terraform.
- Inspeção e administração com `gcloud`.
- Conexão por Cloud SQL Auth Proxy.
- Separação entre autenticação IAM do Proxy e autenticação do usuário PostgreSQL.
- CRUD e transações SQL.
- Backups automáticos, retenção e PITR.
- Diferença entre backup, alta disponibilidade (HA) e disaster recovery (DR).
- Ciclo de vida e custos de recursos gerenciados.

## Observações de custo

A instância `db-f1-micro` foi usada apenas para aprendizado. O Cloud SQL gera custos enquanto provisionado, mesmo sem consultas. Backups, armazenamento e outros recursos associados também podem gerar custos. Por isso, destruímos a instância ao concluir o laboratório.

A destruição desta instância não garante custo zero para o projeto GCP: outros recursos de laboratórios anteriores, como buckets do Cloud Storage, devem ser avaliados separadamente.