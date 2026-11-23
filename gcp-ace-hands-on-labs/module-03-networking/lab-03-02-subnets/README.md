# Lab 03.2 — Subnets

## Objetivo

Aprofundar os conhecimentos sobre subnets na Google Cloud, trabalhando com endereçamento IPv4, CIDR, expansão de intervalos IP, Secondary IP Ranges e Private Google Access.

## Ambiente utilizado

| Configuração | Valor |
|---|---|
| Cloud Provider | Google Cloud Platform |
| Project ID | `ace-hands-on-labs-2026` |
| VPC | `ace-vpc-custom` |
| Região principal | `us-central1` |
| Região secundária | `southamerica-east1` |
| CLI | Google Cloud CLI |

## 1. Conceitos estudados

### CIDR — Classless Inter-Domain Routing

CIDR é uma notação utilizada para representar intervalos de endereços IP.

O número após a barra representa a quantidade de bits utilizados para identificar a parte de rede.

Exemplos:

| CIDR | Máscara | Endereços totais |
|---|---|---:|
| `10.10.0.0/24` | `255.255.255.0` | 256 |
| `10.10.0.0/23` | `255.255.254.0` | 512 |
| `10.10.0.0/20` | `255.255.240.0` | 4.096 |

Quanto menor o prefixo CIDR, maior o intervalo de endereços disponíveis.

Na Google Cloud, quatro endereços IPv4 de cada intervalo de subnet são reservados. Portanto, uma subnet `/24` possui 252 endereços utilizáveis, enquanto uma `/23` possui 508.

### Primary IP Range

É o intervalo IPv4 principal de uma subnet.

Normalmente, é utilizado para endereços IP internos das interfaces de rede das máquinas virtuais.

### Secondary IP Ranges

São intervalos IPv4 adicionais associados a uma subnet.

Um caso comum de utilização é o GKE com VPC-native networking:

- Nodes utilizam endereços do intervalo primário.
- Pods utilizam um intervalo secundário.
- Services podem utilizar outro intervalo secundário.

### Private Google Access

Permite que recursos sem endereço IP externo acessem serviços e APIs Google utilizando conectividade privada.

É especialmente útil para máquinas virtuais que precisam acessar serviços como Cloud Storage sem possuir IP público.

## 2. Inspeção da subnet existente

Reutilizamos a subnet criada no laboratório anterior:

- Nome: `ace-subnet-us-central1`
- VPC: `ace-vpc-custom`
- Região: `us-central1`
- CIDR inicial: `10.10.0.0/24`

Comando utilizado:

```bash
gcloud compute networks subnets describe ace-subnet-us-central1 \
  --region=us-central1
```

Identificamos campos importantes:

| Campo | Valor inicial |
|---|---|
| `ipCidrRange` | `10.10.0.0/24` |
| `gatewayAddress` | `10.10.0.1` |
| `stackType` | `IPV4_ONLY` |
| `privateIpGoogleAccess` | `false` |

## 3. Expansão do intervalo IP

Expandimos o intervalo primário da subnet de `/24` para `/23`.

Comando:

```bash
gcloud compute networks subnets expand-ip-range ace-subnet-us-central1 \
  --region=us-central1 \
  --prefix-length=23
```

### Antes e depois

| Configuração | Antes | Depois |
|---|---|---|
| CIDR | `10.10.0.0/24` | `10.10.0.0/23` |
| Endereços totais | 256 | 512 |
| Endereços utilizáveis | 252 | 508 |

A expansão preservou o endereço inicial da subnet e incorporou o bloco adjacente `10.10.1.0/24`.

### Validação

```bash
gcloud compute networks subnets describe ace-subnet-us-central1 \
  --region=us-central1
```

Confirmamos que o novo intervalo estava configurado corretamente:

```yaml
ipCidrRange: 10.10.0.0/23
```

A expansão não recriou a subnet: seu identificador permaneceu o mesmo.

## 4. Configuração de Secondary IP Ranges

Adicionamos dois intervalos secundários à subnet `ace-subnet-us-central1`.

Comando:

```bash
gcloud compute networks subnets update ace-subnet-us-central1 \
  --region=us-central1 \
  --add-secondary-ranges pods-range=10.30.0.0/20,services-range=10.40.0.0/24
```

### Intervalos configurados

| Tipo | Nome | CIDR | Finalidade |
|---|---|---|---|
| Primary | Principal | `10.10.0.0/23` | Endereços principais da subnet |
| Secondary | `pods-range` | `10.30.0.0/20` | Endereços para Pods |
| Secondary | `services-range` | `10.40.0.0/24` | Endereços para Services |

Essa configuração prepara a subnet para utilização em arquiteturas como GKE VPC-native networking.

**Observação:** neste laboratório não criamos um cluster GKE. Apenas configuramos os intervalos necessários para compreender sua utilização.

### Validação

```bash
gcloud compute networks subnets describe ace-subnet-us-central1 \
  --region=us-central1 \
  --format="yaml(name,ipCidrRange,secondaryIpRanges)"
```

Resultado validado:

```yaml
ipCidrRange: 10.10.0.0/23
name: ace-subnet-us-central1
secondaryIpRanges:
- ipCidrRange: 10.30.0.0/20
  rangeName: pods-range
- ipCidrRange: 10.40.0.0/24
  rangeName: services-range
```

## 5. Inspeção de subnets em diferentes regiões

Listamos as subnets associadas à VPC `ace-vpc-custom`:

```bash
gcloud compute networks subnets list \
  --network=ace-vpc-custom
```

Resultado:

| Subnet | Região | CIDR primário |
|---|---|---|
| `ace-subnet-us-central1` | `us-central1` | `10.10.0.0/23` |
| `ace-subnet-southamerica` | `southamerica-east1` | `10.20.0.0/24` |

Com isso, reforçamos que uma VPC é um recurso global e pode possuir subnets em diferentes regiões.

## 6. Habilitação do Private Google Access

Habilitamos o Private Google Access na subnet `ace-subnet-us-central1`.

Comando:

```bash
gcloud compute networks subnets update ace-subnet-us-central1 \
  --region=us-central1 \
  --enable-private-ip-google-access
```

### Validação

```bash
gcloud compute networks subnets describe ace-subnet-us-central1 \
  --region=us-central1 \
  --format="yaml(name,ipCidrRange,privateIpGoogleAccess,secondaryIpRanges)"
```

Resultado validado:

```yaml
ipCidrRange: 10.10.0.0/23
name: ace-subnet-us-central1
privateIpGoogleAccess: true
secondaryIpRanges:
- ipCidrRange: 10.30.0.0/20
  rangeName: pods-range
- ipCidrRange: 10.40.0.0/24
  rangeName: services-range
```

### Private Google Access vs. Cloud NAT

São recursos com finalidades diferentes:

| Recurso | Finalidade |
|---|---|
| Private Google Access | Permite acesso privado a APIs e serviços Google |
| Cloud NAT | Permite conexões de saída para destinos externos, sem IP público na VM |
| External IP | Fornece conectividade externa diretamente ao recurso |

O Private Google Access não substitui o Cloud NAT.

Neste laboratório habilitamos e validamos a configuração do Private Google Access, mas não realizamos um teste de conectividade com uma VM.

## 7. Arquitetura final

```text
Google Cloud Project
└── ace-hands-on-labs-2026
    │
    └── ace-vpc-custom (CUSTOM)
        │
        ├── ace-subnet-us-central1
        │   ├── Region: us-central1
        │   ├── Primary: 10.10.0.0/23
        │   ├── Secondary:
        │   │   ├── pods-range: 10.30.0.0/20
        │   │   └── services-range: 10.40.0.0/24
        │   └── Private Google Access: ENABLED
        │
        └── ace-subnet-southamerica
            ├── Region: southamerica-east1
            └── Primary: 10.20.0.0/24
```

## 8. Aprendizados para a certificação ACE

- CIDR determina o tamanho de um intervalo de endereços IP.
- Um prefixo menor representa um bloco de endereços maior.
- Subnets podem ter seu intervalo primário expandido.
- A expansão precisa respeitar as restrições de endereçamento e não pode gerar sobreposição indevida.
- Secondary IP Ranges permitem associar intervalos adicionais a uma subnet.
- GKE VPC-native utiliza intervalos secundários para Pods e Services.
- Private Google Access permite acesso privado a APIs e serviços Google para recursos sem IP externo.
- Cloud NAT e Private Google Access resolvem necessidades diferentes.
- Uma VPC global pode possuir subnets em várias regiões.

## 9. Conclusão

Neste laboratório aprofundamos o gerenciamento de subnets na Google Cloud.

Praticamos expansão de intervalos IPv4, configuração de intervalos secundários, inspeção de recursos regionais e habilitação do Private Google Access.

Esses conhecimentos são fundamentais para projetar redes escaláveis, preparar ambientes para GKE e administrar conectividade privada na Google Cloud.