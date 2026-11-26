from google.cloud import spanner

PROJECT_ID = "ace-hands-on-labs-2026"
INSTANCE_ID = "ace-spanner-lab053"
DATABASE_ID = "ace_database"

client = spanner.Client(project=PROJECT_ID)
instance = client.instance(INSTANCE_ID)
database = instance.database(DATABASE_ID)

def update_customer(transaction):
    transaction.execute_update(
        """
        UPDATE Customers
        SET Name = @name
        WHERE CustomerId = @customer_id
        """,
        params={
            "name": "Alice Transacao",
            "customer_id": 1,
        },
        param_types={
            "name": spanner.param_types.STRING,
            "customer_id": spanner.param_types.INT64,
        },
    )

database.run_in_transaction(update_customer)

print("Transação confirmada!")

with database.snapshot() as snapshot:
    results = snapshot.execute_sql(
        "SELECT CustomerId, Name FROM Customers WHERE CustomerId = 1"
    )
    for row in results:
        print(row)

def rollback_demo(transaction):
    transaction.execute_update(
        """
        UPDATE Customers
        SET Name = @name
        WHERE CustomerId = @customer_id
        """,
        params={
            "name": "Alice Rollback",
            "customer_id": 1,
        },
        param_types={
            "name": spanner.param_types.STRING,
            "customer_id": spanner.param_types.INT64,
        },
    )

    raise RuntimeError("Erro simulado para testar rollback")


try:
    database.run_in_transaction(rollback_demo)
except RuntimeError as error:
    print(f"Transação abortada: {error}")


with database.snapshot() as snapshot:
    results = snapshot.execute_sql(
        "SELECT CustomerId, Name FROM Customers WHERE CustomerId = 1"
    )

    for row in results:
        print("Resultado após rollback:", row)