defmodule BetaSigma.Repo.Migrations.DropMailboxTables do
  use Ecto.Migration

  def change do
    drop table(:messages)
    drop table(:mailboxes)
  end
end
