defmodule BetaSigma.Chat.ConversationMembership do
  use Ecto.Schema
  import Ecto.Changeset

  alias BetaSigma.Accounts.User
  alias BetaSigma.Chat.Conversation

  schema "chat_conversation_memberships" do
    field :last_read_at, :utc_datetime

    belongs_to :conversation, Conversation
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:conversation_id, :user_id, :last_read_at])
    |> validate_required([:conversation_id, :user_id])
    |> unique_constraint([:conversation_id, :user_id])
  end
end
