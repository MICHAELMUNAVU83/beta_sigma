defmodule BetaSigmaWeb.SprintsLiveShowBulkTasksTest do
  use BetaSigmaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import BetaSigma.AccountsFixtures

  alias BetaSigma.Projects

  test "previews and creates tasks from pasted AI Markdown", %{conn: conn} do
    admin = admin_fixture(%{name: "Sprint Planner"})
    developer = user_fixture(%{name: "Bulk Developer"})

    {:ok, project} =
      Projects.create_project(%{
        "name" => "Ops Console",
        "status" => "active",
        "created_by_id" => admin.id
      })

    {:ok, sprint} =
      Projects.create_sprint(%{
        "created_by_id" => admin.id,
        "name" => "Ops Sprint",
        "cadence" => "biweekly",
        "start_date" => ~D[2026-07-06]
      })

    markdown = """
    # Sprint Task Plan

    ## Tasks

    ### Task: Add operations task queue
    Phase: backend
    Priority: urgent
    Estimated Hours: 10
    Suggested Assignee Role: Backend developer
    Description:
    Create a queue for operations staff to triage incoming work.

    Acceptance Criteria:
    - Staff can see pending work
    - Completed items leave the active queue

    Dependencies:
    - None

    ---
    """

    {:ok, view, html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/app/sprints/#{sprint.id}")

    assert html =~ "Download MD"
    assert html =~ "Bulk add via AI"

    view
    |> element("button[phx-click=\"open_bulk_tasks\"]")
    |> render_click()

    assert render(view) =~ "Randomly and evenly assign to"
    assert render(view) =~ "Bulk Developer"

    preview_html =
      view
      |> form("#sprint-bulk-tasks-form",
        bulk_tasks: %{
          "project_id" => project.id,
          "markdown" => markdown,
          "assignee_ids" => [developer.id]
        }
      )
      |> render_change()

    assert preview_html =~ "Add operations task queue"
    assert preview_html =~ "1 tasks"

    create_html =
      view
      |> form("#sprint-bulk-tasks-form",
        bulk_tasks: %{
          "project_id" => project.id,
          "markdown" => markdown,
          "assignee_ids" => [developer.id]
        }
      )
      |> render_submit()

    assert create_html =~ "1 tasks created."
    assert create_html =~ "Add operations task queue"

    [task] = Projects.get_sprint!(sprint.id).tasks
    assert task.project_id == project.id
    assert task.status == :backlog
    assert Enum.map(task.assignees, & &1.id) == [developer.id]
  end
end
