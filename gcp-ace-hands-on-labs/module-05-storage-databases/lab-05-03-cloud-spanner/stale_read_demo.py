from datetime import timedelta
from google.cloud import spanner

PROJECT_ID = "ace-hands-on-labs-2026"
INSTANCE_ID = "ace-spanner-lab053"
DATABASE_ID = "ace_database"

client = spanner.Client(project=PROJECT_ID)
instance = client.instance(INSTANCE_ID)
database = instance.database(DATABASE_ID)


# 1. atualiza o registro para termos uma alteração recente
def update_customer(transaction):
    transaction.execute_update(
        """
        UPDATE Customers
        SET Name = @name
        WHERE CustomerId = @customer_id
        """,
        params={
            "name": "Alice Atual",
            "customer_id": 1,
        },
        param_types={
            "name": spanner.param_types.STRING,
            "customer_id": spanner.param_types.INT64,
        },
    )


database.run_in_transaction(update_customer)
print("Registro atualizado!")


# 2. strong read: consulta os dados mais recentes
with database.snapshot() as snapshot:
    results = snapshot.execute_sql(
        "SELECT CustomerId, Name FROM Customers WHERE CustomerId = 1"
    )

    for row in results:
        print("Strong Read:", row)


# 3. stale read: consulta uma versão de 60 segundos atrás
with database.snapshot(
    exact_staleness=timedelta(seconds=60)
) as snapshot:
    results = snapshot.execute_sql(
        "SELECT CustomerId, Name FROM Customers WHERE CustomerId = 1"
    )

    for row in results:
        print("Stale Read (60s):", row)
