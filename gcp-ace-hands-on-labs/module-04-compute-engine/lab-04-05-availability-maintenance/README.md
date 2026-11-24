# Lab 04.5 — Disponibilidade e Manutenção (Availability & Maintenance)

## Objetivo

Estudar como o Compute Engine lida com manutenção de hosts físicos, reinicialização automática, eventos de manutenção e isolamento físico com Sole-Tenant Nodes.

Este laboratório prioriza inspeção e validação sem provisionar infraestrutura física dedicada, evitando custos desnecessários.

## Ambiente

| Configuração | Valor |
|---|---|
| Projeto | `ace-hands-on-labs-2026` |
| Região | `us-central1` |
| Zona | `us-central1-a` |
| VM utilizada na inspeção | `ace-mig-vm-p19v` |
| Instance Template | `ace-instance-template` |
| Tipo da VM | `e2-small` |
| Modelo de provisionamento | `STANDARD` |

## Parte 1 — Políticas de disponibilidade de uma VM

### 1.1 Inspecionar o Instance Template

Comando executado:

```bash
gcloud compute instance-templates describe ace-instance-template \\
  --format="yaml(name,properties.scheduling,properties.machineType)"
```

Resultado observado:

```yaml
name: ace-instance-template
properties:
  machineType: e2-small
  scheduling:
    automaticRestart: true
    onHostMaintenance: MIGRATE
    preemptible: false
    provisioningModel: STANDARD
```

### 1.2 Inspecionar uma VM em execução

Comando executado:

```bash
gcloud compute instances describe ace-mig-vm-p19v \\
  --zone=us-central1-a \\
  --format="yaml(name,scheduling,machineType,status)"
```

A VM estava `RUNNING` e apresentava as mesmas opções de agendamento do template:

- `automaticRestart: true`
- `onHostMaintenance: MIGRATE`
- `preemptible: false`
- `provisioningModel: STANDARD`

### 1.3 Significado das propriedades

| Propriedade | Significado |
|---|---|
| `automaticRestart` | Permite que o Compute Engine reinicie automaticamente a VM após determinados encerramentos inesperados, quando aplicável. |
| `onHostMaintenance` | Define o comportamento da VM durante eventos de manutenção do host físico. |
| `preemptible` | Indica se a VM utiliza o modelo de instância preemptível legado. |
| `provisioningModel` | Define o modelo de provisionamento, por exemplo `STANDARD` ou `SPOT`. |

**MIGRATE:** o Compute Engine tenta migrar a VM para outro host físico durante uma manutenção compatível, buscando manter a execução.

**TERMINATE:** a VM é encerrada durante a manutenção do host. A possibilidade de reinicialização automática depende também da configuração `automaticRestart` e do tipo de evento.

Live Migration e Automatic Restart são mecanismos diferentes: a migração busca manter a VM em execução durante a manutenção do host; a reinicialização automática trata determinados encerramentos inesperados.

Observação do laboratório: a família E2 utiliza `MIGRATE` como comportamento padrão e não permite alterar livremente essa política como algumas outras famílias de máquinas.

## Parte 2 — Metadata Server e eventos de manutenção

### 2.1 Inspecionar metadados da VM

Comando executado localmente:

```bash
gcloud compute instances describe ace-mig-vm-p19v \\
  --zone=us-central1-a \\
  --format="yaml(metadata.items,scheduling)"
```

Foram observados metadados como:

- `instance-template`: referência ao template usado pela VM.
- `created-by`: referência ao Managed Instance Group que criou a VM.
- `enable-oslogin`: indica que OS Login está habilitado.

### 2.2 Consultar o evento de manutenção

A primeira tentativa foi executada no WSL local e falhou porque `metadata.google.internal` só é resolvido dentro de uma VM do Compute Engine.

A consulta correta foi executada dentro da VM por meio de uma sessão SSH via IAP:

```bash
curl -H "Metadata-Flavor: Google" \\
  "http://metadata.google.internal/computeMetadata/v1/instance/maintenance-event"
```

Resultado observado:

```text
NONE
```

Isso indicou que não havia evento de manutenção ativo/anunciado para a instância no momento da consulta.

**Conceito:** o Metadata Server disponibiliza informações da instância e pode ser consultado por aplicações executadas dentro da VM. O endpoint de evento de manutenção permite que uma aplicação verifique o estado de manutenção e se prepare para eventos quando aplicável.

## Parte 3 — Sole-Tenant Nodes

### 3.1 Conceito

Sole-Tenant Nodes permitem executar VMs em hardware físico dedicado a um único cliente, em vez de compartilhar o host físico com VMs de outros clientes.

Possíveis cenários de uso:

- Requisitos de isolamento físico e conformidade.
- Licenciamento de software associado a hardware, núcleos ou processadores.
- Necessidade de controle sobre a alocação física das VMs.

Esse modelo pode gerar custos significativamente maiores do que VMs convencionais, pois a capacidade do host dedicado é cobrada mesmo quando não está totalmente utilizada.

### 3.2 Componentes

| Componente | Responsabilidade |
|---|---|
| Node Type | Tipo de hardware físico disponível em uma zona. |
| Node Template | Define as características do nó dedicado, como tipo de nó e região. |
| Node Group | Agrupa os nós dedicados em uma zona e define parâmetros de manutenção e capacidade. |
| VM | Instância executada em um nó dedicado. |

Fluxo conceitual:

```text
Node Type
   |
   v
Node Template
   |
   v
Node Group
   |
   v
Sole-Tenant Node
   |
   v
VM Instances
```

### 3.3 Listar tipos de nós disponíveis

Comando executado:

```bash
gcloud compute sole-tenancy node-types list \\
  --filter="zone:(us-central1-a)"
```

A listagem retornou tipos de nós disponíveis na zona `us-central1-a`, incluindo famílias como `c2`, `c3`, `c4`, `n1`, `n2`, `n2d`, `m1`, `m2`, `m3`, `m4`, `a2` e outras.

Exemplo observado:

```text
NAME              ZONE           CPUs  MEMORY_MB  MAX_VMS
c2-node-60-240    us-central1-a  60    245760     15
n2-node-80-640    us-central1-a  80    655360     80
n2-node-128-864   us-central1-a  128   884736     128
```

Os valores representam as características do tipo de nó e o limite máximo de VMs indicado pela listagem.

### 3.4 Verificar templates e grupos existentes

Comando executado:

```bash
gcloud compute sole-tenancy node-templates list
```

Resultado observado:

```text
Listed 0 items.
```

Não havia Node Templates existentes no projeto.

A tentativa inicial de listar Node Groups com `--zones` foi rejeitada pela CLI:

```bash
gcloud compute sole-tenancy node-groups list --zones=us-central1-a
```

A CLI informou que `--zones` não era um argumento reconhecido para esse subcomando. A consulta pode ser feita com filtro regional:

```bash
gcloud compute sole-tenancy node-groups list \\
  --filter="region:(us-central1)"
```

Essa consulta corrigida foi proposta como próximo comando, mas seu resultado não foi registrado neste laboratório.

### 3.5 Consultar opções de criação de Node Group

Comando executado:

```bash
gcloud compute sole-tenancy node-groups create --help
```

A ajuda apresentou opções como:

- `--node-template`
- `--target-size`
- `--maintenance-policy`
- `--maintenance-interval`
- `--maintenance-window-start-time`
- `--autoscaler-mode`
- `--max-nodes`
- `--min-nodes`
- `--share-settings`

Nenhum Node Template ou Node Group foi criado com `gcloud`.

### 3.6 Políticas de manutenção de Node Groups

Foram estudadas e simuladas no Terraform as três políticas:

| Política | Comportamento conceitual |
|---|---|
| `DEFAULT` | Utiliza o comportamento padrão de manutenção do grupo. |
| `MIGRATE_WITHIN_NODE_GROUP` | Permite migrar VMs para outro nó dentro do mesmo Node Group. |
| `RESTART_IN_PLACE` | Reinicia VMs no mesmo nó físico após a manutenção, em vez de migrá-las para outro nó. |

Essas políticas pertencem ao nível do Node Group e não devem ser confundidas com a propriedade `onHostMaintenance` configurada individualmente em uma VM.

Também foram identificados parâmetros de manutenção na ajuda da CLI:

- `--maintenance-interval`: intervalo de manutenção, como `AS_NEEDED` ou `RECURRENT`, conforme suporte da API/CLI.
- `--maintenance-window-start-time`: horário de início da janela de manutenção.
- `--maintenance-policy`: política de manutenção do Node Group.

## Parte 4 — Terraform: simulação sem provisionamento

Foi criada uma configuração Terraform para representar um Node Template e um Node Group, mas **não foi executado `terraform apply`**.

### 4.1 Recursos declarados

- `google_compute_node_template.ace_node_template`
- `google_compute_node_group.ace_node_group`

O Node Group referencia o template por meio de:

```hcl
node_template = google_compute_node_template.ace_node_template.self_link
```

Tipo de nó usado no exemplo:

```hcl
node_type = "c2-node-60-240"
```

Política final mantida no arquivo:

```hcl
maintenance_policy = "DEFAULT"
```

O exemplo usa `initial_size = 1`, representando um nó físico inicial. Essa configuração é apenas declarativa enquanto não houver `terraform apply`.

### 4.2 Simulações de política

Foram testadas as três opções alterando temporariamente o valor de `maintenance_policy` e executando `terraform fmt`, `terraform validate` e `terraform plan`.

Os planos mostraram dois recursos para criação em cada simulação:

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

Valores simulados:

- `DEFAULT`
- `MIGRATE_WITHIN_NODE_GROUP`
- `RESTART_IN_PLACE`

A configuração foi então restaurada para:

```hcl
maintenance_policy = "DEFAULT"
```

Validação final:

```bash
terraform validate
```

Resultado:

```text
Success! The configuration is valid.
```

**Importante:** um `terraform plan` bem-sucedido confirma que o provedor conseguiu construir um plano com a configuração local. Não comprova que os recursos foram criados ou que a configuração foi aceita pelo serviço durante um `apply`.

### 4.3 Configuração Terraform de referência

O Node Template usado no exercício:

```hcl
resource "google_compute_node_template" "ace_node_template" {
  name        = "ace-sole-tenant-template"
  region      = var.region
  node_type   = "c2-node-60-240"
  description = "Template de estudo para Sole-Tenant Nodes"
}
```

O Node Group usado no exercício:

```hcl
resource "google_compute_node_group" "ace_node_group" {
  name          = "ace-sole-tenant-group"
  zone          = var.zone
  node_template = google_compute_node_template.ace_node_template.self_link

  initial_size       = var.node_group_size
  maintenance_policy = "DEFAULT"

  description = "Node Group de estudo para certificação ACE"
}
```

## Conceitos importantes para a certificação ACE

- `onHostMaintenance` controla o comportamento da VM durante manutenção do host.
- `MIGRATE` tenta manter a VM em execução migrando-a para outro host, quando suportado.
- `TERMINATE` encerra a VM durante a manutenção do host.
- `automaticRestart` permite reinicialização automática após determinados encerramentos inesperados.
- Live Migration e Automatic Restart são mecanismos diferentes.
- O Metadata Server é acessível de dentro da VM pelo endereço `metadata.google.internal`.
- O endpoint `instance/maintenance-event` permite consultar o estado de eventos de manutenção.
- Sole-Tenant Nodes oferecem hardware físico dedicado.
- Node Type descreve o tipo de hardware disponível; Node Template define as características do nó; Node Group agrupa os nós.
- As políticas de manutenção de Node Groups são diferentes da configuração `onHostMaintenance` de uma VM.
- Sole-Tenant Nodes podem gerar custos elevados; não devem ser provisionados em laboratório sem avaliar preço, duração e limpeza.

## Cleanup e custos

Nenhum Sole-Tenant Node Template ou Node Group foi criado na nuvem durante este exercício. O Terraform foi usado apenas para `fmt`, `validate` e `plan`.

**Não executar `terraform apply` neste laboratório de simulação.**

Como não houve provisionamento dos recursos Sole-Tenant, não há Node Group ou Node Template deste exercício para destruir.

O Instance Template `ace-instance-template` e o Managed Instance Group do Lab 04.4 são recursos de outro laboratório e não devem ser removidos por comandos executados neste diretório.

## Resultado final

O laboratório concluiu a inspeção das políticas de disponibilidade de uma VM, a consulta ao Metadata Server, o estudo de eventos de manutenção e a análise de Sole-Tenant Nodes.

Também foi construída e validada uma configuração Terraform de referência para Node Template e Node Group, sem provisionar hardware dedicado e sem gerar custos de execução.