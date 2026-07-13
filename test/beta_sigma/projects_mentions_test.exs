defmodule BetaSigma.ProjectsMentionsTest do
  use BetaSigma.DataCase, async: false
  use Oban.Testing, repo: BetaSigma.Repo

  import BetaSigma.AccountsFixtures

  alias BetaSigma.Notifications
  alias BetaSigma.Projects
  alias BetaSigma.Projects.Mentions
  alias BetaSigma.Workers.{ProjectMentionWorker, TaskMentionWorker}

  describe "Mentions parsing" do
    test "extract_user_ids/1 pulls unique ids from tokens" do
      text = "Ping @[Jane Doe](user:7) and @[Ada Lovelace](user:12), cc @[Jane Doe](user:7)."

      assert Mentions.extract_user_ids(text) == [7, 12]
      assert Mentions.extract_user_ids(nil) == []
    end

    test "to_segments/1 splits text and mentions in order" do
      assert Mentions.to_segments("hi @[Jane](user:3) bye") == [
               {:line, [{:text, "hi "}, {:mention, "Jane"}, {:text, " bye"}]}
             ]
    end

    test "to_segments/1 recognizes markdown images" do
      assert Mentions.to_segments("![Dashboard](/uploads/tasks/dashboard.png)") == [
               {:image, "Dashboard", "/uploads/tasks/dashboard.png"}
             ]
    end

    test "to_segments/1 preserves HTML text and mention tokens without interpreting markup" do
      assert Mentions.to_segments("<script>alert(1)</script> @[Jane](user:3)") == [
               {:line, [{:text, "<script>alert(1)</script> "}, {:mention, "Jane"}]}
             ]
    end
  end

  describe "mention notifications" do
    setup do
      admin = admin_fixture(%{name: "Project Admin"})
      teammate = user_fixture(%{name: "Design Lead"})

      {:ok, project} =
        Projects.create_project(%{
          "name" => "LearnFlow",
          "status" => "active",
          "created_by_id" => admin.id
        })

      %{admin: admin, teammate: teammate, project: project}
    end

    test "creating a task with a mention notifies and emails the teammate", ctx do
      {:ok, _task} =
        Projects.create_task(%{
          "project_id" => ctx.project.id,
          "created_by_id" => ctx.admin.id,
          "title" => "Kickoff",
          "description" => "cc @[Design Lead](user:#{ctx.teammate.id}) for input",
          "status" => "backlog",
          "priority" => "medium"
        })

      assert [notification] = Notifications.list_notifications(ctx.teammate.id)
      assert notification.type == "task_mention"
      assert notification.message =~ "You were mentioned"

      assert_enqueued(worker: TaskMentionWorker, args: %{user_id: ctx.teammate.id})
    end

    test "editing only notifies newly mentioned teammates", ctx do
      {:ok, task} =
        Projects.create_task(%{
          "project_id" => ctx.project.id,
          "created_by_id" => ctx.admin.id,
          "title" => "Kickoff",
          "description" => "cc @[Design Lead](user:#{ctx.teammate.id})",
          "status" => "backlog",
          "priority" => "medium"
        })

      # Same mention again on edit must not create a second notification.
      {:ok, _task} =
        Projects.update_task(task, %{
          "description" => "cc @[Design Lead](user:#{ctx.teammate.id}) again"
        })

      assert length(Notifications.list_notifications(ctx.teammate.id)) == 1
    end

    test "mentioning a teammate in the project description notifies and emails them", ctx do
      {:ok, _project} =
        Projects.update_project(ctx.project, %{
          "description" => "Owner is @[Design Lead](user:#{ctx.teammate.id})"
        })

      assert [notification] = Notifications.list_notifications(ctx.teammate.id)
      assert notification.type == "project_mention"
      assert notification.message =~ "You were mentioned in the LearnFlow project"

      assert_enqueued(worker: ProjectMentionWorker, args: %{user_id: ctx.teammate.id})
    end
  end
end
