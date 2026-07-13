defmodule BetaSigma.Repo.Migrations.DropClientColumnFromProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      remove :client_id, references(:clients)
    end
  end
end
