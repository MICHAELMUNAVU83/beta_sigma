defmodule BetaSigmaWeb.DiscoveryLive.Admin do
  @moduledoc """
  Internal read-back of the public discovery workspace: every interview
  respondents have filled in, and the answers captured in each one.

  Respondents have no accounts, so a session is attributed by the details they
  type into the public form. Nothing here is editable — this is the review
  side of `BetaSigmaWeb.DiscoveryLive.Index`.
  """
  use BetaSigmaWeb, :live_view

  alias BetaSigma.Discovery
  alias BetaSigma.Discovery.Answer
  alias BetaSigma.Discovery.Session
  alias BetaSigmaWeb.Realtime

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> Realtime.bootstrap()
     |> assign(:page_title, "Discovery")
     |> assign(:departments, Discovery.list_departments())
     |> assign(:status_filter, "all")
     |> assign(:department_filter, "all")
     |> assign(:search_query, "")
     |> assign(:export, nil)
     |> load_sessions()}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    {:noreply, load_transcript(socket, id)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:session, nil)
     |> assign(:transcript, nil)}
  end

  ## Filters

  def handle_event("filter_status", %{"filter" => filter}, socket) do
    {:noreply, socket |> assign(:status_filter, filter) |> load_sessions()}
  end

  def handle_event("filter_department", %{"department_id" => department_id}, socket) do
    {:noreply, socket |> assign(:department_filter, department_id) |> load_sessions()}
  end

  def handle_event("search_sessions", %{"value" => query}, socket) do
    {:noreply, socket |> assign(:search_query, String.trim(query)) |> load_sessions()}
  end

  ## Export

  def handle_event("open_export", _params, socket) do
    {:noreply, assign(socket, :export, Discovery.to_markdown(socket.assigns.session))}
  end

  def handle_event("close_export", _params, socket) do
    {:noreply, assign(socket, :export, nil)}
  end

  ## Loading

  defp load_sessions(socket) do
    sessions =
      Discovery.list_all_sessions(
        status: socket.assigns.status_filter,
        department_id: socket.assigns.department_filter,
        query: socket.assigns.search_query
      )

    socket
    |> assign(:sessions, sessions)
    |> assign(:answered_counts, Discovery.answered_counts(sessions))
    |> assign(:question_counts, Discovery.question_counts_by_department())
  end

  defp load_transcript(socket, id) do
    session = Discovery.get_session!(id)

    socket
    |> assign(:session, session)
    |> assign(:transcript, Discovery.session_transcript(session))
    |> assign(:page_title, "Discovery — #{session.department.name}")
  end

  ## Render helpers

  defp answered(counts, session), do: Map.get(counts, session.id, 0)

  defp total_questions(counts, session), do: Map.get(counts, session.department_id, 0)

  defp progress_percentage(_answered, 0), do: 0
  defp progress_percentage(answered, total), do: round(answered / total * 100)

  defp status_label(:in_progress), do: "In progress"
  defp status_label(:complete), do: "Finished"
  defp status_label(:archived), do: "Archived"
  defp status_label(_), do: "Unknown"

  defp status_class(:complete), do: "bg-emerald-500/15 text-emerald-300"
  defp status_class(:archived), do: "bg-white/5 text-n600"
  defp status_class(_), do: "bg-accent/15 text-accent"

  defp answer_text(nil), do: nil

  defp answer_text(%Answer{} = answer) do
    cond do
      answer.values not in [nil, []] -> Enum.join(answer.values, ", ")
      is_binary(answer.value) and String.trim(answer.value) != "" -> answer.value
      true -> nil
    end
  end

  defp answer_context(nil), do: []

  defp answer_context(%Answer{} = answer) do
    [
      {"Notes", answer.note},
      {"Status", answer.confidence},
      {"Priority", answer.priority},
      {"Owner", answer.owner},
      {"Applies to", answer.applies_to},
      {"Follow-up", answer.follow_up_on && to_string(answer.follow_up_on)},
      {"Evidence", answer.evidence}
    ]
    |> Enum.reject(fn {_label, value} -> value in [nil, ""] end)
  end

  defp module_answered(module, answers) do
    Enum.count(module.questions, &Answer.answered?(Map.get(answers, &1.id)))
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6 py-8">
      <header class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p class="text-xs font-medium uppercase tracking-wide text-n600">Discovery</p>
          <h1 class="mt-1 text-2xl font-semibold tracking-tight text-n100">
            Interviews from the field
          </h1>
          <p class="mt-1 max-w-2xl text-sm text-n600">
            Everything respondents have filled in at
            <.link navigate={~p"/discovery"} class="text-accent hover:underline">/discovery</.link>.
            Read-only — answers are captured by the people we interview.
          </p>
        </div>
        <p class="text-sm text-n600">
          {length(@sessions)} {if length(@sessions) == 1, do: "session", else: "sessions"}
        </p>
      </header>

      <section class="flex flex-wrap items-center gap-3">
        <div class="flex border border-white/10 bg-n800 p-1">
          <button
            :for={
              {label, value} <- [
                {"All", "all"},
                {"In progress", "in_progress"},
                {"Finished", "complete"},
                {"Archived", "archived"}
              ]
            }
            type="button"
            phx-click="filter_status"
            phx-value-filter={value}
            class={[
              "px-3 py-1.5 text-sm font-medium transition",
              @status_filter == value && "bg-accent text-white",
              @status_filter != value && "text-n600 hover:text-n100"
            ]}
          >
            {label}
          </button>
        </div>

        <form phx-change="filter_department">
          <select
            name="department_id"
            class="border border-white/10 bg-black/20 px-3 py-2 text-sm text-n100"
          >
            <option value="all" selected={@department_filter == "all"}>All departments</option>
            <option
              :for={department <- @departments}
              value={department.id}
              selected={to_string(department.id) == to_string(@department_filter)}
            >
              {department.name}
            </option>
          </select>
        </form>

        <input
          type="search"
          phx-keyup="search_sessions"
          phx-debounce="300"
          value={@search_query}
          placeholder="Search person, role, or department"
          class="min-w-64 flex-1 border border-white/10 bg-black/20 px-3 py-2 text-sm text-n100"
        />
      </section>

      <div class="grid gap-6 xl:grid-cols-[24rem_minmax(0,1fr)]">
        <section class="space-y-2">
          <p
            :if={@sessions == []}
            class="border border-white/10 bg-n800 p-6 text-sm text-n600"
          >
            No discovery sessions match this filter yet.
          </p>

          <.link
            :for={session <- @sessions}
            patch={~p"/app/discovery/#{session.id}"}
            class={[
              "block border p-4 transition",
              @session && @session.id == session.id && "border-accent bg-accent/10",
              !(@session && @session.id == session.id) &&
                "border-white/10 bg-n800 hover:border-white/25"
            ]}
          >
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <p class="truncate text-sm font-semibold text-n100">
                  {Session.label(session)}
                </p>
                <p class="truncate text-xs text-n600">{session.department.name}</p>
              </div>
              <span class={["shrink-0 px-2 py-0.5 text-xs font-medium", status_class(session.status)]}>
                {status_label(session.status)}
              </span>
            </div>

            <div class="mt-3 h-1.5 overflow-hidden bg-white/5">
              <div
                class="h-full bg-accent"
                style={"width: #{progress_percentage(answered(@answered_counts, session), total_questions(@question_counts, session))}%"}
              >
              </div>
            </div>
            <p class="mt-2 flex flex-wrap gap-x-3 text-xs text-n600">
              <span>
                {answered(@answered_counts, session)}/{total_questions(@question_counts, session)} answered
              </span>
              <span>{session.held_on || "no date"}</span>
              <span :if={session.interviewer}>via {session.interviewer}</span>
            </p>
          </.link>
        </section>

        <section :if={@transcript} class="space-y-4">
          <div class="border border-white/10 bg-n800 p-4">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h2 class="text-lg font-semibold text-n100">
                  {@transcript.department.name}
                </h2>
                <dl class="mt-2 grid gap-x-6 gap-y-1 text-xs text-n600 sm:grid-cols-2">
                  <.detail label="Spoke to" value={@session.interviewee} />
                  <.detail label="Role" value={@session.interviewee_role} />
                  <.detail label="BetaSigma contact" value={@session.interviewer} />
                  <.detail label="Date" value={@session.held_on} />
                  <.detail label="Status" value={status_label(@session.status)} />
                  <.detail label="Started" value={@session.inserted_at} />
                </dl>
              </div>
              <div class="flex gap-2">
                <button
                  type="button"
                  phx-click="open_export"
                  class="bg-accent px-3 py-1.5 text-sm font-medium text-white hover:bg-accentDeep"
                >
                  View markdown
                </button>
                <a
                  href={~p"/discovery/sessions/#{@session.id}/export"}
                  class="border border-white/10 px-3 py-1.5 text-sm text-n600 hover:text-n100"
                >
                  Download .md
                </a>
              </div>
            </div>
          </div>

          <div
            :for={module <- @transcript.department.modules}
            class="border border-white/10 bg-n800"
          >
            <header class="flex flex-wrap items-baseline justify-between gap-2 border-b border-white/10 p-4">
              <h3 class="text-sm font-semibold text-n100">{module.name}</h3>
              <p class="text-xs text-n600">
                {module_answered(module, @transcript.answers)}/{length(module.questions)} answered
              </p>
            </header>

            <div class="divide-y divide-white/5">
              <.answer_row
                :for={question <- module.questions}
                question={question}
                answer={Map.get(@transcript.answers, question.id)}
              />

              <p :if={module.questions == []} class="p-4 text-sm text-n600">
                This section has no questions yet.
              </p>
            </div>
          </div>
        </section>

        <section
          :if={!@transcript}
          class="flex items-center justify-center border border-white/10 bg-n800 p-10 text-sm text-n600"
        >
          Pick a session to read every answer it captured.
        </section>
      </div>

      <.modal :if={@export} id="discovery-admin-export" show on_cancel={JS.push("close_export")}>
        <h3 class="text-lg font-semibold text-n100">Markdown handover</h3>
        <textarea
          id="discovery-admin-export-text"
          rows="18"
          readonly
          class="mt-4 w-full border border-white/10 bg-black/30 p-3 font-mono text-xs text-n100"
        >{@export}</textarea>
        <div class="mt-4 flex justify-end">
          <button
            type="button"
            phx-hook="CopyToClipboard"
            id="discovery-admin-export-copy"
            data-copy-target="#discovery-admin-export-text"
            class="bg-accent px-3 py-1.5 text-sm font-medium text-white hover:bg-accentDeep"
          >
            <span data-copy-label>Copy</span>
          </button>
        </div>
      </.modal>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, default: nil

  defp detail(assigns) do
    ~H"""
    <div>
      <dt class="inline">{@label}:</dt>
      <dd class="inline text-n100">{if @value in [nil, ""], do: "—", else: @value}</dd>
    </div>
    """
  end

  attr :question, :map, required: true
  attr :answer, :any, default: nil

  defp answer_row(assigns) do
    assigns =
      assigns
      |> assign(:text, answer_text(assigns.answer))
      |> assign(:context, answer_context(assigns.answer))

    ~H"""
    <article class="p-4">
      <p class="text-sm font-medium text-n100">{@question.label}</p>
      <p class={[
        "mt-1 text-sm [overflow-wrap:anywhere]",
        @text && "text-n100",
        !@text && "italic text-n600"
      ]}>
        {@text || "No answer"}
      </p>
      <dl
        :if={@context != []}
        class="mt-2 grid gap-1 border-l-2 border-accent/40 pl-3 text-xs text-n600 sm:grid-cols-2"
      >
        <div :for={{label, value} <- @context}>
          <dt class="inline">{label}:</dt>
          <dd class="inline text-n100 [overflow-wrap:anywhere]">{value}</dd>
        </div>
      </dl>
    </article>
    """
  end
end
