defmodule BetaSigma.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  alias BetaSigma.Accounts.User
  alias BetaSigma.Chat.{ConversationMembership, Message}

  @kind_values [:dm, :group_dm]

  schema "chat_conversations" do
    field :kind, Ecto.Enum, values: @kind_values, default: :dm
    field :unread_count, :integer, virtual: true, default: 0

    belongs_to :created_by, User
    has_many :memberships, ConversationMembership
    has_many :members, through: [:memberships, :user]
    has_many :messages, Message

    timestamps(type: :utc_datetime)
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:kind, :created_by_id])
    |> validate_required([:kind, :created_by_id])
  end

  def kind_values, do: @kind_values
end
