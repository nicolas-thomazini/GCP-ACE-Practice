# Lab 03.6 — Shared VPC

## Objetivo

Praticar o **Shared VPC** do Google Cloud, centralizando a administração da rede em um projeto Host e permitindo que um projeto Service utilize essa rede para hospedar seus próprios recursos.

O laboratório demonstrou que uma VM pode pertencer a um projeto e utilizar uma VPC e uma subnet pertencentes a outro projeto da mesma organização.

## Arquitetura utilizada

| Papel | Projeto | Responsabilidade |
|---|---|---|
| Host Project | `project-e1c42a09-814e-483f-a7c` (`My First Project`) | Hospeda e administra a VPC e a subnet compartilhadas |
| Service Project | `ace-shared-vpc-service-2026` | Hospeda a VM que consome a rede compartilhada |
| Organização | `605949686486` (`mirellathomazini-org`) | Escopo organizacional exigido pelo Shared VPC |
| Região / zona | `us-central1` / `us-central1-a` | Região da subnet e zona da VM |

> O projeto `ace-hands-on-labs-2026` utilizado nos demais laboratórios estava fora da organização. Por isso, foi preservado e não foi utilizado como Host ou Service Project neste exercício.

## Conceitos praticados

### Host Project

É o projeto que contém e administra a infraestrutura de rede compartilhada: VPCs, subnets, rotas e regras de firewall.

### Service Project

É um projeto associado ao Host Project que pode criar recursos, como máquinas virtuais, utilizando as subnets compartilhadas.

### IAM — `roles/compute.networkUser`

A associação do Service Project ao Host Project não substitui as permissões IAM. Para este exercício, foi concedido `roles/compute.networkUser` à conta utilizada no laboratório, no escopo da subnet compartilhada.

### Diferença entre Shared VPC e VPC Peering

- **Shared VPC:** projetos diferentes utilizam a mesma VPC, administrada pelo Host Project.
- **VPC Peering:** conecta duas VPCs distintas para permitir comunicação entre elas; cada VPC continua sendo uma rede separada.

## Etapas executadas

### 1. Verificação da organização e do Billing

Foi identificada uma organização ativa e um projeto já associado a ela. Também foi confirmado que o Host Project tinha Billing habilitado.

Comandos utilizados:

```bash
gcloud organizations list

gcloud projects describe project-e1c42a09-814e-483f-a7c \
  --format="yaml(projectId,name,parent,lifecycleState)"

gcloud billing projects describe project-e1c42a09-814e-483f-a7c

gcloud organizations get-iam-policy 605949686486
```

### 2. Criação do Service Project

```bash
gcloud projects create ace-shared-vpc-service-2026 \
  --organization=605949686486 \
  --name="ACE Shared VPC Service"

gcloud billing projects link ace-shared-vpc-service-2026 \
  --billing-account=01524B-0F156A-A7A8A8
```

A Compute Engine API foi habilitada nos dois projetos:

```bash
gcloud services enable compute.googleapis.com \
  --project=project-e1c42a09-814e-483f-a7c

gcloud services enable compute.googleapis.com \
  --project=ace-shared-vpc-service-2026
```

### 3. Habilitação do Shared VPC no Host Project

A primeira tentativa retornou falta da permissão `compute.organizations.enableXpnHost`. Foi necessário conceder o papel `roles/compute.xpnAdmin` à conta do laboratório no nível da organização.

```bash
gcloud organizations add-iam-policy-binding 605949686486 \
  --member="user:mirellathomazini@gmail.com" \
  --role="roles/compute.xpnAdmin"
```

Depois, o Host Project foi habilitado:

```bash
gcloud compute shared-vpc enable project-e1c42a09-814e-483f-a7c
```

### 4. Associação do Service Project

```bash
gcloud compute shared-vpc associated-projects add \
  ace-shared-vpc-service-2026 \
  --host-project=project-e1c42a09-814e-483f-a7c
```

Verificações:

```bash
gcloud compute shared-vpc get-host-project \
  ace-shared-vpc-service-2026

gcloud compute shared-vpc list-associated-resources \
  project-e1c42a09-814e-483f-a7c
```

O resultado confirmou o Host Project e listou `ace-shared-vpc-service-2026` como projeto associado.

### 5. Criação da VPC e subnet no Host Project com Terraform

Arquivos utilizados:

- `main.tf`
- `variables.tf`
- `terraform.tfvars`
- `outputs.tf`

O provider principal apontou para o Host Project. Foram criados:

| Recurso | Nome | Configuração |
|---|---|---|
| VPC | `ace-shared-vpc` | Custom Mode (`auto_create_subnetworks = false`) |
| Subnet | `ace-shared-subnet` | `10.60.0.0/24`, região `us-central1` |

Comandos:

```bash
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
```

### 6. Permissão para utilizar a subnet

Foi concedido `roles/compute.networkUser` à conta do laboratório no escopo da subnet:

```bash
gcloud compute networks subnets add-iam-policy-binding ace-shared-subnet \
  --region=us-central1 \
  --project=project-e1c42a09-814e-483f-a7c \
  --member="user:mirellathomazini@gmail.com" \
  --role="roles/compute.networkUser"
```

A política foi conferida com:

```bash
gcloud compute networks subnets get-iam-policy ace-shared-subnet \
  --region=us-central1 \
  --project=project-e1c42a09-814e-483f-a7c
```

### 7. Criação da VM no Service Project usando a subnet do Host

Foi adicionado um segundo provider Google com alias `service`, apontando para `ace-shared-vpc-service-2026`.

A VM foi criada no Service Project, enquanto o bloco `network_interface` referenciou a subnet criada no Host Project.

Configuração principal:

- VM: `ace-shared-vpc-service-vm`
- Tipo: `e2-micro`
- Imagem: Debian 12
- Disco: 10 GB
- Zona: `us-central1-a`
- Subnet compartilhada: `ace-shared-subnet`
- IP interno observado: `10.60.0.2`
- IP externo: nenhum

O `terraform plan` mostrou a VM no projeto `ace-shared-vpc-service-2026` e a subnet com caminho completo no projeto Host:

```text
projects/project-e1c42a09-814e-483f-a7c/regions/us-central1/subnetworks/ace-shared-subnet
```

## Validação

A VM apareceu no inventário do Service Project:

```bash
gcloud compute instances list \
  --project=ace-shared-vpc-service-2026
```

Resultado observado:

```text
NAME                       ZONE           MACHINE_TYPE  INTERNAL_IP  EXTERNAL_IP  STATUS
ace-shared-vpc-service-vm  us-central1-a  e2-micro      10.60.0.2                 RUNNING
```

A interface de rede da VM apontou para a VPC e subnet do Host Project:

```bash
gcloud compute instances describe ace-shared-vpc-service-vm \
  --zone=us-central1-a \
  --project=ace-shared-vpc-service-2026 \
  --format="yaml(name,networkInterfaces)"
```

A subnet foi conferida no Host Project:

```bash
gcloud compute networks subnets describe ace-shared-subnet \
  --region=us-central1 \
  --project=project-e1c42a09-814e-483f-a7c \
  --format="yaml(name,network,ipCidrRange)"
```

**Conclusão:** a VM pertence ao Service Project, mas sua interface utiliza a rede e a subnet pertencentes ao Host Project. Essa é a demonstração central do Shared VPC.

## Limpeza dos recursos

O laboratório foi planejado para remover os recursos de infraestrutura criados com Terraform e desfazer a associação entre os projetos.

Ordem de limpeza:

1. Executar `terraform destroy` no diretório do laboratório para remover a VM, a subnet e a VPC gerenciadas pelo Terraform.
2. Remover o Service Project da associação com o Host.
3. Desabilitar Shared VPC no Host Project, depois de confirmar que não há outros Service Projects associados ou recursos dependentes.

Comandos de referência:

```bash
terraform destroy

gcloud compute shared-vpc associated-projects remove \
  ace-shared-vpc-service-2026 \
  --host-project=project-e1c42a09-814e-483f-a7c

gcloud compute shared-vpc disable \
  project-e1c42a09-814e-483f-a7c
```

Verifique o estado antes de considerar a limpeza concluída:

```bash
gcloud compute shared-vpc get-host-project \
  ace-shared-vpc-service-2026
```

> A documentação deste laboratório registra os comandos de limpeza. Execute-os se os recursos ainda estiverem provisionados. Não exclua projetos ou altere vínculos de Billing sem conferir se não há outros recursos ou dependências.

## O que este laboratório ensinou para a ACE

- Shared VPC exige projetos dentro da mesma organização.
- O Host Project centraliza a propriedade e administração da rede.
- O Service Project hospeda recursos que consomem a rede compartilhada.
- Associar um Service Project não concede automaticamente todas as permissões IAM.
- `roles/compute.xpnAdmin` permite administrar Shared VPC.
- `roles/compute.networkUser` permite utilizar redes/subnets compartilhadas, conforme o escopo da concessão.
- Uma VM pode pertencer a um projeto e utilizar uma subnet de outro projeto.
- Shared VPC não é a mesma coisa que VPC Peering.

## Referências oficiais

- [Shared VPC overview](https://cloud.google.com/vpc/docs/shared-vpc)
- [Provisioning Shared VPC](https://cloud.google.com/vpc/docs/provisioning-shared-vpc)
- [Shared VPC permissions](https://cloud.google.com/vpc/docs/shared-vpc#iam_in_shared_vpc)