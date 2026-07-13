defmodule BetaSigma.Repo.Migrations.DropProposals do
  use Ecto.Migration

  def change do
    drop table(:proposals)
  end
end
