defmodule BetaSigmaWeb.ProjectsLive.Index do
  use BetaSigmaWeb, :live_view

  alias BetaSigma.Projects
  alias BetaSigma.Projects.Project
  alias BetaSigmaWeb.Realtime

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> Realtime.bootstrap()
     |> Realtime.subscribe(projects_workspace: true)
     |> assign(:page_title, "Projects")
     |> assign(:active_modal, nil)
     |> assign(:project_changeset, Projects.change_project(%Project{}))
     |> assign_catalog()}
  end

  def handle_info(%{event: _event} = payload, socket) do
    {:noreply,
     socket
     |> Realtime.sync_unread_count(Map.get(payload, :unread_count))
     |> Realtime.track_event(payload)
     |> assign_catalog()}
  end

  def handle_event("validate_project", %{"project" => params}, socket) do
    changeset =
      %Project{}
      |> Projects.change_project(project_params(params, socket.assigns.current_user.id))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :project_changeset, changeset)}
  end

  def handle_event("new_project", _params, socket) do
    {:noreply,
     socket
     |> assign(:project_changeset, Projects.change_project(%Project{}))
     |> assign(:active_modal, :project)}
  end

  def handle_event("close_modal", %{"modal" => "project"}, socket) do
    {:noreply,
     socket
     |> assign(:project_changeset, Projects.change_project(%Project{}))
     |> assign(:active_modal, nil)}
  end

  def handle_event("save_project", %{"project" => params}, socket) do
    case Projects.create_project_with_ai(
           project_params(params, socket.assigns.current_user.id),
           socket.assigns.current_user
         ) do
      {:ok, project, ai_result} ->
        {:noreply,
         socket
         |> put_flash(:info, project_created_message(ai_result))
         |> assign(:active_modal, nil)
         |> assign(:project_changeset, Projects.change_project(%Project{}))
         |> assign_catalog()
         |> push_navigate(to: ~p"/app/projects/#{project.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :project_changeset, Map.put(changeset, :action, :insert))}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <section class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-semibold tracking-tight text-neutral-900">Projects</h1>
          <p class="mt-1 text-sm text-neutral-500">
            {length(@projects)} total · {count_projects(@projects, [:active, :planning, :on_hold])} active · {count_projects(
              @projects,
              [:completed]
            )} completed
          </p>
        </div>
        <button
          type="button"
          phx-click="new_project"
          class="rounded-md bg-[#f26334] px-3 py-1.5 text-sm font-medium text-white transition hover:bg-[#d9532a] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#f26334]/40"
        >
          New project
        </button>
      </section>

      <section class="grid gap-4 lg:grid-cols-2 xl:grid-cols-3">
        <.link
          :for={project <- @projects}
          navigate={~p"/app/projects/#{project.id}"}
          class="group rounded-lg border border-neutral-200 bg-white p-4 transition hover:bg-neutral-50"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
              <p class="text-base font-semibold text-neutral-900">{project.name}</p>
            </div>
            <span class={status_badge(project.status)}>{humanize(project.status)}</span>
          </div>

          <p class="mt-3 line-clamp-3 text-sm leading-6 text-neutral-500">
            {project.description ||
              "Add a project brief to align delivery scope, milestones, and operating context."}
          </p>

          <dl class="mt-4 grid gap-3 text-sm sm:grid-cols-2">
            <div>
              <dt class="text-xs text-neutral-500">Deadline</dt>
              <dd class="mt-0.5 text-sm text-neutral-900">{format_date(project.deadline)}</dd>
            </div>
            <div>
              <dt class="text-xs text-neutral-500">Budget</dt>
              <dd class="mt-0.5 text-sm text-neutral-900">{format_money(project.budget)}</dd>
            </div>
          </dl>

          <div class="mt-4 text-xs text-neutral-500">
            Created by {display_name(project.created_by)}
          </div>
        </.link>
      </section>

      <.modal
        :if={@active_modal == :project}
        id="projects-new-project-modal"
        show
        on_cancel={JS.push("close_modal", value: %{modal: "project"})}
      >
        <div>
          <h3 class="text-base font-semibold text-neutral-900">New project</h3>
          <p class="mt-1 text-sm text-neutral-500">
            Create a project shell with budget, timeline, and delivery notes.
          </p>
        </div>

        <.simple_form
          id="projects-new-project-form"
          for={to_form(@project_changeset)}
          phx-change="validate_project"
          phx-submit="save_project"
        >
          <.input field={to_form(@project_changeset)[:name]} label="Project name" />
          <.input
            field={to_form(@project_changeset)[:status]}
            type="select"
            label="Status"
            options={status_options()}
          />
          <div class="grid gap-4 sm:grid-cols-2">
            <.input field={to_form(@project_changeset)[:start_date]} type="date" label="Start date" />
            <.input field={to_form(@project_changeset)[:deadline]} type="date" label="Deadline" />
          </div>
          <.input
            field={to_form(@project_changeset)[:budget]}
            type="number"
            step="0.01"
            label="Budget"
          />
          <.input
            field={to_form(@project_changeset)[:description]}
            type="textarea"
            label="Description"
            rows="4"
          />
          <div class="rounded-lg border border-neutral-200 bg-neutral-50 p-4">
            <p class="text-sm font-medium text-neutral-700">AI assist</p>
            <p class="mt-1 text-sm leading-6 text-neutral-500">
              Describe the project in plain language and the system will draft starter tasks and save a shared markdown project brief to the database.
            </p>
            <.input
              field={to_form(@project_changeset)[:ai_prompt]}
              type="textarea"
              label="What should this project include?"
              rows="6"
              placeholder="Example: Build a client portal where suppliers can submit onboarding documents, admins can review applications, and the team can track approvals and reminders."
            />
          </div>
          <:actions>
            <button
              type="button"
              phx-click="close_modal"
              phx-value-modal="project"
              class="rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
            >
              Cancel
            </button>
            <.button>Create project</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  defp assign_catalog(socket) do
    projects = Projects.list_projects()

    assign(socket, projects: projects)
  end

  defp project_params(params, current_user_id) do
    params
    |> Map.put("created_by_id", current_user_id)
    |> Map.update("description", "", &String.trim/1)
    |> Map.update("ai_prompt", "", &String.trim/1)
  end

  defp count_projects(projects, statuses) do
    Enum.count(projects, &(&1.status in statuses))
  end

  defp status_options do
    [
      {"Planning", :planning},
      {"Active", :active},
      {"On hold", :on_hold},
      {"Completed", :completed},
      {"Archived", :archived}
    ]
  end

  defp status_badge(:planning),
    do: "shrink-0 rounded bg-neutral-100 px-1.5 py-0.5 text-xs font-medium text-neutral-600"

  defp status_badge(:active),
    do: "shrink-0 rounded bg-neutral-100 px-1.5 py-0.5 text-xs font-medium text-emerald-600"

  defp status_badge(:on_hold),
    do: "shrink-0 rounded bg-neutral-100 px-1.5 py-0.5 text-xs font-medium text-amber-600"

  defp status_badge(:completed),
    do: "shrink-0 rounded bg-neutral-100 px-1.5 py-0.5 text-xs font-medium text-neutral-500"

  defp status_badge(_status),
    do: "shrink-0 rounded bg-neutral-100 px-1.5 py-0.5 text-xs font-medium text-red-600"

  defp humanize(value) when is_atom(value), do: value |> Atom.to_string() |> humanize()

  defp humanize(value) when is_binary(value) do
    value
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_date(nil), do: "No date"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")

  defp format_money(nil), do: "No budget"
  defp format_money(budget), do: BetaSigma.Formatting.money(budget)

  defp project_created_message(%{ai_requested: false}), do: "Project created."

  defp project_created_message(%{ai_error: reason}) do
    "Project created. AI planning could not finish (#{humanize_ai_error(reason)}), so no starter tasks were generated."
  end

  defp project_created_message(%{generated_tasks_count: count, generated_note: note}) do
    cond do
      count > 0 and not is_nil(note) ->
        "Project created. AI drafted #{count} starter #{pluralize("task", count)} and saved a shared project brief."

      count > 0 ->
        "Project created. AI drafted #{count} starter #{pluralize("task", count)}."

      not is_nil(note) ->
        "Project created. AI saved a shared project brief."

      true ->
        "Project created."
    end
  end

  defp pluralize(word, 1), do: word
  defp pluralize(word, _count), do: "#{word}s"

  defp humanize_ai_error(:missing_openai_api_key), do: "the OpenAI API key is missing"
  defp humanize_ai_error(:invalid_json), do: "the AI response could not be read"
  defp humanize_ai_error(:invalid_project_plan), do: "the AI response was incomplete"
  defp humanize_ai_error(:empty_project_plan), do: "the AI returned an empty plan"
  defp humanize_ai_error(:empty_response), do: "the AI returned no content"
  defp humanize_ai_error({:http_error, status}), do: "OpenAI returned HTTP #{status}"
  defp humanize_ai_error({:request_failed, _reason}), do: "the OpenAI request failed"
  defp humanize_ai_error(_reason), do: "the AI planner is unavailable right now"
end
