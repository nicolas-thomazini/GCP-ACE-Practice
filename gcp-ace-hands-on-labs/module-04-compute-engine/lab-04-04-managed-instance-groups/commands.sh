#!/usr/bin/env bash
# Lab 04.4 — Managed Instance Groups (MIGs)
# Projeto: ace-hands-on-labs-2026
# Zona: us-central1-a
#
# Execute os comandos Terraform e gcloud no WSL, dentro do diretório
# deste laboratório. Os comandos marcados como "dentro da VM" devem
# ser executados nas sessões SSH estabelecidas pelo IAP.

set -euo pipefail

PROJECT_ID="ace-hands-on-labs-2026"
ZONE="us-central1-a"
MIG_NAME="ace-managed-instance-group"

# ---------------------------------------------------------------------
# 1. Configurar e verificar o contexto do gcloud
# ---------------------------------------------------------------------
gcloud config set project "${PROJECT_ID}"
gcloud config set compute/zone "${ZONE}"
gcloud config list

# ---------------------------------------------------------------------
# 2. Inicializar, validar e aplicar o Terraform
# ---------------------------------------------------------------------
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply

# ---------------------------------------------------------------------
# 3. Verificar o Managed Instance Group e o Autoscaler
# ---------------------------------------------------------------------
gcloud compute instance-groups managed list --zones="${ZONE}"

gcloud compute instance-groups managed describe "${MIG_NAME}" \\
  --zone="${ZONE}"

gcloud compute instance-groups managed describe "${MIG_NAME}" \\
  --zone="${ZONE}" \\
  --format="yaml(targetSize,autoscaler,status)"

gcloud compute instances list --filter="name~'ace-mig-vm'"

# ---------------------------------------------------------------------
# 4. Conectar às VMs utilizando IAP
# ---------------------------------------------------------------------
gcloud compute ssh ace-mig-vm-lmlt \\
  --zone="${ZONE}" \\
  --tunnel-through-iap

# Dentro da VM ace-mig-vm-lmlt:
# nproc
# yes > /dev/null &
# echo $!
# yes > /dev/null &
# echo $!
# Anote os dois PIDs retornados.

# Em outro terminal local, conectar à segunda VM:
gcloud compute ssh ace-mig-vm-p19v \\
  --zone="${ZONE}" \\
  --tunnel-through-iap

# Dentro da VM ace-mig-vm-p19v:
# yes > /dev/null &
# echo $!
# yes > /dev/null &
# echo $!
# Anote os dois PIDs retornados.

# ---------------------------------------------------------------------
# 5. Monitorar o scale-out em terminais locais
# ---------------------------------------------------------------------
watch -n 15 "gcloud compute instances list --filter=\\"name~'ace-mig-vm'\\""

# Em outro terminal:
# watch -n 15 'gcloud compute instance-groups managed describe ace-managed-instance-group --zone=us-central1-a --format="yaml(targetSize,autoscaler)"'
#
# Resultado observado: aumento de 2 para 4 instâncias.

# ---------------------------------------------------------------------
# 6. Encerrar a carga de CPU dentro das VMs
# ---------------------------------------------------------------------
# Na VM ace-mig-vm-lmlt, utilizando os PIDs anotados:
# kill 4412 4413
#
# Na VM ace-mig-vm-p19v, utilizando os PIDs anotados:
# kill 4648 4649
#
# Não exclua as instâncias manualmente. Aguarde o autoscaler.
# Resultado observado: redução de 4 para 2 instâncias.

# ---------------------------------------------------------------------
# 7. Validar o resultado final
# ---------------------------------------------------------------------
gcloud compute instances list --filter="name~'ace-mig-vm'"

gcloud compute instance-groups managed describe "${MIG_NAME}" \\
  --zone="${ZONE}" \\
  --format="yaml(targetSize,autoscaler,status)"

# ---------------------------------------------------------------------
# 8. Cleanup — executar somente após documentar e validar o laboratório
# ---------------------------------------------------------------------
# terraform plan -destroy
# terraform destroy
#
# O Instance Template é um data source neste laboratório e não será
# removido pelo destroy deste estado Terraform. Preserve ace-instance-template.
#
# Verificar a limpeza:
# gcloud compute instance-groups managed list --zones="${ZONE}"
# gcloud compute instances list --filter="name~'ace-mig-vm'"