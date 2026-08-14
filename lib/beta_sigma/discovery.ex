defmodule BetaSigma.Discovery do
  @moduledoc """
  The Discovery context: the question bank used to interview each department,
  the interview sessions themselves, and the answers captured in them.

  The question bank (departments → modules → questions) is seeded from
  `priv/discovery/question_bank.json`, which is generated out of the
  prototype at `project-docs/html/prd-discovery-workspace.html` by
  `scripts/extract_discovery_bank.mjs`. Seeding is idempotent — re-running it
  upserts the bank without touching captured answers.
  """

  import Ecto.Query, warn: false

  alias BetaSigma.Discovery.Answer
  alias BetaSigma.Discovery.Department
  alias BetaSigma.Discovery.Module, as: DiscoveryModule
  alias BetaSigma.Discovery.Question
  alias BetaSigma.Discovery.Session
  alias BetaSigma.Repo

  ## Question bank

  @doc "Departments in a scope (`:group` or `:company`), in display order."
  def list_departments(scope) do
    Department
    |> where([department], department.scope == ^scope)
    |> order_by([department], asc: department.position, asc: department.id)
    |> Repo.all()
  end

  @doc "Every department, in scope then display order."
  def list_departments do
    Department
    |> order_by([department], asc: department.scope, asc: department.position)
    |> Repo.all()
  end

  @doc "A department with its modules and questions loaded in display order."
  def get_department_with_bank!(slug) when is_binary(slug) do
    Department
    |> Repo.get_by!(slug: slug)
    |> Repo.preload(modules: :questions)
  end

  def get_department!(id), do: Repo.get!(Department, id)

  @doc "Total number of questions in a department."
  def question_count(%Department{id: department_id}) do
    Question
    |> join(:inner, [question], module in DiscoveryModule, on: module.id == question.module_id)
    |> where([_question, module], module.department_id == ^department_id)
    |> Repo.aggregate(:count)
  end

  ## Sessions

  @doc "Sessions for a department, newest first."
  def list_sessions(%Department{id: department_id}) do
    Session
    |> where([session], session.department_id == ^department_id)
    |> where([session], session.status != :archived)
    |> order_by([session], desc: session.inserted_at)
    |> preload(:created_by)
    |> Repo.all()
  end

  def get_session!(id), do: Session |> preload([:department, :created_by]) |> Repo.get!(id)

  def create_session(attrs) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  def update_session(%Session{} = session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  def delete_session(%Session{} = session), do: Repo.delete(session)

  @doc """
  Returns the most recent open session for a department, creating one if the
  department has never been interviewed.
  """
  def current_session(%Department{} = department, attrs \\ %{}) do
    Session
    |> where([session], session.department_id == ^department.id and session.status == :in_progress)
    |> order_by([session], desc: session.inserted_at)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil ->
        {:ok, session} =
          create_session(Map.merge(attrs, %{department_id: department.id}))

        session

      session ->
        session
    end
  end

  ## Answers

  @doc "Answers for a session, keyed by question id."
  def answers_by_question(%Session{id: session_id}) do
    Answer
    |> where([answer], answer.session_id == ^session_id)
    |> Repo.all()
    |> Map.new(&{&1.question_id, &1})
  end

  @doc """
  Creates or updates the answer for `question` in `session`.

  Only the given fields are touched, so saving a note never clears the value
  (and vice versa).
  """
  def upsert_answer(%Session{} = session, %Question{} = question, attrs) do
    answer =
      Repo.get_by(Answer, session_id: session.id, question_id: question.id) ||
        %Answer{session_id: session.id, question_id: question.id}

    answer
    |> Answer.changeset(
      attrs
      |> Map.new(fn {key, value} -> {to_string(key), value} end)
      |> Map.merge(%{
        "session_id" => session.id,
        "question_id" => question.id
      })
    )
    |> Repo.insert_or_update()
  end

  @doc "Count of answered questions in a session."
  def answered_count(%Session{} = session) do
    session
    |> answers_by_question()
    |> Enum.count(fn {_id, answer} -> Answer.answered?(answer) end)
  end

  @doc """
  Progress for one module: `{answered, total}` given the answer map from
  `answers_by_question/1`.
  """
  def module_progress(%DiscoveryModule{questions: questions}, answers) when is_map(answers) do
    answered =
      Enum.count(questions, fn question ->
        Answer.answered?(Map.get(answers, question.id))
      end)

    {answered, length(questions)}
  end

  ## Build reports

  @doc """
  Answers across a session flagged for build planning — everything with a
  priority set, or still needing follow-up. Ordered so must-haves come first.
  """
  def build_backlog(%Session{id: session_id}) do
    Answer
    |> where([answer], answer.session_id == ^session_id)
    |> where(
      [answer],
      not is_nil(answer.priority) or answer.confidence == "Needs follow-up"
    )
    |> preload(question: :module)
    |> Repo.all()
    |> Enum.sort_by(&priority_rank(&1.priority))
  end

  defp priority_rank("Must have at launch"), do: 0
  defp priority_rank("Should have"), do: 1
  defp priority_rank("Later"), do: 2
  defp priority_rank("Not needed"), do: 3
  defp priority_rank(_), do: 4

  @doc """
  Renders a session as the Markdown handover the prototype exported.
  """
  def to_markdown(%Session{} = session) do
    department =
      Department
      |> Repo.get!(session.department_id)
      |> Repo.preload(modules: :questions)
    answers = answers_by_question(session)

    header =
      [
        "# BetaSigma discovery — #{department.name}",
        "",
        session.interviewee && "**Spoke to:** #{session.interviewee}",
        session.interviewee_role && "**Role:** #{session.interviewee_role}",
        session.interviewer && "**Interviewed by:** #{session.interviewer}",
        session.held_on && "**Date:** #{session.held_on}",
        ""
      ]
      |> Enum.reject(&(&1 in [nil, false]))

    body =
      Enum.flat_map(department.modules, fn module ->
        ["## #{module.name}", "" | Enum.flat_map(module.questions, &question_lines(&1, answers))]
      end)

    Enum.join(header ++ body, "\n")
  end

  defp question_lines(%Question{} = question, answers) do
    answer = Map.get(answers, question.id)

    value =
      cond do
        is_nil(answer) -> "_No answer_"
        answer.values != [] -> Enum.join(answer.values, ", ")
        is_binary(answer.value) and answer.value != "" -> answer.value
        true -> "_No answer_"
      end

    extras =
      answer
      |> case do
        nil ->
          []

        answer ->
          [
            {"Notes", answer.note},
            {"Status", answer.confidence},
            {"Priority", answer.priority},
            {"Owner", answer.owner},
            {"Applies to", answer.applies_to},
            {"Follow-up", answer.follow_up_on && to_string(answer.follow_up_on)},
            {"Evidence", answer.evidence}
          ]
      end
      |> Enum.reject(fn {_label, value} -> value in [nil, ""] end)
      |> Enum.map(fn {label, value} -> "  - #{label}: #{value}" end)

    ["- **#{question.label}**", "  - Answer: #{value}"] ++ extras ++ [""]
  end

  ## Seeding

  @doc """
  Upserts the question bank from `priv/discovery/question_bank.json`.
  Safe to re-run; captured answers are untouched.
  """
  def seed_question_bank!(path \\ default_bank_path()) do
    %{"scopes" => scopes} = path |> File.read!() |> Jason.decode!()

    Enum.each(scopes, fn %{"scope" => scope, "departments" => departments} ->
      Enum.each(departments, &seed_department!(scope, &1))
    end)

    :ok
  end

  defp default_bank_path do
    Application.app_dir(:beta_sigma, "priv/discovery/question_bank.json")
  end

  defp seed_department!(scope, attrs) do
    department =
      upsert!(Department, [slug: attrs["slug"]], %{
        scope: scope,
        slug: attrs["slug"],
        name: attrs["name"],
        summary: attrs["summary"],
        position: attrs["position"]
      })

    Enum.each(attrs["modules"], fn module_attrs ->
      module =
        upsert!(DiscoveryModule, [department_id: department.id, slug: module_attrs["slug"]], %{
          department_id: department.id,
          slug: module_attrs["slug"],
          name: module_attrs["name"],
          intro: module_attrs["intro"],
          position: module_attrs["position"]
        })

      Enum.each(module_attrs["questions"], fn question_attrs ->
        upsert!(Question, [module_id: module.id, slug: question_attrs["slug"]], %{
          module_id: module.id,
          slug: question_attrs["slug"],
          label: question_attrs["label"],
          hint: question_attrs["hint"],
          type: question_attrs["type"],
          options: question_attrs["options"],
          placeholder: question_attrs["placeholder"],
          position: question_attrs["position"]
        })
      end)
    end)
  end

  defp upsert!(schema, lookup, attrs) do
    record = Repo.get_by(schema, lookup) || struct(schema)

    record
    |> schema.changeset(attrs)
    |> Repo.insert_or_update!()
  end
end
