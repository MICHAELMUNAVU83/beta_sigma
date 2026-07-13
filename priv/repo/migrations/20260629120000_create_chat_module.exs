defmodule BetaSigma.Repo.Migrations.CreateChatModule do
  use Ecto.Migration

  def change do
    create table(:chat_channels) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :kind, :string, null: false, default: "public"
      add :topic, :string
      add :description, :text
      add :created_by_id, references(:users, on_delete: :nilify_all)
      add :archived_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chat_channels, [:slug])
    create index(:chat_channels, [:kind])

    create table(:chat_channel_memberships) do
      add :channel_id, references(:chat_channels, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "member"
      add :last_read_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chat_channel_memberships, [:channel_id, :user_id])
    create index(:chat_channel_memberships, [:user_id])

    create table(:chat_conversations) do
      add :kind, :string, null: false, default: "dm"
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:chat_conversations, [:created_by_id])

    create table(:chat_conversation_memberships) do
      add :conversation_id, references(:chat_conversations, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :last_read_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chat_conversation_memberships, [:conversation_id, :user_id])
    create index(:chat_conversation_memberships, [:user_id])

    create table(:chat_messages) do
      add :body, :text, null: false
      add :user_id, references(:users, on_delete: :nilify_all)
      add :channel_id, references(:chat_channels, on_delete: :delete_all)
      add :conversation_id, references(:chat_conversations, on_delete: :delete_all)
      add :edited_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:channel_id, :inserted_at])
    create index(:chat_messages, [:conversation_id, :inserted_at])
    create index(:chat_messages, [:user_id])

    create table(:chat_mentions) do
      add :message_id, references(:chat_messages, on_delete: :delete_all), null: false
      add :mentioned_user_id, references(:users, on_delete: :delete_all), null: false
      add :read_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:chat_mentions, [:mentioned_user_id])
    create index(:chat_mentions, [:message_id])
  end
end
