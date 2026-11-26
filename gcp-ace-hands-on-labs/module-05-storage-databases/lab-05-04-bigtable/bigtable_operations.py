from google.cloud import bigtable
from google.cloud.bigtable.row_set import RowSet
from google.cloud.bigtable import row_filters

PROJECT_ID = "ace-hands-on-labs-2026"
INSTANCE_ID = "ace-bigtable-lab054"
TABLE_ID = "customers"


def get_table():
    client = bigtable.Client(
        project=PROJECT_ID,
        admin=False,
    )

    instance = client.instance(INSTANCE_ID)
    table = instance.table(TABLE_ID)

    return client, table


def read_customer(row_key: str):
    client, table = get_table()

    row = table.read_row(row_key.encode("utf-8"))

    if row is None:
        print(f"Cliente {row_key} não encontrado.")
        return

    print(f"\nCliente: {row_key}")

    for family, columns in row.cells.items():
        for qualifier, cells in columns.items():
            for cell in cells:
                value = cell.value.decode("utf-8")
                print(f"{family}:{qualifier.decode('utf-8')} = {value}")

    client.close()


def insert_customer(row_key: str, name: str, status: str, email: str):
    client, table = get_table()

    row = table.direct_row(row_key.encode("utf-8"))

    row.set_cell("profile", "name", name)
    row.set_cell("profile", "status", status)
    row.set_cell("contact", "email", email)

    row.commit()

    print(f"Cliente {row_key} inserido com sucesso.")
    client.close()


def update_customer_status(row_key: str, status: str):
    client, table = get_table()

    row = table.direct_row(row_key.encode("utf-8"))
    row.set_cell("profile", "status", status)
    row.commit()

    print(f"Status de {row_key} atualizado para {status}.")
    client.close()


def delete_customer(row_key: str):
    client, table = get_table()

    row = table.direct_row(row_key.encode("utf-8"))
    row.delete()

    print(f"Cliente {row_key} excluído.")
    client.close()


def batch_insert_customers(customers: list[dict]):
    client, table = get_table()

    mutations = []

    for customer in customers:
        row = table.direct_row(customer["id"].encode("utf-8"))

        row.set_cell("profile", "name", customer["name"])
        row.set_cell("profile", "status", customer["status"])
        row.set_cell("contact", "email", customer["email"])

        mutations.append(row)

    table.mutate_rows(mutations)

    print(f"{len(customers)} clientes enviados para gravação.")

    client.close()



def batch_read_customers(row_keys: list[str]):
    client, table = get_table()

    row_set = RowSet()

    for key in row_keys:
        row_set.add_row_key(key.encode("utf-8"))

    rows = table.read_rows(row_set=row_set)

    for row in rows:
        print(f"\nCliente: {row.row_key.decode('utf-8')}")

        for family, columns in row.cells.items():
            for qualifier, cells in columns.items():
                latest_cell = cells[0]
                value = latest_cell.value.decode("utf-8")

                print(
                    f"{family}:{qualifier.decode('utf-8')} = {value}"
                )

    client.close()


def read_customer_filtered(row_key: str, filter_type: str):
    client, table = get_table()

    filters = {
        "profile": row_filters.FamilyNameRegexFilter("profile"),
        "contact": row_filters.FamilyNameRegexFilter("contact"),
        "status": row_filters.ColumnQualifierRegexFilter("status"),
    }

    row_filter = filters[filter_type]

    row = table.read_row(
        row_key.encode("utf-8"),
        filter_=row_filter,
    )

    if row is None:
        print("Cliente não encontrado.")
    else:
        print(f"\nCliente: {row_key}")

        for family, columns in row.cells.items():
            for qualifier, cells in columns.items():
                value = cells[0].value.decode("utf-8")
                print(f"{family}:{qualifier.decode('utf-8')} = {value}")

    client.close()


def read_customer_combined_filter(row_key: str):
    client, table = get_table()

    row_filter = row_filters.RowFilterChain(
        filters=[
            row_filters.FamilyNameRegexFilter("profile"),
            row_filters.ColumnQualifierRegexFilter("status"),
        ]
    )

    row = table.read_row(
        row_key.encode("utf-8"),
        filter_=row_filter,
    )

    if row:
        for family, columns in row.cells.items():
            for qualifier, cells in columns.items():
                value = cells[0].value.decode("utf-8")
                print(
                    f"{family}:{qualifier.decode('utf-8')} = {value}"
                )

    client.close()


def read_customers_by_rowkey():
    client, table = get_table()

    row_filter = row_filters.RowKeyRegexFilter(
        b"^customer#100[1-3]$"
    )

    rows = table.read_rows(filter_=row_filter)

    for row in rows:
        print(f"\nRow Key: {row.row_key.decode('utf-8')}")

        for family, columns in row.cells.items():
            for qualifier, cells in columns.items():
                value = cells[0].value.decode("utf-8")
                print(
                    f"{family}:{qualifier.decode('utf-8')} = {value}"
                )

    client.close()

if __name__ == "__main__":
    read_customers_by_rowkey()