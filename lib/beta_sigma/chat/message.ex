defmodule BetaSigma.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  alias BetaSigma.Accounts.User
  alias BetaSigma.Chat.{Channel, Conversation, Mention, Reaction}

  schema "chat_messages" do
    field :body, :string, default: ""
    field :edited_at, :utc_datetime
    field :deleted_at, :utc_datetime
    field :attachments, {:array, :map}, default: []
    field :pinned_at, :utc_datetime

    belongs_to :user, User
    belongs_to :channel, Channel
    belongs_to :conversation, Conversation
    belongs_to :pinned_by, User
    has_many :mentions, Mention
    has_many :reactions, Reaction

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:body, :user_id, :channel_id, :conversation_id, :attachments])
    |> validate_required([:user_id])
    |> validate_length(:body, max: 10_000)
    |> validate_body_or_attachments()
    |> validate_exactly_one_target()
  end

  def edit_changeset(message, attrs) do
    message
    |> cast(attrs, [:body])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 10_000)
    |> put_change(:edited_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp validate_body_or_attachments(changeset) do
    body = get_field(changeset, :body) || ""
    attachments = get_field(changeset, :attachments) || []

    if String.trim(body) == "" && Enum.empty?(attachments) do
      add_error(changeset, :body, "can't be blank")
    else
      changeset
    end
  end

  defp validate_exactly_one_target(changeset) do
    channel_id = get_field(changeset, :channel_id)
    conversation_id = get_field(changeset, :conversation_id)

    cond do
      channel_id && conversation_id ->
        add_error(changeset, :base, "message must belong to a channel or conversation, not both")

      is_nil(channel_id) && is_nil(conversation_id) ->
        add_error(changeset, :base, "message must belong to a channel or conversation")

      true ->
        changeset
    end
  end
end
