defmodule BetaSigma.Repo.Migrations.CreateMeetingAudioChunks do
  use Ecto.Migration

  def change do
    create table(:meeting_audio_chunks, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :meeting_recording_id,
          references(:meeting_recordings, type: :binary_id, on_delete: :delete_all),
          null: false

      add :chunk_index, :integer, null: false
      add :data, :binary, null: false
      add :byte_size, :integer, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:meeting_audio_chunks, [:meeting_recording_id, :chunk_index])
    create index(:meeting_audio_chunks, [:meeting_recording_id])
  end
end
