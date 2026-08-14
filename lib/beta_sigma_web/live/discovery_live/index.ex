defmodule BetaSigmaWeb.DiscoveryLive.Index do
  @moduledoc """
  The public discovery workspace: walk a department through its question bank
  one question at a time, capturing answers plus the build context around them.

  This route is open — the people we interview have no accounts. There is no
  `current_user`; respondents identify themselves in the session header, which
  is what attributes the answers.

  Every change is persisted against the active `Discovery.Session`, so the
  interview survives a refresh and two people can pick it up on either side.
  """
  use BetaSigmaWeb, :live_view

  alias BetaSigma.Discovery
  alias BetaSigma.Discovery.Answer
  alias BetaSigma.Discovery.Question
  alias BetaSigma.Discovery.Session

  @finance_steps [
    {"Request", "Staff asks to spend"},
    {"Approve", "The right person agrees"},
    {"Pay", "Finance sends money"},
    {"Receipt", "Proof is returned"},
    {"Check", "Finance closes the item"},
    {"Account", "It reaches the books"}
  ]

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Discovery")
     |> assign(
       :meta_description,
       "Help BetaSigma understand how your department works today, one question at a time."
     )
     |> assign(:active_nav, :discovery)
     |> assign(:scope, :group)
     |> assign(:export, nil)
     |> assign(:saved_at, nil)
     |> load_scope()}
  end

  ## Navigation

  def handle_event("choose_scope", %{"scope" => scope}, socket) do
    {:noreply,
     socket
     |> assign(:scope, scope_atom(scope))
     |> load_scope()}
  end

  def handle_event("choose_department", %{"slug" => slug}, socket) do
    {:noreply, load_department(socket, slug)}
  end

  def handle_event("choose_module", %{"id" => id}, socket) do
    module_id = String.to_integer(id)

    {:noreply,
     socket
     |> assign(:module_id, module_id)
     |> assign(:question_index, 0)}
  end

  def handle_event("move", %{"step" => step}, socket) do
    {:noreply, move(socket, String.to_integer(step))}
  end

  def handle_event("jump_to_question", %{"index" => index}, socket) do
    {:noreply, assign(socket, :question_index, String.to_integer(index))}
  end

  ## Sessions

  def handle_event("choose_session", %{"id" => id}, socket) do
    session = Discovery.get_session!(String.to_integer(id))

    {:noreply,
     socket
     |> assign(:session, session)
     |> assign(:sessions, Discovery.list_sessions(socket.assigns.department))
     |> load_answers()}
  end

  def handle_event("new_session", _params, socket) do
    {:ok, session} =
      Discovery.create_session(%{
        department_id: socket.assigns.department.id,
        held_on: Date.utc_today()
      })

    {:noreply,
     socket
     |> assign(:session, session)
     |> assign(:sessions, Discovery.list_sessions(socket.assigns.department))
     |> assign(:question_index, 0)
     |> load_answers()
     |> flash_saved()}
  end

  def handle_event("update_session", params, socket) do
    attrs =
      params
      |> Map.take(["interviewee", "interviewee_role", "interviewer", "held_on", "status"])
      |> Map.new(fn {key, value} -> {key, blank_to_nil(value)} end)
      |> Map.reject(fn {key, value} -> key == "status" and is_nil(value) end)

    case Discovery.update_session(socket.assigns.session, attrs) do
      {:ok, session} ->
        {:noreply,
         socket
         |> assign(:session, session)
         |> assign(:sessions, Discovery.list_sessions(socket.assigns.department))
         |> flash_saved()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save the session details.")}
    end
  end

  ## Answers

  def handle_event("answer", %{"question-id" => question_id} = params, socket) do
    question = question_by_id(socket, question_id)

    attrs =
      if Question.multi?(question) do
        %{values: checked_values(params), value: nil}
      else
        %{value: params["value"] || "", values: []}
      end

    {:noreply, save_answer(socket, question, attrs)}
  end

  def handle_event(
        "answer_meta",
        %{"question-id" => question_id, "field" => field, "value" => value},
        socket
      ) do
    question = question_by_id(socket, question_id)

    case meta_field_key(field) do
      nil -> {:noreply, socket}
      key -> {:noreply, save_answer(socket, question, %{key => blank_to_nil(value)})}
    end
  end

  ## Export

  def handle_event("open_export", _params, socket) do
    {:noreply, assign(socket, :export, Discovery.to_markdown(socket.assigns.session))}
  end

  def handle_event("close_export", _params, socket) do
    {:noreply, assign(socket, :export, nil)}
  end

  ## Loading

  defp load_scope(socket) do
    departments = Discovery.list_departments(socket.assigns.scope)

    case departments do
      [] ->
        socket
        |> assign(:departments, [])
        |> assign(:department, nil)
        |> assign(:sessions, [])
        |> assign(:session, nil)
        |> assign(:answers, %{})

      [first | _] ->
        socket
        |> assign(:departments, departments)
        |> load_department(first.slug)
    end
  end

  defp load_department(socket, slug) do
    department = Discovery.get_department_with_bank!(slug)

    session = Discovery.current_session(department, %{held_on: Date.utc_today()})

    first_module = List.first(department.modules)

    socket
    |> assign(:department, department)
    |> assign(:sessions, Discovery.list_sessions(department))
    |> assign(:session, session)
    |> assign(:module_id, first_module && first_module.id)
    |> assign(:question_index, 0)
    |> load_answers()
  end

  defp load_answers(socket) do
    assign(socket, :answers, Discovery.answers_by_question(socket.assigns.session))
  end

  defp save_answer(socket, question, attrs) do
    case Discovery.upsert_answer(socket.assigns.session, question, attrs) do
      {:ok, answer} ->
        socket
        |> assign(:answers, Map.put(socket.assigns.answers, question.id, answer))
        |> flash_saved()

      {:error, _changeset} ->
        put_flash(socket, :error, "Could not save that answer.")
    end
  end

  defp flash_saved(socket), do: assign(socket, :saved_at, Time.utc_now())

  ## Question movement

  defp move(socket, step) do
    questions = flat_questions(socket.assigns.department)

    current =
      Enum.find_index(questions, fn {module, _question, index} ->
        module.id == socket.assigns.module_id and index == socket.assigns.question_index
      end) || 0

    target = current + step

    # Enum.at/2 wraps on negative indexes, so guard the start of the list.
    next = if target >= 0, do: Enum.at(questions, target)

    case next do
      nil ->
        socket

      {module, _question, index} ->
        socket
        |> assign(:module_id, module.id)
        |> assign(:question_index, index)
    end
  end

  defp flat_questions(nil), do: []

  defp flat_questions(department) do
    Enum.flat_map(department.modules, fn module ->
      module.questions
      |> Enum.with_index()
      |> Enum.map(fn {question, index} -> {module, question, index} end)
    end)
  end

  defp current_module(%{department: nil}), do: nil

  defp current_module(assigns) do
    Enum.find(assigns.department.modules, &(&1.id == assigns.module_id))
  end

  defp question_by_id(socket, question_id) do
    question_id = String.to_integer(question_id)

    socket.assigns.department.modules
    |> Enum.flat_map(& &1.questions)
    |> Enum.find(&(&1.id == question_id))
  end

  defp checked_values(params) do
    params
    |> Map.get("values", %{})
    |> case do
      values when is_map(values) ->
        values |> Enum.filter(fn {_option, on} -> on == "true" end) |> Enum.map(&elem(&1, 0))

      values when is_list(values) ->
        values

      _ ->
        []
    end
  end

  defp meta_field_key("note"), do: :note
  defp meta_field_key("confidence"), do: :confidence
  defp meta_field_key("priority"), do: :priority
  defp meta_field_key("owner"), do: :owner
  defp meta_field_key("applies_to"), do: :applies_to
  defp meta_field_key("follow_up_on"), do: :follow_up_on
  defp meta_field_key("evidence"), do: :evidence
  defp meta_field_key(_), do: nil

  defp scope_atom("company"), do: :company
  defp scope_atom(_), do: :group

  # A cleared date or select must reach the changeset as nil, not "".
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  ## Render helpers

  defp answer_for(answers, question), do: Map.get(answers, question.id) || %Answer{}

  defp answered?(answers, question), do: Answer.answered?(Map.get(answers, question.id))

  defp module_progress(module, answers), do: Discovery.module_progress(module, answers)

  defp has_context?(%Answer{} = answer) do
    Enum.any?(
      [
        answer.note,
        answer.confidence,
        answer.priority,
        answer.owner,
        answer.applies_to,
        answer.follow_up_on,
        answer.evidence
      ],
      &(&1 not in [nil, ""])
    )
  end

  def render(assigns) do
    module = current_module(assigns)
    questions = flat_questions(assigns.department)

    question = module && Enum.at(module.questions, assigns.question_index)

    global_index =
      question &&
        Enum.find_index(questions, fn {m, q, _index} ->
          m.id == module.id and q.id == question.id
        end)

    assigns =
      assigns
      |> assign(:module, module)
      |> assign(:question, question)
      |> assign(:total_questions, length(questions))
      |> assign(:global_index, global_index || 0)
      |> assign(:finance_steps, @finance_steps)

    ~H"""
    <div class="mx-auto w-full max-w-[1600px] space-y-6 px-5 py-12">
      <section class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p class="text-xs font-medium uppercase tracking-wide text-n600">
            {if @scope == :group, do: "Group functions", else: "Operating companies"}
          </p>
          <h2 class="mt-1 text-2xl font-semibold tracking-tight text-n100">
            {if @department, do: @department.name, else: "Discovery"}
          </h2>
          <p :if={@department && @department.summary} class="mt-1 max-w-2xl text-sm text-n600">
            {@department.summary}
          </p>
          <p class="mt-2 text-xs text-n600">
            Answers save as you type — you can close this page and come back.
          </p>
        </div>

        <div class="flex flex-wrap items-center gap-2">
          <div class="flex rounded-md border border-white/10 bg-n800 p-1">
            <button
              :for={{label, value} <- [{"Group", :group}, {"Companies", :company}]}
              type="button"
              phx-click="choose_scope"
              phx-value-scope={value}
              class={[
                "rounded px-3 py-1.5 text-sm font-medium transition",
                @scope == value && "bg-accent text-white",
                @scope != value && "text-n600 hover:text-n100"
              ]}
            >
              {label}
            </button>
          </div>

          <button
            :if={@session}
            type="button"
            phx-click="open_export"
            class="rounded-md bg-accent px-3 py-1.5 text-sm font-medium text-white hover:bg-accentDeep"
          >
            Export answers
          </button>
        </div>
      </section>

      <div :if={@department} class="grid gap-6 xl:grid-cols-[20rem_minmax(0,1fr)]">
        <aside class="space-y-4">
          <div class="rounded-lg border border-white/10 bg-n800 p-4">
            <label class="block text-xs font-medium uppercase tracking-wide text-n600">
              Department
            </label>
            <form phx-change="choose_department" class="mt-2">
              <select
                name="slug"
                class="w-full rounded-md border border-white/10 bg-black/20 px-3 py-2 text-sm text-n100"
              >
                <option
                  :for={department <- @departments}
                  value={department.slug}
                  selected={department.id == @department.id}
                >
                  {department.name}
                </option>
              </select>
            </form>
          </div>

          <.session_panel session={@session} sessions={@sessions} />

          <nav class="rounded-lg border border-white/10 bg-n800 p-2">
            <button
              :for={{module, index} <- Enum.with_index(@department.modules)}
              type="button"
              phx-click="choose_module"
              phx-value-id={module.id}
              class={[
                "flex w-full items-center justify-between gap-3 rounded px-3 py-2 text-left text-sm transition",
                @module && module.id == @module.id && "bg-accent/15 text-n100",
                !(@module && module.id == @module.id) && "text-n600 hover:bg-white/5 hover:text-n100"
              ]}
            >
              <span class="truncate">{index + 1}. {module.name}</span>
              <span class="shrink-0 text-xs tabular-nums text-n600">
                {progress_label(module_progress(module, @answers))}
              </span>
            </button>
          </nav>
        </aside>

        <section class="space-y-6">
          <div
            :if={@scope == :group && @department.slug == "finance"}
            class="rounded-lg border border-white/10 bg-n800 p-4"
          >
            <div class="flex flex-wrap items-baseline justify-between gap-2">
              <h3 class="text-sm font-semibold text-n100">How the money moves</h3>
              <span class="text-xs text-n600">The questions below define each hand-off.</span>
            </div>
            <ol class="mt-3 flex flex-wrap items-center gap-2">
              <li
                :for={{{name, description}, index} <- Enum.with_index(@finance_steps)}
                class="flex items-center gap-2"
              >
                <div class="rounded border border-white/10 bg-black/20 px-3 py-2">
                  <p class="text-xs font-semibold text-n100">{name}</p>
                  <p class="text-xs text-n600">{description}</p>
                </div>
                <span :if={index < length(@finance_steps) - 1} aria-hidden="true" class="text-n600">
                  →
                </span>
              </li>
            </ol>
          </div>

          <div :if={@module} class="rounded-lg border border-white/10 bg-n800">
            <header class="border-b border-white/10 p-4">
              <div class="flex flex-wrap items-baseline justify-between gap-2">
                <div>
                  <h3 class="text-lg font-semibold text-n100">{@module.name}</h3>
                  <p :if={@module.intro} class="mt-1 text-sm text-n600">{@module.intro}</p>
                </div>
                <p class="text-xs text-n600">
                  {progress_label(module_progress(@module, @answers))} answered in this section ·
                  question {@global_index + 1} of {@total_questions}
                </p>
              </div>
              <div class="mt-3 h-1.5 overflow-hidden rounded bg-white/5">
                <div
                  class="h-full rounded bg-accent transition-all"
                  style={"width: #{progress_percentage(module_progress(@module, @answers))}%"}
                >
                </div>
              </div>
            </header>

            <div :if={@question} class="p-4">
              <.question_card
                question={@question}
                answer={answer_for(@answers, @question)}
                index={@question_index}
                scope={@scope}
              />

              <div class="mt-6 flex flex-wrap items-center justify-between gap-3">
                <button
                  type="button"
                  phx-click="move"
                  phx-value-step="-1"
                  disabled={@global_index == 0}
                  class="rounded-md border border-white/10 px-3 py-1.5 text-sm text-n600 hover:text-n100 disabled:opacity-40"
                >
                  Back
                </button>
                <p class="text-xs text-n600">
                  <span :if={@saved_at}>Saved</span>
                </p>
                <div class="flex gap-2">
                  <button
                    type="button"
                    phx-click="move"
                    phx-value-step="1"
                    class="rounded-md border border-white/10 px-3 py-1.5 text-sm text-n600 hover:text-n100"
                  >
                    Skip
                  </button>
                  <button
                    type="button"
                    phx-click="move"
                    phx-value-step="1"
                    class="rounded-md bg-accent px-3 py-1.5 text-sm font-medium text-white hover:bg-accentDeep"
                  >
                    Next question
                  </button>
                </div>
              </div>
            </div>

            <div :if={!@question} class="p-6 text-sm text-n600">
              This section has no questions yet.
            </div>
          </div>

          <div :if={@module} class="rounded-lg border border-white/10 bg-n800 p-4">
            <h4 class="text-xs font-medium uppercase tracking-wide text-n600">
              Every question in this section
            </h4>
            <div class="mt-3 flex flex-wrap gap-2">
              <button
                :for={{question, index} <- Enum.with_index(@module.questions)}
                type="button"
                phx-click="jump_to_question"
                phx-value-index={index}
                title={question.label}
                class={[
                  "h-8 w-8 rounded text-xs tabular-nums transition",
                  index == @question_index && "bg-accent text-white",
                  index != @question_index && answered?(@answers, question) &&
                    "bg-accent/20 text-n100",
                  index != @question_index && !answered?(@answers, question) &&
                    "bg-white/5 text-n600 hover:text-n100"
                ]}
              >
                {index + 1}
              </button>
            </div>
          </div>
        </section>
      </div>

      <%!-- Public page, so no seeding instructions here — see priv/repo/seeds/discovery.exs. --%>
      <p :if={@departments == []} class="rounded-lg border border-white/10 bg-n800 p-6 text-sm text-n600">
        These questions are not ready yet. Please check back, or contact whoever shared this link.
      </p>

      <.modal :if={@export} id="discovery-export" show on_cancel={JS.push("close_export")}>
        <h3 class="text-lg font-semibold text-n100">Export answers</h3>
        <p class="mt-1 text-sm text-n600">
          Markdown handover for {@department.name}. Copy it, or download the file.
        </p>
        <textarea
          id="discovery-export-text"
          rows="18"
          readonly
          class="mt-4 w-full rounded-md border border-white/10 bg-black/30 p-3 font-mono text-xs text-n100"
        >{@export}</textarea>
        <div class="mt-4 flex justify-end gap-2">
          <a
            href={~p"/app/discovery/sessions/#{@session.id}/export"}
            class="rounded-md border border-white/10 px-3 py-1.5 text-sm text-n600 hover:text-n100"
          >
            Download .md
          </a>
          <button
            type="button"
            phx-hook="CopyToClipboard"
            id="discovery-export-copy"
            data-copy-target="#discovery-export-text"
            class="rounded-md bg-accent px-3 py-1.5 text-sm font-medium text-white hover:bg-accentDeep"
          >
            <span data-copy-label>Copy</span>
          </button>
        </div>
      </.modal>
    </div>
    """
  end

  attr :session, Session, required: true
  attr :sessions, :list, required: true

  defp session_panel(assigns) do
    ~H"""
    <div class="space-y-3 rounded-lg border border-white/10 bg-n800 p-4">
      <div class="flex items-center justify-between gap-2">
        <h3 class="text-xs font-medium uppercase tracking-wide text-n600">About you</h3>
        <button
          type="button"
          phx-click="new_session"
          class="text-xs font-medium text-accent hover:underline"
        >
          Start fresh
        </button>
      </div>

      <form :if={length(@sessions) > 1} phx-change="choose_session">
        <select
          name="id"
          class="w-full rounded-md border border-white/10 bg-black/20 px-3 py-2 text-xs text-n100"
        >
          <option :for={session <- @sessions} value={session.id} selected={session.id == @session.id}>
            {Session.label(session)} — {session.held_on || "no date"}
          </option>
        </select>
      </form>

      <form phx-change="update_session" class="space-y-3">
        <label class="block text-xs text-n600">
          Your name
          <input
            type="text"
            name="interviewee"
            value={@session.interviewee}
            placeholder="Name"
            phx-debounce="500"
            class="mt-1 w-full rounded-md border border-white/10 bg-black/20 px-3 py-2 text-sm text-n100"
          />
        </label>
        <label class="block text-xs text-n600">
          Your role
          <input
            type="text"
            name="interviewee_role"
            value={@session.interviewee_role}
            placeholder="Role or title"
            phx-debounce="500"
            class="mt-1 w-full rounded-md border border-white/10 bg-black/20 px-3 py-2 text-sm text-n100"
          />
        </label>
        <label class="block text-xs text-n600">
          BetaSigma contact
          <input
            type="text"
            name="interviewer"
            placeholder="Who asked you to fill this in?"
            value={@session.interviewer}
            phx-debounce="500"
            class="mt-1 w-full rounded-md border border-white/10 bg-black/20 px-3 py-2 text-sm text-n100"
          />
        </label>
        <div class="grid grid-cols-2 gap-2">
          <label class="block text-xs text-n600">
            Date
            <input
              type="date"
              name="held_on"
              value={@session.held_on}
              class="mt-1 w-full rounded-md border border-white/10 bg-black/20 px-3 py-2 text-sm text-n100"
            />
          </label>
          <label class="block text-xs text-n600">
            Status
            <select
              name="status"
              class="mt-1 w-full rounded-md border border-white/10 bg-black/20 px-3 py-2 text-sm text-n100"
            >
              <%!-- Archiving is a staff action, so it is not offered here. --%>
              <option value="in_progress" selected={@session.status == :in_progress}>
                Still working on it
              </option>
              <option value="complete" selected={@session.status == :complete}>
                Finished
              </option>
            </select>
          </label>
        </div>
      </form>
    </div>
    """
  end

  attr :question, Question, required: true
  attr :answer, Answer, required: true
  attr :index, :integer, required: true
  attr :scope, :atom, required: true

  defp question_card(assigns) do
    ~H"""
    <article>
      <div class="flex gap-3">
        <span class="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-accent/20 text-xs font-semibold text-n100">
          {@index + 1}
        </span>
        <div>
          <h4 class="text-base font-medium text-n100">{@question.label}</h4>
          <p :if={@question.hint} class="mt-1 text-sm text-n600">{@question.hint}</p>
        </div>
      </div>

      <div class="mt-4 space-y-4 pl-10">
        <.answer_control question={@question} answer={@answer} />

        <details open={has_context?(@answer)} class="rounded-md border border-white/10 bg-black/10">
          <summary class="cursor-pointer px-3 py-2 text-xs font-medium text-n600">
            Add context
          </summary>
          <div class="grid gap-3 border-t border-white/10 p-3 sm:grid-cols-2 xl:grid-cols-3">
            <.meta_field
              label="Notes or examples"
              field="note"
              question_id={@question.id}
              type="textarea"
              value={@answer.note}
              placeholder="Rules, exceptions, examples, amounts, or names"
              class="sm:col-span-2"
            />
            <.meta_field
              label="Answer status"
              field="confidence"
              question_id={@question.id}
              type="select"
              value={@answer.confidence}
              options={Answer.confidences()}
            />
            <.meta_field
              label="Build priority"
              field="priority"
              question_id={@question.id}
              type="select"
              value={@answer.priority}
              options={Answer.priorities()}
            />
            <.meta_field
              label="Owner"
              field="owner"
              question_id={@question.id}
              value={@answer.owner}
              placeholder="Person, role, or team"
            />
            <.meta_field
              :if={@scope == :group}
              label="Applies to"
              field="applies_to"
              question_id={@question.id}
              type="select"
              value={@answer.applies_to}
              options={Answer.applies_to_options()}
            />
            <.meta_field
              label="Follow-up date"
              field="follow_up_on"
              question_id={@question.id}
              type="date"
              value={@answer.follow_up_on}
            />
            <.meta_field
              label="Evidence or source"
              field="evidence"
              question_id={@question.id}
              value={@answer.evidence}
              placeholder="Policy, spreadsheet, report, system, or person to verify with"
              class="sm:col-span-2"
            />
          </div>
        </details>
      </div>
    </article>
    """
  end

  attr :question, Question, required: true
  attr :answer, Answer, required: true

  defp answer_control(%{question: %Question{type: :checks}} = assigns) do
    ~H"""
    <form phx-change="answer" class="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
      <input type="hidden" name="question-id" value={@question.id} />
      <label
        :for={option <- @question.options}
        class="flex items-center gap-2 rounded-md border border-white/10 bg-black/20 px-3 py-2 text-sm text-n100"
      >
        <input type="hidden" name={"values[#{option}]"} value="false" />
        <input
          type="checkbox"
          name={"values[#{option}]"}
          value="true"
          checked={option in (@answer.values || [])}
          class="rounded border-white/20 bg-black/40 text-accent"
        />
        {option}
      </label>
    </form>
    """
  end

  defp answer_control(%{question: %Question{type: :radio}} = assigns) do
    ~H"""
    <form phx-change="answer" class="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
      <input type="hidden" name="question-id" value={@question.id} />
      <label
        :for={option <- @question.options}
        class="flex items-center gap-2 rounded-md border border-white/10 bg-black/20 px-3 py-2 text-sm text-n100"
      >
        <input
          type="radio"
          name="value"
          value={option}
          checked={@answer.value == option}
          class="border-white/20 bg-black/40 text-accent"
        />
        {option}
      </label>
    </form>
    """
  end

  defp answer_control(%{question: %Question{type: :select}} = assigns) do
    ~H"""
    <form phx-change="answer">
      <input type="hidden" name="question-id" value={@question.id} />
      <select
        name="value"
        class="w-full rounded-md border border-white/10 bg-black/20 px-3 py-2 text-sm text-n100"
      >
        <option value="">Choose one…</option>
        <option :for={option <- @question.options} value={option} selected={@answer.value == option}>
          {option}
        </option>
      </select>
    </form>
    """
  end

  defp answer_control(assigns) do
    ~H"""
    <form phx-change="answer">
      <input type="hidden" name="question-id" value={@question.id} />
      <input
        type={if @question.type == :number, do: "number", else: "text"}
        name="value"
        value={@answer.value}
        placeholder={@question.placeholder}
        phx-debounce="500"
        class="w-full rounded-md border border-white/10 bg-black/20 px-3 py-2 text-sm text-n100"
      />
    </form>
    """
  end

  attr :label, :string, required: true
  attr :field, :string, required: true
  attr :question_id, :integer, required: true
  attr :type, :string, default: "text"
  attr :value, :any, default: nil
  attr :options, :list, default: []
  attr :placeholder, :string, default: nil
  attr :class, :string, default: nil

  # Each context field is its own form: `phx-change` is only supported on
  # forms, and one form per field keeps a save scoped to what changed.
  defp meta_field(assigns) do
    ~H"""
    <form phx-change="answer_meta" class={@class}>
      <input type="hidden" name="question-id" value={@question_id} />
      <input type="hidden" name="field" value={@field} />
      <label class="block text-xs text-n600">
        {@label}
        <select
          :if={@type == "select"}
          name="value"
          class="mt-1 w-full rounded-md border border-white/10 bg-black/20 px-3 py-2 text-sm text-n100"
        >
          <option value="">Choose…</option>
          <option :for={option <- @options} value={option} selected={@value == option}>
            {option}
          </option>
        </select>
        <textarea
          :if={@type == "textarea"}
          name="value"
          rows="3"
          phx-debounce="600"
          placeholder={@placeholder}
          class="mt-1 w-full rounded-md border border-white/10 bg-black/20 px-3 py-2 text-sm text-n100"
        >{@value}</textarea>
        <input
          :if={@type in ["text", "date"]}
          type={@type}
          name="value"
          value={@value}
          placeholder={@placeholder}
          phx-debounce={@type == "text" && "600"}
          class="mt-1 w-full rounded-md border border-white/10 bg-black/20 px-3 py-2 text-sm text-n100"
        />
      </label>
    </form>
    """
  end

  defp progress_label({answered, total}), do: "#{answered}/#{total}"

  defp progress_percentage({_answered, 0}), do: 0
  defp progress_percentage({answered, total}), do: round(answered / total * 100)
end
