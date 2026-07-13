defmodule BetaSigma.Repo.Migrations.DropMeetingTables do
  use Ecto.Migration

  def change do
    drop table(:meeting_audio_chunks)
    drop table(:meeting_recordings)
  end
end
