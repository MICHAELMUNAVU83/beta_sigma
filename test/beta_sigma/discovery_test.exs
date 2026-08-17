defmodule BetaSigma.DiscoveryTest do
  use BetaSigma.DataCase, async: true

  import BetaSigma.AccountsFixtures

  alias BetaSigma.Discovery
  alias BetaSigma.Discovery.Answer
  alias BetaSigma.Discovery.Session

  setup do
    :ok = Discovery.seed_question_bank!()
    %{user: user_fixture()}
  end

  describe "question bank" do
    test "seeds both scopes and is idempotent" do
      group = Discovery.list_departments(:group)
      company = Discovery.list_departments(:company)

      assert Enum.map(group, & &1.slug) == ["finance", "hr", "platform"]
      assert Enum.map(company, & &1.slug) == ["sla", "tukutane", "chasing-sun"]

      counts = Enum.map(Discovery.list_departments(), &Discovery.question_count/1)

      :ok = Discovery.seed_question_bank!()

      assert Enum.map(Discovery.list_departments(), &Discovery.question_count/1) == counts
    end

    test "every department opens and closes with the system-discovery modules" do
      finance = Discovery.get_department_with_bank!("finance")
      slugs = Enum.map(finance.modules, & &1.slug)

      assert List.first(slugs) == "current-system"
      assert List.last(slugs) == "new-system"
      assert Enum.all?(finance.modules, &(&1.questions != []))
    end
  end

  describe "sessions and answers" do
    test "a department can hold several sessions, each with its own answers", %{user: user} do
      department = Discovery.get_department_with_bank!("finance")
      question = department.modules |> hd() |> Map.fetch!(:questions) |> hd()

      first = Discovery.current_session(department, %{created_by_id: user.id})

      {:ok, _answer} =
        Discovery.upsert_answer(first, question, %{value: "QuickBooks Online"})

      {:ok, second} =
        Discovery.create_session(%{department_id: department.id, interviewee: "Second pass"})

      assert Discovery.answered_count(first) == 1
      assert Discovery.answered_count(second) == 0
      assert length(Discovery.list_sessions(department)) == 2
    end

    test "upserting keeps fields that were not sent", %{user: user} do
      department = Discovery.get_department_with_bank!("finance")
      question = department.modules |> hd() |> Map.fetch!(:questions) |> hd()
      session = Discovery.current_session(department, %{created_by_id: user.id})

      {:ok, _} = Discovery.upsert_answer(session, question, %{value: "Weekly"})
      {:ok, answer} = Discovery.upsert_answer(session, question, %{note: "Except December"})

      assert answer.value == "Weekly"
      assert answer.note == "Except December"

      assert %Answer{value: "Weekly", note: "Except December"} =
               session |> Discovery.answers_by_question() |> Map.fetch!(question.id)
    end

    test "multi-select answers land in values and count as answered", %{user: user} do
      department = Discovery.get_department_with_bank!("finance")

      question =
        department.modules
        |> Enum.flat_map(& &1.questions)
        |> Enum.find(&(&1.type == :checks))

      session = Discovery.current_session(department, %{created_by_id: user.id})

      {:ok, answer} = Discovery.upsert_answer(session, question, %{values: ["KES", "USD"]})

      assert answer.values == ["KES", "USD"]
      assert Answer.answered?(answer)
      assert Discovery.answered_count(session) == 1
    end

    test "blank context selects are stored as nil rather than rejected", %{user: user} do
      department = Discovery.get_department_with_bank!("finance")
      question = department.modules |> hd() |> Map.fetch!(:questions) |> hd()
      session = Discovery.current_session(department, %{created_by_id: user.id})

      assert {:ok, answer} =
               Discovery.upsert_answer(session, question, %{confidence: "", priority: ""})

      assert is_nil(answer.confidence)
      assert is_nil(answer.priority)

      assert {:error, changeset} =
               Discovery.upsert_answer(session, question, %{priority: "Someday"})

      assert "is invalid" in errors_on(changeset).priority
    end
  end

  describe "internal review list" do
    test "lists sessions across departments, newest first, including archived" do
      finance = Discovery.get_department_with_bank!("finance")
      hr = Discovery.get_department_with_bank!("hr")

      {:ok, _older} =
        Discovery.create_session(%{department_id: finance.id, interviewee: "Asha"})

      {:ok, archived} =
        Discovery.create_session(%{
          department_id: hr.id,
          interviewee: "Brian",
          status: :archived
        })

      sessions = Discovery.list_all_sessions()

      assert length(sessions) == 2
      assert archived.id in Enum.map(sessions, & &1.id)
      assert Enum.all?(sessions, &(&1.department.name != nil))
    end

    test "filters by status, department, and free text" do
      finance = Discovery.get_department_with_bank!("finance")
      hr = Discovery.get_department_with_bank!("hr")

      {:ok, asha} =
        Discovery.create_session(%{
          department_id: finance.id,
          interviewee: "Asha",
          status: :complete
        })

      {:ok, brian} =
        Discovery.create_session(%{department_id: hr.id, interviewee: "Brian"})

      assert Enum.map(Discovery.list_all_sessions(status: "complete"), & &1.id) == [asha.id]
      assert Enum.map(Discovery.list_all_sessions(status: :in_progress), & &1.id) == [brian.id]

      assert Enum.map(Discovery.list_all_sessions(department_id: hr.id), & &1.id) == [brian.id]

      assert Enum.map(Discovery.list_all_sessions(query: "ash"), & &1.id) == [asha.id]
      assert Enum.map(Discovery.list_all_sessions(query: "Group HR"), & &1.id) == [brian.id]

      assert Discovery.list_all_sessions(status: "all", department_id: "all", query: "") |> length() ==
               2
    end

    test "answered counts and question totals back the progress column", %{user: user} do
      department = Discovery.get_department_with_bank!("finance")
      [one, two | _] = Enum.flat_map(department.modules, & &1.questions)
      session = Discovery.current_session(department, %{created_by_id: user.id})

      {:ok, _} = Discovery.upsert_answer(session, one, %{value: "QuickBooks Online"})
      # Blank values and metadata alone must not count as answered.
      {:ok, _} = Discovery.upsert_answer(session, two, %{value: "  ", note: "Ask again"})

      assert Discovery.answered_counts([session]) == %{session.id => 1}

      assert Map.fetch!(Discovery.question_counts_by_department(), department.id) ==
               Discovery.question_count(department)
    end

    test "a transcript carries the bank and the answers keyed by question", %{user: user} do
      department = Discovery.get_department_with_bank!("finance")
      question = department.modules |> hd() |> Map.fetch!(:questions) |> hd()
      session = Discovery.current_session(department, %{created_by_id: user.id})

      {:ok, _} = Discovery.upsert_answer(session, question, %{value: "QuickBooks Online"})

      transcript = Discovery.session_transcript(session)

      assert transcript.department.id == department.id
      assert Enum.all?(transcript.department.modules, &is_list(&1.questions))
      assert %Answer{value: "QuickBooks Online"} = Map.fetch!(transcript.answers, question.id)
    end
  end

  describe "reporting" do
    test "the build backlog is ordered must-have first", %{user: user} do
      department = Discovery.get_department_with_bank!("finance")
      [one, two, three | _] = Enum.flat_map(department.modules, & &1.questions)
      session = Discovery.current_session(department, %{created_by_id: user.id})

      {:ok, _} = Discovery.upsert_answer(session, one, %{priority: "Later"})
      {:ok, _} = Discovery.upsert_answer(session, two, %{priority: "Must have at launch"})
      {:ok, _} = Discovery.upsert_answer(session, three, %{confidence: "Needs follow-up"})

      backlog = Discovery.build_backlog(session)

      assert Enum.map(backlog, & &1.question_id) == [two.id, one.id, three.id]
    end

    test "markdown export carries the session header and answers", %{user: user} do
      department = Discovery.get_department_with_bank!("finance")
      question = department.modules |> hd() |> Map.fetch!(:questions) |> hd()

      session =
        Discovery.current_session(department, %{created_by_id: user.id})

      {:ok, session} =
        Discovery.update_session(session, %{
          interviewee: "Asha",
          interviewee_role: "Finance lead",
          held_on: ~D[2026-08-11]
        })

      {:ok, _} =
        Discovery.upsert_answer(session, question, %{
          value: "QuickBooks Online",
          note: "Two files",
          priority: "Must have at launch"
        })

      markdown = Discovery.to_markdown(session)

      assert markdown =~ "# BetaSigma discovery — Group Finance"
      assert markdown =~ "**Spoke to:** Asha"
      assert markdown =~ "**Role:** Finance lead"
      assert markdown =~ "**Date:** 2026-08-11"
      assert markdown =~ "Answer: QuickBooks Online"
      assert markdown =~ "Notes: Two files"
      assert markdown =~ "Priority: Must have at launch"
    end

    test "session labels fall back when nobody is named" do
      assert Session.label(%Session{}) == "Untitled session"
      assert Session.label(%Session{interviewee: "Asha", interviewee_role: "Lead"}) ==
               "Asha · Lead"
    end
  end
end
