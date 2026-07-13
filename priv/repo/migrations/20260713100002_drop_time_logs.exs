defmodule BetaSigma.Repo.Migrations.DropTimeLogs do
  use Ecto.Migration

  def change do
    drop table(:time_logs)
  end
end
