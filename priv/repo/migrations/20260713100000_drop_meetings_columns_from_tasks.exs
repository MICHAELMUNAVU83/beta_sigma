defmodule BetaSigma.Repo.Migrations.DropMeetingsColumnsFromTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      remove :meeting_recording_id, references(:meeting_recordings, type: :binary_id)
    end
  end
end
