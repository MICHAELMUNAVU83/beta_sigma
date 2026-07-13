defmodule BetaSigma.Repo.Migrations.DropFinanceAndCrmTables do
  use Ecto.Migration

  def change do
    drop table(:invoice_items)
    drop table(:invoices)
    drop table(:deals)
    drop table(:clients)
  end
end
