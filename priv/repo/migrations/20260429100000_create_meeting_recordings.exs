defmodule BetaSigma.Repo.Migrations.CreateMeetingRecordings do
  use Ecto.Migration

  def change do
    create table(:meeting_recordings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :recorded_at, :utc_datetime, null: false
      add :duration_seconds, :integer
      add :raw_transcript, :text
      add :summary, :text
      add :markdown_minutes, :text
      add :participants, {:array, :string}, null: false, default: []
      add :minutes_payload, :map
      add :action_items_count, :integer, null: false, default: 0
      add :project_id, references(:projects, on_delete: :nilify_all)
      add :created_by_id, references(:users, on_delete: :nilify_all)
      add :status, :string, null: false, default: "recording"
      add :chunks_received, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:meeting_recordings, [:recorded_at])
    create index(:meeting_recordings, [:project_id])
    create index(:meeting_recordings, [:created_by_id])
    create index(:meeting_recordings, [:status])
  end
end
