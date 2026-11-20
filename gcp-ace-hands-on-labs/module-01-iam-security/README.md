# Módulo 01 — IAM e Segurança (Google Cloud)

Neste módulo, praticamos a criação e o gerenciamento de Service Accounts, atribuição de Roles, Custom IAM Roles, IAM Bindings e Service Account Impersonation.

## 1. Preparação das variáveis

Para tornar os comandos reutilizáveis, definimos variáveis para o projeto, a conta pessoal e as Service Accounts.

```bash
PROJECT_ID="your-project-id"
USER_EMAIL="your-email@gmail.com"

SA_COMPUTE_EMAIL="sa-compute@${PROJECT_ID}.iam.gserviceaccount.com"
SA_CLOUDRUN_EMAIL="sa-cloudrun@${PROJECT_ID}.iam.gserviceaccount.com"
SA_GKE_EMAIL="sa-gke@${PROJECT_ID}.iam.gserviceaccount.com"
```

> Substitua os valores pelos dados do seu ambiente antes de executar os comandos.

## 2. Service Accounts criadas

Criamos três Service Accounts, cada uma destinada a uma finalidade diferente.

| Service Account | Finalidade |
|---|---|
| `sa-compute` | Acesso de uma VM |
| `sa-cloudrun` | Execução do Cloud Run |
| `sa-gke` | Operações de workloads no GKE |

### 2.1 — Criar Service Accounts

```bash
gcloud iam service-accounts create sa-compute \
  --display-name="Compute Service Account"

gcloud iam service-accounts create sa-cloudrun \
  --display-name="Cloud Run Service Account"

gcloud iam service-accounts create sa-gke \
  --display-name="GKE Service Account"
```

### 2.2 — Listar Service Accounts

```bash
gcloud iam service-accounts list
```

As três contas foram criadas sem atribuições adicionais de roles inicialmente.

---

## 3. Roles atribuídas

Trabalhamos com diferentes tipos de IAM Roles.

### 3.1 — Basic Role

A conta pessoal utilizada no laboratório possuía a role:

```text
roles/owner
```

A role `Owner` concede permissões administrativas amplas no projeto.

### 3.2 — Predefined Role

Atribuímos à Service Account `sa-compute`:

```text
roles/storage.objectViewer
```

Essa role permite listar e ler objetos do Cloud Storage, respeitando as demais políticas aplicáveis.

Comando utilizado:

```bash
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_COMPUTE_EMAIL}" \
  --role="roles/storage.objectViewer"
```

### 3.3 — Custom Role

Criamos uma role personalizada chamada:

```text
aceCustomStorageReader
```

Identificador completo:

```text
projects/PROJECT_ID/roles/aceCustomStorageReader
```

Configuração:

| Propriedade | Valor |
|---|---|
| Role ID | `aceCustomStorageReader` |
| Title | ACE Custom Storage Reader |
| Stage inicial | `GA` |
| Scope | Project |

#### Permissões finais

```text
storage.buckets.get
storage.buckets.list
storage.objects.list
```

| Permissão | Finalidade |
|---|---|
| `storage.buckets.get` | Consultar metadados de um bucket |
| `storage.buckets.list` | Listar buckets do projeto |
| `storage.objects.list` | Listar objetos de um bucket |

**Importante:** `storage.objects.list` permite listar objetos e consultar informações associadas, mas não permite ler o conteúdo dos objetos. Para isso, seria necessária, por exemplo, a permissão `storage.objects.get`.

### 3.4 — Criar a Custom Role

Inicialmente, criamos a role com duas permissões:

```bash
gcloud iam roles create aceCustomStorageReader \
  --project="${PROJECT_ID}" \
  --title="ACE Custom Storage Reader" \
  --description="Custom role for reading Cloud Storage bucket metadata" \
  --permissions=storage.buckets.get,storage.buckets.list \
  --stage=GA
```

### 3.5 — Atualizar a Custom Role

Posteriormente, adicionamos a permissão `storage.objects.list`:

```bash
gcloud iam roles update aceCustomStorageReader \
  --project="${PROJECT_ID}" \
  --add-permissions=storage.objects.list
```

### 3.6 — Listar e consultar Roles

Listar as Custom Roles do projeto:

```bash
gcloud iam roles list \
  --project="${PROJECT_ID}"
```

Consultar uma role específica:

```bash
gcloud iam roles describe aceCustomStorageReader \
  --project="${PROJECT_ID}"
```

---

## 4. IAM Binding — Associação da Custom Role

Depois de criar a Custom Role, associamos essa role à Service Account `sa-cloudrun`.

```bash
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_CLOUDRUN_EMAIL}" \
  --role="projects/${PROJECT_ID}/roles/aceCustomStorageReader"
```

Configuração realizada:

| Elemento | Valor |
|---|---|
| Principal | `sa-cloudrun` |
| Role | `aceCustomStorageReader` |
| Scope | Project |

### Conceitos importantes

- **Role:** define um conjunto de permissões.
- **Principal:** identidade que receberá as permissões.
- **Binding:** associa um principal a uma role.
- **IAM Policy:** documento que armazena essas associações.

Uma role pode existir sem estar atribuída a nenhum principal. Um principal também pode receber várias roles.

---

## 5. Service Account Impersonation

O objetivo foi executar operações no Cloud Storage utilizando a identidade da `sa-cloudrun`, em vez da identidade da conta pessoal.

### 5.1 — Identificar a conta autenticada

```bash
gcloud auth list
```

Esse comando lista as contas autenticadas e indica qual está ativa.

### 5.2 — Conceder Service Account Token Creator

Para permitir que a conta pessoal gere credenciais temporárias para a `sa-cloudrun`, concedemos:

```text
roles/iam.serviceAccountTokenCreator
```

Comando:

```bash
gcloud iam service-accounts add-iam-policy-binding \
  "${SA_CLOUDRUN_EMAIL}" \
  --project="${PROJECT_ID}" \
  --member="user:${USER_EMAIL}" \
  --role="roles/iam.serviceAccountTokenCreator"
```

Essa permissão foi atribuída à conta pessoal na política IAM da própria Service Account, e não como uma role geral do projeto.

### 5.3 — Configurar a Impersonation

```bash
gcloud config set auth/impersonate_service_account \
  "${SA_CLOUDRUN_EMAIL}"
```

Para consultar a configuração:

```bash
gcloud config get-value auth/impersonate_service_account
```

**Observação:** `gcloud auth list` continua mostrando a conta pessoal como identidade de origem. Isso é esperado. Os comandos compatíveis com impersonation utilizam as credenciais temporárias da Service Account.

---

## 6. Testes práticos das permissões

Realizamos dois testes para verificar o comportamento da Custom Role.

### 6.1 — Teste 1: Listar buckets

Comando:

```bash
gcloud storage buckets list \
  --project="${PROJECT_ID}"
```

Resultado obtido:

```text
WARNING: This command is using service account impersonation.
Listed 0 items.
```

**Resultado: Permitido.**

A operação foi autorizada porque a Custom Role possuía:

```text
storage.buckets.list
```

O retorno `Listed 0 items` significa que a consulta foi executada, mas não havia buckets no projeto.

### 6.2 — Teste 2: Criar um bucket

Comando utilizado:

```bash
gcloud storage buckets create gs://YOUR-UNIQUE-BUCKET-NAME \
  --project="${PROJECT_ID}" \
  --location=us-central1
```

Resultado obtido:

```text
HTTPError 403

Permission 'storage.buckets.create' denied
```

**Resultado: Bloqueado como esperado.**

A Custom Role não possuía:

```text
storage.buckets.create
```

Portanto, a operação foi negada.

### 6.3 — Conclusão dos testes

| Operação | Permissão | Resultado |
|---|---|---|
| Listar buckets | `storage.buckets.list` | Permitido |
| Criar buckets | `storage.buckets.create` | Bloqueado (403) |

Isso demonstrou o princípio de **Least Privilege**: conceder somente as permissões necessárias para executar determinada atividade.

**Limitação dos testes:** não testamos diretamente `storage.objects.list` nem `storage.objects.get`. A listagem de buckets comprovou `storage.buckets.list`, enquanto a tentativa de criação comprovou a ausência de `storage.buckets.create`.

---

## 7. Remoção do IAM Binding

Após os testes, removemos a associação entre `sa-cloudrun` e a Custom Role.

### 7.1 — Desativar a Impersonation

```bash
gcloud config unset auth/impersonate_service_account
```

Esse comando remove a configuração local de impersonation.

### 7.2 — Remover o IAM Binding

```bash
gcloud projects remove-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_CLOUDRUN_EMAIL}" \
  --role="projects/${PROJECT_ID}/roles/aceCustomStorageReader"
```

A Custom Role ainda existia, mas já não estava associada à `sa-cloudrun`.

---

## 8. Desabilitar e excluir a Custom Role

Por último, praticamos o ciclo de encerramento de uma Custom Role.

### 8.1 — Desabilitar a Role

```bash
gcloud iam roles update aceCustomStorageReader \
  --project="${PROJECT_ID}" \
  --stage=DISABLED
```

Para verificar:

```bash
gcloud iam roles describe aceCustomStorageReader \
  --project="${PROJECT_ID}"
```

Resultado esperado:

```yaml
stage: DISABLED
```

A role foi desabilitada, mas sua definição ainda existia.

### 8.2 — Excluir a Role

```bash
gcloud iam roles delete aceCustomStorageReader \
  --project="${PROJECT_ID}"
```

Resultado obtido:

```text
deleted: true
```

A exclusão foi confirmada.

---

## 9. Estado final dos recursos e permissões

| Identidade | Role | Estado |
|---|---|---|
| Conta pessoal | `roles/owner` | Mantida |
| `sa-compute` | `roles/storage.objectViewer` | Mantida |
| `sa-cloudrun` | `aceCustomStorageReader` | Binding removido e role excluída |
| Conta pessoal | `roles/iam.serviceAccountTokenCreator` na `sa-cloudrun` | Mantida |
| `sa-gke` | Nenhuma role adicional atribuída | Sem alteração |

**Atenção:** removemos o binding da Custom Role e desativamos a impersonation na configuração local, mas não removemos o `roles/iam.serviceAccountTokenCreator` concedido à conta pessoal na `sa-cloudrun`. Essa autorização ainda permanece no ambiente do laboratório.

A Custom Role `aceCustomStorageReader` foi excluída.

---

## 10. Comandos importantes para memorizar para a ACE

| Operação | Comando |
|---|---|
| Listar Service Accounts | `gcloud iam service-accounts list` |
| Criar Service Account | `gcloud iam service-accounts create` |
| Listar Roles | `gcloud iam roles list` |
| Consultar Role | `gcloud iam roles describe` |
| Criar Custom Role | `gcloud iam roles create` |
| Atualizar Custom Role | `gcloud iam roles update` |
| Excluir Custom Role | `gcloud iam roles delete` |
| Adicionar IAM Binding no projeto | `gcloud projects add-iam-policy-binding` |
| Remover IAM Binding do projeto | `gcloud projects remove-iam-policy-binding` |
| Consultar IAM Policy do projeto | `gcloud projects get-iam-policy` |
| Adicionar policy à Service Account | `gcloud iam service-accounts add-iam-policy-binding` |
| Listar contas autenticadas | `gcloud auth list` |
| Configurar impersonation | `gcloud config set auth/impersonate_service_account` |
| Remover impersonation da configuração | `gcloud config unset auth/impersonate_service_account` |

---

## 11. Conceitos que você precisa dominar

### IAM — Identity and Access Management

Controla quem pode acessar quais recursos e quais operações pode executar.

### Service Account

Identidade utilizada por aplicações, serviços e workloads para acessar recursos do Google Cloud.

### Basic Role

Roles básicas, como `Owner`, `Editor` e `Viewer`, que oferecem conjuntos amplos de permissões.

### Predefined Role

Role criada e mantida pelo Google, com permissões predefinidas.

### Custom Role

Role criada pelo usuário, com um conjunto específico de permissões.

### IAM Binding

Associação entre um principal e uma role em determinada política IAM.

### Service Account Impersonation

Permite utilizar temporariamente a identidade de uma Service Account sem precisar criar ou armazenar uma chave JSON.

### Least Privilege

Conceder somente as permissões estritamente necessárias.

---

## 12. Próximas etapas

O próximo laboratório será:

**LAB 01.4 — Service Account Impersonation**

Vamos aprofundar as diferenças entre:

- `roles/iam.serviceAccountUser`
- `roles/iam.serviceAccountTokenCreator`
- `roles/iam.serviceAccountAdmin`

O objetivo será entender quando utilizar cada role, quais permissões elas concedem e como funcionam em diferentes cenários do Google Cloud.