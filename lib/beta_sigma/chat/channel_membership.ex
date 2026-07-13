defmodule BetaSigma.Chat.ChannelMembership do
  use Ecto.Schema
  import Ecto.Changeset

  alias BetaSigma.Accounts.User
  alias BetaSigma.Chat.Channel

  @role_values [:owner, :member]

  schema "chat_channel_memberships" do
    field :role, Ecto.Enum, values: @role_values, default: :member
    field :last_read_at, :utc_datetime

    belongs_to :channel, Channel
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:channel_id, :user_id, :role, :last_read_at])
    |> validate_required([:channel_id, :user_id])
    |> unique_constraint([:channel_id, :user_id])
  end
end
