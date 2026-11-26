# Lab 05.4 — Cloud Bigtable

## Objetivos

Neste laboratório, praticamos os principais recursos do Google Cloud Bigtable:

- Criar e inspecionar uma instância Bigtable Free Trial.
- Criar uma tabela e Column Families com `cbt`.
- Inserir, consultar e atualizar linhas.
- Entender Row Keys, Column Families, Qualifiers e timestamps.
- Explorar múltiplas versões de uma célula.
- Configurar Garbage Collection (GC) por Column Family.
- Acessar o Bigtable com a biblioteca Python `google-cloud-bigtable`.
- Executar operações individuais e em lote.
- Aplicar filtros de linha e de células com `RowFilter`.

> **Atenção a custos e elegibilidade:** a instância foi criada pelo fluxo Free Trial do Console. Não faça upgrade para uma instância paga. A instância de teste pode ter restrições de elegibilidade e prazo; não a exclua sem avaliar as consequências. O campo `trialConfig.expireTime` observado foi `2026-12-06T02:17:26.608683Z`. Confirme a situação atual no Console antes de qualquer alteração. Não aplique Terraform convencional sobre essa instância: a configuração de trial foi criada pelo Console e não deve ser substituída acidentalmente por uma instância paga.

## Ambiente

| Item | Valor |
|---|---|
| Projeto | `ace-hands-on-labs-2026` |
| Região | `us-central1` |
| Zona do cluster | `us-central1-a` |
| Instância | `ace-bigtable-lab054` |
| Display name | `ACE Hands On Labs Bigtable` |
| Cluster | `ace-bigtable-lab054-c1` |
| Nós | 1 |
| Armazenamento | SSD |
| Tabela | `customers` |
| Column Families | `profile`, `contact` |
| Cliente CLI | `cbt` |
| Biblioteca Python | `google-cloud-bigtable==2.50.2` |
| Python | `3.14` |

## 1. Habilitar APIs e verificar a instância

APIs habilitadas:

```bash
gcloud services enable bigtable.googleapis.com
gcloud services enable bigtableadmin.googleapis.com
```

Verificações realizadas:

```bash
gcloud bigtable instances list

gcloud bigtable instances describe ace-bigtable-lab054

gcloud bigtable clusters list \
  --instances=ace-bigtable-lab054
```

A descrição da instância mostrou `state: READY` e a seção `trialConfig`, incluindo o prazo do trial. O campo `type: PRODUCTION` retornado pela API não deve ser interpretado isoladamente como indicação de cobrança: a presença de `trialConfig` identifica a configuração de teste observada.

## 2. Configurar o cliente `cbt`

O arquivo global `~/.cbtrc` foi configurado com:

```ini
project = ace-hands-on-labs-2026
instance = ace-bigtable-lab054
```

O `cbt` utilizou as credenciais já disponíveis no `gcloud`.

As mensagens abaixo apareceram durante a execução no WSL:

```text
-creds flag unset, will use gcloud credential
Failed to read manufacturer, vmOnGCE=false:
open /sys/class/dmi/id/product_name: no such file or directory
```

Elas não impediram as operações. A primeira informa o uso das credenciais do `gcloud`; a segunda é um aviso da detecção de ambiente de VM no WSL.

## 3. Criar a tabela e as Column Families

```bash
cbt createtable customers
cbt createfamily customers profile
cbt createfamily customers contact
cbt ls customers
```

Estrutura:

- `customers`: tabela.
- `profile`: família para dados de perfil.
- `contact`: família para dados de contato.

O Bigtable é um banco NoSQL wide-column. Uma linha é identificada por uma Row Key e pode conter diferentes Qualifiers em cada Column Family. As linhas não precisam ter exatamente o mesmo conjunto de colunas.

## 4. Inserir dados com `cbt`

Alice:

```bash
cbt set customers customer#1001 profile:name="Alice"
cbt set customers customer#1001 profile:status="active"
cbt set customers customer#1001 contact:email="alice@example.com"
cbt set customers customer#1001 contact:phone="5511999991001"
```

Bob:

```bash
cbt set customers customer#1002 profile:name="Bob"
cbt set customers customer#1002 profile:status="inactive"
cbt set customers customer#1002 contact:email="bob@example.com"
```

Charlie:

```bash
cbt set customers customer#1003 profile:name="Charlie"
cbt set customers customer#1003 profile:status="active"
cbt set customers customer#1003 contact:email="charlie@example.com"
```

Consultas:

```bash
cbt count customers
cbt read customers
cbt lookup customers customer#1001
cbt read customers prefix=customer#
```

`lookup` consulta uma Row Key específica. `prefix` restringe a leitura às Row Keys que começam com o prefixo informado.

## 5. Row Keys, células e timestamps

A Row Key usada foi `customer#1001`. Cada célula pode ser entendida pela combinação:

`Row Key + Column Family + Qualifier + Timestamp`

Exemplo:

- Row Key: `customer#1001`
- Column Family: `profile`
- Qualifier: `status`
- Valor inicial: `active`

Ao atualizar o status:

```bash
cbt set customers customer#1001 profile:status="inactive"
cbt lookup customers customer#1001
```

A leitura mostrou as duas versões de `profile:status`, com timestamps diferentes: `inactive` (mais recente) e `active` (anterior).

### Limite de linhas versus limite de versões

Foi testado:

```bash
cbt read customers count=2
```

`count=2` limita a quantidade de linhas retornadas, não a quantidade de versões de cada célula.

Para limitar versões por célula:

```bash
cbt read customers cells-per-column=2
```

Esse comando permitiu visualizar até duas versões por célula.

## 6. Garbage Collection Policy

Inicialmente, as duas famílias estavam com política `<never>`:

```bash
cbt ls customers
```

Foi configurada uma política de no máximo uma versão para `profile`:

```bash
cbt setgcpolicy customers profile maxversions=1
cbt ls customers
```

Resultado observado:

| Column Family | Política |
|---|---|
| `profile` | `versions() > 1` |
| `contact` | `<never>` |

A política de GC é configurada por Column Family. `maxversions=1` torna versões excedentes elegíveis para remoção, mas a coleta é assíncrona. Por isso, versões antigas ainda podem aparecer nas leituras logo após a configuração. Não se deve tratar a política como exclusão imediata e síncrona.

## 7. Acesso com Python

Pacote instalado no ambiente virtual:

```bash
pip show google-cloud-bigtable
```

Versão observada: `2.50.2`.

A autenticação foi feita com Application Default Credentials disponíveis no ambiente. O script local `bigtable_operations.py` foi desenvolvido durante o laboratório.

### Conexão e leitura por Row Key

Exemplo do padrão utilizado:

```python
from google.cloud import bigtable

PROJECT_ID = "ace-hands-on-labs-2026"
INSTANCE_ID = "ace-bigtable-lab054"
TABLE_ID = "customers"

client = bigtable.Client(project=PROJECT_ID, admin=False)
instance = client.instance(INSTANCE_ID)
table = instance.table(TABLE_ID)

row = table.read_row(b"customer#1001")
```

A leitura retornou os dados de Alice e também as versões existentes de `profile:status`.

### Inserção e atualização

Foi implementado o uso de `table.direct_row()` e `set_cell()`:

```python
row = table.direct_row(b"customer#1004")
row.set_cell("profile", "name", "Daniel")
row.set_cell("profile", "status", "active")
row.set_cell("contact", "email", "daniel@example.com")
row.commit()
```

A atualização do status criou uma nova versão da célula:

```python
row = table.direct_row(b"customer#1004")
row.set_cell("profile", "status", "inactive")
row.commit()
```

A leitura de Daniel mostrou as versões de status acumuladas pelas gravações repetidas. Isso foi coerente com o comportamento de versionamento e com a GC assíncrona.

### Batch Insert com `mutate_rows`

Foram inseridos três clientes (`customer#1005`, `customer#1006`, `customer#1007`) usando `table.mutate_rows(mutations)`.

A operação em lote reduz o overhead de chamadas, mas não deve ser tratada como uma transação atômica para todas as linhas. Em aplicações de produção, é importante inspecionar os resultados individuais das mutations.

### Batch Read com `RowSet`

A primeira tentativa com `table.read_rows(keys=keys)` falhou porque `keys` não é um argumento aceito por `Table.read_rows()` nessa versão da biblioteca.

A implementação corrigida utilizou `RowSet`:

```python
from google.cloud.bigtable.row_set import RowSet

row_set = RowSet()
row_set.add_row_key(b"customer#1001")
row_set.add_row_key(b"customer#1004")

rows = table.read_rows(row_set=row_set)
```

O teste consultou cinco Row Keys específicas e retornou Alice, Daniel, Eva, Fernando e Gabriel.

## 8. Filtros (Row Filters)

Os filtros são enviados ao Bigtable para limitar os dados retornados à aplicação.

### FamilyNameRegexFilter

Seleciona uma Column Family:

```python
from google.cloud.bigtable import row_filters

row_filter = row_filters.FamilyNameRegexFilter("profile")
row = table.read_row(b"customer#1001", filter_=row_filter)
```

O teste retornou apenas `profile:name` e `profile:status`.

### ColumnQualifierRegexFilter

Seleciona Qualifiers pelo nome:

```python
row_filter = row_filters.ColumnQualifierRegexFilter("status")
row = table.read_row(b"customer#1001", filter_=row_filter)
```

O teste retornou somente `profile:status`.

### RowFilterChain

Combina filtros em sequência:

```python
row_filter = row_filters.RowFilterChain(
    filters=[
        row_filters.FamilyNameRegexFilter("profile"),
        row_filters.ColumnQualifierRegexFilter("status"),
    ]
)
```

O resultado foi somente `profile:status`. O `RowFilterChain` aplica os filtros em sequência (AND lógico).

`RowFilterUnion`, por sua vez, combina os resultados de filtros alternativos (OR lógico).

### RowKeyRegexFilter

Seleciona linhas com Row Keys que correspondem a uma expressão regular:

```python
row_filter = row_filters.RowKeyRegexFilter(
    b"^customer#100[1-3]$"
)

rows = table.read_rows(filter_=row_filter)
```

O teste retornou somente:

- `customer#1001` — Alice
- `customer#1002` — Bob
- `customer#1003` — Charlie

A expressão `^customer#100[1-3]$` significa início da chave, texto literal `customer#100`, um dígito de 1 a 3 e fim da chave.

## 9. Estado final dos dados

Foram criadas sete linhas:

| Row Key | Nome | Status mais recente |
|---|---|---|
| `customer#1001` | Alice | inactive |
| `customer#1002` | Bob | inactive |
| `customer#1003` | Charlie | active |
| `customer#1004` | Daniel | inactive |
| `customer#1005` | Eva | active |
| `customer#1006` | Fernando | active |
| `customer#1007` | Gabriel | inactive |

Verificação:

```bash
cbt count customers
```

Resultado observado: `7`.

## 10. Conceitos importantes para o ACE

- **Bigtable:** banco NoSQL wide-column, indicado para grandes volumes de dados e baixa latência.
- **Row Key:** identifica a linha e determina a ordenação lexicográfica.
- **Column Family:** agrupamento de colunas, definido no schema da tabela.
- **Qualifier:** identifica uma coluna dentro de uma família.
- **Timestamp:** permite múltiplas versões de uma célula.
- **GC Policy:** controla quais versões podem ser descartadas; a coleta é assíncrona.
- **RowSet:** define Row Keys e intervalos a consultar.
- **RowFilter:** filtra linhas ou células no servidor.
- **`mutate_rows`:** grava mutations em múltiplas linhas, sem atomicidade global do lote.
- **Desenho da Row Key:** influencia o desempenho e a distribuição de carga; padrões sequenciais inadequados podem criar hotspots.

## 11. Cuidados e encerramento

A instância Free Trial foi mantida. Não execute `terraform destroy`, não exclua a instância e não faça upgrade sem avaliar a elegibilidade e os custos.

As APIs habilitadas e a tabela também foram mantidas para continuidade dos estudos. O laboratório não criou instância convencional por Terraform justamente para evitar substituir a instância Free Trial.

Para conferir o estado atual:

```bash
gcloud bigtable instances list
gcloud bigtable instances describe ace-bigtable-lab054
gcloud bigtable clusters list --instances=ace-bigtable-lab054
cbt ls customers
cbt count customers
```