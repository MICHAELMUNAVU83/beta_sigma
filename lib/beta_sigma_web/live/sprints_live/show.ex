defmodule BetaSigmaWeb.SprintsLive.Show do
  use BetaSigmaWeb, :live_view

  alias BetaSigma.Accounts
  alias BetaSigma.Accounts.User
  alias BetaSigma.Projects
  alias BetaSigma.Projects.{Mentions, Task}
  alias BetaSigma.Uploads
  alias BetaSigmaWeb.Realtime

  @task_statuses [:backlog, :in_progress, :review, :done]

  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> Realtime.bootstrap()
     |> Realtime.subscribe(projects_workspace: true)
     |> assign(:active_modal, nil)
     |> assign(:task_statuses, @task_statuses)
     |> assign(:task_status_filter, "all")
     |> assign(:task_assignee_filter, "all")
     |> assign(:task_project_filter, "all")
     |> assign(:task_search_filter, "")
     |> assign(:add_task_search, "")
     |> assign(:add_task_project_filter, "all")
     |> assign(:bulk_task_form, to_form(default_bulk_task_params(), as: :bulk_tasks))
     |> assign(:bulk_task_drafts, [])
     |> assign(:bulk_task_assignee_ids, [])
     |> assign(:task_mode, :new)
     |> assign(:task_assignee_ids, [])
     |> assign(:selected_task_id, nil)
     |> assign(:comment_form, to_form(%{"body" => ""}, as: :comment))
     |> assign_catalog()
     |> load_sprint(id)
     |> assign_task_editor(%Task{sprint_id: String.to_integer(id)}, :new)
     |> allow_task_image_uploads()}
  end

  def handle_info(%{event: event} = payload, socket)
      when event in [
             :sprint_created,
             :sprint_updated,
             :sprint_deleted,
             :task_created,
             :task_updated,
             :task_deleted,
             :task_moved,
             :task_assigned,
             :task_comment_added
           ] do
    {:noreply,
     socket
     |> Realtime.track_event(payload)
     |> assign_catalog()
     |> load_sprint(socket.assigns.sprint.id)}
  end

  def handle_info(%{event: _event} = payload, socket) do
    {:noreply,
     socket
     |> Realtime.sync_unread_count(Map.get(payload, :unread_count))
     |> Realtime.track_event(payload)}
  end

  def handle_event("edit_sprint", _params, socket) do
    {:noreply,
     socket
     |> assign(:sprint_changeset, Projects.change_sprint(socket.assigns.sprint))
     |> assign(:active_modal, :sprint)}
  end

  def handle_event("close_modal", %{"modal" => "sprint"}, socket) do
    {:noreply, assign(socket, :active_modal, nil)}
  end

  def handle_event("close_modal", %{"modal" => "add_task"}, socket) do
    {:noreply,
     socket
     |> assign(:add_task_search, "")
     |> assign(:add_task_project_filter, "all")
     |> assign(:active_modal, nil)}
  end

  def handle_event("close_modal", %{"modal" => "bulk_tasks"}, socket) do
    {:noreply,
     socket
     |> reset_bulk_task_import()
     |> assign(:active_modal, nil)}
  end

  def handle_event("close_modal", %{"modal" => "task"}, socket) do
    {:noreply,
     socket
     |> assign_task_editor(%Task{sprint_id: socket.assigns.sprint.id}, :new)
     |> assign(:active_modal, nil)}
  end

  def handle_event("close_modal", %{"modal" => "comments"}, socket) do
    {:noreply,
     socket
     |> assign(:comment_form, to_form(%{"body" => ""}, as: :comment))
     |> assign(:active_modal, nil)}
  end

  def handle_event("open_add_task", _params, socket) do
    {:noreply, assign(socket, :active_modal, :add_task)}
  end

  def handle_event("open_bulk_tasks", _params, socket) do
    {:noreply, assign(socket, :active_modal, :bulk_tasks)}
  end

  def handle_event("download_bulk_tasks_md", _params, socket) do
    {:noreply,
     push_event(socket, "download:file", %{
       filename: sprint_task_plan_filename(socket.assigns.sprint),
       content_type: "text/markdown;charset=utf-8",
       content: Projects.sprint_task_plan_markdown(socket.assigns.sprint, socket.assigns.projects)
     })}
  end

  def handle_event("preview_bulk_tasks", %{"bulk_tasks" => params}, socket) do
    markdown = Map.get(params, "markdown", "")
    assignee_ids = normalize_ids(params["assignee_ids"])

    case Projects.parse_sprint_task_markdown(markdown) do
      {:ok, drafts} ->
        {:noreply,
         socket
         |> assign(:bulk_task_form, to_form(normalize_bulk_task_params(params), as: :bulk_tasks))
         |> assign(:bulk_task_assignee_ids, assignee_ids)
         |> assign(:bulk_task_drafts, drafts)}

      {:error, :no_tasks_found} ->
        {:noreply,
         socket
         |> assign(:bulk_task_form, to_form(normalize_bulk_task_params(params), as: :bulk_tasks))
         |> assign(:bulk_task_assignee_ids, assignee_ids)
         |> assign(:bulk_task_drafts, [])}
    end
  end

  def handle_event("create_bulk_tasks", %{"bulk_tasks" => params}, socket) do
    project_id = Map.get(params, "project_id")
    markdown = Map.get(params, "markdown", "")
    assignee_ids = normalize_ids(params["assignee_ids"])

    case Projects.create_sprint_tasks_from_markdown(
           socket.assigns.sprint,
           socket.assigns.current_user,
           project_id,
           markdown,
           assignee_ids
         ) do
      {:ok, tasks} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{length(tasks)} tasks created.")
         |> reset_bulk_task_import()
         |> assign(:active_modal, nil)
         |> assign_catalog()
         |> load_sprint(socket.assigns.sprint.id)}

      {:error, :no_tasks_found} ->
        {:noreply, put_flash(socket, :error, "No tasks found. Preview the Markdown first.")}

      {:error, :project_not_found} ->
        {:noreply, put_flash(socket, :error, "Select the project these tasks belong to.")}

      {:error, _reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Tasks could not be created. Check the Markdown and try again."
         )}
    end
  end

  def handle_event("new_task", _params, socket) do
    task = %Task{
      sprint_id: socket.assigns.sprint.id,
      description: default_task_description()
    }

    {:noreply,
     socket
     |> assign_task_editor(task, :new)
     |> assign(:active_modal, :task)}
  end

  def handle_event("switch_task_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_task_tab, String.to_existing_atom(tab))}
  end

  def handle_event("select_task", %{"id" => id}, socket) do
    task = task_by_id(socket.assigns.sprint, id)

    {:noreply,
     socket
     |> assign(:selected_task_id, task.id)
     |> assign_task_editor(task, {:edit, task.id})
     |> assign(:active_modal, :task)}
  end

  def handle_event("open_comments", %{"id" => id}, socket) do
    task = task_by_id(socket.assigns.sprint, id)

    {:noreply,
     socket
     |> assign(:selected_task_id, task.id)
     |> assign(:comment_form, to_form(%{"body" => ""}, as: :comment))
     |> assign(:active_modal, :comments)}
  end

  def handle_event("validate_sprint", %{"sprint" => params}, socket) do
    changeset =
      socket.assigns.sprint
      |> Projects.change_sprint(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :sprint_changeset, changeset)}
  end

  def handle_event("save_sprint", %{"sprint" => params}, socket) do
    case Projects.update_sprint(socket.assigns.sprint, params) do
      {:ok, _sprint} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sprint updated.")
         |> assign(:active_modal, nil)
         |> load_sprint(socket.assigns.sprint.id)}

      {:error, changeset} ->
        {:noreply, assign(socket, :sprint_changeset, Map.put(changeset, :action, :validate))}
    end
  end

  def handle_event("delete_sprint", _params, socket) do
    case Projects.delete_sprint(socket.assigns.sprint) do
      {:ok, _sprint} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sprint deleted.")
         |> push_navigate(to: ~p"/app/sprints")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Sprint could not be deleted.")}
    end
  end

  def handle_event("validate_task", %{"task" => params}, socket) do
    assignee_ids = normalize_ids(params["assignee_ids"])
    task = task_editor_struct(socket)

    changeset =
      task
      |> Projects.change_task(task_params(socket, params))
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:task_assignee_ids, assignee_ids)
     |> assign(:task_changeset, changeset)}
  end

  def handle_event("save_task", %{"task" => params}, socket) do
    assignee_ids = normalize_ids(params["assignee_ids"])
    params = append_task_image_uploads(socket, params)

    case persist_task(socket, params, assignee_ids) do
      {:ok, _task} ->
        {:noreply,
         socket
         |> put_flash(:info, "Task saved.")
         |> assign(:active_modal, nil)
         |> assign_catalog()
         |> load_sprint(socket.assigns.sprint.id)
         |> assign_task_editor(%Task{sprint_id: socket.assigns.sprint.id}, :new)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:task_assignee_ids, assignee_ids)
         |> assign(:task_changeset, Map.put(changeset, :action, :validate))}
    end
  end

  def handle_event("insert_task_images", _params, socket) do
    image_markdown = task_image_upload_markdown(socket)

    if image_markdown == "" do
      {:noreply, put_flash(socket, :error, "Choose an image first.")}
    else
      changeset =
        socket.assigns.task_changeset
        |> Ecto.Changeset.put_change(
          :description,
          append_description_text(
            Ecto.Changeset.get_field(socket.assigns.task_changeset, :description),
            image_markdown
          )
        )

      {:noreply, assign(socket, :task_changeset, changeset)}
    end
  end

  def handle_event("cancel_task_image_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :task_images, ref)}
  end

  def handle_event("move_task", %{"task-id" => id, "status" => status}, socket) do
    task = task_by_id(socket.assigns.sprint, id)

    case Projects.move_task(task, normalize_task_status(status)) do
      {:ok, _moved_task} ->
        {:noreply,
         socket
         |> load_sprint(socket.assigns.sprint.id)
         |> put_flash(:info, "Task moved.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Task could not be moved.")}
    end
  end

  def handle_event("save_comment", %{"comment" => %{"body" => body}}, socket) do
    body = String.trim(body)

    cond do
      body == "" ->
        {:noreply, put_flash(socket, :error, "Comment cannot be empty.")}

      is_nil(socket.assigns.selected_task_id) ->
        {:noreply, put_flash(socket, :error, "Select a task first.")}

      true ->
        task = task_by_id(socket.assigns.sprint, socket.assigns.selected_task_id)

        case Projects.add_comment(task, socket.assigns.current_user, body) do
          {:ok, _comment} ->
            {:noreply,
             socket
             |> load_sprint(socket.assigns.sprint.id)
             |> assign(:comment_form, to_form(%{"body" => ""}, as: :comment))}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Comment could not be saved.")}
        end
    end
  end

  def handle_event("filter_tasks", %{"task_filters" => params}, socket) do
    {:noreply,
     socket
     |> assign(:task_status_filter, normalize_filter_value(params["status"]))
     |> assign(:task_assignee_filter, normalize_filter_value(params["assignee_id"]))
     |> assign(:task_project_filter, normalize_filter_value(params["project_id"]))
     |> assign(:task_search_filter, normalize_search(params["search"]))}
  end

  def handle_event("reset_task_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:task_status_filter, "all")
     |> assign(:task_assignee_filter, "all")
     |> assign(:task_project_filter, "all")
     |> assign(:task_search_filter, "")}
  end

  def handle_event("filter_add_task", %{"add_task_filters" => params}, socket) do
    {:noreply,
     socket
     |> assign(:add_task_search, normalize_search(params["search"]))
     |> assign(:add_task_project_filter, normalize_filter_value(params["project_id"]))}
  end

  def handle_event("add_task_to_sprint", %{"id" => id}, socket) do
    task = Projects.get_task!(id)

    case Projects.add_task_to_sprint(task, socket.assigns.sprint.id) do
      {:ok, _task} ->
        {:noreply,
         socket
         |> put_flash(:info, "Task added to sprint.")
         |> assign_catalog()
         |> load_sprint(socket.assigns.sprint.id)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Task could not be added.")}
    end
  end

  def handle_event("remove_task_from_sprint", %{"id" => id}, socket) do
    task = Projects.get_task!(id)

    case Projects.remove_task_from_sprint(task) do
      {:ok, _task} ->
        {:noreply,
         socket
         |> put_flash(:info, "Task removed from sprint.")
         |> assign_catalog()
         |> load_sprint(socket.assigns.sprint.id)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Task could not be removed.")}
    end
  end

  def render(assigns) do
    selected_task = selected_task(assigns.sprint, assigns.selected_task_id)
    filtered_tasks = filtered_sprint_tasks(assigns.sprint.tasks, assigns)
    assignable_tasks = assignable_tasks(assigns)

    assigns =
      assigns
      |> assign(:selected_task, selected_task)
      |> assign(:filtered_tasks, filtered_tasks)
      |> assign(:assignable_tasks, assignable_tasks)
      |> assign(:sprint_form, sprint_form(assigns))
      |> assign(:task_form, to_form(assigns.task_changeset))

    ~H"""
    <div class="space-y-6">
      <section>
        <.link
          navigate={~p"/app/sprints"}
          class="inline-flex items-center gap-1 text-sm font-medium text-neutral-500 hover:text-neutral-900"
        >
          <.icon name="hero-arrow-left" class="h-4 w-4" /> Back to all sprints
        </.link>

        <div class="mt-5 flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <div class="flex flex-wrap items-center gap-3">
              <h2 class="text-2xl font-semibold tracking-tight text-neutral-900">
                {@sprint.name}
              </h2>
              <span class="rounded bg-neutral-100 px-1.5 py-0.5 text-xs font-medium text-neutral-600">
                {humanize(@sprint.cadence)}
              </span>
            </div>
            <p class="mt-2 text-sm text-neutral-500">
              {format_date(@sprint.start_date)} → {format_date(@sprint.end_date)}
            </p>
            <p class="mt-4 max-w-3xl text-sm leading-6 text-neutral-700">
              <%= if blank?(@sprint.goal) do %>
                No goal set for this sprint yet.
              <% else %>
                {@sprint.goal}
              <% end %>
            </p>
          </div>

          <div class="flex items-center gap-3">
            <button
              type="button"
              phx-click="edit_sprint"
              class="rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
            >
              Edit sprint
            </button>
            <button
              type="button"
              phx-click="delete_sprint"
              data-confirm="Delete this sprint? Tasks will be unassigned from it."
              class="rounded-md px-3 py-1.5 text-sm font-medium text-red-600 hover:bg-red-50"
            >
              Delete
            </button>
          </div>
        </div>
      </section>

      <section class="rounded-lg border border-neutral-200 bg-white p-4">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <.header class="!mb-0">
            Sprint board
            <:subtitle>Tasks from any project can be added to this sprint.</:subtitle>
          </.header>
          <div class="flex items-center gap-3">
            <button
              type="button"
              phx-click="download_bulk_tasks_md"
              class="rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
            >
              Download MD
            </button>
            <button
              type="button"
              phx-click="open_bulk_tasks"
              class="rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
            >
              Bulk add via AI
            </button>
            <button
              type="button"
              phx-click="open_add_task"
              class="rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
            >
              Add existing task
            </button>
            <.button phx-click="new_task">
              New task
            </.button>
          </div>
        </div>

        <div class="mt-6 rounded-lg border border-neutral-200 bg-white p-4">
          <div class="flex flex-col gap-4">
            <form phx-change="filter_tasks" class="grid gap-3 md:grid-cols-2 xl:grid-cols-4 xl:gap-4">
              <label class="block">
                <span class="text-xs font-medium text-neutral-500">Search</span>
                <input
                  type="text"
                  name="task_filters[search]"
                  value={@task_search_filter}
                  placeholder="Search title or description"
                  class="mt-2 w-full rounded-md border border-neutral-200 bg-white px-3 py-2 text-sm text-neutral-900 focus:border-[#f26334] focus:ring-2 focus:ring-[#f26334]/30"
                />
              </label>

              <label class="block">
                <span class="text-xs font-medium text-neutral-500">Project</span>
                <select
                  name="task_filters[project_id]"
                  class="mt-2 w-full rounded-md border border-neutral-200 bg-white px-3 py-2 text-sm text-neutral-900 focus:border-[#f26334] focus:ring-2 focus:ring-[#f26334]/30"
                >
                  <option value="all" selected={@task_project_filter == "all"}>All projects</option>
                  <option
                    :for={project <- @projects}
                    value={project.id}
                    selected={to_string(project.id) == @task_project_filter}
                  >
                    {project.name}
                  </option>
                </select>
              </label>

              <label class="block">
                <span class="text-xs font-medium text-neutral-500">Assignee</span>
                <select
                  name="task_filters[assignee_id]"
                  class="mt-2 w-full rounded-md border border-neutral-200 bg-white px-3 py-2 text-sm text-neutral-900 focus:border-[#f26334] focus:ring-2 focus:ring-[#f26334]/30"
                >
                  <option value="all" selected={@task_assignee_filter == "all"}>
                    All assignees
                  </option>
                  <option
                    :for={user <- @staff_users}
                    value={user.id}
                    selected={to_string(user.id) == @task_assignee_filter}
                  >
                    {display_name(user)}
                  </option>
                </select>
              </label>

              <label class="block">
                <span class="text-xs font-medium text-neutral-500">Status</span>
                <select
                  name="task_filters[status]"
                  class="mt-2 w-full rounded-md border border-neutral-200 bg-white px-3 py-2 text-sm text-neutral-900 focus:border-[#f26334] focus:ring-2 focus:ring-[#f26334]/30"
                >
                  <option value="all" selected={@task_status_filter == "all"}>All statuses</option>
                  <option
                    :for={status <- @task_statuses}
                    value={status}
                    selected={Atom.to_string(status) == @task_status_filter}
                  >
                    {humanize(status)}
                  </option>
                </select>
              </label>
            </form>

            <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <p class="text-xs text-neutral-500 whitespace-nowrap">
                Showing {length(@filtered_tasks)} of {length(@sprint.tasks)} tasks
              </p>
              <button
                type="button"
                phx-click="reset_task_filters"
                class="self-start rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50 sm:self-auto"
              >
                Clear filters
              </button>
            </div>
          </div>
        </div>

        <div
          :if={@filtered_tasks == []}
          class="mt-6 rounded-lg border border-dashed border-neutral-200 p-6 text-center text-sm text-neutral-500"
        >
          No tasks match the current filters.
        </div>

        <div class="mt-6 overflow-x-auto pb-3 [scrollbar-width:thin]">
          <div class="flex min-w-max gap-5 pr-2">
            <div :for={status <- @task_statuses} class={column_shell_class(status)}>
              <div class="flex items-center justify-between gap-3">
                <div class="flex items-center gap-2">
                  <span class={column_badge(status)}></span>
                  <p class="text-sm font-semibold text-neutral-900">
                    {humanize(status)}
                  </p>
                </div>
                <p class="text-xs text-neutral-500">
                  {task_count(@filtered_tasks, status)} items
                </p>
              </div>

              <div
                id={"sprint-kanban-column-#{status}"}
                phx-hook="KanbanColumn"
                data-status={status}
                class="kanban-dropzone mt-4 min-h-[20rem] space-y-3 rounded-lg border border-dashed border-neutral-200 bg-white p-2"
              >
                <article
                  :for={task <- tasks_for_status(@filtered_tasks, status)}
                  id={"sprint-task-card-#{task.id}"}
                  data-task-id={task.id}
                  class={task_card_class(task, @selected_task_id)}
                >
                  <button
                    type="button"
                    phx-click="select_task"
                    phx-value-id={task.id}
                    class="block w-full text-left"
                  >
                    <div class="flex items-start justify-between gap-3">
                      <div class="space-y-2">
                        <p class="text-sm font-medium leading-6 text-neutral-900 line-clamp-3">
                          {task.title}
                        </p>

                        <div class="flex flex-wrap items-center gap-1.5">
                          <span class="rounded bg-neutral-100 px-1.5 py-0.5 text-xs text-neutral-600">
                            {task.project.name}
                          </span>
                          <span :if={present?(task.phase)} class={phase_badge(task.phase)}>
                            {task.phase}
                          </span>
                          <span class={priority_badge(task.priority)}>{humanize(task.priority)}</span>
                        </div>
                      </div>

                      <span class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-md text-neutral-400 hover:bg-neutral-100">
                        <.icon name="hero-pencil-square" class="h-4 w-4" />
                      </span>
                    </div>

                    <div class="mt-3 line-clamp-4 text-sm leading-6 text-neutral-500">
                      <%= if blank_description?(task.description) do %>
                        No description.
                      <% else %>
                        <.mention_text text={task.description} />
                      <% end %>
                    </div>

                    <dl class="mt-4 grid grid-cols-2 gap-x-4 gap-y-2 border-t border-neutral-200 pt-3">
                      <div>
                        <dt class="text-xs text-neutral-500">Due</dt>
                        <dd class={task_meta_value_class(task, :due)}>
                          {due_label(task)}
                        </dd>
                      </div>
                      <div>
                        <dt class="text-xs text-neutral-500">Hours</dt>
                        <dd class="mt-0.5 text-sm font-medium text-neutral-900">
                          {estimated_hours_label(task)}
                        </dd>
                      </div>
                      <div>
                        <dt class="text-xs text-neutral-500">Assigned</dt>
                        <dd class="mt-0.5 text-sm font-medium text-neutral-900">
                          {task_assignee_count(task)}
                        </dd>
                      </div>
                      <div>
                        <dt class="text-xs text-neutral-500">Comments</dt>
                        <dd class="mt-0.5 text-sm font-medium text-neutral-900">
                          {length(task.comments)}
                        </dd>
                      </div>
                    </dl>
                  </button>

                  <div class="mt-3 flex flex-wrap gap-2 border-t border-neutral-200 pt-3">
                    <button
                      type="button"
                      phx-click="open_comments"
                      phx-value-id={task.id}
                      class="rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
                    >
                      Open discussion
                    </button>
                    <button
                      type="button"
                      phx-click="remove_task_from_sprint"
                      phx-value-id={task.id}
                      class="rounded-md px-3 py-1.5 text-sm font-medium text-red-600 hover:bg-red-50"
                    >
                      Remove from sprint
                    </button>
                  </div>
                </article>

                <div
                  :if={tasks_for_status(@filtered_tasks, status) == []}
                  class="rounded-lg border border-dashed border-neutral-200 p-6 text-center text-sm text-neutral-500"
                >
                  {empty_column_message(status)}
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <.modal
        :if={@active_modal == :sprint}
        id="sprint-editor-modal"
        show
        on_cancel={JS.push("close_modal", value: %{modal: "sprint"})}
      >
        <div>
          <h3 class="text-base font-semibold text-neutral-900">Edit sprint</h3>
          <p class="mt-1 text-sm text-neutral-500">Update the goal, title, or dates.</p>
        </div>

        <.simple_form for={@sprint_form} phx-change="validate_sprint" phx-submit="save_sprint">
          <.input field={@sprint_form[:name]} label="Sprint title" />
          <.input field={@sprint_form[:goal]} type="textarea" label="Goal" rows="3" />
          <div class="grid gap-4 sm:grid-cols-2">
            <.input
              field={@sprint_form[:cadence]}
              type="select"
              label="Cadence"
              options={cadence_options()}
            />
            <.input field={@sprint_form[:start_date]} type="date" label="Start date" />
          </div>
          <div class="rounded-lg border border-neutral-200 bg-neutral-50 px-4 py-4 text-sm text-neutral-700">
            <p class="text-xs text-neutral-500">Ends</p>
            <p class="mt-1 text-sm font-medium text-neutral-900">
              {format_date(end_date(@sprint_form.source))}
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
            <.button>Save sprint</.button>
          </:actions>
        </.simple_form>
      </.modal>

      <.modal
        :if={@active_modal == :task}
        id="sprint-task-editor-modal"
        show
        on_cancel={JS.push("close_modal", value: %{modal: "task"})}
      >
        <div>
          <h3 class="text-base font-semibold text-neutral-900">
            {task_form_title(@task_mode)}
          </h3>
          <p class="mt-1 text-sm text-neutral-500">
            Create work items or update the selected task without leaving the sprint board.
          </p>
        </div>

        <.task_tab_nav active_tab={@active_task_tab} />

        <.simple_form for={@task_form} phx-change="validate_task" phx-submit="save_task">
          <div class={task_tab_class(@active_task_tab, :details)}>
            <.input
              field={@task_form[:project_id]}
              type="select"
              label="Project"
              prompt="Select a project"
              options={project_options(@projects)}
            />
            <.input field={@task_form[:title]} label="Task title" />
            <.input field={@task_form[:phase]} label="Phase or workstream" />
            <div class="grid gap-4 sm:grid-cols-2">
              <.input
                field={@task_form[:status]}
                type="select"
                label="Status"
                options={task_status_options()}
              />
              <.input
                field={@task_form[:priority]}
                type="select"
                label="Priority"
                options={priority_options()}
              />
            </div>
            <div class="grid gap-4 sm:grid-cols-2">
              <.input field={@task_form[:due_date]} type="date" label="Due date" />
              <.input
                field={@task_form[:estimated_hours]}
                type="number"
                step="0.25"
                label="Estimated hours"
              />
            </div>
          </div>

          <div class={task_tab_class(@active_task_tab, :assignees)}>
            <.label>Assignees</.label>
            <input type="hidden" name="task[assignee_ids][]" value="" />
            <div class="mt-3 grid gap-2 sm:grid-cols-2">
              <label
                :for={user <- @staff_users}
                class="flex items-center gap-3 rounded-md border border-neutral-200 bg-white px-3 py-2 text-sm text-neutral-700"
              >
                <input
                  type="checkbox"
                  name="task[assignee_ids][]"
                  value={user.id}
                  checked={user.id in @task_assignee_ids}
                  class="rounded border-neutral-300 text-[#f26334]"
                />
                <span>{display_name(user)}</span>
              </label>
            </div>
          </div>

          <div class={task_tab_class(@active_task_tab, :description)}>
            <.label for="sprint-task-description-input">Description</.label>
            <div
              id="sprint-task-description-toolbar"
              phx-hook="FormatToolbar"
              data-target="sprint-task-description-input"
              class="mt-1.5 flex items-center gap-1 rounded-t-md border border-b-0 border-neutral-200 bg-neutral-50 px-2 py-1"
            >
              <button
                type="button"
                data-format="bold"
                class="rounded px-2 py-1 text-sm font-bold text-neutral-600 hover:bg-neutral-200"
                title="Bold"
              >
                B
              </button>
              <button
                type="button"
                data-format="heading"
                class="rounded px-2 py-1 text-xs font-bold text-neutral-600 hover:bg-neutral-200"
                title="Heading"
              >
                H
              </button>
              <label
                class="ml-auto flex cursor-pointer items-center gap-1.5 rounded px-2 py-1 text-xs font-medium text-neutral-600 hover:bg-neutral-200"
                title="Upload image"
              >
                <.icon name="hero-photo" class="h-4 w-4" />
                <span>Image</span>
                <.live_file_input upload={@uploads.task_images} class="sr-only" />
              </label>
            </div>
            <div
              :if={@uploads.task_images.entries != []}
              class="border-x border-neutral-200 bg-neutral-50 px-3 py-2"
            >
              <div class="flex flex-wrap items-start gap-2">
                <div :for={entry <- @uploads.task_images.entries} class="relative">
                  <div class="overflow-hidden rounded-md border border-neutral-200 bg-white">
                    <.live_img_preview
                      :if={String.starts_with?(entry.client_type, "image/")}
                      entry={entry}
                      class="h-20 w-24 object-cover"
                    />
                    <span class="block max-w-24 truncate px-2 py-1 text-[10px] text-neutral-500">
                      {entry.client_name}
                    </span>
                  </div>
                  <button
                    type="button"
                    phx-click="cancel_task_image_upload"
                    phx-value-ref={entry.ref}
                    class="absolute -right-1.5 -top-1.5 rounded-full bg-neutral-700 p-0.5 text-white"
                  >
                    <.icon name="hero-x-mark" class="h-3 w-3" />
                  </button>
                  <p
                    :for={err <- upload_errors(@uploads.task_images, entry)}
                    class="mt-0.5 text-[10px] text-red-600"
                  >
                    {upload_error_msg(err)}
                  </p>
                </div>
                <button
                  type="button"
                  phx-click="insert_task_images"
                  disabled={Enum.any?(@uploads.task_images.entries, fn entry -> not entry.done? end)}
                  class="self-center rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-xs font-medium text-neutral-700 hover:bg-neutral-50 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  Insert into description
                </button>
              </div>
            </div>
            <.input
              field={@task_form[:description]}
              type="textarea"
              rows="16"
              id="sprint-task-description-input"
              phx-hook="MentionInput"
              data-mention-users={@mention_users_json}
              textarea_class="!mt-0 rounded-t-none text-base leading-relaxed"
            />
            <p class="mt-1 text-xs text-neutral-400">
              Type <span class="font-medium text-neutral-500">@</span>
              to mention a teammate. Use <span class="font-medium text-neutral-500">**bold**</span>
              and <span class="font-medium text-neutral-500"># heading</span>
              for formatting.
            </p>
            <.task_description_image_preview text={
              Ecto.Changeset.get_field(@task_changeset, :description)
            } />
          </div>
          <:actions>
            <button
              type="button"
              phx-click="close_modal"
              phx-value-modal="task"
              class="rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
            >
              Cancel
            </button>
            <.button>{task_submit_label(@task_mode)}</.button>
          </:actions>
        </.simple_form>
      </.modal>

      <.modal
        :if={@active_modal == :comments and @selected_task}
        id="sprint-task-comments-modal"
        show
        on_cancel={JS.push("close_modal", value: %{modal: "comments"})}
      >
        <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h3 class="text-base font-semibold text-neutral-900">
              {@selected_task.title}
            </h3>
            <p class="mt-1 text-sm text-neutral-500">
              Review the full discussion and add a new comment without opening the task editor.
            </p>
          </div>

          <button
            type="button"
            phx-click="select_task"
            phx-value-id={@selected_task.id}
            class="rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
          >
            Edit task
          </button>
        </div>

        <div class="mt-6 rounded-lg border border-neutral-200 bg-neutral-50 p-4">
          <div class="flex items-center justify-between">
            <p class="text-sm font-semibold text-neutral-900">Discussion</p>
            <span class="text-xs text-neutral-500">
              {length(@selected_task.comments)} comments
            </span>
          </div>

          <div class="mt-4 space-y-3">
            <article
              :for={comment <- @selected_task.comments}
              class="rounded-lg border border-neutral-200 bg-white px-4 py-3"
            >
              <p class="text-sm font-medium text-neutral-900">{display_name(comment.user)}</p>
              <p class="mt-1 text-sm leading-6 text-neutral-700">{comment.body}</p>
            </article>

            <div
              :if={@selected_task.comments == []}
              class="rounded-lg border border-dashed border-neutral-200 p-6 text-center text-sm text-neutral-500"
            >
              No comments yet. Start the discussion below.
            </div>
          </div>

          <.simple_form for={@comment_form} phx-submit="save_comment">
            <.input field={@comment_form[:body]} type="textarea" label="Add comment" rows="3" />
            <:actions>
              <button
                type="button"
                phx-click="close_modal"
                phx-value-modal="comments"
                class="rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
              >
                Close
              </button>
              <.button>Add comment</.button>
            </:actions>
          </.simple_form>
        </div>
      </.modal>

      <.modal
        :if={@active_modal == :add_task}
        id="sprint-add-task-modal"
        show
        on_cancel={JS.push("close_modal", value: %{modal: "add_task"})}
      >
        <div>
          <h3 class="text-base font-semibold text-neutral-900">Add existing task to sprint</h3>
          <p class="mt-1 text-sm text-neutral-500">
            Pick a task from any project. Tasks already in another sprint will be moved into this one.
          </p>
        </div>

        <form phx-change="filter_add_task" class="mt-4 grid gap-3 sm:grid-cols-2">
          <label class="block">
            <span class="text-xs font-medium text-neutral-500">Search</span>
            <input
              type="text"
              name="add_task_filters[search]"
              value={@add_task_search}
              placeholder="Search task title"
              phx-debounce="300"
              class="mt-2 w-full rounded-md border border-neutral-200 bg-white px-3 py-2 text-sm text-neutral-900 focus:border-[#f26334] focus:ring-2 focus:ring-[#f26334]/30"
            />
          </label>
          <label class="block">
            <span class="text-xs font-medium text-neutral-500">Project</span>
            <select
              name="add_task_filters[project_id]"
              class="mt-2 w-full rounded-md border border-neutral-200 bg-white px-3 py-2 text-sm text-neutral-900 focus:border-[#f26334] focus:ring-2 focus:ring-[#f26334]/30"
            >
              <option value="all" selected={@add_task_project_filter == "all"}>All projects</option>
              <option
                :for={project <- @projects}
                value={project.id}
                selected={to_string(project.id) == @add_task_project_filter}
              >
                {project.name}
              </option>
            </select>
          </label>
        </form>

        <div class="mt-4 max-h-96 space-y-2 overflow-y-auto">
          <div
            :for={task <- @assignable_tasks}
            class="flex items-center justify-between gap-3 rounded-lg border border-neutral-200 bg-white px-4 py-3"
          >
            <div class="min-w-0">
              <p class="truncate text-sm font-medium text-neutral-900">{task.title}</p>
              <p class="mt-0.5 text-xs text-neutral-500">
                {task.project.name}
                <span :if={task.sprint}>· currently in {task.sprint.name}</span>
              </p>
            </div>
            <button
              type="button"
              phx-click="add_task_to_sprint"
              phx-value-id={task.id}
              class="shrink-0 rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
            >
              Add
            </button>
          </div>

          <div
            :if={@assignable_tasks == []}
            class="rounded-lg border border-dashed border-neutral-200 p-6 text-center text-sm text-neutral-500"
          >
            No matching tasks found.
          </div>
        </div>
      </.modal>

      <.modal
        :if={@active_modal == :bulk_tasks}
        id="sprint-bulk-tasks-modal"
        show
        on_cancel={JS.push("close_modal", value: %{modal: "bulk_tasks"})}
      >
        <div>
          <h3 class="text-base font-semibold text-neutral-900">Bulk add tasks via AI Markdown</h3>
          <p class="mt-1 text-sm text-neutral-500">
            Download the template, let AI fill it, paste the result here, preview, then create tasks.
          </p>
        </div>

        <.simple_form
          for={@bulk_task_form}
          id="sprint-bulk-tasks-form"
          phx-change="preview_bulk_tasks"
          phx-submit="create_bulk_tasks"
        >
          <.input
            field={@bulk_task_form[:project_id]}
            type="select"
            label="Project for these tasks"
            prompt="Select a project"
            options={project_options(@projects)}
          />
          <.input
            field={@bulk_task_form[:markdown]}
            type="textarea"
            label="Markdown task plan"
            rows="18"
            placeholder="Paste the completed # Sprint Task Plan Markdown here"
            textarea_class="font-mono text-sm leading-6"
          />

          <div>
            <.label>Randomly and evenly assign to</.label>
            <input type="hidden" name="bulk_tasks[assignee_ids][]" value="" />
            <div class="mt-3 grid gap-2 sm:grid-cols-2">
              <label
                :for={user <- @staff_users}
                class="flex items-center gap-3 rounded-md border border-neutral-200 bg-white px-3 py-2 text-sm text-neutral-700"
              >
                <input
                  type="checkbox"
                  name="bulk_tasks[assignee_ids][]"
                  value={user.id}
                  checked={user.id in @bulk_task_assignee_ids}
                  class="rounded border-neutral-300 text-[#f26334]"
                />
                <span>{display_name(user)}</span>
              </label>
            </div>
            <p class="mt-2 text-xs leading-5 text-neutral-500">
              Selected members are shuffled, then assigned one task at a time so work is spread evenly.
            </p>
          </div>

          <div
            :if={@bulk_task_drafts != []}
            class="rounded-lg border border-neutral-200 bg-neutral-50 p-4"
          >
            <div class="flex items-center justify-between gap-3">
              <p class="text-sm font-semibold text-neutral-900">Preview</p>
              <span class="text-xs text-neutral-500">{length(@bulk_task_drafts)} tasks</span>
            </div>
            <div class="mt-3 max-h-64 space-y-2 overflow-y-auto">
              <article
                :for={draft <- @bulk_task_drafts}
                class="rounded-md border border-neutral-200 bg-white px-3 py-2"
              >
                <div class="flex flex-wrap items-center gap-2">
                  <p class="text-sm font-medium text-neutral-900">{draft.title}</p>
                  <span :if={present?(draft.phase)} class={phase_badge(draft.phase)}>
                    {draft.phase}
                  </span>
                  <span class={priority_badge(draft.priority)}>{humanize(draft.priority)}</span>
                  <span class="text-xs text-neutral-500">
                    {estimated_hours_label(%Task{estimated_hours: draft.estimated_hours})}
                  </span>
                </div>
                <p class="mt-1 line-clamp-2 text-xs leading-5 text-neutral-500">
                  {draft.description || "No description."}
                </p>
              </article>
            </div>
          </div>

          <:actions>
            <button
              type="button"
              phx-click="download_bulk_tasks_md"
              class="rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
            >
              Download template
            </button>
            <.button>Create tasks</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  defp default_task_description do
    """
    # Summary


    # Details


    # Acceptance criteria
    -
    """
  end

  attr :active_tab, :atom, required: true

  defp task_tab_nav(assigns) do
    ~H"""
    <div class="mt-4 flex gap-1 border-b border-neutral-200">
      <.task_tab_button tab={:details} label="Task details" active_tab={@active_tab} />
      <.task_tab_button tab={:assignees} label="Assignees" active_tab={@active_tab} />
      <.task_tab_button tab={:description} label="Description" active_tab={@active_tab} />
    </div>
    """
  end

  attr :tab, :atom, required: true
  attr :label, :string, required: true
  attr :active_tab, :atom, required: true

  defp task_tab_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="switch_task_tab"
      phx-value-tab={@tab}
      class={[
        "-mb-px border-b-2 px-3 py-2 text-sm font-medium",
        @tab == @active_tab && "border-[#f26334] text-neutral-900",
        @tab != @active_tab &&
          "border-transparent text-neutral-500 hover:text-neutral-700"
      ]}
    >
      {@label}
    </button>
    """
  end

  defp task_tab_class(active_tab, tab) do
    [
      "space-y-4 pt-4",
      active_tab != tab && "hidden"
    ]
  end

  attr :text, :string, default: nil

  defp task_description_image_preview(assigns) do
    assigns = assign(assigns, :images, task_description_images(assigns[:text]))

    ~H"""
    <div :if={@images != []} class="mt-3 rounded-md border border-neutral-200 bg-neutral-50 p-3">
      <p class="text-xs font-medium text-neutral-500">Image preview</p>
      <div class="mt-2 grid gap-3 sm:grid-cols-2">
        <figure
          :for={{alt, url} <- @images}
          class="overflow-hidden rounded-md border border-neutral-200 bg-white"
        >
          <img src={url} alt={alt} loading="lazy" class="max-h-60 w-full object-contain" />
          <figcaption class="truncate px-3 py-2 text-xs text-neutral-500">{alt}</figcaption>
        </figure>
      </div>
    </div>
    """
  end

  defp task_description_images(text) do
    text
    |> Mentions.to_segments()
    |> Enum.filter(&match?({:image, _alt, _url}, &1))
    |> Enum.map(fn {:image, alt, url} -> {alt, url} end)
  end

  defp allow_task_image_uploads(socket) do
    allow_upload(socket, :task_images,
      accept: ~w(.jpg .jpeg .png .gif .webp),
      max_entries: 6,
      max_file_size: 10_000_000,
      auto_upload: true
    )
  end

  defp append_task_image_uploads(socket, params) do
    case task_image_upload_markdown(socket) do
      "" ->
        params

      image_markdown ->
        Map.update(
          params,
          "description",
          image_markdown,
          &append_description_text(&1, image_markdown)
        )
    end
  end

  defp task_image_upload_markdown(socket) do
    {completed, _in_progress} = uploaded_entries(socket, :task_images)

    if completed == [] do
      ""
    else
      socket
      |> consume_uploaded_entries(:task_images, fn meta, entry ->
        url = Uploads.persist_upload!("tasks", meta, entry.client_name)
        {:ok, markdown_image(entry.client_name, url)}
      end)
      |> Enum.join("\n")
    end
  end

  defp append_description_text(description, extra) do
    description = String.trim_trailing(description || "")
    extra = String.trim(extra || "")

    cond do
      extra == "" -> description
      description == "" -> extra
      true -> description <> "\n\n" <> extra
    end
  end

  defp markdown_image(filename, url) do
    alt =
      filename
      |> Path.rootname()
      |> String.replace(~r/[_-]+/, " ")
      |> String.trim()
      |> case do
        "" -> "Task image"
        value -> value
      end

    "![#{alt}](#{url})"
  end

  defp upload_error_msg(:too_large), do: "Image too large (max 10 MB)"
  defp upload_error_msg(:not_accepted), do: "Use JPG, PNG, GIF, or WebP"
  defp upload_error_msg(:too_many_files), do: "Too many images (max 6)"
  defp upload_error_msg(_), do: "Upload error"

  attr :text, :string, default: nil

  defp mention_text(assigns) do
    assigns = assign(assigns, :segments, Mentions.to_segments(assigns[:text] || ""))

    ~H"""
    <.line_segment :for={segment <- @segments} segment={segment} />
    """
  end

  defp line_segment(%{segment: {:newline}} = assigns) do
    ~H"""
    <br />
    """
  end

  defp line_segment(%{segment: {:heading, level, inline}} = assigns) do
    assigns =
      assigns
      |> assign(:level, level)
      |> assign(:inline, inline)

    ~H"""
    <span class={heading_class(@level)}>
      <.inline_segment :for={segment <- @inline} segment={segment} />
    </span>
    """
  end

  defp line_segment(%{segment: {:image, alt, url}} = assigns) do
    assigns =
      assigns
      |> assign(:alt, alt)
      |> assign(:url, url)

    ~H"""
    <img
      src={@url}
      alt={@alt}
      loading="lazy"
      class="my-3 max-h-80 w-full rounded-md border border-neutral-200 object-contain"
    />
    """
  end

  defp line_segment(%{segment: {:line, inline}} = assigns) do
    assigns = assign(assigns, :inline, inline)

    ~H"""
    <.inline_segment :for={segment <- @inline} segment={segment} />
    """
  end

  defp inline_segment(assigns) do
    ~H"""
    <span class={inline_segment_class(@segment)}>{inline_segment_text(@segment)}</span>
    """
  end

  defp heading_class(1), do: "block text-base font-semibold text-neutral-900"
  defp heading_class(2), do: "block text-sm font-semibold text-neutral-900"
  defp heading_class(_level), do: "block text-sm font-semibold text-neutral-800"

  defp inline_segment_class({:mention, _name}),
    do: "rounded bg-neutral-100 px-1 font-medium text-neutral-700"

  defp inline_segment_class({:bold, _value}), do: "font-semibold text-neutral-900"
  defp inline_segment_class({:text, _value}), do: nil

  defp inline_segment_text({:mention, name}), do: "@" <> name
  defp inline_segment_text({:bold, value}), do: value
  defp inline_segment_text({:text, value}), do: value

  defp assign_catalog(socket) do
    internal_users =
      Accounts.list_users()
      |> Enum.filter(&User.has_role?(&1, [:admin, :staff]))

    mention_users =
      Accounts.list_users()
      |> Enum.map(fn user -> %{id: user.id, name: display_name(user)} end)
      |> Enum.sort_by(&String.downcase(&1.name))

    assign(socket,
      staff_users: internal_users,
      mention_users_json: Jason.encode!(mention_users),
      projects: Projects.list_projects()
    )
  end

  defp load_sprint(socket, id) do
    sprint = Projects.get_sprint!(id)

    socket
    |> assign(:page_title, sprint.name)
    |> assign(:sprint, sprint)
    |> assign(:sprint_changeset, Projects.change_sprint(sprint))
  end

  defp sprint_form(assigns), do: to_form(assigns.sprint_changeset)

  defp task_editor_struct(socket) do
    case socket.assigns.task_mode do
      :new -> %Task{sprint_id: socket.assigns.sprint.id}
      {:edit, id} -> task_by_id(socket.assigns.sprint, id)
    end
  end

  defp assign_task_editor(socket, %Task{} = task, mode) do
    assignee_ids =
      case Map.get(task, :assignees) do
        assignees when is_list(assignees) -> Enum.map(assignees, & &1.id)
        _ -> []
      end

    socket
    |> assign(:task_mode, mode)
    |> assign(:task_assignee_ids, assignee_ids)
    |> assign(:task_changeset, Projects.change_task(task))
    |> assign(:active_task_tab, :details)
  end

  defp reset_bulk_task_import(socket) do
    socket
    |> assign(:bulk_task_form, to_form(default_bulk_task_params(), as: :bulk_tasks))
    |> assign(:bulk_task_drafts, [])
    |> assign(:bulk_task_assignee_ids, [])
  end

  defp default_bulk_task_params do
    %{"project_id" => "", "markdown" => "", "assignee_ids" => []}
  end

  defp normalize_bulk_task_params(params) do
    %{
      "project_id" => Map.get(params, "project_id", ""),
      "markdown" => Map.get(params, "markdown", ""),
      "assignee_ids" => Map.get(params, "assignee_ids", [])
    }
  end

  defp persist_task(socket, params, assignee_ids) do
    attrs = task_params(socket, params)

    case socket.assigns.task_mode do
      :new ->
        with {:ok, task} <-
               Projects.create_task(
                 Map.put(attrs, "created_by_id", socket.assigns.current_user.id)
               ) do
          Projects.assign_task(task, assignee_ids)
        end

      {:edit, id} ->
        socket.assigns.sprint
        |> task_by_id(id)
        |> Projects.update_task(attrs)
        |> case do
          {:ok, task} -> Projects.assign_task(task, assignee_ids)
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  defp task_params(socket, params) do
    params
    |> Map.drop(["assignee_ids"])
    |> Map.put("sprint_id", socket.assigns.sprint.id)
  end

  defp task_by_id(sprint, id) when is_binary(id), do: task_by_id(sprint, String.to_integer(id))
  defp task_by_id(sprint, id), do: Enum.find(sprint.tasks, &(&1.id == id))

  defp selected_task(sprint, selected_task_id) do
    Enum.find(sprint.tasks, &(&1.id == selected_task_id))
  end

  defp filtered_sprint_tasks(tasks, assigns) do
    status_filter = assigns.task_status_filter
    assignee_filter = assigns.task_assignee_filter
    project_filter = assigns.task_project_filter
    search_filter = String.downcase(assigns.task_search_filter || "")

    Enum.filter(tasks, fn task ->
      (status_filter == "all" or Atom.to_string(task.status) == status_filter) and
        (project_filter == "all" or to_string(task.project_id) == project_filter) and
        (assignee_filter == "all" or task_has_assignee?(task, assignee_filter)) and
        (search_filter == "" or task_matches_search?(task, search_filter))
    end)
  end

  defp task_matches_search?(task, search_filter) do
    String.contains?(String.downcase(task.title || ""), search_filter) or
      String.contains?(String.downcase(task.description || ""), search_filter)
  end

  defp task_has_assignee?(task, assignee_filter) do
    task
    |> Map.get(:assignees, [])
    |> List.wrap()
    |> Enum.any?(&(to_string(&1.id) == assignee_filter))
  end

  defp assignable_tasks(assigns) do
    query = String.downcase(assigns.add_task_search || "")
    project_filter = assigns.add_task_project_filter
    sprint_id = assigns.sprint.id

    Projects.list_tasks_workspace()
    |> Enum.reject(&(&1.sprint_id == sprint_id))
    |> Enum.filter(fn task ->
      (project_filter == "all" or to_string(task.project_id) == project_filter) and
        (query == "" or String.contains?(String.downcase(task.title), query))
    end)
    |> Enum.take(50)
  end

  defp normalize_ids(nil), do: []

  defp normalize_ids(ids) when is_list(ids),
    do: ids |> Enum.reject(&(&1 in [nil, ""])) |> Enum.map(&String.to_integer/1)

  defp normalize_task_status(status) when is_binary(status) do
    case status do
      "backlog" -> :backlog
      "in_progress" -> :in_progress
      "review" -> :review
      "done" -> :done
      _ -> :backlog
    end
  end

  defp normalize_filter_value(nil), do: "all"
  defp normalize_filter_value(""), do: "all"
  defp normalize_filter_value(value), do: value

  defp normalize_search(nil), do: ""
  defp normalize_search(value), do: String.trim(value)

  defp blank?(value), do: String.trim(value || "") == ""
  defp blank_description?(description), do: String.trim(description || "") == ""

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)

  defp cadence_options, do: [{"Weekly", :weekly}, {"2 weeks", :biweekly}]

  defp project_options(projects), do: Enum.map(projects, &{&1.name, &1.id})

  defp end_date(%Ecto.Changeset{} = changeset), do: Ecto.Changeset.get_field(changeset, :end_date)

  defp tasks_for_status(tasks, status), do: Enum.filter(tasks, &(&1.status == status))
  defp task_count(tasks, status), do: Enum.count(tasks, &(&1.status == status))

  defp task_card_class(task, selected_task_id) do
    base =
      "block w-full rounded-lg border bg-white px-4 py-4 text-left transition hover:bg-neutral-50"

    if task.id == selected_task_id do
      base <> " border-[#f26334]"
    else
      base <> " border-neutral-200"
    end
  end

  defp task_assignee_count(%Task{} = task) do
    case Map.get(task, :assignees) do
      assignees when is_list(assignees) -> length(assignees)
      _ -> 0
    end
  end

  defp column_badge(:backlog), do: "h-2.5 w-2.5 rounded-full bg-neutral-400"
  defp column_badge(:in_progress), do: "h-2.5 w-2.5 rounded-full bg-amber-500"
  defp column_badge(:review), do: "h-2.5 w-2.5 rounded-full bg-sky-500"
  defp column_badge(:done), do: "h-2.5 w-2.5 rounded-full bg-emerald-500"

  defp column_shell_class(_status),
    do: "w-[21rem] shrink-0 rounded-lg border border-neutral-200 bg-neutral-50 p-3"

  defp empty_column_message(:backlog),
    do: "No backlog tasks yet. Add one to get the sprint started."

  defp empty_column_message(:in_progress), do: "Nothing is actively moving right now."
  defp empty_column_message(:review), do: "No work is waiting for review."
  defp empty_column_message(:done), do: "Completed work will appear here."

  defp phase_badge(_phase),
    do: "rounded bg-neutral-100 px-1.5 py-0.5 text-xs text-neutral-600"

  defp due_label(task) do
    cond do
      overdue_task?(task) -> "Overdue #{format_date(task.due_date)}"
      is_nil(task.due_date) -> "No due date"
      true -> "Due #{format_date(task.due_date)}"
    end
  end

  defp estimated_hours_label(%Task{estimated_hours: nil}), do: "Hours TBD"
  defp estimated_hours_label(%Task{estimated_hours: hours}), do: "#{hours}h"

  defp sprint_task_plan_filename(sprint) do
    slug =
      sprint.name
      |> to_string()
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "_")
      |> String.trim("_")
      |> case do
        "" -> "sprint"
        value -> value
      end

    "#{slug}_task_plan.md"
  end

  defp task_meta_value_class(task, :due) do
    if overdue_task?(task) do
      "mt-0.5 text-sm font-medium text-red-600"
    else
      "mt-0.5 text-sm font-medium text-neutral-900"
    end
  end

  defp overdue_task?(%Task{due_date: %Date{} = due_date, status: status}) do
    Date.compare(due_date, Date.utc_today()) == :lt and status != :done
  end

  defp overdue_task?(_task), do: false

  defp priority_badge(:urgent),
    do: "rounded bg-neutral-100 px-1.5 py-0.5 text-xs text-red-600"

  defp priority_badge(:high),
    do: "rounded bg-neutral-100 px-1.5 py-0.5 text-xs text-amber-600"

  defp priority_badge(:medium),
    do: "rounded bg-neutral-100 px-1.5 py-0.5 text-xs text-neutral-600"

  defp priority_badge(:low),
    do: "rounded bg-neutral-100 px-1.5 py-0.5 text-xs text-neutral-500"

  defp task_status_options do
    [
      {"Backlog", :backlog},
      {"In progress", :in_progress},
      {"Review", :review},
      {"Done", :done}
    ]
  end

  defp priority_options do
    [
      {"Low", :low},
      {"Medium", :medium},
      {"High", :high},
      {"Urgent", :urgent}
    ]
  end

  defp task_form_title(:new), do: "New task"
  defp task_form_title(_mode), do: "Edit task"
  defp task_submit_label(:new), do: "Create task"
  defp task_submit_label(_mode), do: "Save task"

  defp humanize(value) when is_atom(value), do: value |> Atom.to_string() |> humanize()

  defp humanize(value) when is_binary(value) do
    value
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_date(nil), do: "No date"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
end
