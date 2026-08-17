defmodule BetaSigmaWeb.DiscoveryLiveAdminTest do
  use BetaSigmaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import BetaSigma.AccountsFixtures

  alias BetaSigma.Discovery

  setup do
    :ok = Discovery.seed_question_bank!()
    :ok
  end

  defp answered_session(slug, attrs) do
    department = Discovery.get_department_with_bank!(slug)
    question = department.modules |> hd() |> Map.fetch!(:questions) |> hd()

    {:ok, session} =
      Discovery.create_session(Map.merge(attrs, %{department_id: department.id}))

    {:ok, _answer} =
      Discovery.upsert_answer(session, question, %{
        value: "QuickBooks Online",
        note: "Two company files",
        priority: "Must have at launch"
      })

    %{session: session, question: question, department: department}
  end

  test "an admin sees every session respondents have filled in", %{conn: conn} do
    %{department: department} = answered_session("finance", %{interviewee: "Asha", interviewer: "Mo"})

    {:ok, _view, html} =
      conn |> log_in_user(admin_fixture()) |> live(~p"/app/discovery")

    assert html =~ "Asha"
    assert html =~ "Group Finance"
    assert html =~ "via Mo"
    assert html =~ "1/#{Discovery.question_count(department)} answered"
  end

  test "opening a session shows its answers and the context around them", %{conn: conn} do
    %{session: session, question: question} = answered_session("finance", %{interviewee: "Asha"})

    {:ok, view, _html} =
      conn |> log_in_user(admin_fixture()) |> live(~p"/app/discovery")

    html =
      view
      |> element("a[href='/app/discovery/#{session.id}']")
      |> render_click()

    assert html =~ question.label
    assert html =~ "QuickBooks Online"
    assert html =~ "Two company files"
    assert html =~ "Must have at launch"
    assert html =~ "No answer"
  end

  test "filters narrow the list by department and person", %{conn: conn} do
    answered_session("finance", %{interviewee: "Asha"})
    answered_session("hr", %{interviewee: "Brian"})

    hr = Discovery.get_department_with_bank!("hr")

    {:ok, view, html} =
      conn |> log_in_user(admin_fixture()) |> live(~p"/app/discovery")

    assert html =~ "Asha"
    assert html =~ "Brian"

    filtered =
      view
      |> element("form[phx-change='filter_department']")
      |> render_change(%{"department_id" => to_string(hr.id)})

    assert filtered =~ "Brian"
    refute filtered =~ "Asha"
  end

  test "staff without the discovery permission are turned away", %{conn: conn} do
    staff = user_fixture()

    assert {:error, {:redirect, %{to: to}}} =
             conn |> log_in_user(staff) |> live(~p"/app/discovery")

    refute to == "/app/discovery"
  end
end
