
from google.cloud import spanner

PROJECT_ID = "ace-hands-on-labs-2026"
INSTANCE_ID = "ace-spanner-lab053"
DATABASE_ID = "ace_database"

client = spanner.Client(project=PROJECT_ID)
instance = client.instance(INSTANCE_ID)
database = instance.database(DATABASE_ID)


# atualização em massa usando Partitioned DML
row_count = database.execute_partitioned_dml(
    """
    UPDATE Customers
    SET Name = CASE
        WHEN CustomerId = 2 THEN 'Bob PDM'
        WHEN CustomerId = 3 THEN 'Charlie PDM'
    END
    WHERE CustomerId IN (2, 3)
    """
)

print(f"Registros modificados: {row_count}")


# consultar os resultados
with database.snapshot() as snapshot:
    results = snapshot.execute_sql(
        """
        SELECT CustomerId, Name
        FROM Customers
        ORDER BY CustomerId
        """
    )

    for row in results:
        print(row)


# restaurar os nomes originais
database.execute_partitioned_dml(
    """
    UPDATE Customers
    SET Name = CASE
        WHEN CustomerId = 2 THEN 'Bob'
        WHEN CustomerId = 3 THEN 'Charlie'
    END
    WHERE CustomerId IN (2, 3)
    """

)

print("Nomes originais restaurados!")
