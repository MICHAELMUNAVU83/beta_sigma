defmodule BetaSigma.Repo.Migrations.AddPinToChatMessages do
  use Ecto.Migration

  def change do
    alter table(:chat_messages) do
      add :pinned_at, :utc_datetime
      add :pinned_by_id, references(:users, on_delete: :nilify_all)
    end

    create index(:chat_messages, [:channel_id, :pinned_at])
    create index(:chat_messages, [:conversation_id, :pinned_at])
  end
end
