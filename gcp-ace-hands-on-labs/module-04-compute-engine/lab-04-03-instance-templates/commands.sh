#!/usr/bin/env bash
#
# Lab 04.3 — Compute Engine Instance Templates
# Projeto: ace-hands-on-labs-2026
#
# Observações:
# - Execute os comandos Terraform no diretório do laboratório, no WSL.
# - Os comandos gcloud abaixo foram executados no Cloud Shell.
# - O Cloud Shell pode iniciar com outro projeto ativo; confira o projeto antes de criar recursos.
# - A VM criada pelo gcloud não pertence ao state do Terraform e foi excluída manualmente.
# - O Instance Template foi mantido para reutilização no laboratório de MIGs.
#

# -------------------------------------------------------------------
# 1. Terraform — formatação, inicialização e validação
# -------------------------------------------------------------------

terraform fmt
terraform init
terraform validate
terraform plan

# Criar o Instance Template após revisar o plano:
terraform apply

# Consultar os outputs definidos em outputs.tf:
terraform output

# -------------------------------------------------------------------
# 2. Cloud Shell — selecionar e conferir o projeto
# -------------------------------------------------------------------

gcloud config set project ace-hands-on-labs-2026
gcloud config get-value project

# -------------------------------------------------------------------
# 3. Cloud Shell — listar e inspecionar o Instance Template
# -------------------------------------------------------------------

gcloud compute instance-templates list

gcloud compute instance-templates describe ace-instance-template

# -------------------------------------------------------------------
# 4. Cloud Shell — criar uma VM usando o Instance Template
# -------------------------------------------------------------------

gcloud compute instances create ace-vm-from-template \
  --source-instance-template=ace-instance-template \
  --zone=us-central1-a

# Inspecionar a VM criada:
gcloud compute instances describe ace-vm-from-template \
  --zone=us-central1-a

# -------------------------------------------------------------------
# 5. Cloud Shell — excluir a VM criada para o exercício
# -------------------------------------------------------------------

gcloud compute instances delete ace-vm-from-template \
  --zone=us-central1-a

# -------------------------------------------------------------------
# 6. WSL — validar que o Instance Template permanece sincronizado
# -------------------------------------------------------------------

terraform plan

# Não executar terraform destroy aqui: o template será reutilizado no Lab 04.4.