# Lab 03.4 — VPC Network Peering

## Objetivo

Praticar a conexão privada entre duas Virtual Private Cloud (VPCs) no Google Cloud usando **VPC Network Peering**.

Neste laboratório, foi utilizada uma VPC já existente (`ace-vpc-custom`) e criada uma segunda VPC (`ace-vpc-peering`). A conectividade foi validada entre duas VMs sem endereços IP públicos.

## Arquitetura

```text
VPC existente: ace-vpc-custom
├── ace-subnet-us-central1
│   └── 10.10.0.0/23
├── ace-subnet-southamerica
│   └── 10.20.0.0/24
├── pods-range
│   └── 10.30.0.0/20
├── services-range
│   └── 10.40.0.0/24
└── VM: ace-peering-vm-1
    └── 10.10.0.4
          |
          | VPC Network Peering (configurado nos dois lados)
          |
VPC criada: ace-vpc-peering
└── ace-subnet-peering
    └── 10.50.0.0/24
    └── VM: ace-peering-vm-2
        └── 10.50.0.2
```

**Projeto:** `ace-hands-on-labs-2026`  
**Região das subnets e VMs de teste:** `us-central1`  
**Zona das VMs:** `us-central1-a`

## Conceitos praticados

- VPC Peering conecta duas redes VPC por endereçamento IP privado.
- A conexão precisa ser configurada nos dois lados: cada VPC declara a outra como peer.
- Os intervalos IP das redes conectadas não podem se sobrepor.
- Rotas de sub-rede são trocadas automaticamente pelo Peering.
- Rotas personalizadas não são importadas/exportadas por padrão.
- As regras de firewall não são compartilhadas entre VPCs; cada rede mantém suas próprias regras.
- VPC Peering não é transitivo: uma rede não usa outra VPC como roteador para alcançar uma terceira rede.
- VMs podem se comunicar por IPs internos, sem IP público, desde que rotas e regras de firewall permitam o tráfego.
- IAP TCP forwarding foi usado para administrar as VMs privadas por SSH. IAP é um mecanismo de acesso administrativo, não o mecanismo de conectividade entre as VPCs.

## Recursos criados

| Recurso | Nome |
|---|---|
| VPC | `ace-vpc-peering` |
| Subnet | `ace-subnet-peering` |
| CIDR da subnet | `10.50.0.0/24` |
| Peering na VPC principal | `ace-peering-primary-to-secondary` |
| Peering na VPC secundária | `ace-peering-secondary-to-primary` |
| Firewall ICMP na VPC principal | `ace-peering-allow-icmp-primary` |
| Firewall ICMP na VPC secundária | `ace-peering-allow-icmp-secondary` |
| Firewall SSH/IAP na VPC principal | `ace-peering-allow-iap-ssh-primary` |
| Firewall SSH/IAP na VPC secundária | `ace-peering-allow-iap-ssh-secondary` |
| VM na VPC principal | `ace-peering-vm-1` |
| VM na VPC secundária | `ace-peering-vm-2` |

A VPC `ace-vpc-custom` e suas subnets foram consultadas, mas não foram criadas nem gerenciadas por este laboratório.

## Implementação com Terraform

O laboratório utilizou Terraform com o provider `hashicorp/google` na linha `~> 7.0`.

### 1. Consultar a VPC existente

Foi utilizado um data source para consultar a VPC principal sem recriá-la:

```hcl
data "google_compute_network" "primary" {
  name = var.primary_vpc_name
}
```

### 2. Criar a segunda VPC e subnet

```hcl
resource "google_compute_network" "secondary" {
  name                    = var.secondary_vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "secondary_subnet" {
  name          = "ace-subnet-peering"
  region        = var.region
  network       = google_compute_network.secondary.id
  ip_cidr_range = "10.50.0.0/24"
}
```

### 3. Configurar o Peering nos dois sentidos

```hcl
resource "google_compute_network_peering" "primary_to_secondary" {
  name         = "ace-peering-primary-to-secondary"
  network      = data.google_compute_network.primary.self_link
  peer_network = google_compute_network.secondary.self_link
}

resource "google_compute_network_peering" "secondary_to_primary" {
  name         = "ace-peering-secondary-to-primary"
  network      = google_compute_network.secondary.self_link
  peer_network = data.google_compute_network.primary.self_link
}
```

Os dois recursos são necessários para estabelecer a configuração bilateral do Peering.

### 4. Regras de firewall ICMP

Na VPC principal, foi permitido ICMP com origem na subnet da VPC secundária:

```hcl
resource "google_compute_firewall" "allow_icmp_primary" {
  name      = "ace-peering-allow-icmp-primary"
  network   = data.google_compute_network.primary.name
  direction = "INGRESS"

  source_ranges = ["10.50.0.0/24"]

  allow {
    protocol = "icmp"
  }
}
```

Na VPC secundária, foi permitido ICMP com origem nos dois CIDRs primários da VPC principal:

```hcl
resource "google_compute_firewall" "allow_icmp_secondary" {
  name      = "ace-peering-allow-icmp-secondary"
  network   = google_compute_network.secondary.name
  direction = "INGRESS"

  source_ranges = [
    "10.10.0.0/23",
    "10.20.0.0/24"
  ]

  allow {
    protocol = "icmp"
  }
}
```

### 5. Regras SSH via IAP

O acesso administrativo às VMs sem IP público foi feito por IAP TCP forwarding. Para isso, foram criadas regras de entrada TCP/22 com origem no intervalo de IAP `35.235.240.0/20` e direcionadas à tag `peering-test`.

```hcl
resource "google_compute_firewall" "allow_iap_ssh_primary" {
  name      = "ace-peering-allow-iap-ssh-primary"
  network   = data.google_compute_network.primary.name
  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["peering-test"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
```

```hcl
resource "google_compute_firewall" "allow_iap_ssh_secondary" {
  name      = "ace-peering-allow-iap-ssh-secondary"
  network   = google_compute_network.secondary.name
  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["peering-test"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
```

### 6. VMs de teste

Foram criadas duas VMs `e2-micro`, Debian 12, com disco de 10 GB, sem `access_config` (portanto, sem IP externo). Ambas utilizaram a tag de rede `peering-test`.

| VM | Subnet | IP interno observado |
|---|---|---|
| `ace-peering-vm-1` | `ace-subnet-us-central1` | `10.10.0.4` |
| `ace-peering-vm-2` | `ace-subnet-peering` | `10.50.0.2` |

## Validação

### Estado do Peering

Foi consultado o estado das conexões nas duas VPCs:

```bash
gcloud compute networks peerings list --network=ace-vpc-custom
gcloud compute networks peerings list --network=ace-vpc-peering
```

As duas conexões apresentaram estado `ACTIVE` e detalhe `Connected`.

### Rotas

Foi feita a inspeção das rotas:

```bash
gcloud compute routes list \
  --filter="network:ace-vpc-custom OR network:ace-vpc-peering" \
  --format="table(name,network.basename(),destRange,nextHopPeering)"
```

Foram observadas rotas de Peering para `10.50.0.0/24` na VPC principal e para os intervalos da VPC principal na VPC secundária, incluindo `10.10.0.0/23`, `10.20.0.0/24`, `10.30.0.0/20` e `10.40.0.0/24`.

### Teste de conectividade

A partir da VM `ace-peering-vm-1`:

```bash
ping -c 4 10.50.0.2
```

Resultado observado: 4 pacotes enviados, 4 recebidos, 0% de perda. Latência média aproximada: `0.581 ms`.

A partir da VM `ace-peering-vm-2`:

```bash
ping -c 4 10.10.0.4
```

Resultado observado: 4 pacotes enviados, 4 recebidos, 0% de perda. Latência média aproximada: `0.686 ms`.

Os testes comprovaram conectividade privada bidirecional entre as VPCs.

## Limpeza

Após concluir os testes, remover os recursos gerenciados por este laboratório:

```bash
terraform destroy
```

Confirmar com `yes`.

O `data.google_compute_network.primary` apenas consulta a VPC existente `ace-vpc-custom`; ele não a gerencia nem a destrói. Ainda assim, confira o plano de destruição antes de confirmar. A VPC principal e suas subnets preexistentes devem permanecer intactas.

## Resumo para a ACE

1. Peering é não transitivo.
2. Os CIDRs das VPCs não podem se sobrepor.
3. A configuração precisa ser feita nos dois lados.
4. Rotas de sub-rede são trocadas automaticamente.
5. Firewalls continuam independentes em cada VPC.
6. VPC Peering permite tráfego privado entre redes, mas não fornece por si só acesso geral à internet.
7. IAP permite acesso administrativo a VMs sem IP público, desde que IAM, firewall e SSH estejam configurados corretamente.