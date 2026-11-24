# Lab 04.4 — Managed Instance Groups (MIGs)

## Objetivo

Criar um Managed Instance Group (MIG) zonal utilizando o Instance Template criado no Lab 04.3, configurar o autoscaling baseado na utilização de CPU e validar, na prática, o scale-out e o scale-in.

## Ambiente

| Configuração | Valor |
|---|---|
| Projeto GCP | `ace-hands-on-labs-2026` |
| Região | `us-central1` |
| Zona | `us-central1-a` |
| Instance Template | `ace-instance-template` |
| Managed Instance Group | `ace-managed-instance-group` |
| Autoscaler | `ace-mig-autoscaler` |
| Mínimo de instâncias | `2` |
| Máximo de instâncias | `4` |
| Meta de utilização de CPU | `60%` |
| Cooldown | `60 segundos` |

## Arquitetura

O MIG é zonal e está localizado em `us-central1-a`. Ele cria as instâncias a partir do template existente `ace-instance-template`.

O autoscaler monitora a utilização média de CPU do grupo:
- Quando a demanda aumenta, pode adicionar instâncias até o limite máximo de 4.
- Quando a demanda diminui, pode remover instâncias até o limite mínimo de 2.

As VMs não possuem IP externo. O acesso administrativo foi realizado por meio do Identity-Aware Proxy (IAP).

## Recursos Terraform

Este laboratório gerencia os seguintes recursos:

- `google_compute_instance_group_manager.ace_mig`
- `google_compute_autoscaler.ace_autoscaler`
- `google_compute_firewall.ace_iap_ssh`

O Instance Template é consultado por meio de um data source:

- `data.google_compute_instance_template.ace_template`

Portanto, o template não é criado nem gerenciado pelo estado Terraform deste laboratório. Ele pertence ao Lab 04.3 e deve ser preservado.

A regra de firewall `ace-mig-allow-iap-ssh` permite conexões TCP na porta 22 provenientes do intervalo utilizado pelo IAP TCP forwarding (`35.235.240.0/20`) para instâncias com a tag `ace-template`.

## Configuração do Autoscaler

```hcl
resource "google_compute_autoscaler" "ace_autoscaler" {
  name   = "ace-mig-autoscaler"
  zone   = var.zone
  target = google_compute_instance_group_manager.ace_mig.id

  autoscaling_policy {
    min_replicas     = 2
    max_replicas     = 4
    cooldown_period  = 60

    cpu_utilization {
      target = 0.60
    }
  }
}
```

## Execução e validação

### 1. Verificar o MIG

```bash
gcloud compute instance-groups managed list --zones=us-central1-a
```

Consultar os detalhes do grupo:

```bash
gcloud compute instance-groups managed describe ace-managed-instance-group \\
  --zone=us-central1-a
```

Consultar o tamanho, o autoscaler e o estado:

```bash
gcloud compute instance-groups managed describe ace-managed-instance-group \\
  --zone=us-central1-a \\
  --format="yaml(targetSize,autoscaler,status)"
```

### 2. Acessar as VMs pelo IAP

```bash
gcloud compute ssh ace-mig-vm-lmlt \\
  --zone=us-central1-a \\
  --tunnel-through-iap
```

Em outro terminal, acessar a segunda VM:

```bash
gcloud compute ssh ace-mig-vm-p19v \\
  --zone=us-central1-a \\
  --tunnel-through-iap
```

### 3. Gerar carga de CPU

As VMs não possuem IP externo e o laboratório não provisionou Cloud NAT. Por isso, o comando `apt-get update` não conseguiu acessar os repositórios públicos. O IAP permite o acesso administrativo à VM, mas não fornece conectividade de saída para a internet.

Para gerar carga sem instalar pacotes, utilizamos o comando `yes`, disponível no sistema.

Em cada uma das duas VMs iniciais:

```bash
nproc
yes > /dev/null &
echo $!
yes > /dev/null &
echo $!
```

O comando `nproc` retornou `2`, indicando duas CPUs disponíveis por VM. Os comandos `yes` geraram carga de CPU; os PIDs retornados foram anotados para encerrar os processos posteriormente.

### 4. Monitorar o scale-out

Em um terminal local do WSL:

```bash
watch -n 15 'gcloud compute instances list --filter="name~'\\''ace-mig-vm'\\''"'
```

Em outro terminal:

```bash
watch -n 15 'gcloud compute instance-groups managed describe ace-managed-instance-group --zone=us-central1-a --format="yaml(targetSize,autoscaler)"'
```

**Resultado observado:** o grupo aumentou de 2 para 4 instâncias, demonstrando o scale-out automático.

### 5. Encerrar a carga e monitorar o scale-in

Nas respectivas VMs, os processos foram encerrados utilizando os PIDs anotados:

Na VM `ace-mig-vm-lmlt`:

```bash
kill 4412 4413
```

Na VM `ace-mig-vm-p19v`:

```bash
kill 4648 4649
```

Após encerrar a carga, foi necessário aguardar o autoscaler observar a redução da utilização de CPU e tomar a decisão de scale-in. As instâncias não foram excluídas manualmente.

**Resultado observado:** o grupo retornou de 4 para 2 instâncias, respeitando o mínimo configurado.

A validação final foi realizada com:

```bash
gcloud compute instances list --filter="name~'ace-mig-vm'"
```

E:

```bash
gcloud compute instance-groups managed describe ace-managed-instance-group \\
  --zone=us-central1-a \\
  --format="yaml(targetSize,autoscaler,status)"
```

## Conceitos importantes para a certificação ACE

- Um Managed Instance Group mantém um conjunto de VMs semelhantes, criadas a partir de um Instance Template.
- O Autoscaler ajusta a quantidade de instâncias conforme métricas configuradas, como utilização de CPU.
- `minNumReplicas` define a quantidade mínima de instâncias.
- `maxNumReplicas` define a quantidade máxima de instâncias.
- `utilizationTarget` define a meta de utilização média de CPU do grupo.
- Scale-out adiciona instâncias quando a demanda aumenta.
- Scale-in remove instâncias quando a demanda diminui, respeitando os limites configurados.
- O scale-in não é necessariamente imediato: o autoscaler precisa observar as métricas e considerar o período de estabilização.
- `coolDownPeriodSec` está relacionado ao tempo de inicialização das novas instâncias antes de utilizar suas métricas. Não deve ser confundido com o período de estabilização do scale-in.
- IAP TCP forwarding permite acesso administrativo às VMs, mas não fornece acesso de saída à internet.
- VMs sem IP externo normalmente precisam de Cloud NAT ou outra solução de egress para acessar repositórios públicos.

## Limpeza dos recursos (Cleanup)

Após finalizar a documentação e validar o laboratório, remover os recursos criados por este laboratório utilizando Terraform:

```bash
terraform plan -destroy
terraform destroy
```

O Instance Template é utilizado como data source e não pertence ao estado Terraform deste laboratório. Portanto, o `terraform destroy` deste diretório não deve removê-lo.

**Importante:** preservar `ace-instance-template`, pois ele foi criado no Lab 04.3 e poderá ser utilizado em laboratórios posteriores.

Verificar a remoção do MIG e das VMs:

```bash
gcloud compute instance-groups managed list --zones=us-central1-a
gcloud compute instances list --filter="name~'ace-mig-vm'"
```

## Resultado final

Laboratório concluído com sucesso. Foi criado um Managed Instance Group zonal com autoscaling baseado em CPU e foram demonstrados os dois comportamentos:

- **Scale-out:** 2 → 4 instâncias durante o aumento da carga de CPU.
- **Scale-in:** 4 → 2 instâncias após o encerramento da carga.