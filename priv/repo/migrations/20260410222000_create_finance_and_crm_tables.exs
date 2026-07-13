defmodule BetaSigma.Repo.Migrations.CreateFinanceAndCrmTables do
  use Ecto.Migration

  def change do
    create table(:deals) do
      add :name, :string, null: false
      add :value, :decimal, precision: 15, scale: 2
      add :stage, :string, null: false, default: "lead"
      add :expected_close, :date
      add :client_id, references(:clients, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:deals, [:client_id])
    create index(:deals, [:created_by_id])
    create index(:deals, [:stage])

    create table(:invoices) do
      add :number, :string, null: false
      add :status, :string, null: false, default: "draft"
      add :due_date, :date
      add :currency, :string, null: false, default: "KES"
      add :notes, :text
      add :client_id, references(:clients, on_delete: :nilify_all)
      add :project_id, references(:projects, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:invoices, [:number])
    create index(:invoices, [:client_id])
    create index(:invoices, [:project_id])
    create index(:invoices, [:status])
    create index(:invoices, [:due_date])

    create table(:invoice_items) do
      add :description, :string, null: false
      add :quantity, :decimal, precision: 10, scale: 2, null: false
      add :unit_price, :decimal, precision: 15, scale: 2, null: false
      add :invoice_id, references(:invoices, on_delete: :delete_all), null: false
    end

    create index(:invoice_items, [:invoice_id])

    create table(:expenses) do
      add :description, :string, null: false
      add :amount, :decimal, precision: 15, scale: 2, null: false
      add :category, :string
      add :date, :date
      add :receipt_url, :string
      add :project_id, references(:projects, on_delete: :nilify_all)
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:expenses, [:project_id])
    create index(:expenses, [:created_by_id])
    create index(:expenses, [:category])
    create index(:expenses, [:date])
  end
end
