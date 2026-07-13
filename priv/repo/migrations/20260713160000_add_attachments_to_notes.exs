defmodule BetaSigma.Repo.Migrations.AddAttachmentsToNotes do
  use Ecto.Migration

  def change do
    alter table(:notes) do
      add :attachments, {:array, :map}, default: [], null: false
    end
  end
end
