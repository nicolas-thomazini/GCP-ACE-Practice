# Google Cloud Associate Cloud Engineer — Guia Prático de Laboratórios

**Trilha Hands-on** · **Preparação ACE** · **Google Cloud + gcloud + Terraform**

Vamos montar uma trilha prática no estilo dos laboratórios oficiais do Google Cloud Skills Boost, mas com uma abordagem um pouco mais completa: **construir, configurar, testar, provocar erros, solucionar problemas e destruir os recursos.**

A ideia é que você não apenas aprenda a criar uma VM ou um cluster GKE, mas consiga entender o funcionamento de cada serviço e executar as operações que podem aparecer na prova Associate Cloud Engineer.

Vamos trabalhar principalmente com:

- Google Cloud Console.
- Google Cloud CLI (`gcloud`).
- `kubectl` para Kubernetes.
- Terraform para Infrastructure as Code.
- APIs, IAM, Service Accounts e permissões.
- Cloud Logging e Cloud Monitoring.

O guia será nosso roteiro principal. Não vamos executar todos os laboratórios simultaneamente: concluiremos um por um, documentando os comandos, resultados esperados, problemas encontrados e os conceitos importantes para a certificação.

---

## 1. Organização da trilha

A trilha será dividida em oito módulos.

### Módulo 00 — Preparação do ambiente

Projeto GCP, billing, APIs, CLI, regiões, zonas, quotas e estrutura de recursos.

### Módulo 01 — IAM e segurança

Usuários, grupos, roles, políticas, Service Accounts, impersonation, permissões mínimas e políticas organizacionais.

### Módulo 02 — Computação serverless

Cloud Run, Cloud Functions, revisões, escalabilidade, eventos, Pub/Sub e Eventarc.

### Módulo 03 — Compute Engine

VMs, discos, snapshots, imagens, SSH, firewall, templates, Managed Instance Groups e autoscaling.

### Módulo 04 — Bancos de dados

Cloud SQL, Spanner, Firestore, Bigtable e comparação entre bancos relacionais e NoSQL.

### Módulo 05 — Networking e Load Balancing

VPC, subnets, firewall, IPs, Cloud NAT, DNS, Load Balancers e Managed Instance Groups.

### Módulo 06 — Google Kubernetes Engine

Autopilot, Standard, Pods, Deployments, Services, Ingress, Node Pools, HPA, VPA, ConfigMaps, Secrets, RBAC e troubleshooting.

### Módulo 07 — Operações e Infrastructure as Code

Cloud Monitoring, Logging, Audit Logs, alertas, Terraform, backup, recuperação e gerenciamento de custos.

Essa estrutura acompanha as áreas avaliadas no exame oficial, incluindo configuração, implantação, operação e segurança.

---

## 2. Preparação do ambiente GCP

Antes dos projetos, precisamos preparar um ambiente organizado para evitar problemas de permissões, cobrança e recursos esquecidos.

### Lab 00.1 — Criar projeto

Vamos criar um projeto exclusivo para os laboratórios.

**Nome sugerido:**

`ace-hands-on-labs`

**Identificador sugerido:**

`ace-hands-on-labs-2026`

O Project ID precisa ser globalmente único. Caso já esteja ocupado, utilizaremos uma variação.

Pelo Console:

1. Acesse o Google Cloud Console.
2. Abra o seletor de projetos.
3. Clique em Novo projeto.
4. Informe nome e organização, se aplicável.
5. Crie o projeto.
6. Vincule uma conta de faturamento.

Pela CLI:

```bash
gcloud auth login

gcloud projects create ace-hands-on-labs-2026

gcloud config set project ace-hands-on-labs-2026

gcloud config list
```

### Lab 00.2 — Configurar região e zona

Vamos trabalhar inicialmente com:

| Configuração | Valor |
|---|---|
| Região | `us-central1` |
| Zona | `us-central1-a` |
| Projeto | `ace-hands-on-labs-2026` |

A região será nossa configuração padrão, mas também vamos praticar recursos regionais e zonais em outras localidades.

```bash
gcloud config set compute/region us-central1

gcloud config set compute/zone us-central1-a
```

### Lab 00.3 — Habilitar APIs

Vamos aprender a habilitar APIs individualmente e verificar quais serviços precisam delas.

```bash
gcloud services enable \
  run.googleapis.com \
  cloudfunctions.googleapis.com \
  compute.googleapis.com \
  container.googleapis.com \
  sqladmin.googleapis.com \
  spanner.googleapis.com \
  firestore.googleapis.com \
  bigtable.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  pubsub.googleapis.com \
  eventarc.googleapis.com
```

Para listar as APIs habilitadas:

```bash
gcloud services list --enabled
```

Para verificar as APIs disponíveis:

```bash
gcloud services list --available
```

### Lab 00.4 — Billing e custos

Vamos configurar:

- Budget e alertas de faturamento.
- Visualização de custos por serviço.
- Cost Breakdown Report.
- Pricing Report.
- Exportação de Billing para BigQuery.
- Análise de consumo por projeto.

**Importante:** um Budget com alertas não representa um limite rígido de gastos. Ele avisa quando determinados patamares são atingidos, mas não impede automaticamente a cobrança.

---

## 3. Módulo 01 — IAM e políticas de segurança

Este módulo será fundamental porque IAM aparece tanto nas questões conceituais quanto nos procedimentos práticos.

### Lab 01.1 — Criar Service Accounts

Criar três contas de serviço:

| Service Account | Finalidade |
|---|---|
| `sa-compute` | Acesso de uma VM |
| `sa-cloudrun` | Execução do Cloud Run |
| `sa-gke` | Operações de workloads no GKE |

Comandos:

```bash
gcloud iam service-accounts create sa-compute \
  --display-name="Compute Service Account"

gcloud iam service-accounts create sa-cloudrun \
  --display-name="Cloud Run Service Account"

gcloud iam service-accounts create sa-gke \
  --display-name="GKE Service Account"
```

Listar:

```bash
gcloud iam service-accounts list
```

### Lab 01.2 — Trabalhar com roles

Vamos experimentar os três tipos de roles:

- Basic roles: Owner, Editor e Viewer.
- Predefined roles: permissões previamente definidas pelo Google.
- Custom roles: permissões personalizadas.

Exercícios:

1. Conceder Viewer a um usuário.
2. Conceder Storage Object Viewer.
3. Conceder Cloud Run Admin.
4. Criar uma custom role.
5. Consultar as permissões de uma role.
6. Remover uma role.
7. Comparar Editor com uma role específica.

Exemplo:

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA_EMAIL" \
  --role="roles/storage.objectViewer"
```

Consultar política:

```bash
gcloud projects get-iam-policy PROJECT_ID
```

Remover binding:

```bash
gcloud projects remove-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA_EMAIL" \
  --role="roles/storage.objectViewer"
```

### Lab 01.3 — Custom IAM Roles

Criar uma role com permissões específicas.

```bash
gcloud iam roles create customStorageReader \
  --project=PROJECT_ID \
  --title="Custom Storage Reader" \
  --description="Leitura personalizada de Storage" \
  --permissions=storage.buckets.get,storage.objects.get \
  --stage=GA
```

Testes:

- Criar uma role.
- Atualizar uma role.
- Listar roles.
- Desabilitar uma role.
- Excluir uma role.
- Identificar permissões que não podem ser adicionadas a custom roles.

### Lab 01.4 — Service Account Impersonation

Aqui vamos entender a diferença entre:

- Ter acesso a uma Service Account.
- Utilizar uma Service Account para acessar recursos.
- Gerar credenciais temporárias.
- Impersonar uma Service Account.

Testar:

```bash
gcloud auth list
```

```bash
gcloud config set auth/impersonate_service_account \
  SA_EMAIL
```

Executar um comando utilizando a identidade impersonada e depois retornar à configuração anterior.

Também vamos estudar:

- `roles/iam.serviceAccountUser`
- `roles/iam.serviceAccountTokenCreator`
- `roles/iam.serviceAccountAdmin`

### Lab 01.5 — IAM Policy e Organization Policies

Exercícios:

1. Consultar políticas IAM de projeto.
2. Consultar políticas de uma Service Account.
3. Identificar herança de permissões.
4. Entender políticas em organização, pasta e projeto.
5. Criar uma política organizacional de teste, caso tenhamos uma organização disponível.
6. Testar restrições de criação de recursos.
7. Diferenciar IAM Policy de Organization Policy.

**Desafio:** criar um ambiente em que uma Service Account possa ler objetos de um bucket, mas não possa excluir ou modificar objetos.

---

## 4. Módulo 02 — Cloud Run e Cloud Functions

**Projeto prático: Hello World**

Vamos criar duas aplicações independentes e depois integrá-las.

### Lab 02.1 — Cloud Run Hello World

Objetivo: criar uma API HTTP simples utilizando Python e Flask.

Estrutura:

```text
cloud-run-hello/
├── app.py
├── requirements.txt
└── Dockerfile
```

`app.py`:

```python
from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/")
def hello():
    return jsonify({
        "message": "Hello from Cloud Run!",
        "service": "cloud-run"
    })

@app.route("/health")
def health():
    return jsonify({"status": "healthy"})
```

`requirements.txt`:

```text
flask
gunicorn
```

`Dockerfile`:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["gunicorn", "--bind", ":8080", "app:app"]
```

Deploy:

```bash
gcloud run deploy hello-cloud-run \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
```

Testes:

- Acessar a URL pública.
- Consultar logs.
- Alterar o código e fazer novo deploy.
- Criar uma nova revisão.
- Dividir tráfego entre duas revisões.
- Configurar mínimo e máximo de instâncias.
- Configurar concorrência.
- Configurar autenticação.
- Testar acesso sem autenticação.
- Consultar métricas.

Exemplo de divisão de tráfego:

```bash
gcloud run services update-traffic hello-cloud-run \
  --to-revisions REVISION_1=50,REVISION_2=50 \
  --region us-central1
```

### Lab 02.2 — Cloud Functions Hello World

Vamos utilizar Python e uma função HTTP.

Arquivo `main.py`:

```python
def hello_http(request):
    return "Hello from Cloud Functions!"
```

Arquivo `requirements.txt`:

```text
functions-framework
```

Deploy:

```bash
gcloud functions deploy hello-function \
  --gen2 \
  --runtime python312 \
  --region us-central1 \
  --source . \
  --entry-point hello_http \
  --trigger-http \
  --allow-unauthenticated
```

Vamos estudar a segunda geração do Cloud Functions, atualmente integrada à experiência do Cloud Run Functions.

Testes:

- Criar função HTTP.
- Consultar URL.
- Consultar logs.
- Atualizar código.
- Configurar variáveis de ambiente.
- Configurar Service Account.
- Configurar permissões de invocação.
- Remover a função.

### Lab 02.3 — Cloud Functions + Pub/Sub

Agora vamos criar uma função acionada por eventos.

Arquitetura:

```text
Publisher
    |
    v
Pub/Sub Topic
    |
    v
Subscription / Eventarc
    |
    v
Cloud Function
    |
    v
Cloud Logging
```

Exercícios:

1. Criar um tópico Pub/Sub.
2. Criar uma função acionada pelo tópico.
3. Publicar uma mensagem.
4. Verificar a execução.
5. Consultar logs.
6. Publicar mensagens inválidas.
7. Testar permissões insuficientes.
8. Excluir os recursos.

### Lab 02.4 — Cloud Storage + Eventarc

Criar um bucket e configurar um evento de criação de objeto.

Objetivo:

```text
Upload de arquivo
       |
       v
Cloud Storage
       |
       v
Eventarc
       |
       v
Cloud Function
       |
       v
Log: arquivo recebido
```

Este laboratório é especialmente interessante porque reúne eventos, IAM, Cloud Storage e serverless.

---

## 5. Módulo 03 — Compute Engine

**Projeto prático: Infraestrutura de VMs**

### Lab 03.1 — Criar uma VM

Criar uma instância Linux.

```bash
gcloud compute instances create vm-ace-01 \
  --zone us-central1-a \
  --machine-type e2-micro \
  --image-family debian-12 \
  --image-project debian-cloud \
  --boot-disk-size 10GB
```

Testes:

- Criar VM.
- Listar instâncias.
- Consultar detalhes.
- Conectar via SSH.
- Parar e iniciar.
- Reiniciar.
- Excluir.
- Criar uma VM em outra zona.

Comandos:

```bash
gcloud compute instances list
```

```bash
gcloud compute instances describe vm-ace-01 \
  --zone us-central1-a
```

```bash
gcloud compute ssh vm-ace-01 \
  --zone us-central1-a
```

### Lab 03.2 — Discos e snapshots

Exercícios:

1. Criar disco persistente adicional.
2. Anexar disco à VM.
3. Formatar e montar disco Linux.
4. Desmontar.
5. Desanexar.
6. Criar snapshot.
7. Criar disco a partir do snapshot.
8. Restaurar dados.
9. Criar imagem personalizada a partir de disco.

Comandos úteis:

```bash
gcloud compute disks create disk-ace \
  --size 20GB \
  --zone us-central1-a
```

```bash
gcloud compute snapshots create snapshot-ace \
  --source-disk vm-ace-01 \
  --source-disk-zone us-central1-a
```

### Lab 03.3 — SSH e OS Login

Testar:

- SSH por meio da CLI.
- Chaves SSH.
- OS Login.
- Metadados da instância.
- Metadados do projeto.
- Permissões de acesso SSH.
- Service Accounts vinculadas à VM.

### Lab 03.4 — Instance Templates e Managed Instance Groups

Objetivo: criar um grupo de VMs que se expande automaticamente.

Atividades:

1. Criar um Instance Template.
2. Criar um Managed Instance Group.
3. Definir quantidade inicial de instâncias.
4. Configurar autoscaling.
5. Configurar health check.
6. Aumentar e reduzir a carga.
7. Observar criação e remoção de VMs.
8. Atualizar o template.
9. Realizar rolling update.

Comandos principais que praticaremos:

```bash
gcloud compute instance-templates create ...
```

```bash
gcloud compute instance-groups managed create ...
```

```bash
gcloud compute instance-groups managed set-autoscaling ...
```

```bash
gcloud compute instance-groups managed list
```

---

## 6. Módulo 04 — Bancos de dados

**Projeto prático: Database Lab**

Vamos construir uma API simples de cadastro de clientes e implementar o armazenamento em diferentes bancos.

### Lab 04.1 — Cloud SQL

Banco relacional gerenciado.

Vamos utilizar PostgreSQL.

Atividades:

1. Criar uma instância Cloud SQL.
2. Escolher região e versão.
3. Configurar usuário e senha.
4. Criar database.
5. Criar tabelas.
6. Executar INSERT, SELECT, UPDATE e DELETE.
7. Conectar pela Cloud SQL Auth Proxy.
8. Configurar backups.
9. Restaurar backup.
10. Testar disponibilidade e conectividade.

Tabela proposta:

```sql
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(150),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Lab 04.2 — Cloud Spanner

Banco relacional distribuído.

Atividades:

- Criar uma instância.
- Criar database.
- Criar schema.
- Criar tabelas.
- Inserir registros.
- Executar consultas SQL.
- Criar índices.
- Testar transações.
- Explorar replicação e configuração regional.
- Comparar custos e escalabilidade com Cloud SQL.

### Lab 04.3 — Firestore

Banco NoSQL orientado a documentos.

Estrutura:

```text
customers/
    customer001/
        name: Nicolas
        email: example@email.com

    customer002/
        name: João
        email: joao@email.com
```

Atividades:

1. Criar database Firestore.
2. Escolher Native Mode.
3. Criar collections.
4. Criar documentos.
5. Consultar documentos.
6. Atualizar campos.
7. Excluir documentos.
8. Criar índices.
9. Testar regras de segurança.
10. Configurar backup e restauração.

### Lab 04.4 — Bigtable

Banco NoSQL orientado a colunas largas (*wide-column*).

Atividades:

- Criar instância.
- Criar cluster.
- Criar tabela.
- Criar column families.
- Inserir registros.
- Consultar por Row Key.
- Alterar valores.
- Excluir registros.
- Explorar replicação entre clusters.
- Entender nós e escalabilidade.

### Comparação que precisamos dominar

| Serviço | Modelo | Principal utilização |
|---|---|---|
| Cloud SQL | Relacional | Aplicações transacionais |
| Spanner | Relacional distribuído | Transações em escala global |
| Firestore | NoSQL documental | Aplicações web e mobile |
| Bigtable | NoSQL wide-column | Grandes volumes de dados e baixa latência |

**Desafio do módulo:** implementar a mesma operação de cadastro e consulta de clientes nos quatro bancos, observando as diferenças de modelagem e acesso.

---

## 7. Módulo 05 — Networking e Cloud Load Balancing

**Projeto prático: Load Balancer**

### Lab 05.1 — VPC e Subnets

Criar uma VPC personalizada:

```bash
gcloud compute networks create ace-vpc \
  --subnet-mode=custom
```

Criar subnet:

```bash
gcloud compute networks subnets create ace-subnet \
  --network=ace-vpc \
  --range=10.10.0.0/24 \
  --region=us-central1
```

Exercícios:

- Criar VPC.
- Criar múltiplas subnets.
- Criar regras de firewall.
- Liberar portas TCP.
- Bloquear tráfego.
- Trabalhar com tags de rede.
- Utilizar Service Accounts em regras de firewall.
- Expandir subnet.
- Consultar rotas.
- Criar IP estático.

### Lab 05.2 — Cloud NAT

Criar um cenário em que uma VM sem IP público consiga acessar a internet por meio do Cloud NAT.

Testes:

- VM com IP público.
- VM sem IP público.
- Cloud NAT.
- Cloud Router.
- Testar saída para internet.
- Verificar comportamento de entrada.

### Lab 05.3 — HTTP Load Balancer

Vamos construir um Load Balancer utilizando um Managed Instance Group como backend.

Arquitetura:

```text
Usuários / Internet
        |
        v
External Application Load Balancer
        |
        v
Backend Service + Health Check
        |
        v
  +-----------+-----------+
  |                       |
  v                       v
 VM 01                   VM 02
 Backend                 Backend
```

Atividades:

1. Criar duas VMs.
2. Instalar um servidor web em cada uma.
3. Criar uma página que identifique a VM.
4. Configurar health checks.
5. Criar backend service.
6. Configurar backend instance group.
7. Criar URL map.
8. Criar target HTTP proxy.
9. Criar forwarding rule.
10. Testar distribuição de requisições.
11. Desligar uma VM e observar o health check.
12. Testar indisponibilidade de backend.

### Lab 05.4 — Outros tipos de Load Balancing

Estudar e comparar:

- External Application Load Balancer.
- Internal Application Load Balancer.
- External Network Load Balancer.
- Internal Network Load Balancer.
- Proxy Network Load Balancer.
- Regional e global load balancing.

O objetivo não é apenas criar o balanceador, mas saber escolher o tipo correto em uma questão de cenário.

---

## 8. Módulo 06 — Google Kubernetes Engine (GKE)

**Módulo mais extenso da trilha.**

Este será nosso laboratório mais completo.

Vamos construir uma aplicação distribuída, publicar imagens no Artifact Registry, implantar no Kubernetes e testar os principais recursos operacionais.

### Lab 06.1 — Preparação do ambiente

Instalar/configurar:

- Google Cloud CLI.
- `kubectl`.
- GKE Auth Plugin.
- Docker.
- Artifact Registry.

```bash
gcloud components install kubectl
```

```bash
gcloud components install gke-gcloud-auth-plugin
```

Verificar:

```bash
kubectl version --client
```

### Lab 06.2 — Criar cluster Autopilot

```bash
gcloud container clusters create-auto ace-autopilot \
  --region us-central1
```

Conectar:

```bash
gcloud container clusters get-credentials ace-autopilot \
  --region us-central1
```

Testes:

```bash
kubectl get nodes
kubectl get namespaces
kubectl get pods --all-namespaces
kubectl cluster-info
```

### Lab 06.3 — Criar cluster Standard

Criar um cluster Standard com configurações de node pool.

Estudar:

- Número inicial de nodes.
- Machine types.
- Discos.
- Node locations.
- Node pools.
- Autoscaling.
- Auto-repair.
- Auto-upgrade.
- Escalabilidade horizontal.

Comparar Autopilot e Standard na prática.

### Lab 06.4 — Deploy de aplicação

Criar uma aplicação simples:

```text
gke-hello-world/
├── app.py
├── requirements.txt
└── Dockerfile
```

Publicar no Artifact Registry.

Criar:

- Deployment.
- Pods.
- ReplicaSets.
- Services.
- ConfigMaps.
- Secrets.

Exemplo de Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-gke
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello-gke
  template:
    metadata:
      labels:
        app: hello-gke
    spec:
      containers:
        - name: hello
          image: IMAGE_URL
          ports:
            - containerPort: 8080
```

Aplicar:

```bash
kubectl apply -f deployment.yaml
```

Consultar:

```bash
kubectl get deployments
kubectl get pods
kubectl get replicasets
```

### Lab 06.5 — Kubernetes Services

Vamos testar:

| Service | Teste |
|---|---|
| ClusterIP | Comunicação interna |
| NodePort | Acesso por porta do node |
| LoadBalancer | Exposição externa |
| Headless Service | Descoberta direta dos Pods |

Exercícios:

- Criar Service.
- Alterar portas.
- Testar conectividade.
- Expor aplicação.
- Consultar endpoints.
- Inspecionar DNS interno.

### Lab 06.6 — ConfigMaps e Secrets

Criar variáveis de ambiente para aplicação.

```bash
kubectl create configmap app-config \
  --from-literal=APP_ENV=development
```

Criar Secret:

```bash
kubectl create secret generic app-secret \
  --from-literal=DB_PASSWORD=example-password
```

Testes:

- Injetar ConfigMap no Pod.
- Injetar Secret como variável de ambiente.
- Montar ConfigMap como volume.
- Atualizar configuração.
- Verificar comportamento dos Pods.

Usaremos senhas fictícias exclusivamente neste laboratório.

### Lab 06.7 — Escalabilidade

Implementar:

- Horizontal Pod Autoscaler (HPA).
- Vertical Pod Autoscaler (VPA).
- Cluster Autoscaler.
- Autoscaling de node pools.

Exemplo:

```bash
kubectl autoscale deployment hello-gke \
  --cpu-percent=60 \
  --min=2 \
  --max=10
```

Testar:

- Aumentar carga.
- Observar quantidade de Pods.
- Observar consumo de CPU.
- Reduzir carga.
- Observar redução de réplicas.

### Lab 06.8 — Storage no GKE

Estudar e executar:

- PersistentVolume (PV).
- PersistentVolumeClaim (PVC).
- StorageClass.
- Persistent Disk.
- StatefulSet.
- Volumes temporários.
- Persistência de dados após reinicialização de Pod.

### Lab 06.9 — Ingress e Load Balancing

Criar um Ingress para expor a aplicação.

Estudar a integração entre GKE, Load Balancing e Gateway API.

Testar:

- Ingress.
- Regras de roteamento.
- Múltiplos serviços.
- Health checks.
- HTTPS.
- Certificados.
- External Load Balancing.

### Lab 06.10 — Segurança no Kubernetes

Este laboratório será dedicado a identidade e controle de acesso.

Exercícios:

1. Criar Service Account Kubernetes.
2. Criar Role.
3. Criar RoleBinding.
4. Criar ClusterRole.
5. Criar ClusterRoleBinding.
6. Testar RBAC.
7. Utilizar Workload Identity Federation for GKE.
8. Atribuir acesso a recursos GCP.
9. Testar permissões insuficientes.
10. Trabalhar com namespaces.

### Lab 06.11 — Troubleshooting

Aqui vamos provocar problemas intencionalmente.

| Problema | O que investigar |
|---|---|
| CrashLoopBackOff | Logs e inicialização |
| ImagePullBackOff | Imagem e permissões |
| Pending | Recursos e scheduling |
| OOMKilled | Memória |
| Pod sem comunicação | Networking |
| Service indisponível | Selector e endpoints |
| Deployment sem réplicas disponíveis | Eventos e readiness |
| Falha de acesso ao Artifact Registry | IAM |

Comandos:

```bash
kubectl describe pod POD_NAME
```

```bash
kubectl logs POD_NAME
```

```bash
kubectl logs POD_NAME --previous
```

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

```bash
kubectl describe deployment hello-gke
```

### Lab 06.12 — Operações avançadas

Outros testes:

- Rolling Update.
- Rollback.
- Liveness Probe.
- Readiness Probe.
- Startup Probe.
- Resource Requests.
- Resource Limits.
- Taints.
- Tolerations.
- Node Affinity.
- Pod Affinity.
- Pod Disruption Budget.
- DaemonSet.
- StatefulSet.
- Jobs.
- CronJobs.
- Network Policies.
- Private Cluster.
- Regional Cluster.
- Upgrade de cluster.
- Upgrade de Node Pool.
- Backup e recuperação.

**Desafio final GKE:** criar uma aplicação com três réplicas, autoscaling, configuração externa, persistência, controle de acesso, exposição por Load Balancer e monitoramento. Depois, simular falhas e recuperar a aplicação.

---

## 9. Módulo 07 — Observabilidade e Infrastructure as Code

### Lab 07.1 — Cloud Logging

Atividades:

- Consultar logs de VMs.
- Consultar logs de Cloud Run.
- Consultar logs de Cloud Functions.
- Consultar logs de GKE.
- Criar filtros.
- Utilizar Logs Explorer.
- Identificar erros HTTP.
- Consultar Audit Logs.
- Criar Log Sinks.

### Lab 07.2 — Cloud Monitoring

Atividades:

1. Criar dashboard.
2. Adicionar métricas de CPU.
3. Adicionar métricas de memória.
4. Criar alertas.
5. Criar Notification Channels.
6. Criar uptime checks.
7. Consultar métricas de VM.
8. Consultar métricas de GKE.
9. Configurar alertas de disponibilidade.

### Lab 07.3 — Terraform

Vamos transformar parte dos laboratórios anteriores em infraestrutura como código.

Estrutura:

```text
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
└── providers.tf
```

Comandos:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform destroy
```

Exercícios:

- Criar VPC.
- Criar subnet.
- Criar VM.
- Criar Service Account.
- Criar IAM bindings.
- Criar Cloud Run.
- Criar infraestrutura de GKE.

### Lab 07.4 — Backup e recuperação

Vamos testar:

- Snapshot de discos.
- Imagens de VMs.
- Backups de Cloud SQL.
- Backup e recuperação de Firestore.
- Estratégias de recuperação.
- Retenção de dados.
- Lifecycle de objetos no Cloud Storage.

---

## 10. Controle de custos e limpeza dos laboratórios

Esse é um dos pontos mais importantes. Não queremos terminar os estudos com uma surpresa na conta do Google Cloud.

Alguns serviços podem gerar custos mesmo quando não estamos enviando requisições.

| Serviço | Cuidados |
|---|---|
| Cloud Run | Instâncias mínimas e tráfego |
| Cloud Functions | Invocações e recursos associados |
| Compute Engine | VM ligada e discos |
| Cloud SQL | Instância provisionada |
| Spanner | Capacidade provisionada |
| Firestore | Operações e armazenamento |
| Bigtable | Nós e armazenamento |
| Load Balancer | Regras de encaminhamento e recursos associados |
| GKE | Control plane, nodes e recursos adicionais |
| Cloud NAT | Gateway e tráfego processado |

**Nossa regra será:** criar, testar, documentar e destruir cada recurso antes de passar para o próximo laboratório, exceto quando um recurso for explicitamente reutilizado.

Comandos de limpeza:

```bash
# Excluir VM
gcloud compute instances delete vm-ace-01 \
  --zone us-central1-a

# Excluir Cloud Run
gcloud run services delete hello-cloud-run \
  --region us-central1

# Excluir cluster GKE
gcloud container clusters delete ace-autopilot \
  --region us-central1

# Listar recursos de Compute
gcloud compute instances list
```

A exclusão de uma VM, por exemplo, não garante que todos os discos e snapshots associados sejam excluídos. Vamos verificar os recursos remanescentes individualmente.

Também não vamos criar simultaneamente Cloud SQL, Spanner, Bigtable e GKE só para testar. Esses serão laboratórios separados.

---

## 11. Como vamos executar cada laboratório

Quero que todos os projetos sigam um padrão de documentação semelhante ao Google Skills Boost.

Cada laboratório terá:

1. **Objetivo** — O que vamos construir e qual conceito da certificação será trabalhado.
2. **Pré-requisitos** — APIs, permissões, ferramentas e recursos necessários.
3. **Implementação** — Passo a passo com Console e comandos CLI.
4. **Testes práticos** — Executar, consultar, atualizar, alterar configurações e validar resultados.
5. **Troubleshooting** — Provocar erros e aprender a identificá-los e corrigi-los.
6. **Limpeza** — Destruir recursos e conferir se não restaram cobranças recorrentes.
7. **Revisão ACE** — Perguntas práticas, cenários de prova e comandos importantes.

---

## 12. Checklist geral de acompanhamento

Este será nosso quadro de progresso. Podemos ir marcando os laboratórios à medida que concluirmos.

### Módulo 00 — Preparação

- [x] Criar projeto e configurar billing
- [x] Configurar gcloud e regiões
- [x] Habilitar APIs e consultar quotas
- [x] Configurar budgets e alertas

### Módulo 01 — IAM

- [x] Criar Service Accounts
- [x] Basic, predefined e custom roles
- [x] IAM Policy e bindings
- [x] Impersonation e credenciais temporárias
- [x] Organization Policies e least privilege

### Módulo 02 — Serverless

- [x] Cloud Run Hello World
- [x] Revisões e traffic splitting
- [x] Cloud Functions HTTP
- [x] Pub/Sub e Eventarc
- [x] Cloud Storage triggers

### Módulo 03 — Compute Engine

- [x] Criar e administrar VMs
- [x] Discos, snapshots e imagens
- [x] SSH e OS Login
- [x] Instance Templates
- [x] Managed Instance Groups e autoscaling

### Módulo 04 — Databases

- [x] Cloud SQL PostgreSQL
- [x] Cloud Spanner
- [x] Firestore
- [ ] Bigtable
- [x] Backup, restore e comparação

### Módulo 05 — Networking

- [x] VPC e Subnets
- [x] Firewall, rotas e IPs
- [x] Cloud NAT e Cloud DNS
- [ ] External Load Balancer
- [ ] Internal Load Balancer e health checks

### Módulo 06 — GKE

- [ ] Autopilot e Standard
- [ ] Artifact Registry e Deployments
- [ ] Pods, ReplicaSets e Services
- [ ] ConfigMaps e Secrets
- [ ] HPA, VPA e Cluster Autoscaler
- [ ] PV, PVC e StatefulSets
- [ ] Ingress, Gateway e Load Balancing
- [ ] IAM, RBAC e Workload Identity
- [ ] Private e Regional Clusters
- [ ] Troubleshooting e upgrades

### Módulo 07 — Operações e IaC

- [ ] Cloud Logging e Audit Logs
- [ ] Cloud Monitoring e alertas
- [ ] Terraform
- [ ] Backup e recuperação
- [ ] Revisão geral e simulado prático

---

## 13. Materiais oficiais de referência

Vamos utilizar a documentação oficial para validar comandos e configurações, especialmente porque o Google Cloud recebe atualizações frequentes.

1. [Guia oficial da certificação ACE em português](https://cloud.google.com/learn/certification/cloud-engineer).
2. [Preparação para a certificação Associate Cloud Engineer](https://cloud.google.com/learn/certification/cloud-engineer).
3. [Quickstart oficial do Cloud Run](https://cloud.google.com/run/docs/quickstarts).
4. [Documentação da Google Cloud CLI](https://cloud.google.com/sdk/gcloud).
5. [Documentação oficial do GKE](https://cloud.google.com/kubernetes-engine/docs).
6. [Documentação do IAM](https://cloud.google.com/iam/docs).

---

## 14. Ordem de execução recomendada

Minha recomendação é seguirmos esta sequência:

| Ordem | Laboratório | Prioridade |
|---:|---|---|
| 1 | Preparação do projeto | Essencial |
| 2 | IAM e Service Accounts | Essencial |
| 3 | Cloud Run | Essencial |
| 4 | Cloud Functions | Essencial |
| 5 | Compute Engine | Essencial |
| 6 | Cloud SQL e bancos NoSQL | Alta |
| 7 | Networking e Load Balancing | Alta |
| 8 | GKE | Muito alta |
| 9 | Monitoring, Logging e Terraform | Alta |

**Uma observação:** GKE merece bastante atenção, mas não podemos negligenciar IAM, Compute Engine e Networking. São áreas que se conectam diretamente aos cenários práticos da certificação.

---

## 15. Primeiro laboratório: preparação do ambiente

### LAB 00 — Preparando o ambiente Google Cloud

**Objetivo:** deixar seu ambiente pronto para executar todos os projetos seguintes.

Vamos começar verificando:

- [ ] Conta Google e projeto de laboratório.
- [ ] Conta de faturamento vinculada.
- [ ] Google Cloud CLI instalada e autenticada.
- [ ] Projeto selecionado na CLI.
- [ ] Região e zona configuradas.
- [ ] APIs habilitadas.
- [ ] Billing Budget configurado.

A partir daí, trabalharemos como se estivéssemos fazendo um laboratório oficial: você executa os comandos, me mostra os resultados e avançamos juntos, sem pular etapas.
'''

output_path = "/mnt/data/guia-pratico-gcp-ace-labs.md"
pypandoc.convert_text(markdown, "md", format="md", outputfile=output_path, extra_args=["--standalone"])
print(f"Arquivo criado: {output_path}")