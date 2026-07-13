defmodule BetaSigma.Repo.Migrations.CreateProposals do
  use Ecto.Migration

  def change do
    create table(:proposals) do
      add :title, :string, null: false
      add :client_name, :string, null: false
      add :proposal_type, :string, null: false, default: "technical_proposal"
      add :audience, :string
      add :objective, :text
      add :reference_url, :string
      add :raw_notes, :text
      add :source_notes, :text
      add :generated_content, :text
      add :summary, :text
      add :solution_areas, {:array, :string}, null: false, default: []
      add :selected_note_ids, {:array, :integer}, null: false, default: []
      add :status, :string, null: false, default: "draft"
      add :visibility, :string, null: false, default: "shared"
      add :generation_meta, :map, null: false, default: %{}
      add :created_by_id, references(:users, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:proposals, [:created_by_id])
    create index(:proposals, [:visibility])
    create index(:proposals, [:proposal_type])
    create index(:proposals, [:status])
    create index(:proposals, [:inserted_at])
  end
end
