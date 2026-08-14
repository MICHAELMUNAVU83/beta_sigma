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
