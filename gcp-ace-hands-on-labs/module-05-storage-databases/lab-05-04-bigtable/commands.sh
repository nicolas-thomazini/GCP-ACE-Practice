#!/usr/bin/env bash
# Lab 05.4 — Cloud Bigtable
# Registro dos comandos executados durante o laboratório.
# Atenção: este arquivo é um histórico didático, não um script idempotente.
# Algumas operações criam recursos/linhas e podem falhar se executadas novamente.

set -euo pipefail

PROJECT_ID="ace-hands-on-labs-2026"
INSTANCE_ID="ace-bigtable-lab054"
TABLE_ID="customers"

# 1. Habilitar APIs
gcloud services enable bigtable.googleapis.com
gcloud services enable bigtableadmin.googleapis.com

# 2. Inspecionar instância e cluster criados pelo Console (Free Trial)
gcloud bigtable instances list
gcloud bigtable instances describe "${INSTANCE_ID}"
gcloud bigtable clusters list --instances="${INSTANCE_ID}"

# 3. Configuração global do cbt (executada no shell interativo)
# cat > ~/.cbtrc <<'EOF'
# project = ace-hands-on-labs-2026
# instance = ace-bigtable-lab054
# EOF

# 4. Criar tabela e famílias (executado uma vez)
cbt createtable "${TABLE_ID}"
cbt createfamily "${TABLE_ID}" profile
cbt createfamily "${TABLE_ID}" contact
cbt ls "${TABLE_ID}"

# 5. Inserir Alice, Bob e Charlie
cbt set "${TABLE_ID}" customer#1001 profile:name="Alice"
cbt set "${TABLE_ID}" customer#1001 profile:status="active"
cbt set "${TABLE_ID}" customer#1001 contact:email="alice@example.com"
cbt set "${TABLE_ID}" customer#1001 contact:phone="5511999991001"

cbt set "${TABLE_ID}" customer#1002 profile:name="Bob"
cbt set "${TABLE_ID}" customer#1002 profile:status="inactive"
cbt set "${TABLE_ID}" customer#1002 contact:email="bob@example.com"

cbt set "${TABLE_ID}" customer#1003 profile:name="Charlie"
cbt set "${TABLE_ID}" customer#1003 profile:status="active"
cbt set "${TABLE_ID}" customer#1003 contact:email="charlie@example.com"

# 6. Consultas
cbt count "${TABLE_ID}"
cbt read "${TABLE_ID}"
cbt lookup "${TABLE_ID}" customer#1001
cbt read "${TABLE_ID}" prefix=customer#

# 7. Criar uma nova versão de status para Alice
cbt set "${TABLE_ID}" customer#1001 profile:status="inactive"
cbt lookup "${TABLE_ID}" customer#1001

# 8. Limites de leitura e versões
cbt read "${TABLE_ID}" count=2
cbt read "${TABLE_ID}" cells-per-column=2

# 9. Política de Garbage Collection por Column Family
cbt ls "${TABLE_ID}"
cbt setgcpolicy "${TABLE_ID}" profile maxversions=1
cbt ls "${TABLE_ID}"
cbt read "${TABLE_ID}" cells-per-column=2

# 10. Verificação final
cbt count "${TABLE_ID}"
cbt read "${TABLE_ID}"

# As operações Python foram executadas com:
# pip show google-cloud-bigtable
# python bigtable_operations.py
#
# O script bigtable_operations.py incluiu:
# - leitura individual via table.read_row()
# - inserção/atualização via table.direct_row() e row.commit()
# - batch insert via table.mutate_rows()
# - batch read via RowSet + table.read_rows(row_set=...)
# - FamilyNameRegexFilter
# - ColumnQualifierRegexFilter
# - RowFilterChain
# - RowKeyRegexFilter
#
# 11. Estado final da instância
gcloud bigtable instances list
gcloud bigtable instances describe "${INSTANCE_ID}"
gcloud bigtable clusters list --instances="${INSTANCE_ID}"