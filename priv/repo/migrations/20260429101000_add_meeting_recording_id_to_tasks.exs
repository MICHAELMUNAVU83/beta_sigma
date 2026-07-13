defmodule BetaSigma.Repo.Migrations.AddMeetingRecordingIdToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :meeting_recording_id,
          references(:meeting_recordings, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:tasks, [:meeting_recording_id])
  end
end
