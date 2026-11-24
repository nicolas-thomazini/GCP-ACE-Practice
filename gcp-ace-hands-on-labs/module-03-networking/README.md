# Módulo 03 — Networking | Google Cloud ACE Hands-on Labs

## Objetivo do módulo

Praticar os principais recursos de rede do Google Cloud para a certificação **Associate Cloud Engineer (ACE)**, utilizando o Console/CLI do Google Cloud e Terraform.

O módulo percorreu a criação e organização de redes VPC, sub-redes, regras de firewall, conectividade entre VPCs, saída para a internet por Cloud NAT e compartilhamento de rede entre projetos com Shared VPC.

> Este é um resumo dos laboratórios realizados neste repositório. O Lab 03.4 foi dedicado a VPC Peering; o tópico de rotas foi deixado fora da sequência prática deste módulo.

## Índice

| Lab | Tema | Serviço / recurso principal |
|---|---|---|
| 03.1 | VPC Networks | VPC Network |
| 03.2 | Subnets | VPC Subnets |
| 03.3 | Firewall Rules | VPC Firewall Rules |
| 03.4 | VPC Peering | VPC Network Peering |
| 03.5 | Cloud NAT | Cloud Router e Cloud NAT |
| 03.6 | Shared VPC | Host Project e Service Project |

---

## Lab 03.1 — VPC Networks

### O que fizemos

Estudamos a criação e configuração de redes VPC no Google Cloud, utilizando uma rede em modo customizado como base para os exercícios seguintes.

A rede `ace-vpc-custom` foi utilizada posteriormente nos laboratórios de subnets, firewall, peering e Cloud NAT.

### O que a VPC oferece

- Rede virtual isolada e definida por software.
- Conectividade entre recursos de rede do Google Cloud.
- Organização de sub-redes, rotas e regras de firewall.
- Escopo global: uma VPC pode conter subnets em diferentes regiões.

### Conceitos importantes para a ACE

- **Auto Mode:** cria subnets automaticamente em regiões.
- **Custom Mode:** permite definir manualmente as subnets e seus intervalos CIDR.
- Uma VPC é um recurso global; subnets são regionais.
- VPCs diferentes são isoladas por padrão.

---

## Lab 03.2 — Subnets

### O que fizemos

Praticamos a criação e inspeção de subnets na VPC customizada, trabalhando com intervalos IPv4 e entendendo a distribuição regional da rede.

Na infraestrutura usada nos exercícios posteriores, foram identificados:

| Subnet / intervalo | CIDR |
|---|---|
| `ace-subnet-us-central1` | `10.10.0.0/23` |
| `ace-subnet-southamerica` | `10.20.0.0/24` |
| `pods-range` (secundário) | `10.30.0.0/20` |
| `services-range` (secundário) | `10.40.0.0/24` |

### O que as subnets oferecem

- Divisão da VPC em intervalos de endereços IP.
- Organização de recursos por região e finalidade.
- Separação de endereçamento para workloads.
- Intervalos secundários úteis em cenários como GKE, para Pods e Services.

### Conceitos importantes para a ACE

- Subnets são regionais.
- O intervalo primário é usado para endereços de recursos conectados à subnet.
- Intervalos secundários podem ser usados por serviços que precisam de faixas adicionais.
- Os intervalos de subnets de uma mesma rede não devem se sobrepor.
- **Private Google Access** permite que recursos sem IP externo acessem serviços e APIs do Google compatíveis, conforme a configuração de rede.

---

## Lab 03.3 — Firewall Rules

### O que fizemos

Praticamos regras de firewall associadas à VPC, entendendo como controlar tráfego de entrada e saída e como restringir a aplicação das regras por origem, protocolo, porta e tags de destino.

Nos exercícios seguintes, foram utilizadas regras para permitir ICMP entre redes e SSH via IAP.

### O que as regras de firewall oferecem

- Controle do tráfego de rede permitido ou negado.
- Filtragem por direção (ingress/egress).
- Seleção de origem e destino.
- Restrição por protocolo e portas.
- Aplicação a instâncias por meio de network tags ou outros critérios compatíveis.

### Conceitos importantes para a ACE

- **Ingress:** tráfego que entra nos recursos.
- **Egress:** tráfego que sai dos recursos.
- Regras são associadas à VPC.
- Uma regra de firewall não cria conectividade por si só: rotas e demais condições de rede também precisam permitir o fluxo.
- O acesso SSH via IAP normalmente exige uma regra de entrada TCP 22 a partir do intervalo `35.235.240.0/20`, além das permissões IAM apropriadas.

---

## Lab 03.4 — VPC Peering

### O que fizemos

Conectamos duas VPCs distintas por meio de VPC Network Peering:

- VPC principal: `ace-vpc-custom`.
- VPC secundária: `ace-vpc-peering`.
- Subnet da VPC secundária: `10.50.0.0/24`.

Criamos os dois lados do peering:

- `ace-peering-primary-to-secondary`
- `ace-peering-secondary-to-primary`

Também configuramos regras de firewall para ICMP e SSH via IAP e criamos duas VMs de teste sem IP externo:

| VM | VPC | IP interno |
|---|---|---|
| `ace-peering-vm-1` | `ace-vpc-custom` | `10.10.0.4` |
| `ace-peering-vm-2` | `ace-vpc-peering` | `10.50.0.2` |

### Validação realizada

O estado dos dois peerings foi `ACTIVE` e a conectividade foi validada com ping nos dois sentidos. Os testes tiveram 4 pacotes enviados, 4 recebidos e 0% de perda em ambas as direções.

### O que o VPC Peering oferece

- Conectividade privada entre duas VPCs distintas.
- Comunicação usando endereços IP internos.
- Troca de rotas de subnets entre as redes pareadas, conforme as configurações suportadas.

### Conceitos importantes para a ACE

- O peering precisa ser configurado nos dois lados.
- Os intervalos IP não podem se sobrepor.
- Regras de firewall continuam sendo administradas separadamente em cada VPC.
- VPC Peering não é transitivo: uma terceira VPC não passa a alcançar as demais automaticamente por estar pareada com uma delas.
- Peering não transforma duas VPCs em uma única rede.

---

## Lab 03.5 — Cloud NAT

### O que fizemos

Utilizamos a VPC `ace-vpc-custom` e a subnet `ace-subnet-us-central1` para criar uma VM sem IP externo e configurar conectividade de saída com Cloud NAT.

Recursos criados:

- VM: `ace-cloud-nat-vm`.
- IP interno observado: `10.10.0.5`.
- Firewall: `ace-cloud-nat-allow-iap-ssh`.
- Cloud Router: `ace-cloud-nat-router`.
- Cloud NAT: `ace-cloud-nat`.

O NAT foi configurado com alocação automática de IPs (`AUTO_ONLY`) e escopo limitado à subnet selecionada (`LIST_OF_SUBNETWORKS`).

### Validação realizada

A VM não possuía IP externo, mas conseguiu acessar a internet depois da configuração do NAT. O endereço público observado com `api.ipify.org` foi `34.61.229.86`.

Também consultamos os logs do Cloud NAT. Um registro mostrou:

- IP de origem: `10.10.0.5`.
- IP de destino: `104.26.12.205`.
- Status de alocação: `OK`.

### O que Cloud NAT oferece

- Conectividade de saída para a internet de recursos sem IP externo.
- Tradução de endereços privados para endereços públicos de NAT.
- Gerenciamento de NAT sem precisar configurar uma VM como appliance NAT.
- Logs para observar traduções e erros, quando habilitados.

### Conceitos importantes para a ACE

- Cloud NAT é regional.
- Cloud Router é utilizado para configurar o Cloud NAT.
- `AUTO_ONLY` permite alocação automática de IPs NAT.
- Cloud NAT permite conexões iniciadas de dentro para fora; não disponibiliza acesso de entrada não solicitado às VMs.
- **Private Google Access e Cloud NAT são diferentes:** PGA permite acesso a APIs/serviços Google compatíveis sem IP externo; Cloud NAT oferece saída para destinos externos na internet.

---

## Lab 03.6 — Shared VPC

### O que fizemos

Praticamos o compartilhamento de uma rede entre dois projetos da mesma organização.

Arquitetura:

| Papel | Projeto |
|---|---|
| Host Project | `project-e1c42a09-814e-483f-a7c` |
| Service Project | `ace-shared-vpc-service-2026` |

O Host Project foi habilitado como Host de Shared VPC e o Service Project foi associado a ele.

Criamos no Host Project:

- VPC: `ace-shared-vpc`.
- Subnet: `ace-shared-subnet`.
- CIDR: `10.60.0.0/24`.
- Região: `us-central1`.

Concedemos `roles/compute.networkUser` no escopo da subnet para permitir seu uso pela identidade do laboratório.

Em seguida, criamos no Service Project uma VM:

- Nome: `ace-shared-vpc-service-vm`.
- Tipo: `e2-micro`.
- IP interno observado: `10.60.0.2`.
- Subnet utilizada: `ace-shared-subnet`, pertencente ao Host Project.

### Validação realizada

A VM foi listada no Service Project, mas sua interface de rede apontava para a VPC e a subnet do Host Project.

### O que Shared VPC oferece

- Centralização da administração de rede em um projeto Host.
- Uso de subnets compartilhadas por recursos de outros projetos.
- Separação entre administração de rede e administração de workloads.
- Governança e controle de acesso por IAM.

### Conceitos importantes para a ACE

- Host Project hospeda a VPC e suas subnets.
- Service Project consome a rede compartilhada e hospeda seus próprios recursos.
- Os projetos precisam pertencer à mesma organização.
- `roles/compute.xpnAdmin` está relacionado à administração de Shared VPC.
- `roles/compute.networkUser` permite utilizar redes/subnets compartilhadas, conforme o escopo concedido.
- Shared VPC não é VPC Peering: no Shared VPC os projetos utilizam a mesma VPC; no peering são conectadas VPCs distintas.

---

## Comparativo dos serviços de Networking

| Recurso | Principal finalidade | Escopo / característica |
|---|---|---|
| VPC Network | Criar a rede virtual | Global |
| Subnet | Dividir a rede em intervalos IP | Regional |
| Firewall Rules | Controlar tráfego de entrada e saída | Associadas à VPC |
| VPC Peering | Conectar VPCs distintas | Entre duas VPCs, não transitivo |
| Cloud Router | Componente de configuração de roteamento dinâmico e suporte ao Cloud NAT | Regional |
| Cloud NAT | Permitir saída para internet sem IP externo na VM | Regional |
| Shared VPC | Compartilhar uma VPC entre projetos | Organização, Host e Service Projects |
| Private Google Access | Acessar APIs/serviços Google compatíveis sem IP externo | Configuração da subnet |

## Principais aprendizados do módulo

Ao concluir o módulo, praticamos:

1. Criar e organizar redes VPC em modo customizado.
2. Definir subnets e intervalos CIDR.
3. Controlar tráfego com regras de firewall.
4. Conectar VPCs distintas por VPC Peering.
5. Fornecer saída para a internet com Cloud NAT sem IP externo na VM.
6. Compartilhar uma rede entre projetos com Shared VPC.
7. Aplicar IAM para controlar o uso de recursos de rede.
8. Utilizar Terraform para provisionar e destruir infraestrutura.

## Limpeza e custos

Os laboratórios criaram recursos de rede e máquinas virtuais. Ao finalizar cada exercício:

- Execute `terraform destroy` no diretório correspondente quando os recursos forem gerenciados pelo Terraform.
- Confira recursos criados por comandos `gcloud`, pois eles podem não estar no state do Terraform.
- Verifique VMs, discos, IPs reservados, Cloud NAT, Cloud Routers, regras e associações de Shared VPC.
- Não remova projetos ou vínculos de Billing sem verificar se são utilizados por outros exercícios.

A criação de VPCs e subnets normalmente não é o principal componente de custo, mas VMs, discos, tráfego de rede, IPs e logs podem gerar cobranças.

## Estrutura sugerida do módulo

```text
module-03-networking/
├── README.md
├── lab-03-01-vpc-networks/
├── lab-03-02-subnets/
├── lab-03-03-firewall-rules/
├── lab-03-04-vpc-peering/
├── lab-03-05-cloud-nat/
└── lab-03-06-shared-vpc/
    └── README.md
```

## Referências oficiais do Google Cloud

- [VPC overview](https://cloud.google.com/vpc/docs/vpc)
- [Subnets](https://cloud.google.com/vpc/docs/subnets)
- [Firewall rules](https://cloud.google.com/firewall/docs/firewalls)
- [VPC Network Peering](https://cloud.google.com/vpc/docs/vpc-peering)
- [Cloud NAT overview](https://cloud.google.com/nat/docs/overview)
- [Shared VPC overview](https://cloud.google.com/vpc/docs/shared-vpc)
- [Private Google Access](https://cloud.google.com/vpc/docs/private-google-access)