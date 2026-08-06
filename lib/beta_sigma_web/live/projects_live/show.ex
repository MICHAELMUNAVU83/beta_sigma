# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule BetaSigmaWeb.ProjectsLive.Show do
  use BetaSigmaWeb, :live_view

  alias BetaSigma.Accounts
  alias BetaSigma.Accounts.User
  alias BetaSigma.Notes
  alias BetaSigma.Notes.Note
  alias BetaSigma.Projects
  alias BetaSigma.Projects.{Mentions, Project, Task}
  alias BetaSigma.Uploads
  alias BetaSigmaWeb.Realtime

  @task_statuses [:backlog, :in_progress, :review, :done]

  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> Realtime.bootstrap()
     |> Realtime.subscribe(project_id: id)
     |> assign(:active_modal, nil)
     |> assign(:task_statuses, @task_statuses)
     |> assign(:project_changeset, Projects.change_project(%Project{}))
     |> assign(:task_changeset, Projects.change_task(%Task{}))
     |> assign(:note_changeset, Notes.change_note(%Note{}))
     |> assign(:task_assignee_ids, [])
     |> assign(:task_search_query, "")
     |> assign(:task_status_filter, "all")
     |> assign(:task_priority_filter, "all")
     |> assign(:task_assignee_filter, "all")
     |> assign(:selected_task_id, nil)
     |> assign(:selected_document_id, nil)
     |> assign(:task_mode, :new)
     |> assign(:active_task_tab, :details)
     |> assign(:note_task_id, nil)
     |> assign(:comment_form, to_form(%{"body" => ""}, as: :comment))
     |> assign_catalog()
     |> load_project(id)
     |> allow_task_image_uploads()}
  end

  def handle_event("select_task", %{"id" => id}, socket) do
    task = task_by_id(socket.assigns.project, id)

    {:noreply,
     socket
     |> assign(:selected_task_id, task.id)
     |> assign_task_editor(task, {:edit, task.id})
     |> assign(:active_modal, :task)}
  end

  def handle_event("edit_task", %{"id" => id}, socket) do
    task = task_by_id(socket.assigns.project, id)

    {:noreply,
     socket
     |> assign(:selected_task_id, task.id)
     |> assign_task_editor(task, {:edit, task.id})
     |> assign(:active_modal, :task)}
  end

  def handle_event("new_task", _params, socket) do
    task = %Task{project_id: socket.assigns.project.id, description: default_task_description()}

    {:noreply,
     socket
     |> assign_task_editor(task, :new)
     |> assign(:active_modal, :task)}
  end

  def handle_event("switch_task_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_task_tab, String.to_existing_atom(tab))}
  end

  def handle_event("open_comments", %{"id" => id}, socket) do
    task = task_by_id(socket.assigns.project, id)

    {:noreply,
     socket
     |> assign(:selected_task_id, task.id)
     |> assign(:comment_form, to_form(%{"body" => ""}, as: :comment))
     |> assign(:active_modal, :comments)}
  end

  def handle_event("open_document", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_document_id, String.to_integer(id))
     |> assign(:active_modal, :document)}
  end

  def handle_event("edit_project", _params, socket) do
    {:noreply,
     socket
     |> assign(:project_changeset, Projects.change_project(socket.assigns.project))
     |> assign(:active_modal, :project)}
  end

  def handle_event("delete_project", _params, socket) do
    case Projects.delete_project(socket.assigns.project) do
      {:ok, _project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project deleted.")
         |> push_navigate(to: ~p"/app/projects")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Project could not be deleted.")}
    end
  end

  def handle_event("new_note", _params, socket) do
    {:noreply,
     socket
     |> assign_project_note_editor(%Note{project_id: socket.assigns.project.id})
     |> assign(:active_modal, :note)}
  end

  def handle_event("close_modal", %{"modal" => "project"}, socket) do
    {:noreply,
     socket
     |> assign(:project_changeset, Projects.change_project(socket.assigns.project))
     |> assign(:active_modal, nil)}
  end

  def handle_event("close_modal", %{"modal" => "task"}, socket) do
    {:noreply,
     socket
     |> assign_task_editor(%Task{project_id: socket.assigns.project.id}, :new)
     |> assign(:active_modal, nil)}
  end

  def handle_event("close_modal", %{"modal" => "comments"}, socket) do
    {:noreply,
     socket
     |> assign(:comment_form, to_form(%{"body" => ""}, as: :comment))
     |> assign(:active_modal, nil)}
  end

  def handle_event("close_modal", %{"modal" => "document"}, socket) do
    {:noreply,
     socket
     |> assign(:selected_document_id, nil)
     |> assign(:active_modal, nil)}
  end

  def handle_event("close_modal", %{"modal" => "note"}, socket) do
    {:noreply,
     socket
     |> assign_project_note_editor(%Note{project_id: socket.assigns.project.id})
     |> assign(:active_modal, nil)}
  end

  def handle_event("validate_project", %{"project" => params}, socket) do
    changeset =
      socket.assigns.project
      |> Projects.change_project(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :project_changeset, changeset)}
  end

  def handle_event("validate_note", %{"note" => params}, socket) do
    task_id = blank_to_nil(params["task_id"])

    changeset =
      socket.assigns.note_changeset.data
      |> Notes.change_note(note_params(socket, params))
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:note_task_id, task_id)
     |> assign(:note_changeset, changeset)}
  end

  def handle_event("save_project", %{"project" => params}, socket) do
    case Projects.update_project(socket.assigns.project, params) do
      {:ok, _project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project updated.")
         |> assign(:active_modal, nil)
         |> load_project(socket.assigns.project.id,
           selected_task_id: socket.assigns.selected_task_id
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, :project_changeset, Map.put(changeset, :action, :update))}
    end
  end

  def handle_event("save_note", %{"note" => params}, socket) do
    case persist_note(socket, params) do
      {:ok, note} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project note saved.")
         |> assign(:active_modal, nil)
         |> assign(:selected_document_id, note.id)
         |> assign_project_note_editor(%Note{project_id: socket.assigns.project.id})
         |> load_project(socket.assigns.project.id,
           selected_task_id: socket.assigns.selected_task_id
         )}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:note_task_id, blank_to_nil(params["task_id"]))
         |> assign(:note_changeset, Map.put(changeset, :action, :validate))}
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

  def handle_event("filter_tasks", %{"task_filters" => params}, socket) do
    {:noreply,
     socket
     |> assign(:task_search_query, normalize_search_query(params["search"]))
     |> assign(:task_status_filter, normalize_filter_value(params["status"]))
     |> assign(:task_priority_filter, normalize_filter_value(params["priority"]))
     |> assign(:task_assignee_filter, normalize_filter_value(params["assignee_id"]))}
  end

  def handle_event("reset_task_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:task_search_query, "")
     |> assign(:task_status_filter, "all")
     |> assign(:task_priority_filter, "all")
     |> assign(:task_assignee_filter, "all")}
  end

  def handle_event("save_task", %{"task" => params}, socket) do
    assignee_ids = normalize_ids(params["assignee_ids"])
    params = append_task_image_uploads(socket, params)

    case persist_task(socket, params, assignee_ids) do
      {:ok, task} ->
        {:noreply,
         socket
         |> put_flash(:info, "Task saved.")
         |> assign(:active_modal, nil)
         |> load_project(socket.assigns.project.id, selected_task_id: task.id)
         |> assign_task_editor(%Task{project_id: socket.assigns.project.id}, :new)}

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

  def handle_event("delete_task", %{"id" => id}, socket) do
    task = task_by_id(socket.assigns.project, id)
    {:ok, _task} = Projects.delete_task(task)

    next_selected =
      socket.assigns.project.tasks
      |> Enum.reject(&(&1.id == task.id))
      |> List.first()
      |> case do
        nil -> nil
        next_task -> next_task.id
      end

    {:noreply,
     socket
     |> put_flash(:info, "Task deleted.")
     |> assign(:active_modal, nil)
     |> load_project(socket.assigns.project.id, selected_task_id: next_selected)
     |> assign_task_editor(%Task{project_id: socket.assigns.project.id}, :new)}
  end

  def handle_event("move_task", %{"task-id" => id, "status" => status}, socket) do
    task = task_by_id(socket.assigns.project, id)

    case Projects.move_task(task, normalize_task_status(status)) do
      {:ok, moved_task} ->
        {:noreply,
         socket
         |> load_project(socket.assigns.project.id, selected_task_id: moved_task.id)
         |> put_flash(:info, "Task moved to #{humanize(moved_task.status)}.")}

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
        task = task_by_id(socket.assigns.project, socket.assigns.selected_task_id)

        case Projects.add_comment(task, socket.assigns.current_user, body) do
          {:ok, _comment} ->
            {:noreply,
             socket
             |> load_project(socket.assigns.project.id, selected_task_id: task.id)
             |> assign(:comment_form, to_form(%{"body" => ""}, as: :comment))}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Comment could not be saved.")}
        end
    end
  end

  def handle_info(%{event: event} = payload, socket)
      when event in [
             :task_created,
             :task_updated,
             :task_deleted,
             :task_moved,
             :task_assigned,
             :task_comment_added,
             :project_updated
           ] do
    {:noreply,
     socket
     |> Realtime.track_event(payload)
     |> load_project(socket.assigns.project.id, selected_task_id: socket.assigns.selected_task_id)}
  end

  def handle_info(%{event: event} = payload, socket)
      when event in [
             :notification_created,
             :notification_read,
             :notification_unread,
             :notifications_read_all
           ] do
    {:noreply,
     socket
     |> Realtime.sync_unread_count(Map.get(payload, :unread_count))
     |> Realtime.track_event(payload)}
  end

  def render(assigns) do
    selected_task = selected_task(assigns.project, assigns.selected_task_id)
    selected_document = selected_document(assigns.project, assigns.selected_document_id)
    project_notes = project_notes(assigns.project)
    project_documents = project_documents(project_notes)
    linked_notes = linked_notes(project_notes)
    filtered_tasks = filtered_tasks(assigns.project.tasks, assigns)
    task_filter_assignees = task_filter_assignees(assigns.project.tasks)

    assigns =
      assigns
      |> assign(:selected_task, selected_task)
      |> assign(:selected_document, selected_document)
      |> assign(:project_notes, project_notes)
      |> assign(:project_documents, project_documents)
      |> assign(:linked_notes, linked_notes)
      |> assign(:filtered_tasks, filtered_tasks)
      |> assign(:task_filter_assignees, task_filter_assignees)
      |> assign(:note_form, to_form(assigns.note_changeset))
      |> assign(:note_task_options, note_task_options(assigns.project))
      |> assign(:project_form, to_form(assigns.project_changeset))
      |> assign(:task_form, to_form(assigns.task_changeset))

    ~H"""
    <div class="space-y-6">
      <section>
        <div class="flex w-[100%] items-center justify-between gap-3 text-sm">
          <.link
            navigate={~p"/app/projects"}
            class="inline-flex items-center gap-1 text-sm font-medium text-n600 hover:text-n100"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4" /> Back to all projects
          </.link>

          <div class="flex items-center gap-2">
            <button
              type="button"
              phx-click="edit_project"
              class="rounded-md bg-accent px-3 py-1.5 text-sm font-medium text-white hover:bg-accentDeep"
            >
              Edit Project
            </button>
            <button
              type="button"
              phx-click="delete_project"
              data-confirm="Delete this project? All tasks, notes, expenses, time logs, and invoices for this project will also be deleted."
              class="rounded-md px-3 py-1.5 text-sm font-medium text-red-400 hover:bg-red-500/10"
            >
              Delete
            </button>
          </div>
        </div>

        <div class="mt-5 flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <div class="flex flex-wrap items-center gap-3">
              <h2 class="text-2xl font-semibold tracking-tight text-n100">
                {@project.name}
              </h2>
              <span class={project_status_badge(@project.status)}>
                {project_status_label(@project.status)}
              </span>
            </div>
            <p class="mt-4 max-w-3xl text-sm leading-6 text-n600">
              <%= if blank_description?(@project.description) do %>
                Use the project editor to add context, scope, and timeline details for this delivery stream.
              <% else %>
                <.mention_text text={@project.description} />
              <% end %>
            </p>

            <div class="mt-4 max-w-2xl divide-y divide-white/10 rounded-lg border border-white/10 bg-ink">
              <.stat_row label="Deadline" value={format_date(@project.deadline)} />
              <.stat_row label="Budget" value={format_money(@project.budget)} />
            </div>
          </div>
        </div>
      </section>

      <div class="grid gap-6 ">
        <section class="min-w-0 rounded-lg border border-white/10 bg-ink p-4">
          <div class="flex items-start justify-between gap-4">
            <div class="min-w-0">
              <h3 class="text-sm font-semibold text-n100">
                Project documents
              </h3>
              <p class="mt-1 max-w-2xl text-sm text-n600">
                Open the generated markdown document or any other project-level note saved as a document.
              </p>
            </div>
            <span class="text-xs text-n600">
              {length(@project_documents)} docs
            </span>
          </div>

          <div class="mt-4 grid gap-4 md:grid-cols-2">
            <button
              :for={document <- @project_documents}
              type="button"
              phx-click="open_document"
              phx-value-id={document.id}
              class="group min-w-0 rounded-lg border border-white/10 bg-ink p-4 text-left transition hover:bg-white/5"
            >
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0">
                  <p class="line-clamp-2 text-sm font-medium leading-6 text-n100 [overflow-wrap:anywhere]">
                    {document.title}
                  </p>
                  <p class="mt-1 text-xs text-n600">
                    {display_name(document.created_by)}
                  </p>
                </div>
              </div>

              <p class="mt-3 line-clamp-4 text-sm leading-6 text-n600">
                {markdown_preview(
                  document.body,
                  "Open this markdown document to review the full project brief."
                )}
              </p>

              <div class="mt-4 flex items-center justify-between text-xs text-n600">
                <span>{format_datetime(document.inserted_at)}</span>
                <span class="text-accent transition group-hover:underline">
                  Open document
                </span>
              </div>
            </button>

            <div
              :if={@project_documents == []}
              class="rounded-lg border border-dashed border-white/10 p-6 text-center text-sm text-n600 md:col-span-2"
            >
              No markdown project document yet. Create a project with AI assist to generate one automatically.
            </div>
          </div>

          <div class="mt-6 border-t border-white/10 pt-6">
            <div class="flex items-start justify-between gap-4">
              <div class="min-w-0">
                <h4 class="text-sm font-semibold text-n100">
                  Linked notes
                </h4>
                <p class="mt-1 max-w-2xl text-sm text-n600">
                  Shared notes, decision logs, and markdown capture linked directly to this project.
                </p>
              </div>
              <div class="flex items-center gap-3">
                <span class="text-xs text-n600">
                  {length(@linked_notes)} notes
                </span>
                <button
                  type="button"
                  phx-click="new_note"
                  class="rounded-md bg-accent px-3 py-1.5 text-sm font-medium text-white hover:bg-accentDeep"
                >
                  New note
                </button>
              </div>
            </div>

            <div class="mt-4 grid gap-4 md:grid-cols-2">
              <button
                :for={note <- @linked_notes}
                type="button"
                phx-click="open_document"
                phx-value-id={note.id}
                class="group min-w-0 rounded-lg border border-white/10 bg-ink p-4 text-left transition hover:bg-white/5"
              >
                <div class="flex items-start justify-between gap-3">
                  <div class="min-w-0">
                    <div class="flex flex-wrap items-center gap-2">
                      <span class={note_visibility_badge(note.visibility)}>
                        {humanize(note.visibility)}
                      </span>
                      <span
                        :if={markdown_title?(note.title)}
                        class="rounded bg-white/10 px-1.5 py-0.5 text-xs text-n600"
                      >
                        Markdown
                      </span>
                    </div>
                    <p class="mt-2 line-clamp-2 text-sm font-medium leading-6 text-n100 [overflow-wrap:anywhere]">
                      {note.title}
                    </p>
                  </div>
                  <span class="shrink-0 text-xs text-n600">
                    {display_name(note.created_by)}
                  </span>
                </div>

                <p class="mt-3 line-clamp-4 text-sm leading-6 text-n600">
                  {markdown_preview(note.body, "Open this note to review the full content.")}
                </p>

                <div class="mt-4 flex items-center justify-between text-xs text-n600">
                  <span>{format_datetime(note.inserted_at)}</span>
                  <span class="text-accent transition group-hover:underline">Open note</span>
                </div>
              </button>

              <div
                :if={@linked_notes == []}
                class="rounded-lg border border-dashed border-white/10 p-6 text-center text-sm text-n600 md:col-span-2"
              >
                No additional notes are linked to this project yet. Attach one from the Notes workspace to keep context close to delivery.
              </div>
            </div>
          </div>
        </section>
      </div>

      <section class="rounded-lg border border-white/10 bg-ink p-4">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <.header class="!mb-0">
            Project board
            <:subtitle>
              Search the board, narrow by assignee or status, and scan only the work you care about right now.
            </:subtitle>
          </.header>
          <div class="flex items-center gap-3">
            <.link
              navigate={~p"/app/sprints"}
              class="rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 hover:bg-white/5"
            >
              Manage sprints
            </.link>
            <.button phx-click="new_task">
              New task
            </.button>
          </div>
        </div>

        <div class="mt-6 rounded-lg border border-white/10 bg-ink p-4">
          <div class="flex flex-col gap-4">
            <form phx-change="filter_tasks" class="grid gap-3 md:grid-cols-2 xl:grid-cols-5 xl:gap-4">
              <label class="block md:col-span-2 xl:col-span-2">
                <span class="text-xs font-medium text-n600">
                  Search tasks
                </span>
                <input
                  type="text"
                  name="task_filters[search]"
                  value={@task_search_query}
                  placeholder="Search title, description, phase, or assignee"
                  phx-debounce="300"
                  class="mt-2 w-full rounded-md border border-white/10 bg-ink px-3 py-2 text-sm text-n100 placeholder-n600 focus:border-accent focus:ring-2 focus:ring-accent/30"
                />
              </label>

              <label class="block">
                <span class="text-xs font-medium text-n600">
                  Assignee
                </span>
                <select
                  name="task_filters[assignee_id]"
                  class="mt-2 w-full rounded-md border border-white/10 bg-ink px-3 py-2 text-sm text-n100 focus:border-accent focus:ring-2 focus:ring-accent/30"
                >
                  <option value="all" selected={@task_assignee_filter == "all"}>All assignees</option>
                  <option
                    :for={user <- @task_filter_assignees}
                    value={user.id}
                    selected={to_string(user.id) == @task_assignee_filter}
                  >
                    {display_name(user)}
                  </option>
                </select>
              </label>

              <label class="block">
                <span class="text-xs font-medium text-n600">
                  Status
                </span>
                <select
                  name="task_filters[status]"
                  class="mt-2 w-full rounded-md border border-white/10 bg-ink px-3 py-2 text-sm text-n100 focus:border-accent focus:ring-2 focus:ring-accent/30"
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

              <label class="block">
                <span class="text-xs font-medium text-n600">
                  Priority
                </span>
                <select
                  name="task_filters[priority]"
                  class="mt-2 w-full rounded-md border border-white/10 bg-ink px-3 py-2 text-sm text-n100 focus:border-accent focus:ring-2 focus:ring-accent/30"
                >
                  <option value="all" selected={@task_priority_filter == "all"}>
                    All priorities
                  </option>
                  <option
                    :for={priority <- task_priorities()}
                    value={priority}
                    selected={Atom.to_string(priority) == @task_priority_filter}
                  >
                    {humanize(priority)}
                  </option>
                </select>
              </label>
            </form>

            <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <p class="text-xs text-n600 whitespace-nowrap">
                Showing {length(@filtered_tasks)} of {length(@project.tasks)} tasks
              </p>
              <button
                type="button"
                phx-click="reset_task_filters"
                class="self-start rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 hover:bg-white/5 sm:self-auto"
              >
                Clear filters
              </button>
            </div>
          </div>
        </div>

        <div
          :if={@filtered_tasks == []}
          class="mt-6 rounded-lg border border-dashed border-white/10 p-6 text-center text-sm text-n600"
        >
          No tasks match the current filters. Try a different search term or clear one of the filters above.
        </div>

        <div class="mt-6 overflow-x-auto pb-3 [scrollbar-width:thin]">
          <div class="flex min-w-max gap-5 pr-2">
            <div :for={status <- @task_statuses} class={column_shell_class(status)}>
              <div class="flex items-center justify-between gap-3">
                <div class="flex items-center gap-2">
                  <span class={column_badge(status)}></span>
                  <p class="text-sm font-semibold text-n100">
                    {humanize(status)}
                  </p>
                </div>
                <p class="text-xs text-n600">
                  {task_count(@filtered_tasks, status)} items
                </p>
              </div>

              <div
                id={"kanban-column-#{status}"}
                phx-hook="KanbanColumn"
                data-status={status}
                class="kanban-dropzone mt-4 min-h-[20rem] space-y-3 rounded-lg border border-dashed border-white/10 bg-ink p-2"
              >
                <article
                  :for={task <- tasks_for_status(@filtered_tasks, status)}
                  id={"task-card-#{task.id}"}
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
                        <p class="text-sm font-medium leading-6 text-n100 line-clamp-3">
                          {task.title}
                        </p>

                        <div class="flex flex-wrap items-center gap-1.5">
                          <span :if={present?(task.phase)} class={phase_badge(task.phase)}>
                            {task.phase}
                          </span>
                          <span class={priority_badge(task.priority)}>{humanize(task.priority)}</span>
                          <span
                            :if={task.sprint}
                            class="rounded bg-white/10 px-1.5 py-0.5 text-xs text-n600"
                          >
                            {task.sprint.name}
                          </span>
                        </div>
                      </div>

                      <span class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-md text-n600 hover:bg-white/10">
                        <.icon name="hero-pencil-square" class="h-4 w-4" />
                      </span>
                    </div>

                    <div class="mt-3 line-clamp-4 text-sm leading-6 text-n600">
                      <%= if blank_description?(task.description) do %>
                        No description.
                      <% else %>
                        <.mention_text text={task.description} />
                      <% end %>
                    </div>

                    <dl class="mt-4 grid grid-cols-2 gap-x-4 gap-y-2 border-t border-white/10 pt-3">
                      <div>
                        <dt class="text-xs text-n600">
                          Due
                        </dt>
                        <dd class={task_meta_value_class(task, :due)}>
                          {due_label(task)}
                        </dd>
                      </div>
                      <div>
                        <dt class="text-xs text-n600">
                          Hours
                        </dt>
                        <dd class="mt-0.5 text-sm font-medium text-n100">
                          {estimated_hours_label(task)}
                        </dd>
                      </div>
                      <div>
                        <dt class="text-xs text-n600">
                          Assigned
                        </dt>
                        <dd class="mt-0.5 text-sm font-medium text-n100">
                          {task_assignee_count(task)}
                        </dd>
                      </div>
                      <div>
                        <dt class="text-xs text-n600">
                          Comments
                        </dt>
                        <dd class="mt-0.5 text-sm font-medium text-n100">
                          {length(task.comments)}
                        </dd>
                      </div>
                    </dl>
                  </button>

                  <div class="mt-3 flex flex-wrap gap-2 border-t border-white/10 pt-3">
                    <button
                      type="button"
                      phx-click="open_comments"
                      phx-value-id={task.id}
                      class="rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 hover:bg-white/5"
                    >
                      Open discussion
                    </button>
                  </div>
                </article>

                <div
                  :if={tasks_for_status(@filtered_tasks, status) == []}
                  class="rounded-lg border border-dashed border-white/10 p-6 text-center text-sm text-n600"
                >
                  {empty_column_message(status)}
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <.modal
        :if={@active_modal == :comments and @selected_task}
        id="task-comments-modal"
        show
        on_cancel={JS.push("close_modal", value: %{modal: "comments"})}
      >
        <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h3 class="text-base font-semibold text-n100">
              {@selected_task.title}
            </h3>
            <p class="mt-1 text-sm text-n600">
              Review the full discussion and add a new comment without opening the task editor.
            </p>
          </div>

          <button
            type="button"
            phx-click="edit_task"
            phx-value-id={@selected_task.id}
            class="rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 hover:bg-white/5"
          >
            Edit task
          </button>
        </div>

        <div class="mt-6 rounded-lg border border-white/10 bg-white/5 p-4">
          <div class="flex items-center justify-between">
            <p class="text-sm font-semibold text-n100">
              Discussion
            </p>
            <span class="text-xs text-n600">
              {length(@selected_task.comments)} comments
            </span>
          </div>

          <div class="mt-4 space-y-3">
            <article
              :for={comment <- @selected_task.comments}
              class="rounded-lg border border-white/10 bg-ink px-4 py-3"
            >
              <p class="text-sm font-medium text-n100">{display_name(comment.user)}</p>
              <p class="mt-1 text-sm leading-6 text-n600 whitespace-pre-wrap break-words">
                <.mention_text text={comment.body} />
              </p>
            </article>

            <div
              :if={@selected_task.comments == []}
              class="rounded-lg border border-dashed border-white/10 p-6 text-center text-sm text-n600"
            >
              No comments yet. Start the discussion below.
            </div>
          </div>

          <.simple_form for={@comment_form} phx-submit="save_comment">
            <div>
              <.input
                field={@comment_form[:body]}
                type="textarea"
                label="Add comment"
                rows="3"
                id="task-comment-input"
                phx-hook="MentionInput"
                data-mention-users={@mention_users_json}
              />
              <p class="mt-1 text-xs text-n600">
                Type <span class="font-medium text-n600">@</span>
                to mention a teammate. They'll get a notification and an email.
              </p>
            </div>
            <:actions>
              <button
                type="button"
                phx-click="close_modal"
                phx-value-modal="comments"
                class="rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 hover:bg-white/5"
              >
                Close
              </button>
              <.button>Add comment</.button>
            </:actions>
          </.simple_form>
        </div>
      </.modal>

      <.modal
        :if={@active_modal == :document and @selected_document}
        id="project-document-modal"
        show
        on_cancel={JS.push("close_modal", value: %{modal: "document"})}
      >
        <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h3 class="text-base font-semibold text-n100">
              {@selected_document.title}
            </h3>
            <p class="mt-1 text-sm text-n600">
              Linked project note stored in the database. Markdown headings and bullets are rendered below when present.
            </p>
          </div>

          <div class="flex items-center gap-3">
            <button
              id={"copy-project-document-#{@selected_document.id}"}
              type="button"
              phx-hook="CopyToClipboard"
              data-copy-target={"#project-document-source-#{@selected_document.id}"}
              data-success-label="Copied"
              class="inline-flex items-center gap-2 rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 hover:bg-white/5"
            >
              <.icon name="hero-document-duplicate" class="h-4 w-4" />
              <span data-copy-label>Copy</span>
            </button>

            <button
              type="button"
              phx-click="close_modal"
              phx-value-modal="document"
              class="rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 hover:bg-white/5"
            >
              Close
            </button>
          </div>
        </div>

        <div class="mt-6 rounded-lg border border-white/10 bg-white/5 p-4">
          <div class="flex flex-wrap items-center justify-between gap-3 border-b border-white/10 pb-4">
            <p class="text-xs text-n600">
              {display_name(@selected_document.created_by)}
            </p>
            <span class="text-xs text-n600">
              {format_datetime(@selected_document.inserted_at)}
            </span>
          </div>

          <textarea id={"project-document-source-#{@selected_document.id}"} class="sr-only" readonly>{@selected_document.body}</textarea>

          <article class="mt-5 max-h-[65vh] overflow-y-auto rounded-lg border border-white/10 bg-ink p-6">
            <.markdown_viewer body={@selected_document.body} empty_copy="No note body yet." />
          </article>
        </div>
      </.modal>

      <.modal
        :if={@active_modal == :project}
        id="project-editor-modal"
        show
        on_cancel={JS.push("close_modal", value: %{modal: "project"})}
      >
        <div>
          <h3 class="text-base font-semibold text-n100">Edit project</h3>
          <p class="mt-1 text-sm text-n600">
            Update budget and timeline without leaving the project board.
          </p>
        </div>

        <.simple_form for={@project_form} phx-change="validate_project" phx-submit="save_project">
          <.input field={@project_form[:name]} label="Project name" />
          <.input
            field={@project_form[:status]}
            type="select"
            label="Status"
            options={project_status_options()}
          />
          <div class="grid gap-4 sm:grid-cols-2">
            <.input field={@project_form[:start_date]} type="date" label="Start date" />
            <.input field={@project_form[:deadline]} type="date" label="Deadline" />
          </div>
          <.input field={@project_form[:budget]} type="number" step="0.01" label="Budget" />
          <div>
            <.input
              field={@project_form[:description]}
              type="textarea"
              label="Description"
              rows="4"
              id="project-description-input"
              phx-hook="MentionInput"
              data-mention-users={@mention_users_json}
            />
            <p class="mt-1 text-xs text-n600">
              Type <span class="font-medium text-n600">@</span>
              to mention a teammate. They'll get a notification and an email.
            </p>
          </div>
          <:actions>
            <button
              type="button"
              phx-click="close_modal"
              phx-value-modal="project"
              class="rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 hover:bg-white/5"
            >
              Cancel
            </button>
            <.button>Save project</.button>
          </:actions>
        </.simple_form>
      </.modal>

      <.modal
        :if={@active_modal == :task}
        id="task-editor-modal"
        show
        on_cancel={JS.push("close_modal", value: %{modal: "task"})}
      >
        <div>
          <h3 class="text-base font-semibold text-n100">
            {task_form_title(@task_mode)}
          </h3>
          <p class="mt-1 text-sm text-n600">
            Create work items or update the selected task in a focused popup form.
          </p>
        </div>

        <.task_tab_nav active_tab={@active_task_tab} />

        <.simple_form for={@task_form} phx-change="validate_task" phx-submit="save_task">
          <div class={task_tab_class(@active_task_tab, :details)}>
            <.input field={@task_form[:title]} label="Task title" />
            <.input field={@task_form[:phase]} label="Phase or workstream" />
            <.input
              field={@task_form[:sprint_id]}
              type="select"
              label="Sprint"
              prompt="No sprint"
              options={sprint_options(@all_sprints)}
            />
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
                class="flex items-center gap-3 rounded-md border border-white/10 bg-ink px-3 py-2 text-sm text-n600"
              >
                <input
                  type="checkbox"
                  name="task[assignee_ids][]"
                  value={user.id}
                  checked={user.id in @task_assignee_ids}
                  class="rounded border-white/10 text-accent"
                />
                <span>{display_name(user)}</span>
              </label>
            </div>
          </div>

          <div class={task_tab_class(@active_task_tab, :description)}>
            <.label for="task-description-input">Description</.label>
            <div
              id="task-description-toolbar"
              phx-hook="FormatToolbar"
              data-target="task-description-input"
              class="mt-1.5 flex items-center gap-1 rounded-t-md border border-b-0 border-white/10 bg-white/5 px-2 py-1"
            >
              <button
                type="button"
                data-format="bold"
                class="rounded px-2 py-1 text-sm font-bold text-n600 hover:bg-white/10"
                title="Bold"
              >
                B
              </button>
              <button
                type="button"
                data-format="heading"
                class="rounded px-2 py-1 text-xs font-bold text-n600 hover:bg-white/10"
                title="Heading"
              >
                H
              </button>
              <label
                class="ml-auto flex cursor-pointer items-center gap-1.5 rounded px-2 py-1 text-xs font-medium text-n600 hover:bg-white/10"
                title="Upload image"
              >
                <.icon name="hero-photo" class="h-4 w-4" />
                <span>Image</span>
                <.live_file_input upload={@uploads.task_images} class="sr-only" />
              </label>
            </div>
            <div
              :if={@uploads.task_images.entries != []}
              class="border-x border-white/10 bg-white/5 px-3 py-2"
            >
              <div class="flex flex-wrap items-start gap-2">
                <div :for={entry <- @uploads.task_images.entries} class="relative">
                  <div class="overflow-hidden rounded-md border border-white/10 bg-ink">
                    <.live_img_preview
                      :if={String.starts_with?(entry.client_type, "image/")}
                      entry={entry}
                      class="h-20 w-24 object-cover"
                    />
                    <span class="block max-w-24 truncate px-2 py-1 text-[10px] text-n600">
                      {entry.client_name}
                    </span>
                  </div>
                  <button
                    type="button"
                    phx-click="cancel_task_image_upload"
                    phx-value-ref={entry.ref}
                    class="absolute -right-1.5 -top-1.5 rounded-full bg-white/10 p-0.5 text-white"
                  >
                    <.icon name="hero-x-mark" class="h-3 w-3" />
                  </button>
                  <p
                    :for={err <- upload_errors(@uploads.task_images, entry)}
                    class="mt-0.5 text-[10px] text-red-400"
                  >
                    {upload_error_msg(err)}
                  </p>
                </div>
                <button
                  type="button"
                  phx-click="insert_task_images"
                  disabled={Enum.any?(@uploads.task_images.entries, fn entry -> not entry.done? end)}
                  class="self-center rounded-md border border-white/10 bg-ink px-3 py-1.5 text-xs font-medium text-n600 hover:bg-white/5 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  Insert into description
                </button>
              </div>
            </div>
            <.input
              field={@task_form[:description]}
              type="textarea"
              rows="16"
              id="task-description-input"
              phx-hook="MentionInput"
              data-mention-users={@mention_users_json}
              textarea_class="!mt-0 rounded-t-none text-base leading-relaxed"
            />
            <p class="mt-1 text-xs text-n600">
              Type <span class="font-medium text-n600">@</span>
              to mention a teammate. Use <span class="font-medium text-n600">**bold**</span>
              and <span class="font-medium text-n600"># heading</span>
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
              class="rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 hover:bg-white/5"
            >
              Cancel
            </button>
            <.button>{task_submit_label(@task_mode)}</.button>
          </:actions>
        </.simple_form>
      </.modal>

      <.modal
        :if={@active_modal == :note}
        id="project-note-modal"
        show
        on_cancel={JS.push("close_modal", value: %{modal: "note"})}
      >
        <div>
          <h3 class="text-base font-semibold text-n100">
            Add note to project
          </h3>
          <p class="mt-1 text-sm text-n600">
            Capture decisions, markdown briefs, meeting notes, or research directly against this project.
          </p>
        </div>

        <.simple_form for={@note_form} phx-change="validate_note" phx-submit="save_note">
          <.input field={@note_form[:title]} label="Title" />
          <.input
            field={@note_form[:visibility]}
            type="select"
            label="Visibility"
            options={note_visibility_options()}
          />
          <.input
            field={@note_form[:task_id]}
            type="select"
            label="Linked task"
            prompt="Optional task link"
            options={@note_task_options}
          />
          <.input field={@note_form[:body]} type="textarea" label="Body" rows="10" />
          <:actions>
            <button
              type="button"
              phx-click="close_modal"
              phx-value-modal="note"
              class="rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 hover:bg-white/5"
            >
              Cancel
            </button>
            <.button>Save note</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp stat_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-4 px-4 py-3">
      <p class="text-xs text-n600">{@label}</p>
      <p class="text-sm font-medium text-n100">{@value}</p>
    </div>
    """
  end

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
      class="my-3 max-h-80 w-full rounded-md border border-white/10 object-contain"
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

  defp heading_class(1), do: "block text-base font-semibold text-n100"
  defp heading_class(2), do: "block text-sm font-semibold text-n100"
  defp heading_class(_level), do: "block text-sm font-semibold text-n100"

  defp inline_segment_class({:mention, _name}),
    do: "rounded bg-white/10 px-1 font-medium text-n600"

  defp inline_segment_class({:bold, _value}), do: "font-semibold text-n100"
  defp inline_segment_class({:text, _value}), do: nil

  defp inline_segment_text({:mention, name}), do: "@" <> name
  defp inline_segment_text({:bold, value}), do: value
  defp inline_segment_text({:text, value}), do: value

  defp blank_description?(description), do: String.trim(description || "") == ""

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
    <div class="mt-4 flex gap-1 border-b border-white/10">
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
        @tab == @active_tab && "border-accent text-n100",
        @tab != @active_tab &&
          "border-transparent text-n600 hover:text-n600"
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
    <div :if={@images != []} class="mt-3 rounded-md border border-white/10 bg-white/5 p-3">
      <p class="text-xs font-medium text-n600">Image preview</p>
      <div class="mt-2 grid gap-3 sm:grid-cols-2">
        <figure
          :for={{alt, url} <- @images}
          class="overflow-hidden rounded-md border border-white/10 bg-ink"
        >
          <img src={url} alt={alt} loading="lazy" class="max-h-60 w-full object-contain" />
          <figcaption class="truncate px-3 py-2 text-xs text-n600">{alt}</figcaption>
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
      all_sprints: Projects.list_sprints()
    )
  end

  defp load_project(socket, id, opts \\ []) do
    project = Projects.get_project!(id)

    selected_task_id =
      pick_selected_task(project, opts[:selected_task_id] || socket.assigns[:selected_task_id])

    socket
    |> assign(:page_title, project.name)
    |> assign(:project, project)
    |> assign(:selected_task_id, selected_task_id)
    |> assign(:project_changeset, opts[:project_changeset] || Projects.change_project(project))
  end

  defp task_editor_struct(socket) do
    case socket.assigns.task_mode do
      :new ->
        %Task{project_id: socket.assigns.project.id}

      {:edit, id} ->
        task_by_id(socket.assigns.project, id)
    end
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
        socket.assigns.project
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
    |> Map.put("project_id", socket.assigns.project.id)
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

  defp pick_selected_task(project, nil) do
    case List.first(project.tasks) do
      nil -> nil
      task -> task.id
    end
  end

  defp pick_selected_task(project, selected_task_id) do
    if Enum.any?(project.tasks, &(&1.id == selected_task_id)),
      do: selected_task_id,
      else: pick_selected_task(project, nil)
  end

  defp selected_task(project, selected_task_id) do
    Enum.find(project.tasks, &(&1.id == selected_task_id))
  end

  defp selected_document(project, selected_document_id) do
    Enum.find(project.notes || [], &(&1.id == selected_document_id))
  end

  defp task_by_id(project, id) when is_binary(id), do: task_by_id(project, String.to_integer(id))
  defp task_by_id(project, id), do: Enum.find(project.tasks, &(&1.id == id))

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

  defp normalize_search_query(nil), do: ""
  defp normalize_search_query(query), do: String.trim(query)

  defp normalize_filter_value(nil), do: "all"
  defp normalize_filter_value(""), do: "all"
  defp normalize_filter_value(value), do: value

  defp filtered_tasks(tasks, assigns) do
    query = String.downcase(assigns.task_search_query || "")
    status_filter = assigns.task_status_filter || "all"
    priority_filter = assigns.task_priority_filter || "all"
    assignee_filter = assigns.task_assignee_filter || "all"

    Enum.filter(tasks, fn task ->
      task_matches_query?(task, query) and
        task_matches_status?(task, status_filter) and
        task_matches_priority?(task, priority_filter) and
        task_matches_assignee?(task, assignee_filter)
    end)
  end

  defp tasks_for_status(tasks, status), do: Enum.filter(tasks, &(&1.status == status))
  defp task_count(tasks, status), do: Enum.count(tasks, &(&1.status == status))

  defp task_filter_assignees(tasks) do
    tasks
    |> Enum.flat_map(fn task ->
      case Map.get(task, :assignees) do
        assignees when is_list(assignees) -> assignees
        _ -> []
      end
    end)
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(&String.downcase(display_name(&1)))
  end

  defp task_matches_query?(_task, ""), do: true

  defp task_matches_query?(task, query) do
    haystacks =
      [
        task.title,
        task.description,
        task.phase
      ] ++ task_assignee_names(task)

    Enum.any?(haystacks, fn value ->
      value
      |> to_string()
      |> String.downcase()
      |> String.contains?(query)
    end)
  end

  defp task_matches_status?(_task, "all"), do: true
  defp task_matches_status?(task, status_filter), do: Atom.to_string(task.status) == status_filter

  defp task_matches_priority?(_task, "all"), do: true

  defp task_matches_priority?(task, priority_filter),
    do: Atom.to_string(task.priority) == priority_filter

  defp task_matches_assignee?(_task, "all"), do: true

  defp task_matches_assignee?(task, assignee_filter) do
    task
    |> task_assignee_ids()
    |> Enum.any?(&(to_string(&1) == assignee_filter))
  end

  defp task_assignee_ids(%Task{} = task) do
    case Map.get(task, :assignees) do
      assignees when is_list(assignees) -> Enum.map(assignees, & &1.id)
      _ -> []
    end
  end

  defp task_assignee_names(%Task{} = task) do
    case Map.get(task, :assignees) do
      assignees when is_list(assignees) -> Enum.map(assignees, &display_name/1)
      _ -> []
    end
  end

  defp task_card_class(task, selected_task_id) do
    base =
      "block w-full rounded-lg border bg-ink px-4 py-4 text-left transition hover:bg-white/5"

    if task.id == selected_task_id do
      base <> " border-accent"
    else
      base <> " border-white/10"
    end
  end

  defp task_assignee_count(%Task{} = task) do
    case Map.get(task, :assignees) do
      assignees when is_list(assignees) -> length(assignees)
      _ -> 0
    end
  end

  defp column_badge(:backlog), do: "h-2.5 w-2.5 rounded-full bg-white/10"
  defp column_badge(:in_progress), do: "h-2.5 w-2.5 rounded-full bg-amber-500"
  defp column_badge(:review), do: "h-2.5 w-2.5 rounded-full bg-sky-500"
  defp column_badge(:done), do: "h-2.5 w-2.5 rounded-full bg-emerald-500"

  defp column_shell_class(_status),
    do: "w-[21rem] shrink-0 rounded-lg border border-white/10 bg-white/5 p-3"

  defp empty_column_message(:backlog),
    do: "No backlog tasks yet. Capture the next chunk of work here."

  defp empty_column_message(:in_progress), do: "Nothing is actively moving right now."
  defp empty_column_message(:review), do: "No work is waiting for review."
  defp empty_column_message(:done), do: "Completed work will appear here."

  defp phase_badge(_phase),
    do: "rounded bg-white/10 px-1.5 py-0.5 text-xs text-n600"

  defp priority_badge(:urgent),
    do: "rounded bg-white/10 px-1.5 py-0.5 text-xs text-red-400"

  defp priority_badge(:high),
    do: "rounded bg-white/10 px-1.5 py-0.5 text-xs text-amber-600"

  defp priority_badge(:medium),
    do: "rounded bg-white/10 px-1.5 py-0.5 text-xs text-n600"

  defp priority_badge(:low),
    do: "rounded bg-white/10 px-1.5 py-0.5 text-xs text-n600"

  defp due_label(task) do
    cond do
      overdue_task?(task) -> "Overdue #{format_date(task.due_date)}"
      is_nil(task.due_date) -> "No due date"
      true -> "Due #{format_date(task.due_date)}"
    end
  end

  defp estimated_hours_label(%Task{estimated_hours: nil}), do: "Hours TBD"
  defp estimated_hours_label(%Task{estimated_hours: hours}), do: "#{hours}h"

  defp task_meta_value_class(task, :due) do
    if overdue_task?(task) do
      "mt-0.5 text-sm font-medium text-red-400"
    else
      "mt-0.5 text-sm font-medium text-n100"
    end
  end

  defp project_status_badge(:planning),
    do: "inline-flex items-center gap-1 text-xs font-medium text-n600"

  defp project_status_badge(:active),
    do: "inline-flex items-center gap-1 text-xs font-medium text-emerald-600"

  defp project_status_badge(:on_hold),
    do: "inline-flex items-center gap-1 text-xs font-medium text-amber-600"

  defp project_status_badge(:completed),
    do: "inline-flex items-center gap-1 text-xs font-medium text-sky-600"

  defp project_status_badge(:archived),
    do: "inline-flex items-center gap-1 text-xs font-medium text-red-400"

  defp project_status_badge(:backlog), do: project_status_badge(:planning)
  defp project_status_badge(:in_progress), do: project_status_badge(:on_hold)
  defp project_status_badge(:review), do: project_status_badge(:completed)
  defp project_status_badge(:done), do: project_status_badge(:active)

  defp project_status_label(status), do: "● " <> humanize(status)

  defp note_visibility_badge(:shared),
    do: "rounded bg-white/10 px-1.5 py-0.5 text-xs text-emerald-600"

  defp note_visibility_badge(:personal),
    do: "rounded bg-white/10 px-1.5 py-0.5 text-xs text-n600"

  defp project_status_options do
    [
      {"Planning", :planning},
      {"Active", :active},
      {"On hold", :on_hold},
      {"Completed", :completed},
      {"Archived", :archived}
    ]
  end

  defp task_status_options do
    [
      {"Backlog", :backlog},
      {"In progress", :in_progress},
      {"Review", :review},
      {"Done", :done}
    ]
  end

  defp task_priorities, do: [:low, :medium, :high, :urgent]

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
  defp note_visibility_options, do: [{"Personal", :personal}, {"Shared", :shared}]

  defp sprint_options(sprints) do
    sprints
    |> List.wrap()
    |> Enum.map(&{&1.name, &1.id})
  end

  defp project_notes(project), do: List.wrap(project.notes)

  defp project_documents(notes) do
    Enum.filter(notes, &markdown_title?(&1.title || ""))
  end

  defp linked_notes(notes), do: Enum.reject(notes, &markdown_title?(&1.title || ""))

  defp note_task_options(project) do
    project.tasks
    |> List.wrap()
    |> Enum.map(&{&1.title, &1.id})
  end

  defp assign_project_note_editor(socket, %Note{} = note) do
    socket
    |> assign(:note_task_id, note.task_id)
    |> assign(:note_changeset, Notes.change_note(note))
  end

  defp persist_note(socket, params) do
    attrs = note_params(socket, params)
    Notes.create_note(attrs)
  end

  defp note_params(socket, params) do
    params
    |> Map.put("project_id", socket.assigns.project.id)
    |> Map.put("created_by_id", socket.assigns.current_user.id)
    |> Map.update("task_id", nil, &blank_to_nil/1)
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp overdue_task?(%Task{due_date: %Date{} = due_date, status: status}) do
    Date.compare(due_date, Date.utc_today()) == :lt and status != :done
  end

  defp overdue_task?(_task), do: false

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)

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
  defp format_datetime(nil), do: "Unknown"
  defp format_datetime(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%d %b %Y %H:%M")
end
