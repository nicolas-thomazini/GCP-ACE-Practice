# Lab 04.1 — VM Instances

## Objetivo

Criar e administrar uma instância do Compute Engine usando Terraform, explorar os principais atributos de uma VM, conectar-se com SSH por meio do Identity-Aware Proxy (IAP) e praticar o redimensionamento do tipo de máquina.

Este laboratório faz parte do **Module 04 — Compute Engine** do repositório `GCP-ACE-Practice`.

## Ambiente

| Item | Configuração |
|---|---|
| Projeto GCP | `ace-hands-on-labs-2026` |
| Região | `us-central1` |
| Zona | `us-central1-a` |
| VPC | `default` |
| Sub-rede | `default` |
| Sistema operacional | Debian GNU/Linux 12 (Bookworm) |
| Instância | `ace-vm-instance` |
| Tipo inicial | `e2-micro` |
| Tipo final do exercício | `e2-small` |
| Disco de inicialização | 10 GB, `pd-balanced` |
| IP interno observado | `10.128.0.2` |
| IP externo | Nenhum |
| Acesso administrativo | SSH via IAP |

## Estrutura do laboratório

```text
lab-04-01-vm-instances/
├── main.tf
├── variables.tf
├── terraform.tfvars
├── outputs.tf
├── README.md
└── commands.sh
```

## 1. Configuração do Terraform

### `variables.tf`

```hcl
variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "Compute Engine machine type"
  type        = string
  default     = "e2-small"
}
```

> Durante a primeira criação, `machine_type` foi `e2-micro`. Depois foi alterado para `e2-small` para praticar o redimensionamento. O valor final da configuração é `e2-small`.

### `terraform.tfvars`

```hcl
project_id = "ace-hands-on-labs-2026"
region     = "us-central1"
zone       = "us-central1-a"
```

### `main.tf`

A configuração final mantém o firewall de IAP SSH e a instância. O Cloud Router e o Cloud NAT foram usados temporariamente durante o exercício de conectividade e removidos ao final desse teste.

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

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "ace-vm-allow-iap-ssh"
  network = "default"

  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["ace-vm"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_instance" "vm" {
  name         = "ace-vm-instance"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["ace-vm"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  labels = {
    environment = "lab"
    module      = "compute-engine"
  }

  depends_on = [
    google_compute_firewall.allow_iap_ssh
  ]
}
```

### `outputs.tf`

```hcl
output "instance_name" {
  value = google_compute_instance.vm.name
}

output "instance_zone" {
  value = google_compute_instance.vm.zone
}

output "internal_ip" {
  value = google_compute_instance.vm.network_interface[0].network_ip
}

output "external_ip" {
  value = google_compute_instance.vm.network_interface[0].access_config
}
```

## 2. Inicialização e criação da VM

Com os arquivos configurados:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

O primeiro `apply` criou dois recursos:

- `google_compute_firewall.allow_iap_ssh`
- `google_compute_instance.vm`

A instância foi criada inicialmente como `e2-micro`.

## 3. Firewall e acesso SSH via IAP

A regra `ace-vm-allow-iap-ssh` permite tráfego TCP na porta 22 a partir do intervalo usado pelo IAP TCP forwarding:

```text
35.235.240.0/20
```

A regra usa a target tag `ace-vm`, aplicada à instância.

Conexão:

```bash
gcloud compute ssh ace-vm-instance \
  --zone=us-central1-a \
  --project=ace-hands-on-labs-2026 \
  --tunnel-through-iap
```

A VM não possui IP externo. O acesso administrativo é feito pelo túnel IAP.

## 4. Inspeção da VM por dentro

Com a sessão SSH aberta, foram utilizados:

```bash
hostname
ip addr
cat /etc/os-release
df -h
ip route
getent hosts google.com
lscpu
free -h
```

Resultados observados antes do redimensionamento:

- Hostname: `ace-vm-instance`
- Interface de rede: `ens4`
- IP interno: `10.128.0.2`
- Sistema: Debian GNU/Linux 12 (Bookworm)
- Disco raiz: aproximadamente 9,7 GB disponíveis para o sistema de arquivos
- CPU reportada pelo Linux: 2 CPUs lógicas
- Memória: aproximadamente 969 MiB

O endereço `10.128.0.2/32` é o endereço configurado na interface da VM. O `/32` representa uma máscara de host único; a conectividade da VPC é gerenciada pela infraestrutura de rede do Google Cloud.

## 5. Machine Types e comparação E2

Os tipos foram consultados na zona `us-central1-a` com `gcloud compute machine-types describe`.

| Machine type | vCPUs reportadas | Memória | Shared CPU |
|---|---:|---:|---|
| `e2-micro` | 2 | 1 GB | Sim |
| `e2-small` | 2 | 2 GB | Sim |
| `e2-medium` | 2 | 4 GB | Sim |
| `e2-standard-2` | 2 | 8 GB | Não |

Comandos usados:

```bash
gcloud compute machine-types list \
  --zones=us-central1-a \
  --filter="name~'^e2-'"

gcloud compute machine-types describe e2-micro \
  --zone=us-central1-a

gcloud compute machine-types describe e2-small \
  --zone=us-central1-a

gcloud compute machine-types describe e2-medium \
  --zone=us-central1-a

gcloud compute machine-types describe e2-standard-2 \
  --zone=us-central1-a
```

A propriedade `isSharedCpu` indica se o tipo usa CPU compartilhada. Nas descrições consultadas, `e2-micro`, `e2-small` e `e2-medium` são shared-core; `e2-standard-2` não é.

As descrições retornadas também indicaram as frações de core físico compartilhado para os tipos pequenos:
- `e2-micro`: 1/8 de core físico compartilhado.
- `e2-small`: 1/4 de core físico compartilhado.
- `e2-medium`: 1/2 de core físico compartilhado.

Esses valores descrevem a capacidade compartilhada do tipo de máquina; duas vCPUs reportadas não significam dois núcleos físicos dedicados.

## 6. Teste temporário de Cloud NAT

Foi realizado um exercício adicional para demonstrar saída IPv4 de uma VM sem IP externo.

Antes do NAT:
- A VM não tinha `access_config` (IP externo).
- A VPC tinha uma rota padrão `0.0.0.0/0` para `default-internet-gateway`.
- Não havia Cloud Router/NAT na região.
- A resolução DNS funcionava, mas `curl -4` para `www.google.com` expirava.
- O acesso ao servidor de metadados do Compute Engine funcionava.

Foi adicionado temporariamente ao Terraform:

```hcl
resource "google_compute_router" "nat_router" {
  name    = "ace-vm-nat-router"
  region  = var.region
  network = "default"
}

resource "google_compute_router_nat" "nat" {
  name                               = "ace-vm-nat"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = "default"
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ALL"
  }
}
```

Após aplicar, a conexão:

```bash
curl -4 -I --connect-timeout 10 https://www.google.com
```

retornou `HTTP/2 200`.

O IP público observado com `curl -4 https://ifconfig.me` foi `35.202.240.7`. A consulta `gcloud compute routers get-nat-ip-info` indicou o IP em modo `AUTO` e uso `IN_USE`.

O NAT e o Router foram removidos após o teste para evitar custos contínuos. Os blocos temporários também foram retirados da configuração final do Terraform.

**Conceitos importantes:**
- Uma rota padrão para o Internet Gateway não garante, sozinha, saída IPv4 de uma VM sem IP externo.
- Cloud NAT permite conexões de saída sem atribuir IP externo diretamente à VM.
- Cloud NAT não permite conexões de entrada não solicitadas.
- Private Google Access é um recurso diferente de Cloud NAT. Na subnet `default`, `privateIpGoogleAccess` estava `false`.

## 7. Redimensionamento: `e2-micro` para `e2-small`

A configuração Terraform foi alterada para:

```hcl
default = "e2-small"
```

O plano esperado foi:

```text
~ update in-place
Plan: 0 to add, 1 to change, 0 to destroy.
```

A instância foi parada:

```bash
gcloud compute instances stop ace-vm-instance \
  --zone=us-central1-a \
  --project=ace-hands-on-labs-2026
```

Depois foi aplicado:

```bash
terraform apply
```

O resultado foi:

```text
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

A instância foi iniciada novamente:

```bash
gcloud compute instances start ace-vm-instance \
  --zone=us-central1-a \
  --project=ace-hands-on-labs-2026
```

Após reconectar via IAP, `free -h` mostrou aproximadamente 1,9 GiB de memória total, confirmando o novo tipo `e2-small`.

## 8. Validação final observada

A instância ficou com:

| Propriedade | Resultado |
|---|---|
| Nome | `ace-vm-instance` |
| Machine Type | `e2-small` |
| Zona | `us-central1-a` |
| Status | `RUNNING` |
| IP interno | `10.128.0.2` |
| IP externo | Nenhum |
| Disco | 10 GB |
| Tipo do disco | `pd-balanced` |
| Estado do disco | `READY` |
| Sistema operacional | Debian 12 |

Comandos de validação:

```bash
gcloud compute instances describe ace-vm-instance \
  --zone=us-central1-a \
  --format="yaml(name,machineType,status,disks)"

gcloud compute disks describe ace-vm-instance \
  --zone=us-central1-a \
  --format="yaml(name,sizeGb,type,status)"
```

## 9. Limpeza dos recursos

**Atenção:** a instância e o firewall ainda precisam ser destruídos ao terminar o laboratório para evitar custos de Compute Engine e disco.

No diretório do laboratório:

```bash
terraform plan
terraform destroy
```

Confirme com `yes`. O `terraform destroy` remove a VM e a regra de firewall gerenciadas por esta configuração.

Depois, valide que não existem mais recursos do laboratório:

```bash
gcloud compute instances list \
  --project=ace-hands-on-labs-2026

gcloud compute firewall-rules list \
  --filter="name=ace-vm-allow-iap-ssh" \
  --project=ace-hands-on-labs-2026
```

## 10. Conceitos para a certificação ACE

- **Compute Engine instance:** máquina virtual executada no Google Cloud.
- **Machine type:** define a quantidade de vCPUs e memória da instância.
- **Shared-core:** tipos econômicos que compartilham capacidade de CPU física.
- **Zone:** localização zonal da instância e de recursos como Persistent Disks zonais.
- **Boot disk:** disco de inicialização que contém o sistema operacional.
- **Persistent Disk:** armazenamento em bloco persistente, independente do ciclo de vida da VM quando configurado para ser preservado.
- **External IP:** endereço público atribuído à interface da VM.
- **IAP TCP forwarding:** permite acesso administrativo a VMs sem expor SSH publicamente.
- **Cloud NAT:** fornece conectividade de saída para VMs sem IP externo.
- **Terraform update in-place:** atualização de um recurso sem destruí-lo e recriá-lo.

## Status do laboratório

- [x] Criar VM com Terraform.
- [x] Criar firewall para SSH via IAP.
- [x] Acessar VM sem IP externo.
- [x] Inspecionar sistema operacional, rede, CPU, memória e disco.
- [x] Comparar tipos de máquina E2.
- [x] Testar Cloud NAT e removê-lo.
- [x] Redimensionar `e2-micro` para `e2-small`.
- [x] Validar o novo tipo e a persistência do disco.
- [ ] Executar `terraform destroy`.
- [ ] Commit, push e merge da branch.

Próximo laboratório: **Lab 04.2 — Disks & Snapshots**.