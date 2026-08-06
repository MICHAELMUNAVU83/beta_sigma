defmodule BetaSigmaWeb.NotesLive.Index do
  use BetaSigmaWeb, :live_view

  alias BetaSigma.{Notes, Projects}
  alias BetaSigma.Notes.Note
  alias BetaSigmaWeb.Realtime

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> Realtime.bootstrap()
     |> Realtime.subscribe()
     |> assign(:page_title, "Notes")
     |> assign(:active_modal, nil)
     |> assign(:visibility_filter, "all")
     |> assign(:search_query, "")
     |> assign(:selected_note_id, nil)
     |> assign(:note_mode, :new)
     |> assign(:note_project_id, nil)
     |> assign(:note_attachments, [])
     |> assign(:note_changeset, Notes.change_note(%Note{}))
     |> assign_catalog()
     |> allow_upload(:note_files,
       accept: ~w(.pdf .doc .docx),
       max_entries: 5,
       max_file_size: 25_000_000
     )
     |> load_notes()}
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

  def handle_event("filter_visibility", params, socket) do
    value = params["filter"] || params["value"] || "all"

    {:noreply,
     socket
     |> assign(:visibility_filter, value)
     |> load_notes()}
  end

  def handle_event("search_notes", %{"value" => query}, socket) do
    {:noreply, assign(socket, :search_query, String.downcase(query))}
  end

  def handle_event("select_note", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_note_id, String.to_integer(id))}
  end

  def handle_event("edit_note", %{"id" => id}, socket) do
    note = note_by_id(socket.assigns.notes, id)

    if note.created_by_id == socket.assigns.current_user.id do
      {:noreply,
       socket
       |> reset_note_uploads()
       |> assign(:selected_note_id, note.id)
       |> assign_note_editor(note, {:edit, note.id})
       |> assign(:active_modal, :note)}
    else
      {:noreply, put_flash(socket, :error, "Only the author can edit this note.")}
    end
  end

  def handle_event("new_note", _params, socket) do
    {:noreply,
     socket
     |> reset_note_uploads()
     |> assign_note_editor(%Note{}, :new)
     |> assign(:active_modal, :note)}
  end

  def handle_event("close_modal", %{"modal" => "note"}, socket) do
    {:noreply,
     socket
     |> reset_note_uploads()
     |> assign_note_editor(%Note{}, :new)
     |> assign(:active_modal, nil)}
  end

  def handle_event("cancel_note_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :note_files, ref)}
  end

  def handle_event("remove_note_attachment", %{"url" => url}, socket) do
    remaining = Enum.reject(socket.assigns.note_attachments, &(&1["url"] == url))
    {:noreply, assign(socket, :note_attachments, remaining)}
  end

  def handle_event("validate_note", %{"note" => params}, socket) do
    project_id = blank_to_nil(params["project_id"])

    changeset =
      note_editor_struct(socket)
      |> Notes.change_note(note_params(socket, params))
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:note_project_id, project_id)
     |> assign(:note_changeset, changeset)}
  end

  def handle_event("save_note", %{"note" => params}, socket) do
    new_attachments =
      consume_uploaded_entries(socket, :note_files, fn %{path: path}, entry ->
        url = BetaSigma.Uploads.persist_upload!("notes", %{path: path}, entry.client_name)

        {:ok,
         %{
           "url" => url,
           "filename" => entry.client_name,
           "content_type" => entry.client_type
         }}
      end)

    params = Map.put(params, "attachments", socket.assigns.note_attachments ++ new_attachments)

    case persist_note(socket, params) do
      {:ok, note} ->
        {:noreply,
         socket
         |> put_flash(:info, "Note saved.")
         |> assign(:note_changeset, Notes.change_note(%Note{}))
         |> assign(:note_mode, :new)
         |> assign(:note_project_id, nil)
         |> assign(:active_modal, nil)
         |> load_notes(selected_note_id: note.id)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:note_project_id, blank_to_nil(params["project_id"]))
         |> assign(:note_changeset, Map.put(changeset, :action, :validate))}
    end
  end

  def handle_event("delete_note", %{"id" => id}, socket) do
    note = note_by_id(socket.assigns.notes, id)

    if note.created_by_id == socket.assigns.current_user.id do
      {:ok, _note} = Notes.delete_note(note)

      next_selected =
        socket.assigns.notes
        |> Enum.reject(&(&1.id == note.id))
        |> List.first()
        |> case do
          nil -> nil
          remaining_note -> remaining_note.id
        end

      {:noreply,
       socket
       |> put_flash(:info, "Note deleted.")
       |> assign_note_editor(%Note{}, :new)
       |> assign(:active_modal, nil)
       |> load_notes(selected_note_id: next_selected)}
    else
      {:noreply, put_flash(socket, :error, "Only the author can delete this note.")}
    end
  end

  def render(assigns) do
    selected_note = Enum.find(assigns.notes, &(&1.id == assigns.selected_note_id))

    filtered_notes =
      if assigns.search_query == "" do
        assigns.notes
      else
        Enum.filter(assigns.notes, &note_matches_query?(&1, assigns.search_query))
      end

    assigns =
      assigns
      |> assign(:selected_note, selected_note)
      |> assign(:filtered_notes, filtered_notes)
      |> assign(:note_form, to_form(assigns.note_changeset))
      |> assign(:task_options, task_options(assigns.task_map, assigns.note_project_id))

    ~H"""
    <div class="space-y-6">
      <section class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 class="text-2xl font-semibold tracking-tight text-n100">Notes</h2>
          <p class="mt-1 text-sm text-n600">
            {length(@notes)} total
          </p>
        </div>
        <button
          type="button"
          phx-click="new_note"
          class="rounded-md bg-accent px-3 py-1.5 text-sm font-medium text-white hover:bg-accentDeep focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40"
        >
          New note
        </button>
      </section>

      <div class="grid gap-6 xl:grid-cols-[22rem_minmax(0,1fr)]">
        <aside
          class="flex flex-col overflow-hidden rounded-lg border border-white/10 bg-ink xl:sticky xl:top-6"
          style="max-height: calc(100vh - 6rem);"
        >
          <div class="flex-shrink-0 space-y-4 p-4">
            <div>
              <p class="text-sm font-medium text-n600">
                Visibility
              </p>
              <div class="mt-3 flex flex-wrap gap-2">
                <button
                  :for={filter <- visibility_filters()}
                  type="button"
                  phx-click="filter_visibility"
                  phx-value-filter={filter.value}
                  class={filter_button_class(@visibility_filter, filter.value)}
                >
                  {filter.label}
                </button>
              </div>
            </div>

            <div class="relative">
              <span class="pointer-events-none absolute inset-y-0 left-3 flex items-center text-n600">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-4 w-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M21 21l-4.35-4.35M17 11A6 6 0 1 1 5 11a6 6 0 0 1 12 0z"
                  />
                </svg>
              </span>
              <input
                type="text"
                placeholder="Search notes..."
                value={@search_query}
                phx-keyup="search_notes"
                class="w-full rounded-md border border-white/10 bg-ink py-2 pl-9 pr-3 text-sm text-n100 placeholder-n600 focus:border-accent focus:outline-none focus:ring-2 focus:ring-accent/30"
              />
            </div>
          </div>

          <div class="flex flex-shrink-0 items-center justify-between border-t border-white/10 px-4 py-2">
            <p class="text-xs font-medium text-n600">Notes</p>
            <span class="text-xs text-n600">
              {length(@filtered_notes)} total
            </span>
          </div>

          <div class="flex-1 overflow-y-auto">
            <div class="divide-y divide-white/10">
              <button
                :for={note <- @filtered_notes}
                type="button"
                phx-click="select_note"
                phx-value-id={note.id}
                class={note_list_item_class(note.id == @selected_note_id)}
              >
                <div class="flex items-start justify-between gap-3">
                  <div class="min-w-0 flex-1">
                    <p class="line-clamp-2 text-left text-sm font-medium leading-6 text-n100 [overflow-wrap:anywhere]">
                      {note.title}
                    </p>
                    <p class="mt-1 line-clamp-2 text-left text-xs leading-5 text-n600 [overflow-wrap:anywhere]">
                      {markdown_preview(note.body, "No content preview yet.")}
                    </p>
                    <div class="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-n600">
                      <span class={visibility_badge(note.visibility)}>
                        {humanize(note.visibility)}
                      </span>
                      <span :if={markdown_title?(note.title)} class="text-n600">
                        Markdown
                      </span>
                      <span class="text-n600">·</span>
                      <span class="[overflow-wrap:anywhere]">{note_scope_label(note)}</span>
                    </div>
                  </div>
                  <span class="flex-shrink-0 text-xs text-n600">
                    {display_name(note.created_by)}
                  </span>
                </div>
              </button>
              <p :if={@filtered_notes == []} class="px-4 py-4 text-center text-sm text-n600">
                No notes match your search.
              </p>
            </div>
          </div>
        </aside>

        <section class="flex min-w-0 flex-col overflow-hidden rounded-lg border border-white/10 bg-ink p-6 xl:sticky xl:top-6 xl:h-[calc(100vh-6rem)]">
          <%= if @selected_note do %>
            <div class="flex min-h-0 flex-1 flex-col">
              <div class="flex flex-shrink-0 flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                <div class="min-w-0">
                  <div class="flex flex-wrap items-center gap-3">
                    <h3 class="min-w-0 text-2xl font-semibold tracking-tight text-n100 [overflow-wrap:anywhere]">
                      {@selected_note.title}
                    </h3>
                    <span class={visibility_badge(@selected_note.visibility)}>
                      {humanize(@selected_note.visibility)}
                    </span>
                    <span :if={markdown_title?(@selected_note.title)} class="text-xs text-n600">
                      Markdown
                    </span>
                  </div>
                  <p class="mt-2 text-sm text-n600">
                    Created by {display_name(@selected_note.created_by)}
                  </p>
                </div>

                <div :if={@selected_note.created_by_id == @current_user.id} class="flex gap-2">
                  <button
                    type="button"
                    phx-click="edit_note"
                    phx-value-id={@selected_note.id}
                    class="rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 hover:bg-white/10"
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    phx-click="delete_note"
                    phx-value-id={@selected_note.id}
                    class="rounded-md px-3 py-1.5 text-sm font-medium text-red-400 hover:bg-red-500/10"
                  >
                    Delete
                  </button>
                </div>
              </div>

              <div class="mt-6 flex-1 overflow-y-auto xl:pr-2">
                <article class="min-h-[8rem] overflow-hidden rounded-lg border border-white/10 bg-ink p-4">
                  <.markdown_viewer body={@selected_note.body} empty_copy="No body content yet." />
                </article>

                <.note_attachment_list
                  :if={@selected_note.attachments != []}
                  attachments={@selected_note.attachments}
                  note_id={@selected_note.id}
                />

                <div class="mt-6 grid gap-4 lg:grid-cols-3">
                  <div class="rounded-lg border border-white/10 bg-white/10 p-4">
                    <p class="text-sm font-medium text-n600">
                      Linked project
                    </p>
                    <p class="mt-1 text-sm font-medium text-n100">
                      {(@selected_note.project && @selected_note.project.name) || "No linked project"}
                    </p>
                  </div>
                  <div class="rounded-lg border border-white/10 bg-white/10 p-4">
                    <p class="text-sm font-medium text-n600">
                      Linked task
                    </p>
                    <p class="mt-1 text-sm font-medium text-n100">
                      {(@selected_note.task && @selected_note.task.title) || "No linked task"}
                    </p>
                  </div>
                  <div class="rounded-lg border border-white/10 bg-white/10 p-4">
                    <p class="text-sm font-medium text-n600">
                      Format
                    </p>
                    <p class="mt-1 text-sm font-medium text-n100">
                      {note_format_label(@selected_note)}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          <% else %>
            <div class="flex flex-1 items-center justify-center rounded-lg border border-dashed border-white/10 p-6 text-center text-sm leading-6 text-n600">
              Select a note from the left to inspect details, or start a fresh note from the editor.
            </div>
          <% end %>
        </section>
      </div>

      <.modal
        :if={@active_modal == :note}
        id="notes-editor-modal"
        show
        on_cancel={JS.push("close_modal", value: %{modal: "note"})}
      >
        <div>
          <h3 class="text-base font-semibold text-n100">
            {note_form_title(@note_mode)}
          </h3>
          <p class="mt-1 text-sm text-n600">
            Attach notes to a project or task when the idea should stay close to the work itself.
          </p>
        </div>

        <.simple_form for={@note_form} phx-change="validate_note" phx-submit="save_note">
          <.input field={@note_form[:title]} label="Title" />
          <.input
            field={@note_form[:visibility]}
            type="select"
            label="Visibility"
            options={visibility_options()}
          />
          <.input
            field={@note_form[:project_id]}
            type="select"
            label="Project"
            prompt="Optional project link"
            options={@project_options}
          />
          <.input
            field={@note_form[:task_id]}
            type="select"
            label="Task"
            prompt="Optional task link"
            options={@task_options}
          />
          <.input field={@note_form[:body]} type="textarea" label="Body" rows="10" />

          <div>
            <p class="text-sm font-medium leading-6 text-n100">Attachments</p>
            <p class="mt-1 text-xs text-n600">Attach PDF or Word documents (max 25 MB each).</p>

            <div :if={@note_attachments != []} class="mt-3 space-y-2">
              <div
                :for={attachment <- @note_attachments}
                class="flex items-center gap-2 rounded-md border border-white/10 bg-white/10 px-3 py-2"
              >
                <.icon name="hero-document" class="h-5 w-5 shrink-0 text-n600" />
                <span class="min-w-0 flex-1 truncate text-sm text-n600">
                  {attachment["filename"]}
                </span>
                <button
                  type="button"
                  phx-click="remove_note_attachment"
                  phx-value-url={attachment["url"]}
                  class="shrink-0 rounded-md p-1 text-n600 hover:bg-white/10 hover:text-red-400"
                  title="Remove attachment"
                >
                  <.icon name="hero-x-mark" class="h-4 w-4" />
                </button>
              </div>
            </div>

            <div :if={@uploads.note_files.entries != []} class="mt-3 space-y-2">
              <div
                :for={entry <- @uploads.note_files.entries}
                class="flex items-center gap-2 rounded-md border border-white/10 bg-white/10 px-3 py-2"
              >
                <.icon name="hero-paper-clip" class="h-5 w-5 shrink-0 text-n600" />
                <span class="min-w-0 flex-1 truncate text-sm text-n600">
                  {entry.client_name}
                </span>
                <button
                  type="button"
                  phx-click="cancel_note_upload"
                  phx-value-ref={entry.ref}
                  class="shrink-0 rounded-md p-1 text-n600 hover:bg-white/10 hover:text-red-400"
                  title="Cancel upload"
                >
                  <.icon name="hero-x-mark" class="h-4 w-4" />
                </button>
                <p :for={err <- upload_errors(@uploads.note_files, entry)} class="text-xs text-red-400">
                  {upload_error_msg(err)}
                </p>
              </div>
            </div>

            <label class="mt-3 flex w-fit cursor-pointer items-center gap-1.5 rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 hover:bg-white/10">
              <.icon name="hero-paper-clip" class="h-4 w-4" />
              <span>Attach file</span>
              <.live_file_input upload={@uploads.note_files} class="sr-only" />
            </label>
            <p :for={err <- upload_errors(@uploads.note_files)} class="mt-1 text-xs text-red-400">
              {upload_error_msg(err)}
            </p>
          </div>

          <:actions>
            <button
              type="button"
              phx-click="close_modal"
              phx-value-modal="note"
              class="rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 hover:bg-white/10"
            >
              Cancel
            </button>
            <.button>{note_submit_label(@note_mode)}</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  attr :attachments, :list, required: true
  attr :note_id, :integer, required: true

  defp note_attachment_list(assigns) do
    assigns =
      assign(assigns, :attachments, Enum.with_index(assigns.attachments))

    ~H"""
    <div class="mt-6 space-y-2">
      <p class="text-sm font-medium text-n600">Attachments</p>
      <div :for={{attachment, idx} <- @attachments} class="rounded-lg border border-white/10">
        <div class="flex items-center gap-2 px-3 py-2">
          <.icon name="hero-document" class="h-5 w-5 shrink-0 text-n600" />
          <a
            href={attachment["url"]}
            target="_blank"
            rel="noopener noreferrer"
            download={attachment["filename"]}
            class="min-w-0 flex-1 truncate text-sm font-medium text-accent underline underline-offset-2 hover:text-accentDeep"
          >
            {attachment["filename"] || "Download file"}
          </a>
          <button
            type="button"
            phx-click={JS.toggle(to: "#note-attachment-preview-#{@note_id}-#{idx}")}
            class="shrink-0 rounded-md p-1 text-n600 hover:bg-white/10 hover:text-n600"
            title="Preview"
          >
            <.icon name="hero-eye" class="h-4 w-4" />
          </button>
        </div>
        <div id={"note-attachment-preview-#{@note_id}-#{idx}"} class="hidden border-t border-white/10">
          <iframe
            src={attachment_preview_src(attachment)}
            class="h-[32rem] w-full rounded-b-lg bg-ink"
            title={attachment["filename"] || "Attachment preview"}
          >
          </iframe>
        </div>
      </div>
    </div>
    """
  end

  defp attachment_preview_src(attachment) do
    filename = attachment["filename"] || attachment["url"] || ""

    if String.ends_with?(String.downcase(filename), ".pdf") do
      attachment["url"]
    else
      absolute_url = BetaSigmaWeb.Endpoint.url() <> attachment["url"]
      "https://docs.google.com/viewer?embedded=true&url=#{URI.encode_www_form(absolute_url)}"
    end
  end

  defp upload_error_msg(:too_large), do: "File too large (max 25 MB)"
  defp upload_error_msg(:not_accepted), do: "Only PDF and Word documents are allowed"
  defp upload_error_msg(:too_many_files), do: "Too many files (max 5)"
  defp upload_error_msg(_), do: "Upload error"

  defp assign_catalog(socket) do
    projects = Projects.list_projects()

    task_map =
      projects
      |> Enum.map(fn project -> {project.id, Projects.list_tasks(project.id)} end)
      |> Map.new()

    assign(socket,
      project_options: Enum.map(projects, &{&1.name, &1.id}),
      task_map: task_map
    )
  end

  defp load_notes(socket, opts \\ []) do
    current_user = socket.assigns.current_user

    filters =
      case socket.assigns.visibility_filter do
        f when f in ["all", "", nil] -> []
        "shared" -> [visibility: :shared]
        "personal" -> [visibility: :personal]
        _ -> []
      end

    notes = Notes.list_notes(current_user, filters)

    selected_note_id =
      pick_selected_note(notes, opts[:selected_note_id] || socket.assigns[:selected_note_id])

    assign(socket,
      notes: notes,
      selected_note_id: selected_note_id
    )
  end

  defp note_editor_struct(socket) do
    case socket.assigns.note_mode do
      :new -> %Note{}
      {:edit, id} -> Notes.get_note!(id, socket.assigns.current_user)
    end
  end

  defp persist_note(socket, params) do
    attrs = note_params(socket, params)

    case socket.assigns.note_mode do
      :new ->
        Notes.create_note(Map.put(attrs, "created_by_id", socket.assigns.current_user.id))

      {:edit, id} ->
        id |> Notes.get_note!(socket.assigns.current_user) |> Notes.update_note(attrs)
    end
  end

  defp note_params(_socket, params) do
    params
    |> Map.update("project_id", nil, &blank_to_nil/1)
    |> Map.update("task_id", nil, &blank_to_nil/1)
  end

  defp assign_note_editor(socket, %Note{} = note, mode) do
    socket
    |> assign(:note_mode, mode)
    |> assign(:note_project_id, note.project_id)
    |> assign(:note_attachments, note.attachments || [])
    |> assign(:note_changeset, Notes.change_note(note))
  end

  defp reset_note_uploads(socket) do
    Enum.reduce(socket.assigns.uploads.note_files.entries, socket, fn entry, socket ->
      cancel_upload(socket, :note_files, entry.ref)
    end)
  end

  defp pick_selected_note(notes, nil) do
    case List.first(notes) do
      nil -> nil
      note -> note.id
    end
  end

  defp pick_selected_note(notes, selected_note_id) do
    if Enum.any?(notes, &(&1.id == selected_note_id)),
      do: selected_note_id,
      else: pick_selected_note(notes, nil)
  end

  defp note_by_id(notes, id) when is_binary(id), do: note_by_id(notes, String.to_integer(id))
  defp note_by_id(notes, id), do: Enum.find(notes, &(&1.id == id))

  defp task_options(_task_map, nil), do: []

  defp task_options(task_map, project_id) do
    project_id = if is_binary(project_id), do: String.to_integer(project_id), else: project_id

    task_map
    |> Map.get(project_id, [])
    |> Enum.map(&{&1.title, &1.id})
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp visibility_filters do
    [
      %{value: "all", label: "All"},
      %{value: "shared", label: "Shared"},
      %{value: "personal", label: "Personal"}
    ]
  end

  defp visibility_options do
    [{"Personal", :personal}, {"Shared", :shared}]
  end

  defp filter_button_class(active, value) do
    base = "rounded-md px-3 py-1.5 text-sm font-medium transition"

    if active == value do
      base <> " bg-white/10 text-n100"
    else
      base <> " border border-white/10 bg-ink text-n600 hover:bg-white/10"
    end
  end

  defp note_list_item_class(true),
    do: "block w-full px-3 py-2 text-left bg-white/10"

  defp note_list_item_class(false),
    do: "block w-full px-3 py-2 text-left hover:bg-white/10"

  defp note_scope_label(note) do
    cond do
      note.project && note.task -> "#{note.project.name} • #{note.task.title}"
      note.project -> note.project.name
      note.task -> note.task.title
      true -> "Standalone note"
    end
  end

  defp note_format_label(note) do
    if markdown_title?(note.title) do
      "Markdown document"
    else
      "Markdown-friendly note"
    end
  end

  defp note_matches_query?(note, query) do
    haystacks =
      [
        note.title,
        note.body,
        note.project && note.project.name,
        note.task && note.task.title,
        display_name(note.created_by)
      ]
      |> Enum.map(&String.downcase(to_string(&1 || "")))

    Enum.any?(haystacks, &String.contains?(&1, query))
  end

  defp visibility_badge(:shared),
    do:
      "inline-flex items-center gap-1 text-xs font-medium text-emerald-600 before:h-1.5 before:w-1.5 before:rounded-full before:bg-emerald-600 before:content-['']"

  defp visibility_badge(:personal),
    do:
      "inline-flex items-center gap-1 text-xs font-medium text-n600 before:h-1.5 before:w-1.5 before:rounded-full before:bg-white/10 before:content-['']"

  defp note_form_title(:new), do: "New note"
  defp note_form_title(_mode), do: "Edit note"
  defp note_submit_label(:new), do: "Create note"
  defp note_submit_label(_mode), do: "Save note"

  defp humanize(value) when is_atom(value), do: value |> Atom.to_string() |> humanize()

  defp humanize(value) when is_binary(value) do
    value
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
