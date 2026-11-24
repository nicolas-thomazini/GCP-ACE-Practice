# Lab 05.1 — Cloud Storage

## Objetivos

Neste laboratório, provisionamos e exploramos um bucket do Google Cloud Storage usando Terraform e `gcloud`.

Ao final, praticamos:

- Criação de bucket regional com Terraform.
- Storage Class padrão.
- Uniform Bucket-Level Access (UBLA) e Public Access Prevention.
- Object Versioning e recuperação de uma geração anterior.
- Inspeção da política IAM do bucket.
- Lifecycle Management.
- Alteração da Storage Class de um objeto.

## Ambiente

| Item | Valor |
|---|---|
| Projeto | `ace-hands-on-labs-2026` |
| Região | `US-CENTRAL1` |
| Bucket | `ace-hands-on-labs-2026-lab051-20261124` |
| Storage Class inicial | `STANDARD` |
| Versionamento | Habilitado |
| Uniform Bucket-Level Access | Habilitado |
| Public Access Prevention | `enforced` |
| Soft Delete | 7 dias (configuração observada no bucket) |

> O nome de bucket do GCS precisa ser globalmente único. Se reproduzir o laboratório em outro projeto, escolha outro nome.

## 1. Provisionamento com Terraform

O bucket foi criado com as seguintes configurações principais:

```hcl
resource "google_storage_bucket" "ace_bucket" {
  name          = var.bucket_name
  location      = var.region
  storage_class = "STANDARD"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }

    action {
      type = "Delete"
    }
  }

  force_destroy = false

  labels = {
    environment = "learning"
    module      = "module-05"
    lab         = "lab-05-01"
  }
}
```

Variáveis utilizadas:

```hcl
project_id  = "ace-hands-on-labs-2026"
region      = "US-CENTRAL1"
bucket_name = "ace-hands-on-labs-2026-lab051-20261124"
```

Fluxo executado:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

O bucket foi criado e depois atualizado para adicionar a regra de Lifecycle. O plano dessa atualização indicou `0 to add, 1 to change, 0 to destroy`.

## 2. Bucket e objetos

Criamos um arquivo local e enviamos ao bucket:

```bash
mkdir -p test-data
echo "Meu primeiro objeto no Google Cloud Storage!" > test-data/hello-gcp.txt

gcloud storage cp test-data/hello-gcp.txt \
  gs://ace-hands-on-labs-2026-lab051-20261124/

gcloud storage ls \
  gs://ace-hands-on-labs-2026-lab051-20261124/

gcloud storage objects describe \
  gs://ace-hands-on-labs-2026-lab051-20261124/hello-gcp.txt
```

O objeto foi identificado como `text/plain`, com tamanho de 45 bytes e Storage Class `STANDARD`.

## 3. Object Versioning

Com o versionamento habilitado, fizemos um segundo upload usando o mesmo nome de objeto:

```bash
echo "Meu segundo objeto no Google Cloud Storage!" > test-data/hello-gcp.txt

gcloud storage cp test-data/hello-gcp.txt \
  gs://ace-hands-on-labs-2026-lab051-20261124/

gcloud storage ls --all-versions \
  gs://ace-hands-on-labs-2026-lab051-20261124/
```

Foram observadas duas gerações:

| Generation | Operação |
|---|---|
| `1795555969858914` | Primeiro upload |
| `1795556037679729` | Segundo upload |

Recuperamos a primeira geração sem substituir o objeto atual:

```bash
gcloud storage cp \
  gs://ace-hands-on-labs-2026-lab051-20261124/hello-gcp.txt#1795555969858914 \
  test-data/hello-gcp-v1.txt

cat test-data/hello-gcp-v1.txt
```

Resultado esperado:

```text
Meu primeiro objeto no Google Cloud Storage!
```

**Conceitos:**

- `generation`: identifica uma versão específica do conteúdo do objeto.
- `metageneration`: identifica a revisão dos metadados daquela geração.
- `--all-versions`: lista as gerações disponíveis.
- Uma geração específica pode ser referenciada pelo sufixo `#GENERATION`.

## 4. IAM, UBLA e Public Access Prevention

Consultamos a política IAM:

```bash
gcloud storage buckets get-iam-policy \
  gs://ace-hands-on-labs-2026-lab051-20261124
```

A saída apresentou papéis legados de bucket e objeto, associados aos membros de projeto `projectOwner`, `projectEditor` e `projectViewer`.

Também inspecionamos as configurações:

```bash
gcloud storage buckets describe \
  gs://ace-hands-on-labs-2026-lab051-20261124
```

Valores confirmados:

```yaml
uniform_bucket_level_access: true
public_access_prevention: enforced
versioning_enabled: true
```

**Para a ACE:**

- **IAM:** define quem pode executar ações sobre recursos.
- **Uniform Bucket-Level Access (UBLA):** centraliza o controle de acesso no IAM do bucket e desabilita ACLs.
- **ACL:** mecanismo legado de controle de acesso por bucket ou objeto.
- **Public Access Prevention:** impede a concessão de acesso público ao bucket e aos objetos.

A consulta formatada de Lifecycle usa o campo `lifecycle_config`:

```bash
gcloud storage buckets describe \
  gs://ace-hands-on-labs-2026-lab051-20261124 \
  --format="default(lifecycle_config)"
```

## 5. Lifecycle Management

Inicialmente, o bucket não tinha regra de Lifecycle. Adicionamos ao recurso Terraform:

```hcl
lifecycle_rule {
  condition {
    age = 30
  }

  action {
    type = "Delete"
  }
}
```

Depois executamos `terraform plan` e `terraform apply`. A regra foi confirmada no GCS:

```yaml
lifecycle_config:
  rule:
  - action:
      type: Delete
    condition:
      age: 30
```

**Atenção:** a regra torna objetos elegíveis para a ação quando atendem à condição; o processamento do Lifecycle é assíncrono. Em buckets com Object Versioning, é importante compreender o comportamento das versões não atuais antes de configurar exclusões. Não presuma que uma regra `Delete` elimina imediatamente e permanentemente todas as gerações.

Outras ações e condições comuns:

- `Delete`: aplica exclusão a objetos elegíveis.
- `SetStorageClass`: altera a classe de armazenamento.
- `age`: idade do objeto em dias.
- `matchesStorageClass`: filtra por classe de armazenamento.

## 6. Storage Classes

As classes estudadas:

| Classe | Perfil de acesso | Período mínimo de armazenamento para cobrança |
|---|---|---:|
| `STANDARD` | Dados acessados frequentemente | Sem mínimo |
| `NEARLINE` | Acesso pouco frequente, aproximadamente mensal | 30 dias |
| `COLDLINE` | Acesso raro, aproximadamente trimestral | 90 dias |
| `ARCHIVE` | Acesso muito raro, normalmente retenção de longo prazo | 365 dias |

Os períodos mínimos são referências de cobrança, não prazos automáticos para migrar os objetos. Classes mais frias podem ter custos de recuperação e cobranças por exclusão antecipada.

O bucket foi criado com `STANDARD` como classe padrão. Isso não significa que todos os objetos existentes mudem automaticamente quando a classe padrão do bucket é alterada.

### Alteração de classe de um objeto

Executamos:

```bash
gcloud storage objects update \
  gs://ace-hands-on-labs-2026-lab051-20261124/hello-gcp.txt \
  --storage-class=NEARLINE
```

A operação foi concluída e a consulta confirmou:

```yaml
storage_class: NEARLINE
```

O `storage_url` passou a apresentar a geração `1795557734155484`. Com o versionamento habilitado, a listagem mostrou três gerações:

| Generation | Operação |
|---|---|
| `1795555969858914` | Primeiro upload |
| `1795556037679729` | Segundo upload |
| `1795557734155484` | Rewrite para `NEARLINE` |

O comando `objects update --storage-class` executa uma operação de rewrite para mudar a classe do objeto.

### Lifecycle para transição de classe

Exemplo de regra que pode ser configurada no Terraform:

```hcl
lifecycle_rule {
  condition {
    age = 30
  }

  action {
    type          = "SetStorageClass"
    storage_class = "NEARLINE"
  }
}
```

Essa regra é apenas um exemplo de configuração; não foi aplicada neste laboratório. A regra aplicada foi `Delete` após 30 dias.

## 7. Comandos úteis de consulta

```bash
# Descrever o bucket
gcloud storage buckets describe \
  gs://ace-hands-on-labs-2026-lab051-20261124

# Consultar IAM
gcloud storage buckets get-iam-policy \
  gs://ace-hands-on-labs-2026-lab051-20261124

# Listar objetos
gcloud storage ls \
  gs://ace-hands-on-labs-2026-lab051-20261124/

# Listar todas as gerações
gcloud storage ls --all-versions \
  gs://ace-hands-on-labs-2026-lab051-20261124/

# Descrever um objeto
gcloud storage objects describe \
  gs://ace-hands-on-labs-2026-lab051-20261124/hello-gcp.txt

# Consultar Lifecycle
gcloud storage buckets describe \
  gs://ace-hands-on-labs-2026-lab051-20261124 \
  --format="default(lifecycle_config)"
```

## 8. Limpeza e custos

Este laboratório deixou recursos reais no projeto:

- Bucket `ace-hands-on-labs-2026-lab051-20261124`.
- Objeto `hello-gcp.txt` e suas três gerações.
- Regra Lifecycle `Delete` após 30 dias.

O Terraform está configurado com `force_destroy = false`. Portanto, não conte com `terraform destroy` para remover automaticamente um bucket que ainda contém objetos.

Antes de destruir o bucket:

1. Confirme que o bucket pertence exclusivamente a este laboratório.
2. Faça backup de qualquer objeto que queira manter.
3. Remova os objetos e todas as versões de forma consciente.
4. Considere a política de Soft Delete de 7 dias observada no bucket.
5. Só então execute `terraform destroy` e confira o resultado.

**Não remova os buckets preexistentes do projeto** (Eventarc, Cloud Functions e Cloud Run). Eles não pertencem a este laboratório.

## Checklist de conclusão

- [x] Criar bucket com Terraform.
- [x] Configurar `STANDARD` como classe padrão.
- [x] Habilitar Uniform Bucket-Level Access.
- [x] Habilitar Public Access Prevention.
- [x] Habilitar Object Versioning.
- [x] Enviar e inspecionar um objeto.
- [x] Sobrescrever o objeto e listar gerações.
- [x] Recuperar uma geração anterior.
- [x] Inspecionar a política IAM.
- [x] Configurar e validar Lifecycle Management.
- [x] Alterar a classe do objeto para `NEARLINE`.
- [ ] Fazer a limpeza dos recursos ao encerrar o laboratório.

## Referências oficiais

- [Cloud Storage documentation](https://cloud.google.com/storage/docs)
- [Storage classes](https://cloud.google.com/storage/docs/storage-classes)
- [Object Versioning](https://cloud.google.com/storage/docs/object-versioning)
- [Object Lifecycle Management](https://cloud.google.com/storage/docs/lifecycle)
- [Uniform bucket-level access](https://cloud.google.com/storage/docs/uniform-bucket-level-access)
- [Public access prevention](https://cloud.google.com/storage/docs/public-access-prevention)