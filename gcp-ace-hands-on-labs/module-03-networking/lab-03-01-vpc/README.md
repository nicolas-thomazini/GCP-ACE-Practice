# Lab 03.1 — VPC Networks

## Objetivo

Compreender o funcionamento das redes VPC (Virtual Private Cloud) na Google Cloud, explorando os modos **Auto** e **Custom**, criação de subnets em diferentes regiões e conversão entre os modos.

## Ambiente utilizado

| Configuração | Valor |
|---|---|
| Cloud Provider | Google Cloud Platform |
| Project ID | `ace-hands-on-labs-2026` |
| Região principal | `us-central1` |
| CLI | Google Cloud CLI |

## 1. Conceitos estudados

### VPC — Virtual Private Cloud

Uma VPC é uma rede virtual privada e global dentro da Google Cloud.

Ela permite organizar e conectar recursos de infraestrutura, como máquinas virtuais, serviços e sub-redes.

Uma VPC pode possuir subnets distribuídas em diferentes regiões.

### Auto Mode

No modo Auto, a Google Cloud cria automaticamente uma subnet em cada região disponível, utilizando intervalos IPv4 predefinidos.

Características:
- Criação automática de subnets.
- Intervalos IP definidos pela Google Cloud.
- Novas regiões recebem subnets automaticamente enquanto a rede permanecer em Auto Mode.

### Custom Mode

No modo Custom, o administrador define manualmente:
- Quais subnets serão criadas.
- Em quais regiões estarão localizadas.
- Quais intervalos CIDR serão utilizados.

É o modo que oferece maior controle sobre o endereçamento IP da infraestrutura.

### Subnets

São divisões regionais de uma VPC, cada uma com seu próprio intervalo de endereços IP.

Exemplo: `10.10.0.0/24`.

## 2. Habilitação da API

Durante a criação da primeira VPC, identificamos que a Compute Engine API estava desabilitada.

Habilitamos:

```bash
gcloud services enable compute.googleapis.com
```

API utilizada:
- `compute.googleapis.com`

## 3. Criação da VPC Custom

Criamos uma VPC em modo Custom:

```bash
gcloud compute networks create ace-vpc-custom \
  --subnet-mode=custom
```

Resultado:
- Nome: `ace-vpc-custom`
- Modo: `CUSTOM`
- BGP Routing Mode: `REGIONAL`

### Criação da primeira subnet

Criamos uma subnet na região `us-central1`:

```bash
gcloud compute networks subnets create ace-subnet-us-central1 \
  --network=ace-vpc-custom \
  --region=us-central1 \
  --range=10.10.0.0/24
```

### Criação da segunda subnet

Criamos outra subnet na região `southamerica-east1`:

```bash
gcloud compute networks subnets create ace-subnet-southamerica \
  --network=ace-vpc-custom \
  --region=southamerica-east1 \
  --range=10.20.0.0/24
```

### Resultado

| Subnet | Região | CIDR |
|---|---|---|
| `ace-subnet-us-central1` | `us-central1` | `10.10.0.0/24` |
| `ace-subnet-southamerica` | `southamerica-east1` | `10.20.0.0/24` |

Com isso, validamos que uma mesma VPC pode possuir subnets em diferentes regiões.

## 4. Inspeção das subnets

Listamos as subnets associadas à VPC Custom:

```bash
gcloud compute networks subnets list \
  --network=ace-vpc-custom
```

## 5. Criação da VPC Auto

Criamos uma segunda VPC utilizando Auto Mode:

```bash
gcloud compute networks create ace-vpc-auto \
  --subnet-mode=auto
```

A Google Cloud criou automaticamente subnets em diversas regiões.

Inspecionamos as subnets:

```bash
gcloud compute networks subnets list \
  --network=ace-vpc-auto
```

Observamos 42 subnets criadas automaticamente, incluindo regiões como:
- `us-central1`
- `southamerica-east1`
- `europe-west1`
- `asia-east1`
- `australia-southeast1`

Os intervalos IPv4 foram definidos automaticamente pela Google Cloud.

## 6. Listagem das VPCs

Para visualizar as redes existentes no projeto:

```bash
gcloud compute networks list
```

Identificamos três VPCs:

| VPC | Modo |
|---|---|
| `default` | AUTO |
| `ace-vpc-auto` | AUTO |
| `ace-vpc-custom` | CUSTOM |

A rede `default` já existia no projeto.

## 7. Conversão de Auto para Custom

Realizamos a conversão da VPC `ace-vpc-auto`:

```bash
gcloud compute networks update ace-vpc-auto \
  --switch-to-custom-subnet-mode
```

A operação é unidirecional:
- Auto → Custom: permitido.
- Custom → Auto: não permitido.

As subnets existentes são preservadas após a conversão.

### Validação

Listamos novamente as VPCs:

```bash
gcloud compute networks list
```

Resultado esperado:

| VPC | Modo atual |
|---|---|
| `ace-vpc-auto` | CUSTOM |
| `ace-vpc-custom` | CUSTOM |
| `default` | AUTO |

Também verificamos que as 42 subnets anteriormente criadas na `ace-vpc-auto` continuavam existentes:

```bash
gcloud compute networks subnets list \
  --network=ace-vpc-auto
```

## 8. Arquitetura final

O laboratório resultou na seguinte estrutura:

```text
Google Cloud Project
└── ace-hands-on-labs-2026
    │
    ├── default (AUTO)
    │
    ├── ace-vpc-custom (CUSTOM)
    │   ├── ace-subnet-us-central1
    │   │   └── 10.10.0.0/24
    │   │
    │   └── ace-subnet-southamerica
    │       └── 10.20.0.0/24
    │
    └── ace-vpc-auto (CUSTOM)
        └── 42 subnets preservadas
            └── Diferentes regiões
```

## 9. Aprendizados para a certificação ACE

- VPCs são recursos globais.
- Subnets são recursos regionais.
- Uma VPC pode possuir subnets em diferentes regiões.
- Auto Mode cria subnets automaticamente.
- Custom Mode permite controlar manualmente os intervalos IP.
- A conversão de Auto para Custom preserva as subnets existentes.
- A conversão de Custom para Auto não é permitida.
- A comunicação entre subnets da mesma VPC utiliza a rede interna da Google Cloud, respeitando as regras de firewall.

## 10. Conclusão

Neste laboratório, criamos e configuramos redes VPC utilizando Auto e Custom Mode.

Também praticamos a criação de subnets em diferentes regiões, inspeção dos recursos pela CLI e conversão de uma rede Auto para Custom.

O laboratório serviu como introdução prática ao gerenciamento de redes na Google Cloud e preparou o ambiente conceitual para os próximos estudos de Networking.