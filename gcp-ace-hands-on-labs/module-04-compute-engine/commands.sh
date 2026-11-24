#!/usr/bin/env bash
#
# Lab 04.1 — VM Instances
# Comandos de referência usados durante o laboratório.
#
# ATENÇÃO:
# - Este arquivo é um registro didático, não um script para executar
#   integralmente de uma só vez.
# - Os comandos estão organizados por etapa.
# - O bloco de criação do Cloud NAT é histórico e está comentado:
#   o NAT e o Cloud Router já foram removidos.
# - O terraform destroy, no final, é destrutivo e remove a VM e o firewall.
#

set -euo pipefail

PROJECT_ID="ace-hands-on-labs-2026"
REGION="us-central1"
ZONE="us-central1-a"
VM_NAME="ace-vm-instance"
FIREWALL_NAME="ace-vm-allow-iap-ssh"

# -------------------------------------------------------------------
# 1. Terraform — inicialização, validação e criação inicial
# Executar no diretório lab-04-01-vm-instances.
# -------------------------------------------------------------------

# terraform init
# terraform fmt
# terraform validate
# terraform plan
# terraform apply

# -------------------------------------------------------------------
# 2. Inspeção da VM, disco e firewall
# -------------------------------------------------------------------

gcloud compute instances list \
  --project="${PROJECT_ID}"

gcloud compute instances describe "${VM_NAME}" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}"

gcloud compute instances describe "${VM_NAME}" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}" \
  --format="get(networkInterfaces[0].accessConfigs)"

gcloud compute disks describe "${VM_NAME}" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}" \
  --format="yaml(name,sizeGb,type,status)"

gcloud compute firewall-rules describe "${FIREWALL_NAME}" \
  --project="${PROJECT_ID}"

# -------------------------------------------------------------------
# 3. Conexão SSH via IAP
# -------------------------------------------------------------------

# gcloud compute ssh "${VM_NAME}" \
#   --zone="${ZONE}" \
#   --project="${PROJECT_ID}" \
#   --tunnel-through-iap

# Executar dentro da VM:
# hostname
# ip addr
# cat /etc/os-release
# df -h
# ip route
# getent hosts google.com
# lscpu
# free -h

# Testes de conectividade realizados antes do NAT:
# curl -4 -I --connect-timeout 5 https://www.google.com
# curl -6 -I --connect-timeout 5 https://www.google.com
# curl -s -H "Metadata-Flavor: Google" \
#   http://metadata.google.internal/computeMetadata/v1/instance/name
# getent ahosts google.com

# -------------------------------------------------------------------
# 4. Inspeção da rota padrão, subnet e Cloud Router
# -------------------------------------------------------------------

gcloud compute routes list \
  --filter="network:default AND destRange=0.0.0.0/0" \
  --project="${PROJECT_ID}"

gcloud compute networks subnets describe default \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  --format="yaml(name,ipCidrRange,privateIpGoogleAccess)"

gcloud compute firewall-rules list \
  --filter="network:default" \
  --project="${PROJECT_ID}"

gcloud compute routers list \
  --regions="${REGION}" \
  --project="${PROJECT_ID}"

# -------------------------------------------------------------------
# 5. Cloud NAT — comandos de validação usados durante o teste
# O NAT foi removido depois do teste.
# -------------------------------------------------------------------

# gcloud compute routers nats list \
#   --router=ace-vm-nat-router \
#   --region="${REGION}" \
#   --project="${PROJECT_ID}"

# gcloud compute routers nats describe ace-vm-nat \
#   --router=ace-vm-nat-router \
#   --region="${REGION}" \
#   --project="${PROJECT_ID}"

# gcloud compute routers get-nat-ip-info ace-vm-nat-router \
#   --region="${REGION}" \
#   --project="${PROJECT_ID}"

# Executado dentro da VM enquanto o NAT estava ativo:
# curl -4 -I --connect-timeout 10 https://www.google.com
# curl -4 https://ifconfig.me
#
# Resultado observado:
# HTTP/2 200
# IP público de saída: 35.202.240.7

# O Cloud Router e o Cloud NAT foram provisionados temporariamente
# por recursos Terraform e depois removidos.
# Os blocos google_compute_router.nat_router e
# google_compute_router_nat.nat não fazem parte da configuração final.

# -------------------------------------------------------------------
# 6. Comparação dos Machine Types E2
# -------------------------------------------------------------------

gcloud compute machine-types list \
  --zones="${ZONE}" \
  --filter="name~'^e2-'"

gcloud compute machine-types describe e2-micro \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}"

gcloud compute machine-types describe e2-small \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}"

gcloud compute machine-types describe e2-medium \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}"

gcloud compute machine-types describe e2-standard-2 \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}"

# -------------------------------------------------------------------
# 7. Redimensionamento de e2-micro para e2-small
# A variável machine_type foi alterada em variables.tf para e2-small.
# -------------------------------------------------------------------

# terraform fmt
# terraform validate
# terraform plan

# A VM foi parada antes da alteração:
# gcloud compute instances stop "${VM_NAME}" \
#   --zone="${ZONE}" \
#   --project="${PROJECT_ID}"

# Conferir status:
# gcloud compute instances describe "${VM_NAME}" \
#   --zone="${ZONE}" \
#   --project="${PROJECT_ID}" \
#   --format="get(status)"

# Aplicar o redimensionamento:
# terraform apply

# Iniciar novamente:
# gcloud compute instances start "${VM_NAME}" \
#   --zone="${ZONE}" \
#   --project="${PROJECT_ID}"

# Reconectar via IAP:
# gcloud compute ssh "${VM_NAME}" \
#   --zone="${ZONE}" \
#   --project="${PROJECT_ID}" \
#   --tunnel-through-iap

# Validar no Linux:
# free -h
# lscpu

# -------------------------------------------------------------------
# 8. Validação final
# -------------------------------------------------------------------

gcloud compute instances describe "${VM_NAME}" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}" \
  --format="yaml(name,machineType,status,disks)"

gcloud compute disks describe "${VM_NAME}" \
  --zone="${ZONE}" \
  --project="${PROJECT_ID}" \
  --format="yaml(name,sizeGb,type,status)"

# Resultado final observado:
# Machine Type: e2-small
# Status: RUNNING
# Disco: 10 GB
# Tipo do disco: pd-balanced
# Estado do disco: READY
# IP interno: 10.128.0.2
# IP externo: nenhum

# -------------------------------------------------------------------
# 9. LIMPEZA FINAL — EXECUTAR SOMENTE QUANDO ENCERRAR O LAB
# -------------------------------------------------------------------
#
# Atenção: terraform destroy remove os recursos gerenciados por esta
# configuração (VM e firewall). Confirme o plano antes de aprovar.
#
# terraform plan
# terraform destroy
#
# Verificações após a limpeza:
# gcloud compute instances list --project="${PROJECT_ID}"
# gcloud compute firewall-rules list \
#   --filter="name=${FIREWALL_NAME}" \
#   --project="${PROJECT_ID}"
#
# -------------------------------------------------------------------
# 10. Git — quando a documentação e a limpeza estiverem concluídas
# -------------------------------------------------------------------
#
# git status
# git add .
# git commit -m "docs: complete lab 04.1 vm instances"
# git push -u origin feature/module-04-01-vm-instances
#
# Depois, abrir PR e fazer merge para main.