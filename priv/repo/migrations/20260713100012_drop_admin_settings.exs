defmodule BetaSigma.Repo.Migrations.DropAdminSettings do
  use Ecto.Migration

  def change do
    drop table(:admin_settings)
  end
end
