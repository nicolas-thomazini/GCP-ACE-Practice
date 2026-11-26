# Lab 05.3 — Cloud Spanner

## Objetivos

Neste laboratório, foram praticados os principais conceitos do Google Cloud Spanner:

- Criação de uma instância regional do tipo `FREE_INSTANCE` com Terraform.
- Criação de banco de dados e schema.
- DDL, DML, índices secundários e commit timestamps.
- Transações de leitura e escrita, commit e rollback.
- Concorrência e repetição automática de transações.
- Strong Reads, Stale Reads e snapshots.
- Partitioned DML.

> **Atenção a custos e elegibilidade:** a instância deste laboratório foi criada como `FREE_INSTANCE`, em `regional-us-central1`. Não faça upgrade para uma instância paga sem avaliar os custos. A oferta gratuita tem limites e condições próprios. A instância foi mantida após os exercícios; não execute `terraform destroy` sem decidir conscientemente se deseja perder essa instância e sua elegibilidade associada.

## Ambiente

| Item | Valor |
|---|---|
| Projeto | `ace-hands-on-labs-2026` |
| Região | `us-central1` |
| Configuração | `regional-us-central1` |
| Instância | `ace-spanner-lab053` |
| Tipo | `FREE_INSTANCE` |
| Banco | `ace_database` |
| Dialeto SQL | `GOOGLE_STANDARD_SQL` |
| Retenção de versões | `1h` |
| Provider Terraform | `hashicorp/google` `6.50.0` |

## 1. Habilitar a API e verificar a configuração

```bash
gcloud services enable spanner.googleapis.com

gcloud spanner instances list

gcloud billing projects describe ace-hands-on-labs-2026

gcloud spanner instance-configs list \
  --filter="name:regional-us-central1"
```

A configuração `regional-us-central1` deve estar disponível e o projeto precisa ter faturamento habilitado para criar recursos, mesmo quando a instância selecionada é do tipo gratuito.

## 2. Provisionar a instância com Terraform

Arquivos utilizados:

- `main.tf`
- `variables.tf`
- `terraform.tfvars`
- `outputs.tf`

### `main.tf`

```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_spanner_instance" "main" {
  name          = var.instance_name
  config        = var.instance_config
  display_name  = "ACE Hands On Labs - Spanner"
  force_destroy = true
  instance_type = "FREE_INSTANCE"
}
```

### `variables.tf`

```hcl
variable "project_id" {
  description = "ID do projeto GCP"
  type        = string
}

variable "region" {
  description = "Região do laboratório"
  type        = string
  default     = "us-central1"
}

variable "instance_name" {
  description = "ID da instância Spanner"
  type        = string
}

variable "instance_config" {
  description = "Configuração regional da instância"
  type        = string
  default     = "regional-us-central1"
}
```

### `terraform.tfvars`

```hcl
project_id      = "ace-hands-on-labs-2026"
region          = "us-central1"
instance_name   = "ace-spanner-lab053"
instance_config = "regional-us-central1"
```

### `outputs.tf`

```hcl
output "instance_name" {
  description = "Nome da instância Cloud Spanner"
  value       = google_spanner_instance.main.name
}

output "instance_config" {
  description = "Configuração regional da instância"
  value       = google_spanner_instance.main.config
}

output "instance_type" {
  description = "Tipo da instância"
  value       = google_spanner_instance.main.instance_type
}
```

Inicialização, validação e provisionamento:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

Verificações realizadas:

```bash
gcloud spanner instances list
terraform state list
```

A instância ficou no estado `READY` e foi identificada como `FREE_INSTANCE`.

## 3. Criar o banco de dados

O banco foi criado com a CLI do Google Cloud, fora do estado Terraform:

```bash
gcloud spanner databases create ace_database \
  --instance=ace-spanner-lab053

gcloud spanner databases list \
  --instance=ace-spanner-lab053

gcloud spanner databases describe ace_database \
  --instance=ace-spanner-lab053
```

Configurações observadas:

- Dialeto: `GOOGLE_STANDARD_SQL`
- Estado: `READY`
- Retenção de versões: `1h`
- Criptografia: `GOOGLE_DEFAULT_ENCRYPTION`

## 4. Criar a tabela com DDL

O schema foi criado usando a API de DDL:

```bash
gcloud spanner databases ddl update ace_database \
  --instance=ace-spanner-lab053 \
  --ddl="CREATE TABLE Customers (
    CustomerId INT64 NOT NULL,
    Name STRING(100) NOT NULL,
    Email STRING(200),
    CreatedAt TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp=true)
  ) PRIMARY KEY (CustomerId)"
```

**Importante:** comandos DDL, como `CREATE TABLE` e `CREATE INDEX`, devem ser enviados pela API de DDL. A Query API (`execute-sql`) é usada para consultas SQL e comandos DML; tentar executar DDL por ela resultou em `INVALID_ARGUMENT`.

## 5. Inserir e consultar registros com DML

Os três registros foram inseridos em uma única instrução:

```bash
gcloud spanner databases execute-sql ace_database \
  --instance=ace-spanner-lab053 \
  --sql="INSERT INTO Customers (CustomerId, Name, Email, CreatedAt) VALUES
    (1, 'Alice', 'alice@example.com', PENDING_COMMIT_TIMESTAMP()),
    (2, 'Bob', 'bob@example.com', PENDING_COMMIT_TIMESTAMP()),
    (3, 'Charlie', 'charlie@example.com', PENDING_COMMIT_TIMESTAMP())"
```

A instrução modificou três linhas.

Consulta:

```bash
gcloud spanner databases execute-sql ace_database \
  --instance=ace-spanner-lab053 \
  --sql="SELECT CustomerId, Name, Email, CreatedAt
         FROM Customers
         ORDER BY CustomerId"
```

`PENDING_COMMIT_TIMESTAMP()` atribui o timestamp de commit da transação. Como os três registros foram inseridos na mesma instrução/transação, receberam o mesmo valor de `CreatedAt`.

## 6. Criar índices secundários

Os índices foram criados com DDL:

```bash
gcloud spanner databases ddl update ace_database \
  --instance=ace-spanner-lab053 \
  --ddl="CREATE INDEX CustomersByEmail ON Customers(Email)"
```

```bash
gcloud spanner databases ddl update ace_database \
  --instance=ace-spanner-lab053 \
  --ddl="CREATE INDEX CustomersByName ON Customers(Name) STORING (Email)"
```

Consultar o schema:

```bash
gcloud spanner databases ddl describe ace_database \
  --instance=ace-spanner-lab053
```

Consulta por e-mail:

```bash
gcloud spanner databases execute-sql ace_database \
  --instance=ace-spanner-lab053 \
  --sql="SELECT CustomerId, Name, Email
         FROM Customers
         WHERE Email = 'alice@example.com'"
```

## 7. Atualizar registros com DML

Exemplo de atualização de Alice:

```bash
gcloud spanner databases execute-sql ace_database \
  --instance=ace-spanner-lab053 \
  --sql="UPDATE Customers
         SET Name = 'Alice Silva'
         WHERE CustomerId = 1"
```

A instrução modificou uma linha. O nome foi posteriormente atualizado pelos exercícios Python.

## 8. Configurar o cliente Python

A biblioteca utilizada foi `google-cloud-spanner`:

```bash
pip install google-cloud-spanner
```

O cliente Python utiliza Application Default Credentials (ADC). A autenticação do `gcloud` CLI não configura necessariamente ADC. Para verificar:

```bash
gcloud auth application-default print-access-token
```

Se ainda não houver ADC configuradas:

```bash
gcloud auth application-default login
```

Não inclua tokens ou credenciais nos arquivos versionados.

## 9. Transações, commit e rollback

No arquivo `transaction_demo.py`, foi utilizado o cliente Python para:

1. Atualizar Alice para `Alice Transacao` com `database.run_in_transaction()`.
2. Consultar o valor confirmado com um snapshot.
3. Tentar atualizar o nome para `Alice Rollback`.
4. Lançar uma exceção proposital dentro da transação.
5. Confirmar que o valor anterior permaneceu no banco.

Execução:

```bash
python transaction_demo.py
```

Saída observada:

```text
Transação confirmada!
[1, 'Alice Transacao']
Transação abortada: Erro simulado para testar rollback
Resultado após rollback: [1, 'Alice Transacao']
```

**Conclusão:** quando a função da transação termina normalmente, o cliente confirma o commit. Quando a exceção é propagada, a transação não é confirmada e as alterações são descartadas.

Uma transação é uma unidade de trabalho e pode agrupar várias operações, como `INSERT`, `UPDATE`, `DELETE` e leituras.

## 10. Concorrência entre transações

No arquivo `concurrency_demo.py`, duas threads executaram transações concorrentes que liam e atualizavam o mesmo registro (`CustomerId = 1`).

Execução:

```bash
python concurrency_demo.py
```

Saída observada:

```text
Alice Concorrencia A leu: [1, 'Alice Transacao']
Alice Concorrencia B leu: [1, 'Alice Transacao']
Alice Concorrencia A: transação concluída!
Alice Concorrencia B leu: [1, 'Alice Concorrencia A']
Alice Concorrencia B: transação concluída!
Resultado final: [1, 'Alice Concorrencia B']
```

O cliente Python do Spanner pode repetir automaticamente transações que recebem determinados erros transitórios, como `ABORTED`. O resultado é compatível com uma repetição da transação B, mas a saída, por si só, não prova que ocorreu um `ABORTED`: o exercício não instrumentou as tentativas nem registrou essa exceção.

## 11. Commit Timestamp e CURRENT_TIMESTAMP()

Consulta dos timestamps gravados:

```bash
gcloud spanner databases execute-sql ace_database \
  --instance=ace-spanner-lab053 \
  --sql="SELECT CustomerId, Name, CreatedAt
         FROM Customers
         ORDER BY CreatedAt"
```

Consulta do horário atual:

```bash
gcloud spanner databases execute-sql ace_database \
  --instance=ace-spanner-lab053 \
  --sql="SELECT CURRENT_TIMESTAMP() AS CurrentTime"
```

Diferenças:

- `PENDING_COMMIT_TIMESTAMP()`: valor especial usado para atribuir o timestamp de commit.
- `CreatedAt`: coluna que armazena o timestamp de commit associado ao registro.
- `CURRENT_TIMESTAMP()`: função SQL que retorna o horário atual.
- TrueTime: mecanismo interno do Spanner que fornece intervalos de tempo com incerteza conhecida. Não foi acessado diretamente neste laboratório.

## 12. Strong Read e Stale Read

No arquivo `stale_read_demo.py`, foi feita uma atualização de Alice para `Alice Atual`, seguida de duas leituras:

- Strong Read: snapshot sem especificar staleness.
- Stale Read: snapshot com `exact_staleness=timedelta(seconds=60)`.

Execução:

```bash
python stale_read_demo.py
```

Saída observada:

```text
Registro atualizado!
Strong Read: [1, 'Alice Atual']
Stale Read (60s): [1, 'Alice Concorrencia B']
```

A leitura forte retornou o valor mais recente confirmado. A leitura com 60 segundos de staleness retornou uma versão anterior, ainda disponível dentro da retenção de versões configurada.

A retenção do banco estava em `1h`. A staleness solicitada precisa ser compatível com o histórico de versões disponível.

## 13. Partitioned DML

No arquivo `partitioned_dml_demo.py`, foram atualizados Bob e Charlie usando `database.execute_partitioned_dml()` e, em seguida, os nomes foram restaurados.

Execução:

```bash
python3 partitioned_dml_demo.py
```

Saída observada:

```text
Registros modificados: 2
[1, 'Alice Atual']
[2, 'Bob PDM']
[3, 'Charlie PDM']
Nomes originais restaurados!
```

Partitioned DML é apropriado para operações DML em larga escala que podem ser divididas em partições. Diferentemente de uma transação de leitura e escrita tradicional, não oferece atomicidade global para toda a operação: algumas partições podem concluir mesmo que outras falhem. Projete operações para serem idempotentes e considere a possibilidade de execução parcial.

O conjunto de dados deste laboratório é pequeno; portanto, o exercício demonstrou a API, não um ganho de desempenho em larga escala.

## 14. Conceitos para revisar para o ACE

| Conceito | Resumo |
|---|---|
| Instance | Recurso que fornece capacidade e configuração do Spanner |
| Database | Contém schema, tabelas e dados |
| DDL | Criação e alteração de schema |
| DML | Inserção, atualização e exclusão de dados |
| Secondary Index | Índice adicional para apoiar consultas |
| Commit Timestamp | Timestamp associado ao commit de uma transação |
| ACID | Atomicidade, Consistência, Isolamento e Durabilidade |
| Read-write transaction | Agrupa operações de leitura e escrita |
| Rollback | Descarta alterações não confirmadas |
| Strong Read | Leitura fortemente consistente |
| Stale Read | Leitura que pode usar uma versão anterior |
| Partitioned DML | DML distribuído em partições, sem atomicidade global |

## 15. Estado e limpeza

A instância `ace-spanner-lab053` foi mantida após os exercícios. O banco `ace_database` também foi mantido.

Verificações:

```bash
gcloud spanner instances list

gcloud spanner databases list \
  --instance=ace-spanner-lab053

terraform state list
```

**Não execute `terraform destroy` automaticamente:** esta instância foi criada como `FREE_INSTANCE` e sua exclusão pode afetar a possibilidade de criar outra instância gratuita no mesmo projeto. Além disso, `force_destroy = true` permite que o Terraform destrua a instância mesmo contendo bancos de dados.

---

## Estrutura esperada do laboratório

```text
lab-05-03-cloud-spanner/
├── main.tf
├── variables.tf
├── terraform.tfvars
├── outputs.tf
├── .terraform.lock.hcl
├── transaction_demo.py
├── concurrency_demo.py
├── stale_read_demo.py
├── partitioned_dml_demo.py
├── README.md
└── commands.sh
```