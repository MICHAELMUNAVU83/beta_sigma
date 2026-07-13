defmodule BetaSigma.Chat.Reaction do
  use Ecto.Schema
  import Ecto.Changeset

  alias BetaSigma.Accounts.User
  alias BetaSigma.Chat.Message

  @allowed_emojis ~w(👍 ❤️ 😂 🎉 👀)

  schema "chat_message_reactions" do
    field :emoji, :string

    belongs_to :message, Message
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def allowed_emojis, do: @allowed_emojis

  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:message_id, :user_id, :emoji])
    |> validate_required([:message_id, :user_id, :emoji])
    |> validate_inclusion(:emoji, @allowed_emojis)
    |> unique_constraint([:message_id, :user_id, :emoji],
      name: :chat_message_reactions_message_id_user_id_emoji_index
    )
  end
end
