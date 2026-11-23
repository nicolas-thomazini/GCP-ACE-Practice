# Lab 03.3 — Firewall Rules (Google Cloud + Terraform)

## Objetivo

Praticar regras de firewall de VPC no Google Cloud usando Terraform e duas VMs privadas.

Conteúdos:
- INGRESS e EGRESS.
- ALLOW e DENY.
- Prioridade das regras.
- Network tags.
- SSH privado por IAP.
- Testes TCP entre instâncias.
- Firewall stateful e regras implícitas.

## Ambiente

| Item | Valor |
|---|---|
| Projeto | `ace-hands-on-labs-2026` |
| Região / zona | `us-central1` / `us-central1-a` |
| VPC existente | `ace-vpc-custom` |
| Subnet existente | `ace-subnet-us-central1` |
| CIDR | `10.10.0.0/23` |
| Imagem | Debian 12 |
| Tipo de máquina | `e2-micro` |
| Disco | 10 GB `pd-standard` |

A VPC e a subnet foram criadas em laboratórios anteriores. Neste laboratório, o Terraform as consulta usando `data` sources; não as cria.

## Arquitetura

Duas VMs foram criadas sem IP externo:

| VM | IP interno observado | Tags |
|---|---|---|
| `ace-firewall-client` | `10.10.0.2` | `iap-ssh`, `firewall-client` |
| `ace-firewall-vm` | `10.10.0.3` | `web-server`, `iap-ssh` |

Os endereços são os observados nesta execução e podem mudar em uma nova implantação.

A VM servidora executa Python HTTP na porta 8080. Um segundo servidor foi iniciado manualmente na porta 9090 para os testes.

## Recursos Terraform

### Data sources
- `data.google_compute_network.existing_vpc`
- `data.google_compute_subnetwork.existing_subnet`

### Compute Engine
- `google_compute_instance.firewall_vm`: servidor `ace-firewall-vm`.
- `google_compute_instance.client_vm`: cliente `ace-firewall-client`.

As VMs não possuem `access_config`, portanto não recebem IP externo IPv4.

O startup script da VM servidora cria `/var/www/html/index.html` e executa:

```bash
python3 -m http.server 8080 --directory /var/www/html --bind 0.0.0.0
```

A imagem Debian 12 já tinha Python 3.11.2 disponível durante o laboratório.

### Regras de firewall

| Nome | Direção | Prioridade | Ação | Escopo |
|---|---|---:|---|---|
| `ace-allow-http-8080` | INGRESS | 1000 | ALLOW TCP 8080 | Origem `10.10.0.0/23`, tag `web-server` |
| `ace-allow-iap-ssh` | INGRESS | 1000 | ALLOW TCP 22 | Origem `35.235.240.0/20`, tag `iap-ssh` |
| `ace-deny-http-8080` | INGRESS | 900 | DENY TCP 8080 | Origem `10.10.0.0/23`, tag `web-server` |
| `ace-allow-http-9090` | INGRESS | 1000 | ALLOW TCP 9090 | Origem `10.10.0.0/23`, tag `web-server` |
| `ace-deny-egress-9090` | EGRESS | 900 | DENY TCP 9090 | Destino `10.10.0.0/23`, tag `firewall-client` |

As regras foram adicionadas em etapas. A regra DENY 8080 foi criada após o primeiro teste bem-sucedido e passou a prevalecer sobre a ALLOW 8080 por ter prioridade numérica menor.

## Conceitos importantes

### INGRESS e EGRESS
- `INGRESS`: controla tráfego que entra nas VMs selecionadas.
- `EGRESS`: controla tráfego que sai das VMs selecionadas.
- Em INGRESS, `source_ranges` define as origens.
- Em EGRESS, `destination_ranges` define os destinos.

### ALLOW e DENY
Cada regra representa uma ação `ALLOW` ou `DENY`, além de direção, prioridade, protocolo, portas e critérios de seleção. No Terraform, a ação é declarada em um bloco `allow` ou `deny`.

### Prioridade
Números menores representam maior prioridade. Quando regras aplicáveis entram em conflito, a regra de prioridade mais alta (menor número) prevalece. Assim, DENY 900 prevaleceu sobre ALLOW 1000 nos testes.

### Network tags
- `web-server`: seleciona a VM servidora.
- `iap-ssh`: seleciona VMs que aceitam SSH via IAP.
- `firewall-client`: seleciona especificamente a VM cliente para o teste EGRESS.

### Firewall stateful
O firewall de VPC é stateful. Quando uma conexão é permitida, o tráfego de resposta correspondente é permitido automaticamente.

### Regras implícitas
As VPCs possuem regras implícitas:
- `INGRESS DENY ALL`, prioridade `65535`.
- `EGRESS ALLOW ALL`, prioridade `65535`.

Elas não aparecem na listagem comum de regras explícitas.

## Execução e testes

### Preparação
A API IAP foi habilitada. A autenticação ADC foi configurada para o provider Terraform. A conta ativa no `gcloud` recebeu `roles/iap.tunnelResourceAccessor` no projeto.

### Provisionamento
Foram utilizados:

```bash
terraform fmt
terraform validate
terraform plan
terraform apply
```

Primeiro apply:

```text
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

Foram criadas duas VMs e as regras iniciais de HTTP 8080 e SSH via IAP.

### SSH via IAP
O acesso às VMs foi feito sem IP público:

```bash
gcloud compute ssh ace-firewall-client --zone=us-central1-a --tunnel-through-iap
gcloud compute ssh ace-firewall-vm --zone=us-central1-a --tunnel-through-iap
```

Na primeira conexão, o `gcloud` gerou `~/.ssh/google_compute_engine` e `~/.ssh/google_compute_engine.pub`, publicando a chave pública nos metadados SSH do projeto.

### INGRESS ALLOW TCP 8080
Na VM cliente:

```bash
curl http://10.10.0.3:8080
```

Resposta observada:

```text
Hello from GCP Firewall Lab!
```

O log da VM servidora registrou `GET / HTTP/1.1` com status `200`.

### Porta 9090 antes das regras específicas
Na VM servidora, foi iniciado um segundo servidor:

```bash
nohup python3 -m http.server 9090 --bind 0.0.0.0 > /tmp/http-9090.log 2>&1 &
sudo ss -lntp | grep 9090
```

A tentativa da VM cliente para a porta 9090 expirou. Naquele momento, não havia regra INGRESS explícita permitindo TCP 9090, então o tráfego era bloqueado pela regra implícita INGRESS DENY ALL.

### INGRESS DENY TCP 8080
Foi criada `ace-deny-http-8080` com prioridade 900, enquanto `ace-allow-http-8080` tinha prioridade 1000. Depois do apply, o acesso à porta 8080 expirou, demonstrando a precedência da regra DENY aplicável.

### EGRESS DENY TCP 9090
Foi criada uma regra INGRESS ALLOW TCP 9090 para a VM servidora e uma regra EGRESS DENY TCP 9090 com prioridade 900, direcionada à tag `firewall-client`.

A tentativa a partir da VM cliente:

```bash
curl --connect-timeout 5 http://10.10.0.3:9090
```

expirou, embora o servidor estivesse escutando na porta 9090. A regra EGRESS bloqueou a tentativa de conexão originada pela VM cliente.

## Comandos úteis de inspeção

Listar as VMs:

```bash
gcloud compute instances list \\
  --filter="name~'ace-firewall'" \\
  --format="table(name,status,zone,networkInterfaces[0].networkIP,networkInterfaces[0].accessConfigs[0].natIP)"
```

Listar regras explícitas:

```bash
gcloud compute firewall-rules list \\
  --filter="network:ace-vpc-custom" \\
  --format="table(name,direction,priority,disabled)"
```

Verificar listeners na VM servidora:

```bash
sudo ss -lntp | grep -E '8080|9090'
```

Consultar o log do servidor principal:

```bash
sudo cat /var/log/firewall-server.log
```

## Limpeza

Ao terminar os testes, remover os recursos gerenciados por este diretório Terraform:

```bash
terraform plan -destroy
terraform destroy
```

Revise o plano e confirme com `yes`.

O `terraform destroy` remove as VMs e regras de firewall gerenciadas pelo estado deste laboratório. A VPC e a subnet existentes são `data sources` e não serão destruídas.

A API IAP habilitada, a associação IAM concedida à conta e a chave pública SSH adicionada aos metadados do projeto não são gerenciadas por esta configuração Terraform. Revise e remova essas configurações separadamente se não forem mais necessárias.

## Checklist

- [x] Consultar VPC e subnet existentes com Terraform data sources.
- [x] Criar VMs privadas sem IP externo.
- [x] Criar regras INGRESS ALLOW e INGRESS DENY.
- [x] Criar regra EGRESS DENY.
- [x] Entender prioridades.
- [x] Aplicar regras por network tags.
- [x] Acessar VMs privadas por SSH via IAP.
- [x] Testar conectividade TCP entre VMs.
- [x] Entender firewall stateful e regras implícitas.
- [ ] Executar `terraform destroy` após a documentação e os testes.
"""

commands = r'''#!/usr/bin/env bash
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
'''

out = Path("/mnt/data")
readme_path = out / "README-lab-03-03-firewall-rules.md"
commands_path = out / "commands-lab-03-03-firewall-rules.sh"
readme_path.write_text(readme, encoding="utf-8")
commands_path.write_text(commands, encoding="utf-8")
commands_path.chmod(0o755)

print("Arquivos criados:")
print(readme_path)
print(commands_path)
