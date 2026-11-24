# Lab 04.3 — Compute Engine Instance Templates

## Objetivos

Neste laboratório, criamos um **Compute Engine Instance Template** usando Terraform e utilizamos esse template para criar uma VM com o Google Cloud CLI.

Ao final, praticamos:

- Declarar um Instance Template com Terraform.
- Configurar máquina, imagem, disco, rede, metadados e políticas de agendamento.
- Exportar atributos do recurso com `output`.
- Inspecionar o template pela CLI.
- Criar e inspecionar uma VM baseada no template.
- Excluir a VM criada pela CLI e verificar que o template permanece gerenciado pelo Terraform.

## Ambiente utilizado

| Item | Valor |
|---|---|
| Projeto | `ace-hands-on-labs-2026` |
| Região | `us-central1` |
| Zona | `us-central1-a` |
| Terraform | `1.17.2` |
| Provider Google | `6.50.0` |
| Template | `ace-instance-template` |
| Tipo de máquina | `e2-small` |
| Imagem | Debian 12 |
| Disco de boot | 10 GB, `pd-balanced` |
| Rede | `default` |

## Estrutura do laboratório

```text
lab-04-03-instance-templates/
├── main.tf
├── variables.tf
├── terraform.tfvars
├── outputs.tf
├── .terraform.lock.hcl
├── README.md
└── commands.sh
```

O arquivo `.terraform.lock.hcl` deve ser versionado no Git para registrar a seleção de versões dos providers.

## 1. Conceito: Instance Template

Um **Instance Template** é um recurso reutilizável que define as configurações de VMs do Compute Engine. Ele pode especificar, por exemplo:

- Tipo de máquina.
- Imagem e configuração dos discos.
- Interfaces de rede.
- Metadados e tags.
- Configurações de agendamento.

O template, por si só, **não cria uma VM**. Ele funciona como uma especificação que pode ser usada para criar instâncias ou como base para um Managed Instance Group (MIG).

Instance Templates são recursos globais do Compute Engine. A VM criada a partir do template, por outro lado, pertence a uma zona.

## 2. Configuração Terraform

### `main.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"

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
  zone    = var.zone
}

resource "google_compute_instance_template" "ace_template" {
  name        = "ace-instance-template"
  description = "Instance Template created for ACE hands-on lab"

  machine_type = "e2-small"

  tags = ["ace-template"]

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true

    disk_size_gb = 10
    disk_type    = "pd-balanced"
  }

  network_interface {
    network = "default"
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

### `variables.tf`

```hcl
variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Google Cloud zone"
  type        = string
  default     = "us-central1-a"
}
```

### `terraform.tfvars`

```hcl
project_id = "ace-hands-on-labs-2026"
region     = "us-central1"
zone       = "us-central1-a"
```

### `outputs.tf`

```hcl
output "instance_template_name" {
  description = "Name of the Compute Engine Instance Template"
  value       = google_compute_instance_template.ace_template.name
}

output "instance_template_id" {
  description = "ID of the Compute Engine Instance Template"
  value       = google_compute_instance_template.ace_template.id
}

output "instance_template_self_link" {
  description = "Self link of the Instance Template"
  value       = google_compute_instance_template.ace_template.self_link
}
```

## 3. Provisionamento e validação

A sequência utilizada foi:

```bash
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
terraform output
```

O plano apresentou:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

O `apply` concluiu com:

```text
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

Os outputs exibiram o nome, o ID e o Self Link do template.

## 4. Inspeção com Google Cloud CLI

No Cloud Shell, primeiro foi necessário selecionar o projeto correto:

```bash
gcloud config set project ace-hands-on-labs-2026
gcloud config get-value project
```

Isso foi necessário porque o Cloud Shell iniciou com outro projeto selecionado. A configuração do `gcloud` no Cloud Shell é independente da configuração local do WSL.

Listamos e inspecionamos o template:

```bash
gcloud compute instance-templates list

gcloud compute instance-templates describe ace-instance-template
```

A saída confirmou, entre outros atributos:

- `machineType: e2-small`
- Imagem Debian 12.
- Disco de boot de 10 GB.
- Rede `default`.
- Metadado `enable-oslogin=TRUE`.
- Tag `ace-template`.
- `automaticRestart: true`.
- `onHostMaintenance: MIGRATE`.

## 5. Criar uma VM a partir do template

Usamos o Cloud Shell para criar uma instância independente a partir do template:

```bash
gcloud compute instances create ace-vm-from-template \
  --source-instance-template=ace-instance-template \
  --zone=us-central1-a
```

A VM foi criada com sucesso e apresentou:

| Propriedade | Resultado observado |
|---|---|
| Nome | `ace-vm-from-template` |
| Zona | `us-central1-a` |
| Tipo de máquina | `e2-small` |
| IP interno | `10.128.0.4` |
| IP externo | Nenhum |
| Estado | `RUNNING` |

Depois, inspecionamos a instância:

```bash
gcloud compute instances describe ace-vm-from-template \
  --zone=us-central1-a
```

A comparação entre o template e a VM confirmou que as configurações definidas no template foram aplicadas à instância.

### Template versus VM

| Instance Template | VM |
|---|---|
| Define uma configuração reutilizável. | É uma instância concreta em execução. |
| É um recurso global. | É criada em uma zona ou região, conforme o tipo de instância. |
| Não consome uma VM em execução por si só. | Usa recursos de computação e armazenamento. |
| Pode servir de base para MIGs. | Pode ser gerenciada individualmente ou por um MIG. |

Uma VM criada a partir de um template não fica dinamicamente vinculada a ele. Alterar ou criar outro template não atualiza automaticamente as VMs já existentes.

## 6. Limpeza e validação final

A VM foi criada pelo `gcloud`, portanto não fazia parte do state do Terraform. Por isso, foi excluída manualmente:

```bash
gcloud compute instances delete ace-vm-from-template \
  --zone=us-central1-a
```

O disco de boot estava configurado com `auto_delete = true`, então foi excluído junto com a VM.

O Instance Template foi mantido para reutilização no laboratório de Managed Instance Groups.

No WSL, executamos:

```bash
terraform plan
```

Resultado:

```text
No changes. Your infrastructure matches the configuration.
```

Isso confirmou que o template continuava presente e que a infraestrutura gerenciada pelo Terraform correspondia à configuração.

**Atenção:** não execute `terraform destroy` ao encerrar este laboratório se a intenção for reutilizar o template no próximo laboratório.

## 7. Aprendizados para a certificação ACE

- Instance Templates definem configurações reutilizáveis de VMs.
- Um Instance Template não cria instâncias por conta própria.
- Templates podem ser usados para criar VMs individuais ou Managed Instance Groups.
- Managed Instance Groups usam templates para gerenciar grupos de instâncias.
- Uma VM criada por CLI não passa automaticamente a fazer parte do state do Terraform.
- O `gcloud config` do Cloud Shell pode apontar para um projeto diferente do ambiente local.
- `terraform plan` permite verificar se o state e a infraestrutura real estão sincronizados.

### Próximo laboratório

**Lab 04.4 — Managed Instance Groups (MIGs)**

No próximo laboratório, reutilizaremos o Instance Template para criar e gerenciar um grupo de instâncias.