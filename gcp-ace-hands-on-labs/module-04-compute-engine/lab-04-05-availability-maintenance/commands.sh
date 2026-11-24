#!/usr/bin/env bash
# Lab 04.5 — Disponibilidade e Manutenção
# Projeto: ace-hands-on-labs-2026
# Região: us-central1
# Zona: us-central1-a
#
# Este script reúne comandos de inspeção e validação utilizados no laboratório.
# Não executa terraform apply e não cria Sole-Tenant Nodes.

set -euo pipefail

PROJECT_ID="ace-hands-on-labs-2026"
REGION="us-central1"
ZONE="us-central1-a"
INSTANCE_TEMPLATE="ace-instance-template"
VM_NAME="ace-mig-vm-p19v"

# ---------------------------------------------------------------------
# 1. Configurar e conferir o contexto do gcloud
# ---------------------------------------------------------------------
gcloud config set project "${PROJECT_ID}"
gcloud config set compute/region "${REGION}"
gcloud config set compute/zone "${ZONE}"
gcloud config list

# ---------------------------------------------------------------------
# 2. Inspecionar políticas de agendamento do Instance Template
# ---------------------------------------------------------------------
gcloud compute instance-templates describe "${INSTANCE_TEMPLATE}" \\
  --format="yaml(name,properties.scheduling,properties.machineType)"

# ---------------------------------------------------------------------
# 3. Inspecionar políticas de agendamento da VM
# ---------------------------------------------------------------------
gcloud compute instances describe "${VM_NAME}" \\
  --zone="${ZONE}" \\
  --format="yaml(name,scheduling,machineType,status)"

# Consultar metadados e scheduling da VM:
gcloud compute instances describe "${VM_NAME}" \\
  --zone="${ZONE}" \\
  --format="yaml(metadata.items,scheduling)"

# ---------------------------------------------------------------------
# 4. Consultar evento de manutenção — executar DENTRO da VM
# ---------------------------------------------------------------------
# Conectar por IAP:
# gcloud compute ssh "${VM_NAME}" --zone="${ZONE}" --tunnel-through-iap
#
# Já dentro da VM, executar:
# curl -H "Metadata-Flavor: Google" \\
#   "http://metadata.google.internal/computeMetadata/v1/instance/maintenance-event"
#
# Resultado observado no laboratório: NONE
# Não execute esse curl no WSL local: metadata.google.internal é
# disponibilizado pelo Metadata Server dentro da VM.

# ---------------------------------------------------------------------
# 5. Consultar tipos de Sole-Tenant Nodes disponíveis
# ---------------------------------------------------------------------
gcloud compute sole-tenancy node-types list \\
  --filter="zone:(${ZONE})"

# ---------------------------------------------------------------------
# 6. Consultar Node Templates existentes
# ---------------------------------------------------------------------
gcloud compute sole-tenancy node-templates list

# ---------------------------------------------------------------------
# 7. Consultar Node Groups existentes
# ---------------------------------------------------------------------
# A opção --zones não foi aceita por esse subcomando.
# Usar filtro regional:
gcloud compute sole-tenancy node-groups list \\
  --filter="region:(${REGION})"

# ---------------------------------------------------------------------
# 8. Consultar opções de criação de Node Group
# ---------------------------------------------------------------------
gcloud compute sole-tenancy node-groups create --help

# ---------------------------------------------------------------------
# 9. Validar configuração Terraform local — sem provisionar
# ---------------------------------------------------------------------
terraform init
terraform fmt -recursive
terraform validate
terraform plan

# IMPORTANTE:
# Não executar terraform apply neste laboratório.
# O plano representa um Node Template e um Node Group de Sole-Tenant,
# que podem gerar custos elevados se forem provisionados.

# ---------------------------------------------------------------------
# 10. Não destruir recursos de outros laboratórios
# ---------------------------------------------------------------------
# Este diretório não criou recursos na nuvem.
# O Instance Template ace-instance-template e o MIG do Lab 04.4
# pertencem ao laboratório anterior e não devem ser removidos daqui.