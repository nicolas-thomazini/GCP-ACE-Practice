from concurrent.futures import ThreadPoolExecutor
from google.cloud import spanner
import time

PROJECT_ID = "ace-hands-on-labs-2026"
INSTANCE_ID = "ace-spanner-lab053"
DATABASE_ID = "ace_database"

client = spanner.Client(project=PROJECT_ID)
instance = client.instance(INSTANCE_ID)
database = instance.database(DATABASE_ID)


def update_customer(customer_name):
    def transaction_work(transaction):
        results = transaction.execute_sql(
            """
            SELECT CustomerId, Name
            FROM Customers
            WHERE CustomerId = 1
            """
        )

        for row in results:
            print(f"{customer_name} leu: {row}")

        time.sleep(2)

        transaction.execute_update(
            """
            UPDATE Customers
            SET Name = @name
            WHERE CustomerId = 1
            """,
            params={"name": customer_name},
            param_types={
                "name": spanner.param_types.STRING
            },
        )

    database.run_in_transaction(transaction_work)
    print(f"{customer_name}: transação concluída!")


with ThreadPoolExecutor(max_workers=2) as executor:
    futures = [
        executor.submit(update_customer, "Alice Concorrencia A"),
        executor.submit(update_customer, "Alice Concorrencia B"),
    ]

    for future in futures:
        future.result()


with database.snapshot() as snapshot:
    results = snapshot.execute_sql(
        "SELECT CustomerId, Name FROM Customers WHERE CustomerId = 1"
    )

    for row in results:
        print("Resultado final:", row)
