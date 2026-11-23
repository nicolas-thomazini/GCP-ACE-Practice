# Lab 03.4 — VPC Network Peering
# Projeto: ace-hands-on-labs-2026
# Região: us-central1
# Zona: us-central1-a
#
# Este arquivo reúne os principais comandos de CLI executados no laboratório.
# Os blocos Terraform correspondentes estão documentados no README.md.

set -euo pipefail

PROJECT_ID="ace-hands-on-labs-2026"
REGION="us-central1"
ZONE="us-central1-a"

# ------------------------------------------------------------
# 1. Inspecionar redes e subnets existentes
# ------------------------------------------------------------

gcloud compute networks list

gcloud compute networks subnets list \
  --network=ace-vpc-custom

# ------------------------------------------------------------
# 2. Terraform — inicialização e validação
# ------------------------------------------------------------

terraform init
terraform fmt
terraform validate
terraform plan

# Aplicar a VPC secundária e a subnet
terraform apply

# ------------------------------------------------------------
# 3. Terraform — criar VPC Network Peering bilateral
# ------------------------------------------------------------

terraform fmt
terraform validate
terraform plan

# Aplicar os dois lados do Peering
terraform apply

# ------------------------------------------------------------
# 4. Verificar estado do Peering nos dois lados
# ------------------------------------------------------------

gcloud compute networks peerings list \
  --network=ace-vpc-custom

gcloud compute networks peerings list \
  --network=ace-vpc-peering

# ------------------------------------------------------------
# 5. Verificar rotas de ambas as VPCs
# ------------------------------------------------------------

gcloud compute routes list \
  --filter="network:ace-vpc-custom OR network:ace-vpc-peering" \
  --format="table(name,network.basename(),destRange,nextHopPeering)"

# ------------------------------------------------------------
# 6. Inspecionar regras de firewall existentes
# ------------------------------------------------------------

gcloud compute firewall-rules list \
  --format="table(name,network.basename(),direction,sourceRanges,allowed,denied)"

# ------------------------------------------------------------
# 7. Terraform — criar regras ICMP
# ------------------------------------------------------------

terraform fmt
terraform validate
terraform plan

# Aplicar as regras ICMP
terraform apply

# ------------------------------------------------------------
# 8. Terraform — criar as duas VMs privadas de teste
# ------------------------------------------------------------

terraform fmt
terraform validate
terraform plan

# Aplicar as VMs
terraform apply

# ------------------------------------------------------------
# 9. Consultar IPs internos e confirmar ausência de IP público
# ------------------------------------------------------------

gcloud compute instances list \
  --filter="name~'ace-peering-vm'" \
  --format="table(name,zone,networkInterfaces[0].network.basename(),networkInterfaces[0].networkIP,networkInterfaces[0].accessConfigs[0].natIP)"

# IPs internos observados:
# ace-peering-vm-1: 10.10.0.4
# ace-peering-vm-2: 10.50.0.2

# ------------------------------------------------------------
# 10. Terraform — permitir SSH via IAP nas duas VPCs
# ------------------------------------------------------------

terraform fmt
terraform validate
terraform plan

# Aplicar as regras TCP/22 para IAP
terraform apply

# ------------------------------------------------------------
# 11. Acessar a VM 1 via IAP
# ------------------------------------------------------------

gcloud compute ssh ace-peering-vm-1 \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --tunnel-through-iap

# Já dentro da VM 1, testar a VM 2:
# ping -c 4 10.50.0.2
#
# Resultado observado:
# 4 packets transmitted, 4 received, 0% packet loss
# RTT médio aproximado: 0.581 ms

# Sair da VM 1:
# exit

# ------------------------------------------------------------
# 12. Acessar a VM 2 via IAP e testar o sentido inverso
# ------------------------------------------------------------

gcloud compute ssh ace-peering-vm-2 \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --tunnel-through-iap

# Já dentro da VM 2, testar a VM 1:
# ping -c 4 10.10.0.4
#
# Resultado observado:
# 4 packets transmitted, 4 received, 0% packet loss
# RTT médio aproximado: 0.686 ms

# Sair da VM 2:
# exit

# ------------------------------------------------------------
# 13. Limpeza dos recursos do laboratório
# ------------------------------------------------------------

# Execute no diretório do laboratório, depois de sair das VMs:
terraform destroy

# Confirme com "yes" após revisar o plano.
#
# IMPORTANTE:
# A VPC ace-vpc-custom é uma infraestrutura preexistente consultada
# por data source. Ela não deve ser removida por este laboratório.