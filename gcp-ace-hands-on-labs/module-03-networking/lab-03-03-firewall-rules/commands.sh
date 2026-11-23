#!/usr/bin/env bash
#
# Lab 03.3 — Firewall Rules
# Registro dos principais comandos usados durante o laboratório.
#
# ATENÇÃO:
# Este arquivo é um roteiro/histórico, não execute tudo de uma vez.
# Há comandos interativos (SSH, Terraform apply e destroy).
#

# 1. Configuração e autenticação
gcloud config get-value account
gcloud config set project ace-hands-on-labs-2026
gcloud auth application-default login
gcloud services enable iap.googleapis.com

# A conta ativa observada no laboratório foi:
gcloud projects add-iam-policy-binding ace-hands-on-labs-2026 \
  --member="user:mirellathomazini@gmail.com" \
  --role="roles/iap.tunnelResourceAccessor"

# 2. Terraform — formatação, validação, plano e aplicação
terraform fmt
terraform validate
terraform plan

# Primeiro apply: duas VMs e regras iniciais
terraform apply

# Apply posterior: INGRESS DENY TCP 8080
terraform plan
terraform apply

# Apply posterior: INGRESS ALLOW 9090, EGRESS DENY 9090
terraform fmt
terraform validate
terraform plan
terraform apply

# 3. Inspeção de infraestrutura
gcloud compute instances list \
  --filter="name~'ace-firewall'" \
  --format="table(name,status,zone,networkInterfaces[0].networkIP,networkInterfaces[0].accessConfigs[0].natIP)"

gcloud compute firewall-rules list \
  --filter="network:ace-vpc-custom" \
  --format="table(name,direction,priority,disabled)"

# 4. SSH via IAP
gcloud compute ssh ace-firewall-client \
  --zone=us-central1-a \
  --tunnel-through-iap

gcloud compute ssh ace-firewall-vm \
  --zone=us-central1-a \
  --tunnel-through-iap

# Na primeira conexão, o gcloud criou:
# ~/.ssh/google_compute_engine
# ~/.ssh/google_compute_engine.pub

# 5. Comandos executados dentro das VMs

# Na VM cliente: INGRESS ALLOW TCP 8080
curl http://10.10.0.3:8080

# Na VM servidora: verificar Python e o listener 8080
python3 --version
sudo ss -lntp | grep 8080
sudo cat /var/log/firewall-server.log

# Na VM servidora: iniciar servidor HTTP temporário na porta 9090
nohup python3 -m http.server 9090 --bind 0.0.0.0 \
  > /tmp/http-9090.log 2>&1 &

sudo ss -lntp | grep 9090

# Na VM cliente: tentativa na porta 9090 antes da regra ALLOW 9090
curl --connect-timeout 5 http://10.10.0.3:9090

# Na VM cliente: tentativa na porta 8080 depois do INGRESS DENY
curl --connect-timeout 5 http://10.10.0.3:8080

# Na VM cliente: tentativa na porta 9090 depois do EGRESS DENY
curl --connect-timeout 5 http://10.10.0.3:9090

# Sair de uma sessão SSH
exit

# 6. Limpeza — executar quando o laboratório terminar
terraform plan -destroy
terraform destroy

# Observações:
# - VPC e subnet são data sources e não serão destruídas.
# - API IAP, binding IAM e chave SSH em metadados do projeto
#   precisam ser revisados separadamente se não forem mais necessários.