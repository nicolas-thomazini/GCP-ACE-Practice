#
# Recursos criados:
#   VPC:    ace-shared-vpc (Custom Mode)
#   Subnet: ace-shared-subnet
#   CIDR:   10.60.0.0/24

terraform fmt
terraform init
terraform validate
terraform plan
terraform apply

# ---------------------------------------------------------------------------
# 7. Conceder permissão de uso da subnet compartilhada
# ---------------------------------------------------------------------------

gcloud compute networks subnets add-iam-policy-binding ace-shared-subnet \
  --region="${REGION}" \
  --project="${HOST_PROJECT_ID}" \
  --member="user:${LAB_USER}" \
  --role="roles/compute.networkUser"

# Conferir a política IAM da subnet:

gcloud compute networks subnets get-iam-policy ace-shared-subnet \
  --region="${REGION}" \
  --project="${HOST_PROJECT_ID}"

# ---------------------------------------------------------------------------
# 8. Terraform — criar VM no Service Project usando subnet do Host
# ---------------------------------------------------------------------------
# No main.tf foi adicionado um provider Google com alias "service":
#
# provider "google" {
#   alias   = "service"
#   project = var.service_project_id
#   region  = var.region
# }
#
# A VM usa:
#   provider     = google.service
#   name         = ace-shared-vpc-service-vm
#   machine_type = e2-micro
#   zone         = us-central1-a
#
# A interface de rede referencia a subnet do Host:
#   subnetwork = google_compute_subnetwork.shared_subnet.id
#
# Validar e aplicar a alteração:

terraform init
terraform fmt
terraform validate
terraform plan
terraform apply

# ---------------------------------------------------------------------------
# 9. Validar a VM no Service Project e a subnet no Host Project
# ---------------------------------------------------------------------------

gcloud compute instances list \
  --project="${SERVICE_PROJECT_ID}"

gcloud compute instances describe ace-shared-vpc-service-vm \
  --zone="${ZONE}" \
  --project="${SERVICE_PROJECT_ID}" \
  --format="yaml(name,networkInterfaces)"

gcloud compute networks subnets describe ace-shared-subnet \
  --region="${REGION}" \
  --project="${HOST_PROJECT_ID}" \
  --format="yaml(name,network,ipCidrRange)"

# Resultado observado no laboratório:
#   VM: ace-shared-vpc-service-vm
#   Projeto da VM: ace-shared-vpc-service-2026
#   IP interno: 10.60.0.2
#   VPC: ace-shared-vpc (Host Project)
#   Subnet: ace-shared-subnet (Host Project)
#   CIDR: 10.60.0.0/24
#   IP externo: nenhum

# ---------------------------------------------------------------------------
# 10. Limpeza — executar somente quando quiser encerrar o laboratório
# ---------------------------------------------------------------------------
# IMPORTANTE:
# - Confirme que não há outros recursos usando a VPC/subnet.
# - O terraform destroy remove a VM, a subnet e a VPC gerenciadas pelo state.
# - A associação Shared VPC e os papéis IAM criados via gcloud não são
#   removidos automaticamente pelo Terraform.
# - Não exclua os projetos nem altere o Billing sem verificar dependências.

terraform destroy

gcloud compute shared-vpc associated-projects remove \
  "${SERVICE_PROJECT_ID}" \
  --host-project="${HOST_PROJECT_ID}"

gcloud compute shared-vpc disable "${HOST_PROJECT_ID}"

# Verificação final da associação:
gcloud compute shared-vpc get-host-project "${SERVICE_PROJECT_ID}"

# Observação:
# A concessão roles/compute.xpnAdmin na organização e
# roles/compute.networkUser na subnet foi criada via gcloud.
# Se desejar removê-las, confirme primeiro que não são necessárias
# para outros projetos/laboratórios. Os comandos de remoção são:
#
# gcloud organizations remove-iam-policy-binding "${ORG_ID}" \
#   --member="user:${LAB_USER}" \
#   --role="roles/compute.xpnAdmin"
#
# gcloud compute networks subnets remove-iam-policy-binding ace-shared-subnet \
#   --region="${REGION}" \
#   --project="${HOST_PROJECT_ID}" \
#   --member="user:${LAB_USER}" \
#   --role="roles/compute.networkUser"
