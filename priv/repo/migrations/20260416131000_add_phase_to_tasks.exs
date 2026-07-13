defmodule BetaSigma.Repo.Migrations.AddPhaseToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :phase, :string
    end

    create index(:tasks, [:phase])
  end
end
