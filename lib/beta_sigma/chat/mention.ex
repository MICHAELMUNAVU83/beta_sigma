defmodule BetaSigma.Chat.Mention do
  use Ecto.Schema
  import Ecto.Changeset

  alias BetaSigma.Accounts.User
  alias BetaSigma.Chat.Message

  schema "chat_mentions" do
    field :read_at, :utc_datetime

    belongs_to :message, Message
    belongs_to :mentioned_user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(mention, attrs) do
    mention
    |> cast(attrs, [:message_id, :mentioned_user_id, :read_at])
    |> validate_required([:message_id, :mentioned_user_id])
  end
end
