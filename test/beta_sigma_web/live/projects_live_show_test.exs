defmodule BetaSigmaWeb.ProjectsLiveShowTest do
  use BetaSigmaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import BetaSigma.AccountsFixtures

  alias BetaSigma.Projects

  test "filters board tasks by search and assignee", %{conn: conn} do
    admin = admin_fixture(%{name: "Project Admin"})
    designer = user_fixture(%{name: "Design Lead"})
    engineer = user_fixture(%{name: "Backend Lead"})

    {:ok, project} =
      Projects.create_project(%{
        "name" => "LearnFlow",
        "status" => "active",
        "created_by_id" => admin.id
      })

    {:ok, kickoff_task} =
      Projects.create_task(%{
        "project_id" => project.id,
        "created_by_id" => admin.id,
        "title" => "Kickoff workshop",
        "description" => "Align stakeholders on scope and milestones.",
        "phase" => "Discovery",
        "status" => "backlog",
        "priority" => "medium"
      })

    {:ok, invoice_task} =
      Projects.create_task(%{
        "project_id" => project.id,
        "created_by_id" => admin.id,
        "title" => "Build invoice sync",
        "description" => "Connect billing events into the finance ledger.",
        "phase" => "Backend",
        "status" => "in_progress",
        "priority" => "high"
      })

    {:ok, review_task} =
      Projects.create_task(%{
        "project_id" => project.id,
        "created_by_id" => admin.id,
        "title" => "QA review",
        "description" => "Validate the release candidate and log regressions.",
        "phase" => "QA",
        "status" => "review",
        "priority" => "urgent"
      })

    {:ok, _task} = Projects.assign_task(kickoff_task, [designer.id])
    {:ok, _task} = Projects.assign_task(invoice_task, [engineer.id])
    {:ok, _task} = Projects.assign_task(review_task, [designer.id, engineer.id])

    {:ok, view, html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/app/projects/#{project.id}")

    assert html =~ "Kickoff workshop"
    assert html =~ "Build invoice sync"
    assert html =~ "QA review"

    filtered_by_search =
      view
      |> element("form[phx-change=\"filter_tasks\"]")
      |> render_change(%{
        "task_filters" => %{
          "search" => "invoice",
          "assignee_id" => "all",
          "status" => "all",
          "priority" => "all"
        }
      })

    assert filtered_by_search =~ "Build invoice sync"
    refute filtered_by_search =~ "Kickoff workshop"
    refute filtered_by_search =~ "QA review"
    assert filtered_by_search =~ "Showing 1 of 3 tasks"

    filtered_by_assignee =
      view
      |> element("form[phx-change=\"filter_tasks\"]")
      |> render_change(%{
        "task_filters" => %{
          "search" => "",
          "assignee_id" => Integer.to_string(designer.id),
          "status" => "all",
          "priority" => "all"
        }
      })

    assert filtered_by_assignee =~ "Kickoff workshop"
    assert filtered_by_assignee =~ "QA review"
    refute filtered_by_assignee =~ "Build invoice sync"
    assert filtered_by_assignee =~ "Showing 2 of 3 tasks"
  end

  test "shows only tasks belonging to this project", %{conn: conn} do
    admin = admin_fixture(%{name: "Sprint Admin"})

    {:ok, project} =
      Projects.create_project(%{
        "name" => "SprintFlow",
        "status" => "active",
        "created_by_id" => admin.id
      })

    {:ok, other_project} =
      Projects.create_project(%{
        "name" => "OtherFlow",
        "status" => "active",
        "created_by_id" => admin.id
      })

    {:ok, sprint} =
      Projects.create_sprint(%{
        "created_by_id" => admin.id,
        "name" => "Sprint 1",
        "cadence" => "weekly",
        "start_date" => ~D[2026-04-20]
      })

    {:ok, _in_project_task} =
      Projects.create_task(%{
        "project_id" => project.id,
        "created_by_id" => admin.id,
        "sprint_id" => sprint.id,
        "title" => "Sprint work item",
        "status" => "backlog",
        "priority" => "medium"
      })

    {:ok, _other_project_task} =
      Projects.create_task(%{
        "project_id" => other_project.id,
        "created_by_id" => admin.id,
        "sprint_id" => sprint.id,
        "title" => "Other project item",
        "status" => "backlog",
        "priority" => "medium"
      })

    {:ok, _view, html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/app/projects/#{project.id}")

    assert html =~ "Sprint work item"
    refute html =~ "Other project item"
  end

  test "comments render escaped HTML while preserving mention tokens", %{conn: conn} do
    admin = admin_fixture(%{name: "Project Admin"})

    {:ok, project} =
      Projects.create_project(%{
        "name" => "LearnFlow",
        "status" => "active",
        "created_by_id" => admin.id
      })

    {:ok, task} =
      Projects.create_task(%{
        "project_id" => project.id,
        "created_by_id" => admin.id,
        "title" => "Review API",
        "description" => "Please review the API.",
        "phase" => "Backend",
        "status" => "backlog",
        "priority" => "high"
      })

    {:ok, _comment} =
      Projects.add_comment(task, admin, "<script>alert(1)</script> @[Jane](user:3)")

    {:ok, view, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/app/projects/#{project.id}")

    html =
      view
      |> element("button[phx-click=\"open_comments\"]")
      |> render_click()

    assert html =~ "&lt;script&gt;alert(1)&lt;/script&gt;"
    assert html =~ "@Jane"
    refute html =~ "<script>alert(1)</script>"
  end
end
