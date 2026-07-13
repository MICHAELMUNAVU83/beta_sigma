defmodule BetaSigma.Notes do
  @moduledoc """
  The Notes context.
  """

  import Ecto.Query, warn: false

  alias BetaSigma.Accounts.User
  alias BetaSigma.Notes.Note
  alias BetaSigma.Repo

  def list_notes(%User{} = user, filters \\ []) do
    Note
    |> visible_to(user)
    |> maybe_filter_visibility(filters[:visibility])
    |> maybe_filter_project(filters[:project_id])
    |> maybe_filter_task(filters[:task_id])
    |> maybe_filter_query(filters[:query])
    |> order_by([note], desc: note.inserted_at)
    |> preload([:project, :task, :created_by])
    |> Repo.all()
  end

  def get_note!(id, %User{} = user) do
    Note
    |> visible_to(user)
    |> preload([:project, :task, :created_by])
    |> Repo.get!(id)
  end

  def create_note(attrs) do
    %Note{}
    |> Note.changeset(attrs)
    |> Repo.insert()
  end

  def update_note(%Note{} = note, attrs) do
    note
    |> Note.changeset(attrs)
    |> Repo.update()
  end

  def delete_note(%Note{} = note), do: Repo.delete(note)

  def change_note(%Note{} = note, attrs \\ %{}) do
    Note.changeset(note, attrs)
  end

  defp visible_to(query, %User{id: user_id}) do
    from(note in query,
      where: note.visibility == :shared or note.created_by_id == ^user_id
    )
  end

  defp maybe_filter_visibility(query, nil), do: query

  defp maybe_filter_visibility(query, visibility) do
    from(note in query, where: note.visibility == ^visibility)
  end

  defp maybe_filter_project(query, nil), do: query

  defp maybe_filter_project(query, project_id) do
    from(note in query, where: note.project_id == ^project_id)
  end

  defp maybe_filter_task(query, nil), do: query

  defp maybe_filter_task(query, task_id) do
    from(note in query, where: note.task_id == ^task_id)
  end

  defp maybe_filter_query(query, nil), do: query

  defp maybe_filter_query(query, search_term) do
    pattern = "%#{search_term}%"

    from(note in query,
      where: ilike(note.title, ^pattern) or ilike(note.body, ^pattern)
    )
  end
end
