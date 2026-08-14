defmodule BetaSigma.Discovery.Session do
  @moduledoc """
  One discovery interview for a department. A department can be interviewed
  many times (different people, or a second pass), and each session carries
  its own answer set.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @statuses [:in_progress, :complete, :archived]

  schema "discovery_sessions" do
    field :interviewee, :string
    field :interviewee_role, :string
    field :interviewer, :string
    field :held_on, :date
    field :status, Ecto.Enum, values: @statuses, default: :in_progress

    belongs_to :department, BetaSigma.Discovery.Department
    belongs_to :created_by, BetaSigma.Accounts.User
    has_many :answers, BetaSigma.Discovery.Answer

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :department_id,
      :interviewee,
      :interviewee_role,
      :interviewer,
      :held_on,
      :status,
      :created_by_id
    ])
    |> validate_required([:department_id, :status])
    |> validate_length(:interviewee, max: 200)
    |> validate_length(:interviewer, max: 200)
    |> foreign_key_constraint(:department_id)
    |> foreign_key_constraint(:created_by_id)
  end

  @doc "Human label for a session, used in pickers."
  def label(%__MODULE__{} = session) do
    [session.interviewee, session.interviewee_role]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> case do
      [] -> "Untitled session"
      parts -> Enum.join(parts, " · ")
    end
  end
end
