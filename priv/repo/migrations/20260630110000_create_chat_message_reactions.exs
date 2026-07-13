defmodule BetaSigma.Repo.Migrations.CreateChatMessageReactions do
  use Ecto.Migration

  def change do
    create table(:chat_message_reactions) do
      add :message_id, references(:chat_messages, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :emoji, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chat_message_reactions, [:message_id])
    create index(:chat_message_reactions, [:user_id])
    create unique_index(:chat_message_reactions, [:message_id, :user_id, :emoji])
  end
end
