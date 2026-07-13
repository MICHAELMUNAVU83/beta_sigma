defmodule BetaSigma.ProjectsSprintTaskMarkdownTest do
  use BetaSigma.DataCase, async: true

  import BetaSigma.AccountsFixtures

  alias BetaSigma.Projects

  test "creates sprint tasks from AI Markdown" do
    admin = admin_fixture()

    {:ok, project} =
      Projects.create_project(%{
        "name" => "Client Portal",
        "status" => "active",
        "created_by_id" => admin.id
      })

    {:ok, sprint} =
      Projects.create_sprint(%{
        "created_by_id" => admin.id,
        "name" => "Sprint 4",
        "cadence" => "biweekly",
        "start_date" => ~D[2026-07-06]
      })

    markdown = """
    # Sprint Task Plan

    ## Tasks

    ### Task: Build project dashboard filters
    Phase: frontend
    Priority: high
    Estimated Hours: 8
    Suggested Assignee Role: Fullstack developer
    Description:
    Add filters for status, assignee, and due date to the project task dashboard.

    Acceptance Criteria:
    - Users can filter tasks without leaving the board
    - Empty states explain when no tasks match

    Dependencies:
    - None

    ---
    """

    assert {:ok, [task]} =
             Projects.create_sprint_tasks_from_markdown(sprint, admin, project.id, markdown)

    assert task.title == "Build project dashboard filters"
    assert task.project_id == project.id
    assert task.sprint_id == sprint.id
    assert task.created_by_id == admin.id
    assert task.priority == :high
    assert task.phase == "frontend"
    assert Decimal.equal?(task.estimated_hours, Decimal.new("8.0"))
    assert task.description =~ "Acceptance Criteria:"
    assert task.description =~ "Users can filter tasks without leaving the board"
    assert task.description =~ "Suggested Assignee Role: Fullstack developer"
  end

  test "randomly distributes imported tasks across selected assignees" do
    admin = admin_fixture()
    developer_a = user_fixture(%{name: "Developer A"})
    developer_b = user_fixture(%{name: "Developer B"})

    {:ok, project} =
      Projects.create_project(%{
        "name" => "Client Portal",
        "status" => "active",
        "created_by_id" => admin.id
      })

    {:ok, sprint} =
      Projects.create_sprint(%{
        "created_by_id" => admin.id,
        "name" => "Sprint 5",
        "cadence" => "biweekly",
        "start_date" => ~D[2026-07-20]
      })

    markdown = """
    ### Task: Build task one
    Phase: backend
    Priority: high
    Estimated Hours: 6
    Description:
    Build the first task.

    ---

    ### Task: Build task two
    Phase: frontend
    Priority: medium
    Estimated Hours: 5
    Description:
    Build the second task.

    ---

    ### Task: Build task three
    Phase: qa
    Priority: medium
    Estimated Hours: 4
    Description:
    Build the third task.

    ---
    """

    assert {:ok, tasks} =
             Projects.create_sprint_tasks_from_markdown(
               sprint,
               admin,
               project.id,
               markdown,
               [developer_a.id, developer_b.id]
             )

    assignment_counts =
      tasks
      |> Enum.flat_map(& &1.assignees)
      |> Enum.frequencies_by(& &1.id)

    assert map_size(assignment_counts) == 2
    assert Enum.sort(Map.values(assignment_counts)) == [1, 2]
  end

  test "returns an error when Markdown has no task blocks" do
    assert Projects.parse_sprint_task_markdown("# Sprint Task Plan\n\nNo tickets yet.") ==
             {:error, :no_tasks_found}
  end
end
