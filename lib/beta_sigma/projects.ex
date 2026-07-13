# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule BetaSigma.Projects do
  @moduledoc """
  The Projects context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Phoenix.PubSub
  alias BetaSigma.Accounts.User
  alias BetaSigma.Automation
  alias BetaSigma.Notes.Note
  alias BetaSigma.OpenAI
  alias BetaSigma.Projects.{Mentions, Project, Sprint, Task, TaskAssignee, TaskComment}
  alias BetaSigma.Repo

  def subscribe(project_id) do
    PubSub.subscribe(BetaSigma.PubSub, project_topic(project_id))
  end

  def subscribe_workspace do
    PubSub.subscribe(BetaSigma.PubSub, workspace_topic())
  end

  def list_projects(filters \\ []) do
    Project
    |> maybe_filter_project_status(filters[:status])
    |> maybe_filter_project_creator(filters[:created_by_id])
    |> order_by([project], desc: project.inserted_at)
    |> preload([:created_by])
    |> Repo.all()
  end

  def get_project!(id) do
    Project
    |> preload([
      :created_by,
      notes: ^project_notes_query(),
      tasks: ^project_tasks_query()
    ])
    |> Repo.get!(id)
  end

  def create_project(attrs) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, project} ->
        loaded_project = load_project(Repo, project.id)
        broadcast_workspace_event(:project_created, %{project: loaded_project})
        notify_project_mentions(loaded_project, nil)
        {:ok, loaded_project}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create_project_with_ai(attrs, %User{} = current_user, opts \\ []) do
    ai_prompt = attrs |> map_get("ai_prompt") |> normalize_text()
    project_attrs = Map.drop(attrs, ["ai_prompt", :ai_prompt])

    with {:ok, project} <- create_project(project_attrs) do
      case maybe_attach_ai_plan(project, project_attrs, ai_prompt, current_user, opts) do
        {:ok, ai_result} ->
          {:ok, load_project(Repo, project.id), ai_result}

        {:error, reason} ->
          {:ok, load_project(Repo, project.id), %{ai_requested: true, ai_error: reason}}
      end
    end
  end

  def update_project(%Project{} = project, attrs) do
    previous_description = project.description

    project
    |> Project.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_project} ->
        loaded_project = load_project(Repo, updated_project.id)
        broadcast_project_event(loaded_project.id, :project_updated, %{project: loaded_project})
        notify_project_mentions(loaded_project, previous_description)
        {:ok, loaded_project}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete_project(%Project{} = project) do
    loaded_project = load_project(Repo, project.id)

    Repo.delete(project)
    |> case do
      {:ok, deleted_project} ->
        broadcast_workspace_event(:project_deleted, %{project: loaded_project})
        {:ok, deleted_project}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end

  def list_tasks(project_id, filters \\ []) do
    Task
    |> where([task], task.project_id == ^project_id)
    |> maybe_filter_task_status(filters[:status])
    |> maybe_filter_task_priority(filters[:priority])
    |> maybe_filter_task_creator(filters[:created_by_id])
    |> maybe_filter_task_assignee(filters[:assignee_id])
    |> maybe_filter_task_due_before(filters[:due_before])
    |> maybe_filter_task_due_after(filters[:due_after])
    |> maybe_filter_task_overdue(filters[:overdue])
    |> maybe_filter_task_sprint(filters[:sprint_id])
    |> order_by([task], asc: task.due_date, desc: task.inserted_at)
    |> preload([:project, :sprint, :created_by, :assignees, comments: :user])
    |> Repo.all()
  end

  def list_tasks_workspace(filters \\ []) do
    Task
    |> maybe_filter_task_status(filters[:status])
    |> maybe_filter_task_priority(filters[:priority])
    |> maybe_filter_task_creator(filters[:created_by_id])
    |> maybe_filter_task_assignee(filters[:assignee_id])
    |> maybe_filter_task_due_before(filters[:due_before])
    |> maybe_filter_task_due_after(filters[:due_after])
    |> maybe_filter_task_overdue(filters[:overdue])
    |> maybe_filter_task_sprint(filters[:sprint_id])
    |> maybe_filter_task_project(filters[:project_id])
    |> order_by([task], asc: task.due_date, desc: task.inserted_at)
    |> preload([:project, :sprint, :created_by, :assignees, comments: :user])
    |> Repo.all()
  end

  def get_task!(id), do: load_task(Repo, id)

  def create_task(attrs) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, task} ->
        loaded_task = load_task(Repo, task.id)
        broadcast_project_event(loaded_task.project_id, :task_created, %{task: loaded_task})
        notify_task_mentions(loaded_task, nil)
        {:ok, loaded_task}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_task(%Task{} = task, attrs) do
    previous_description = task.description

    task
    |> Task.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_task} ->
        loaded_task = load_task(Repo, updated_task.id)
        broadcast_project_event(loaded_task.project_id, :task_updated, %{task: loaded_task})
        notify_task_mentions(loaded_task, previous_description)
        {:ok, loaded_task}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete_task(%Task{} = task) do
    loaded_task = load_task(Repo, task.id)

    Repo.delete(task)
    |> case do
      {:ok, deleted_task} ->
        broadcast_project_event(loaded_task.project_id, :task_deleted, %{task: loaded_task})
        {:ok, deleted_task}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end

  def list_sprints(filters \\ []) do
    Sprint
    |> maybe_filter_sprint_creator(filters[:created_by_id])
    |> order_by([sprint], desc: sprint.start_date, desc: sprint.inserted_at)
    |> preload([:created_by])
    |> Repo.all()
    |> Enum.map(&put_sprint_task_stats/1)
  end

  def current_sprint(date \\ Date.utc_today()) do
    Sprint
    |> where([sprint], sprint.start_date <= ^date and sprint.end_date >= ^date)
    |> order_by([sprint], desc: sprint.start_date, desc: sprint.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def get_sprint!(id) do
    id |> load_sprint(Repo) |> put_sprint_task_stats()
  end

  def create_sprint(attrs) do
    %Sprint{}
    |> Sprint.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, sprint} ->
        loaded_sprint = load_sprint(sprint.id, Repo)
        broadcast_workspace_event(:sprint_created, %{sprint: loaded_sprint})
        {:ok, loaded_sprint}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_sprint(%Sprint{} = sprint, attrs) do
    sprint
    |> Sprint.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_sprint} ->
        loaded_sprint = load_sprint(updated_sprint.id, Repo)
        broadcast_workspace_event(:sprint_updated, %{sprint: loaded_sprint})
        {:ok, loaded_sprint}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete_sprint(%Sprint{} = sprint) do
    loaded_sprint = load_sprint(sprint.id, Repo)

    Repo.delete(sprint)
    |> case do
      {:ok, deleted_sprint} ->
        broadcast_workspace_event(:sprint_deleted, %{sprint: loaded_sprint})
        {:ok, deleted_sprint}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def change_sprint(%Sprint{} = sprint, attrs \\ %{}) do
    Sprint.changeset(sprint, attrs)
  end

  def sprint_task_plan_markdown(%Sprint{} = sprint, projects \\ []) do
    project_names =
      projects
      |> Enum.map(& &1.name)
      |> Enum.reject(&is_nil/1)
      |> case do
        [] -> "- <PROJECT_NAME>"
        names -> Enum.map_join(names, "\n", &"- #{&1}")
      end

    """
    # Sprint Task Plan

    Use this file with AI to generate sprint-ready engineering tickets, then paste the completed Markdown back into the sprint bulk task importer.

    ## AI Prompt

    You are helping define sprint-ready engineering tickets for a Phoenix/Ecto ERP project.

    Sprint context:
    - Sprint name: #{sprint.name}
    - Sprint duration: #{format_markdown_date(sprint.start_date)} to #{format_markdown_date(sprint.end_date)}
    - Sprint goal: #{sprint.goal || "<SPRINT_GOAL>"}
    - Team size: 3 developers
    - Available projects:
    #{project_names}

    Instructions:
    1. Create realistic tickets for a 2-week sprint.
    2. Split work across 3 developers.
    3. Each task must be small enough to complete in 0.5 to 2 days.
    4. Avoid vague tasks like "improve UI" or "fix backend".
    5. Include backend, frontend, testing, integration, and review work where relevant.
    6. Include priority, estimated hours, phase, description, acceptance criteria, dependencies, and suggested assignee role.
    7. Output only Markdown using the exact format below.

    ## Sprint
    Name: #{sprint.name}
    Duration: #{format_markdown_date(sprint.start_date)} to #{format_markdown_date(sprint.end_date)}
    Goal: #{sprint.goal || "<SPRINT_GOAL>"}

    ## Tasks

    ### Task: <Task title>
    Phase: <planning | backend | frontend | integration | qa | deployment>
    Priority: <low | medium | high | urgent>
    Estimated Hours: <number>
    Suggested Assignee Role: <role>
    Description:
    <short description>

    Acceptance Criteria:
    - <criterion>
    - <criterion>
    - <criterion>

    Dependencies:
    - None

    ---
    """
  end

  def parse_sprint_task_markdown(markdown) when is_binary(markdown) do
    tasks =
      markdown
      |> String.split(~r/(?:^|\n)### Task:\s*/u)
      |> Enum.drop(1)
      |> Enum.map(&parse_sprint_task_block/1)
      |> Enum.reject(&is_nil/1)

    case tasks do
      [] -> {:error, :no_tasks_found}
      tasks -> {:ok, tasks}
    end
  end

  def parse_sprint_task_markdown(_markdown), do: {:error, :no_tasks_found}

  def create_sprint_tasks_from_markdown(
        %Sprint{} = sprint,
        %User{} = current_user,
        project_id,
        markdown,
        assignee_ids \\ []
      ) do
    with {:ok, drafts} <- parse_sprint_task_markdown(markdown),
         %Project{} = project <- Repo.get(Project, project_id) do
      task_ops =
        drafts
        |> Enum.map(&bulk_task_attrs(&1, sprint, project, current_user))
        |> Enum.with_index()
        |> Enum.map(fn {attrs, index} -> {{:bulk_task, index}, attrs} end)

      Multi.new()
      |> insert_generated_tasks(task_ops)
      |> Repo.transaction()
      |> case do
        {:ok, changes} ->
          tasks =
            task_ops
            |> Enum.map(fn {key, _attrs} -> load_task(Repo, changes[key].id) end)

          Enum.each(tasks, fn task ->
            broadcast_project_event(task.project_id, :task_created, %{task: task})
          end)

          broadcast_workspace_event(:sprint_updated, %{sprint: load_sprint(sprint.id, Repo)})

          assign_bulk_imported_tasks(tasks, assignee_ids)

        {:error, _operation, reason, _changes} ->
          {:error, reason}
      end
    else
      nil -> {:error, :project_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def add_task_to_sprint(%Task{} = task, sprint_id) do
    update_task(task, %{"sprint_id" => sprint_id})
  end

  def remove_task_from_sprint(%Task{} = task) do
    update_task(task, %{"sprint_id" => nil})
  end

  def move_task(%Task{} = task, new_status) do
    task
    |> Task.changeset(%{status: new_status})
    |> Repo.update()
    |> case do
      {:ok, updated_task} ->
        loaded_task = load_task(Repo, updated_task.id)
        broadcast_project_event(loaded_task.project_id, :task_moved, %{task: loaded_task})
        {:ok, loaded_task}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def assign_task(%Task{} = task, user_ids) when is_list(user_ids) do
    previous_assignee_ids = existing_assignee_ids(task.id)

    Multi.new()
    |> Multi.delete_all(
      :delete_assignments,
      from(task_assignee in TaskAssignee, where: task_assignee.task_id == ^task.id)
    )
    |> Multi.run(:assignments, fn repo, _changes ->
      replace_task_assignees(repo, task.id, user_ids)
    end)
    |> Multi.run(:task, fn repo, _changes -> {:ok, load_task(repo, task.id)} end)
    |> Repo.transaction()
    |> case do
      {:ok, %{task: loaded_task}} ->
        newly_assigned_ids =
          user_ids
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()
          |> Kernel.--(previous_assignee_ids)

        broadcast_project_event(loaded_task.project_id, :task_assigned, %{task: loaded_task})
        Automation.handle_task_assigned(loaded_task, newly_assigned_ids)
        {:ok, loaded_task}

      {:error, :assignments, changeset, _changes} ->
        {:error, changeset}
    end
  end

  defp notify_task_mentions(task, previous_description) do
    previous_ids = Mentions.extract_user_ids(previous_description)
    newly_mentioned_ids = Mentions.extract_user_ids(task.description) -- previous_ids

    Automation.handle_task_mentioned(task, newly_mentioned_ids)
  end

  defp notify_project_mentions(project, previous_description) do
    previous_ids = Mentions.extract_user_ids(previous_description)
    newly_mentioned_ids = Mentions.extract_user_ids(project.description) -- previous_ids

    Automation.handle_project_mentioned(project, newly_mentioned_ids)
  end

  defp notify_task_comment_mentions(task, %User{} = author, body) do
    body
    |> Mentions.extract_user_ids()
    |> Enum.reject(&(&1 == author.id))
    |> then(&Automation.handle_task_mentioned(task, &1))
  end

  defp existing_assignee_ids(task_id) do
    TaskAssignee
    |> where([task_assignee], task_assignee.task_id == ^task_id)
    |> select([task_assignee], task_assignee.user_id)
    |> Repo.all()
  end

  def add_comment(%Task{} = task, %User{} = user, body) when is_binary(body) do
    %TaskComment{}
    |> TaskComment.changeset(%{task_id: task.id, user_id: user.id, body: body})
    |> Repo.insert()
    |> case do
      {:ok, comment} ->
        loaded_comment = Repo.preload(comment, :user)
        notify_task_comment_mentions(task, user, body)

        broadcast_project_event(task.project_id, :task_comment_added, %{
          task_id: task.id,
          comment: loaded_comment
        })

        {:ok, loaded_comment}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def list_comments(task_id) do
    TaskComment
    |> where([comment], comment.task_id == ^task_id)
    |> order_by([comment], asc: comment.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  defp replace_task_assignees(repo, task_id, user_ids) do
    user_ids
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, []}, fn user_id, {:ok, assignees} ->
      %TaskAssignee{}
      |> TaskAssignee.changeset(%{task_id: task_id, user_id: user_id})
      |> repo.insert()
      |> case do
        {:ok, assignee} -> {:cont, {:ok, [assignee | assignees]}}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
    |> case do
      {:ok, assignees} -> {:ok, Enum.reverse(assignees)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp load_task(repo, id) do
    Task
    |> preload([:project, :sprint, :created_by, :assignees, comments: :user])
    |> repo.get!(id)
  end

  defp load_sprint(id, repo) do
    Sprint
    |> preload([:created_by])
    |> repo.get!(id)
  end

  defp put_sprint_task_stats(%Sprint{} = sprint) do
    tasks =
      Task
      |> where([task], task.sprint_id == ^sprint.id)
      |> preload([:project, :assignees, comments: :user])
      |> Repo.all()

    %{sprint | tasks: tasks}
  end

  defp load_project(repo, id) do
    Project
    |> preload([
      :created_by,
      notes: ^project_notes_query(),
      tasks: ^project_tasks_query()
    ])
    |> repo.get!(id)
  end

  defp broadcast_project_event(project_id, event, payload) do
    payload =
      payload
      |> Map.put(:event, event)
      |> Map.put_new(:project_id, project_id)

    PubSub.broadcast(
      BetaSigma.PubSub,
      project_topic(project_id),
      payload
    )

    PubSub.broadcast(BetaSigma.PubSub, workspace_topic(), payload)
  end

  defp broadcast_workspace_event(event, payload) do
    PubSub.broadcast(BetaSigma.PubSub, workspace_topic(), Map.put(payload, :event, event))
  end

  defp maybe_attach_ai_plan(_project, _project_attrs, nil, _current_user, _opts) do
    {:ok, %{ai_requested: false, generated_tasks_count: 0, generated_note: nil}}
  end

  defp maybe_attach_ai_plan(project, project_attrs, ai_prompt, current_user, opts) do
    openai_module =
      Keyword.get(opts, :openai_module, Application.get_env(:beta_sigma, :openai_client, OpenAI))

    with {:ok, plan} <- openai_module.generate_project_plan(project_attrs, ai_prompt, opts),
         {:ok, result} <- persist_ai_plan(project, current_user, plan) do
      {:ok, Map.put(result, :ai_requested, true)}
    end
  end

  defp persist_ai_plan(project, current_user, plan) do
    document_name = generated_document_name(project, plan)
    summary = plan |> map_get("project_summary") |> normalize_text()
    markdown_brief = plan |> map_get("markdown_brief") |> normalize_text()

    task_ops =
      plan
      |> map_get("tasks")
      |> List.wrap()
      |> Enum.map(&build_generated_task_attrs(project, current_user, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.with_index()
      |> Enum.map(fn {attrs, index} -> {{:generated_task, index}, attrs} end)

    if task_ops == [] and is_nil(markdown_brief) and is_nil(summary) do
      {:error, :empty_project_plan}
    else
      multi =
        Multi.new()
        |> maybe_update_generated_summary(project, summary)
        |> maybe_insert_generated_note(project, current_user, markdown_brief, document_name)
        |> insert_generated_tasks(task_ops)

      case Repo.transaction(multi) do
        {:ok, changes} ->
          updated_project = load_project(Repo, project.id)

          if Map.has_key?(changes, :generated_summary) do
            broadcast_project_event(updated_project.id, :project_updated, %{
              project: updated_project
            })
          end

          generated_tasks =
            task_ops
            |> Enum.map(fn {key, _attrs} -> load_task(Repo, changes[key].id) end)

          Enum.each(generated_tasks, fn task ->
            broadcast_project_event(task.project_id, :task_created, %{task: task})
          end)

          {:ok,
           %{
             generated_tasks_count: length(generated_tasks),
             generated_note: Map.get(changes, :generated_note)
           }}

        {:error, _operation, reason, _changes} ->
          {:error, reason}
      end
    end
  end

  defp maybe_update_generated_summary(multi, project, summary) do
    if is_nil(summary) or present?(project.description) do
      multi
    else
      Multi.update(
        multi,
        :generated_summary,
        Project.changeset(project, %{description: summary})
      )
    end
  end

  defp maybe_insert_generated_note(multi, _project, _current_user, nil, _document_name), do: multi

  defp maybe_insert_generated_note(multi, project, current_user, markdown_brief, document_name) do
    Multi.insert(
      multi,
      :generated_note,
      Note.changeset(%Note{}, %{
        title: document_name,
        body: markdown_brief,
        visibility: :shared,
        project_id: project.id,
        created_by_id: current_user.id
      })
    )
  end

  defp insert_generated_tasks(multi, task_ops) do
    Enum.reduce(task_ops, multi, fn {key, attrs}, acc ->
      Multi.insert(acc, key, Task.changeset(%Task{}, attrs))
    end)
  end

  defp build_generated_task_attrs(project, current_user, raw_task) when is_map(raw_task) do
    title =
      raw_task
      |> map_get("title")
      |> normalize_text()

    if is_nil(title) do
      nil
    else
      %{
        phase: raw_task |> map_get("phase") |> normalize_phase(),
        title: String.slice(title, 0, 200),
        description: raw_task |> map_get("description") |> normalize_text(),
        status: :backlog,
        priority: raw_task |> map_get("priority") |> normalize_priority(),
        estimated_hours: raw_task |> map_get("estimated_hours") |> normalize_estimated_hours(),
        project_id: project.id,
        created_by_id: current_user.id
      }
    end
  end

  defp build_generated_task_attrs(_project, _current_user, _raw_task), do: nil

  defp assign_bulk_imported_tasks(tasks, assignee_ids) do
    assignee_ids = existing_user_ids(assignee_ids)

    if assignee_ids == [] do
      {:ok, tasks}
    else
      assignee_cycle =
        assignee_ids
        |> Enum.shuffle()
        |> Stream.cycle()

      tasks
      |> Enum.zip(assignee_cycle)
      |> Enum.reduce_while({:ok, []}, fn {task, assignee_id}, {:ok, assigned_tasks} ->
        case assign_task(task, [assignee_id]) do
          {:ok, assigned_task} -> {:cont, {:ok, [assigned_task | assigned_tasks]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, assigned_tasks} -> {:ok, Enum.reverse(assigned_tasks)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp existing_user_ids(user_ids) do
    user_ids
    |> List.wrap()
    |> Enum.map(&normalize_integer/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> case do
      [] ->
        []

      ids ->
        User
        |> where([user], user.id in ^ids)
        |> select([user], user.id)
        |> Repo.all()
    end
  end

  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp normalize_integer(_value), do: nil

  defp bulk_task_attrs(draft, sprint, project, current_user) do
    %{
      phase: draft.phase,
      title: draft.title,
      description: sprint_task_description(draft),
      status: :backlog,
      priority: draft.priority,
      estimated_hours: draft.estimated_hours,
      project_id: project.id,
      sprint_id: sprint.id,
      created_by_id: current_user.id
    }
  end

  defp parse_sprint_task_block(block) do
    [raw_title | raw_lines] = String.split(block, "\n")
    title = normalize_text(raw_title)

    if is_nil(title) or String.starts_with?(title, "<") do
      nil
    else
      parsed =
        Enum.reduce(
          raw_lines,
          %{section: nil, fields: %{}, description: [], criteria: [], dependencies: []},
          fn
            "---" <> _, acc ->
              %{acc | section: nil}

            line, acc ->
              parse_sprint_task_line(line, acc)
          end
        )

      %{
        title: String.slice(title, 0, 200),
        phase: parsed.fields |> Map.get("phase") |> normalize_phase(),
        priority: parsed.fields |> Map.get("priority") |> normalize_priority(),
        estimated_hours:
          parsed.fields |> Map.get("estimated_hours") |> normalize_estimated_hours(),
        suggested_assignee_role:
          parsed.fields |> Map.get("suggested_assignee_role") |> normalize_text(),
        description: parsed.description |> lines_to_text(),
        acceptance_criteria: parsed.criteria |> clean_list_lines(),
        dependencies: parsed.dependencies |> clean_list_lines()
      }
    end
  end

  defp parse_sprint_task_line(line, acc) do
    cond do
      String.starts_with?(line, "Description:") ->
        append_section_line(
          %{acc | section: :description},
          :description,
          after_label(line, "Description:")
        )

      String.starts_with?(line, "Acceptance Criteria:") ->
        append_section_line(
          %{acc | section: :criteria},
          :criteria,
          after_label(line, "Acceptance Criteria:")
        )

      String.starts_with?(line, "Dependencies:") ->
        append_section_line(
          %{acc | section: :dependencies},
          :dependencies,
          after_label(line, "Dependencies:")
        )

      String.contains?(line, ":") and is_nil(acc.section) ->
        [raw_key, raw_value] = String.split(line, ":", parts: 2)
        key = raw_key |> String.trim() |> String.downcase() |> String.replace(~r/\s+/u, "_")
        value = String.trim(raw_value)
        put_in(acc.fields[key], value)

      is_atom(acc.section) ->
        append_section_line(acc, acc.section, line)

      true ->
        acc
    end
  end

  defp after_label(line, label), do: line |> String.replace_prefix(label, "") |> String.trim()

  defp append_section_line(acc, _section, ""), do: acc

  defp append_section_line(acc, :description, line),
    do: %{acc | description: acc.description ++ [line]}

  defp append_section_line(acc, :criteria, line),
    do: %{acc | criteria: acc.criteria ++ [line]}

  defp append_section_line(acc, :dependencies, line),
    do: %{acc | dependencies: acc.dependencies ++ [line]}

  defp lines_to_text(lines) do
    lines
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
    |> normalize_text()
  end

  defp clean_list_lines(lines) do
    lines
    |> Enum.map(fn line ->
      line
      |> String.trim()
      |> String.trim_leading("-")
      |> String.trim()
    end)
    |> Enum.reject(&(&1 in ["", "None", "none", "<criterion>"]))
  end

  defp sprint_task_description(draft) do
    [
      draft.description,
      markdown_list_section("Acceptance Criteria", draft.acceptance_criteria),
      markdown_list_section("Dependencies", draft.dependencies),
      assignee_role_section(draft.suggested_assignee_role)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  defp markdown_list_section(_title, []), do: nil

  defp markdown_list_section(title, items) do
    """
    #{title}:
    #{Enum.map_join(items, "\n", &"- #{&1}")}
    """
    |> String.trim()
  end

  defp assignee_role_section(nil), do: nil
  defp assignee_role_section(role), do: "Suggested Assignee Role: #{role}"

  defp format_markdown_date(nil), do: "<DATE>"
  defp format_markdown_date(%Date{} = date), do: Date.to_iso8601(date)

  defp normalize_phase(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      phase -> String.slice(phase, 0, 100)
    end
  end

  defp normalize_phase(_value), do: nil

  defp normalize_priority(value) when value in [:low, :medium, :high, :urgent], do: value

  defp normalize_priority(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> case do
      "low" -> :low
      "medium" -> :medium
      "high" -> :high
      "urgent" -> :urgent
      _ -> :medium
    end
  end

  defp normalize_priority(_value), do: :medium

  defp normalize_estimated_hours(value) when is_integer(value) and value > 0,
    do: Decimal.new(value)

  defp normalize_estimated_hours(value) when is_float(value) and value > 0,
    do: Decimal.from_float(Float.round(value, 2))

  defp normalize_estimated_hours(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {hours, ""} when hours > 0 -> Decimal.from_float(Float.round(hours, 2))
      _ -> nil
    end
  end

  defp normalize_estimated_hours(_value), do: nil

  defp normalize_text(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp normalize_text(_value), do: nil

  defp present?(value), do: not is_nil(normalize_text(value))

  defp generated_document_name(project, plan) do
    candidate =
      plan
      |> map_get("document_name")
      |> normalize_document_name()

    candidate || fallback_document_name(project.name)
  end

  defp normalize_document_name(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" ->
        nil

      name ->
        normalized =
          name
          |> String.replace(~r/[^A-Za-z0-9._-]+/u, "_")
          |> String.trim("_")

        cond do
          normalized == "" -> nil
          String.ends_with?(normalized, ".md") -> String.slice(normalized, 0, 200)
          true -> String.slice(normalized <> ".md", 0, 200)
        end
    end
  end

  defp normalize_document_name(_value), do: nil

  defp fallback_document_name(project_name) do
    slug =
      project_name
      |> to_string()
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "_")
      |> String.trim("_")
      |> case do
        "" -> "project"
        value -> value
      end

    String.slice("#{slug}_project_document.md", 0, 200)
  end

  defp map_get(map, key) when is_map(map) do
    case key do
      "ai_prompt" -> Map.get(map, "ai_prompt") || Map.get(map, :ai_prompt)
      "document_name" -> Map.get(map, "document_name") || Map.get(map, :document_name)
      "project_summary" -> Map.get(map, "project_summary") || Map.get(map, :project_summary)
      "markdown_brief" -> Map.get(map, "markdown_brief") || Map.get(map, :markdown_brief)
      "tasks" -> Map.get(map, "tasks") || Map.get(map, :tasks)
      "phase" -> Map.get(map, "phase") || Map.get(map, :phase)
      "title" -> Map.get(map, "title") || Map.get(map, :title)
      "description" -> Map.get(map, "description") || Map.get(map, :description)
      "priority" -> Map.get(map, "priority") || Map.get(map, :priority)
      "estimated_hours" -> Map.get(map, "estimated_hours") || Map.get(map, :estimated_hours)
      _ -> Map.get(map, key)
    end
  end

  defp project_tasks_query do
    from(task in Task,
      order_by: [asc: task.id],
      preload: [:sprint, :created_by, :assignees, comments: :user]
    )
  end

  defp project_notes_query do
    from(note in Note,
      order_by: [desc: note.inserted_at],
      preload: [:created_by]
    )
  end

  defp project_topic(project_id), do: "project:#{project_id}"
  defp workspace_topic, do: "projects:workspace"

  defp maybe_filter_project_status(query, nil), do: query

  defp maybe_filter_project_status(query, status),
    do: from(project in query, where: project.status == ^status)

  defp maybe_filter_project_creator(query, nil), do: query

  defp maybe_filter_project_creator(query, created_by_id) do
    from(project in query, where: project.created_by_id == ^created_by_id)
  end

  defp maybe_filter_task_status(query, nil), do: query

  defp maybe_filter_task_status(query, status),
    do: from(task in query, where: task.status == ^status)

  defp maybe_filter_task_priority(query, nil), do: query

  defp maybe_filter_task_priority(query, priority),
    do: from(task in query, where: task.priority == ^priority)

  defp maybe_filter_task_creator(query, nil), do: query

  defp maybe_filter_task_creator(query, created_by_id),
    do: from(task in query, where: task.created_by_id == ^created_by_id)

  defp maybe_filter_task_assignee(query, nil), do: query

  defp maybe_filter_task_assignee(query, assignee_id) do
    from(task in query,
      join: task_assignee in TaskAssignee,
      on: task_assignee.task_id == task.id,
      where: task_assignee.user_id == ^assignee_id,
      distinct: task.id
    )
  end

  defp maybe_filter_task_due_before(query, nil), do: query

  defp maybe_filter_task_due_before(query, due_before),
    do: from(task in query, where: task.due_date <= ^due_before)

  defp maybe_filter_task_due_after(query, nil), do: query

  defp maybe_filter_task_due_after(query, due_after),
    do: from(task in query, where: task.due_date >= ^due_after)

  defp maybe_filter_task_overdue(query, true) do
    today = Date.utc_today()

    from(task in query,
      where: not is_nil(task.due_date) and task.due_date < ^today and task.status != :done
    )
  end

  defp maybe_filter_task_overdue(query, _overdue), do: query

  defp maybe_filter_task_sprint(query, nil), do: query

  defp maybe_filter_task_sprint(query, sprint_id),
    do: from(task in query, where: task.sprint_id == ^sprint_id)

  defp maybe_filter_task_project(query, nil), do: query

  defp maybe_filter_task_project(query, project_id),
    do: from(task in query, where: task.project_id == ^project_id)

  defp maybe_filter_sprint_creator(query, nil), do: query

  defp maybe_filter_sprint_creator(query, created_by_id),
    do: from(sprint in query, where: sprint.created_by_id == ^created_by_id)
end
