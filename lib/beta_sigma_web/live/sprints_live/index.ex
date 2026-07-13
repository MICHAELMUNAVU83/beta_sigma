defmodule BetaSigmaWeb.SprintsLive.Index do
  use BetaSigmaWeb, :live_view

  alias BetaSigma.Projects
  alias BetaSigma.Projects.Sprint
  alias BetaSigmaWeb.Realtime

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> Realtime.bootstrap()
     |> Realtime.subscribe(projects_workspace: true)
     |> assign(:page_title, "Sprints")
     |> assign(:active_modal, nil)
     |> assign(:sprint_changeset, Projects.change_sprint(%Sprint{}))
     |> assign_catalog()}
  end

  def handle_info(%{event: _event} = payload, socket) do
    {:noreply,
     socket
     |> Realtime.sync_unread_count(Map.get(payload, :unread_count))
     |> Realtime.track_event(payload)
     |> assign_catalog()}
  end

  def handle_event("new_sprint", _params, socket) do
    {:noreply,
     socket
     |> assign(:sprint_changeset, Projects.change_sprint(%Sprint{}))
     |> assign(:active_modal, :sprint)}
  end

  def handle_event("close_modal", %{"modal" => "sprint"}, socket) do
    {:noreply,
     socket
     |> assign(:sprint_changeset, Projects.change_sprint(%Sprint{}))
     |> assign(:active_modal, nil)}
  end

  def handle_event("validate_sprint", %{"sprint" => params}, socket) do
    changeset =
      %Sprint{}
      |> Projects.change_sprint(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :sprint_changeset, changeset)}
  end

  def handle_event("save_sprint", %{"sprint" => params}, socket) do
    attrs = Map.put(params, "created_by_id", socket.assigns.current_user.id)

    case Projects.create_sprint(attrs) do
      {:ok, sprint} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sprint created.")
         |> assign(:active_modal, nil)
         |> assign(:sprint_changeset, Projects.change_sprint(%Sprint{}))
         |> push_navigate(to: ~p"/app/sprints/#{sprint.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :sprint_changeset, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("delete_sprint", %{"id" => id}, socket) do
    sprint = Projects.get_sprint!(id)

    case Projects.delete_sprint(sprint) do
      {:ok, _sprint} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sprint deleted.")
         |> assign_catalog()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Sprint could not be deleted.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <section class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-semibold tracking-tight text-neutral-900">Sprints</h1>
          <p class="mt-1 text-sm text-neutral-500">
            {length(@sprints)} total · {count_active(@sprints)} in progress
          </p>
        </div>
        <button
          type="button"
          phx-click="new_sprint"
          class="rounded-md bg-[#f26334] px-3 py-1.5 text-sm font-medium text-white transition hover:bg-[#d9532a] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#f26334]/40"
        >
          New sprint
        </button>
      </section>

      <section class="grid gap-4 lg:grid-cols-2 xl:grid-cols-3">
        <div
          :for={sprint <- @sprints}
          class="rounded-lg border border-neutral-200 bg-white p-4 transition hover:bg-neutral-50"
        >
          <div class="flex items-start justify-between gap-3">
            <span class={sprint_status_badge(sprint)}>{sprint_status_label(sprint)}</span>
            <button
              type="button"
              phx-click="delete_sprint"
              phx-value-id={sprint.id}
              data-confirm="Delete this sprint? Tasks will be unassigned from it."
              class="shrink-0 rounded-md px-2 py-1 text-xs font-medium text-red-600 hover:bg-red-50"
            >
              Delete
            </button>
          </div>

          <.link navigate={~p"/app/sprints/#{sprint.id}"} class="mt-2 block">
            <p class="text-base font-semibold text-neutral-900">{sprint.name}</p>
            <p class="mt-0.5 text-xs text-neutral-500">
              {format_date(sprint.start_date)} → {format_date(sprint.end_date)}
            </p>

            <p class="mt-3 line-clamp-3 text-sm leading-6 text-neutral-500">
              {sprint.goal || "Add a goal to describe what this sprint should accomplish."}
            </p>

            <div class="mt-4 flex items-center justify-between text-xs text-neutral-500">
              <span>{length(sprint.tasks)} tasks</span>
              <span>{humanize(sprint.cadence)}</span>
            </div>
          </.link>
        </div>

        <div
          :if={@sprints == []}
          class="rounded-lg border border-dashed border-neutral-200 p-6 text-center text-sm text-neutral-500 lg:col-span-2 xl:col-span-3"
        >
          No sprints yet. Create one to start planning work across projects.
        </div>
      </section>

      <.modal
        :if={@active_modal == :sprint}
        id="sprints-new-sprint-modal"
        show
        on_cancel={JS.push("close_modal", value: %{modal: "sprint"})}
      >
        <div>
          <h3 class="text-base font-semibold text-neutral-900">New sprint</h3>
          <p class="mt-1 text-sm text-neutral-500">
            Sprints are independent of any single project — add tasks from any project once it's created.
          </p>
        </div>

        <.simple_form
          id="sprints-new-sprint-form"
          for={to_form(@sprint_changeset)}
          phx-change="validate_sprint"
          phx-submit="save_sprint"
        >
          <.input field={to_form(@sprint_changeset)[:name]} label="Sprint title" />
          <.input
            field={to_form(@sprint_changeset)[:goal]}
            type="textarea"
            label="Goal"
            rows="3"
            placeholder="What should this sprint accomplish?"
          />
          <div class="grid gap-4 sm:grid-cols-2">
            <.input
              field={to_form(@sprint_changeset)[:cadence]}
              type="select"
              label="Cadence"
              options={cadence_options()}
            />
            <.input field={to_form(@sprint_changeset)[:start_date]} type="date" label="Start date" />
          </div>
          <div class="rounded-lg border border-neutral-200 bg-neutral-50 px-4 py-4 text-sm text-neutral-700">
            <p class="text-xs text-neutral-500">Ends</p>
            <p class="mt-1 text-sm font-medium text-neutral-900">
              {format_date(end_date(@sprint_changeset))}
            </p>
          </div>
          <:actions>
            <button
              type="button"
              phx-click="close_modal"
              phx-value-modal="sprint"
              class="rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
            >
              Cancel
            </button>
            <.button>Create sprint</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  defp assign_catalog(socket) do
    assign(socket, :sprints, Projects.list_sprints())
  end

  defp count_active(sprints) do
    today = Date.utc_today()

    Enum.count(sprints, fn sprint ->
      Date.compare(sprint.start_date, today) in [:lt, :eq] and
        Date.compare(sprint.end_date, today) in [:gt, :eq]
    end)
  end

  defp sprint_status_label(sprint) do
    today = Date.utc_today()

    cond do
      Date.compare(today, sprint.start_date) == :lt -> "Upcoming"
      Date.compare(today, sprint.end_date) == :gt -> "Completed"
      true -> "In progress"
    end
  end

  defp sprint_status_badge(sprint) do
    base = "shrink-0 rounded bg-neutral-100 px-1.5 py-0.5 text-xs font-medium"

    case sprint_status_label(sprint) do
      "Upcoming" -> base <> " text-neutral-500"
      "In progress" -> base <> " text-emerald-600"
      "Completed" -> base <> " text-sky-600"
    end
  end

  defp cadence_options do
    [{"Weekly", :weekly}, {"2 weeks", :biweekly}]
  end

  defp end_date(%Ecto.Changeset{} = changeset), do: Ecto.Changeset.get_field(changeset, :end_date)

  defp humanize(value) when is_atom(value), do: value |> Atom.to_string() |> humanize()

  defp humanize(value) when is_binary(value) do
    value
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_date(nil), do: "No date"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
end
