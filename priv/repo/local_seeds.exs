alias Decimal, as: D
alias BetaSigma.Accounts
alias BetaSigma.Notifications.Notification
alias BetaSigma.Notes.Note
alias BetaSigma.Pages
alias BetaSigma.Projects.{Project, Task, TaskAssignee, TaskComment}
alias BetaSigma.Repo

today = Date.utc_today()
confirmed_at = DateTime.utc_now() |> DateTime.truncate(:second)

money = &D.new/1

upsert = fn module, lookup, attrs ->
  record = Repo.get_by(module, lookup) || struct(module)

  apply(module, :changeset, [record, attrs])
  |> Repo.insert_or_update!()
end

ensure_user = fn attrs ->
  user =
    Accounts.get_user_by_email(attrs.email) ||
      case Accounts.register_user(%{
             name: attrs.name,
             email: attrs.email,
             password: attrs.password
           }) do
        {:ok, created_user} ->
          created_user

        {:error, changeset} ->
          raise "failed to seed user #{attrs.email}: #{inspect(changeset.errors)}"
      end

  permissions =
    Map.get_lazy(attrs, :permissions, fn -> Pages.default_keys_for_role(attrs.role) end)

  user
  |> Ecto.Changeset.change(%{
    name: attrs.name,
    role: attrs.role,
    avatar_url: attrs.avatar_url,
    permissions: permissions,
    confirmed_at: confirmed_at
  })
  |> Repo.update!()
end

ensure_assignment = fn task_id, user_id ->
  Repo.get_by(TaskAssignee, task_id: task_id, user_id: user_id) ||
    %TaskAssignee{}
    |> TaskAssignee.changeset(%{task_id: task_id, user_id: user_id})
    |> Repo.insert!()
end

admin_user =
  ensure_user.(%{
    name: "Admin User",
    email: "admin@gmail.com",
    password: "123456",
    role: :admin,
    avatar_url:
      "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=400&q=80"
  })

operations_admin =
  ensure_user.(%{
    name: "Daniel Otieno",
    email: "operations.admin@vumbuzi.local",
    password: "ChangeMe123456!",
    role: :admin,
    avatar_url:
      "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80"
  })

delivery_staff =
  ensure_user.(%{
    name: "Mercy Wanjiku",
    email: "mercy@vumbuzi.local",
    password: "ChangeMe123456!",
    role: :staff,
    avatar_url:
      "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=400&q=80"
  })

automation_staff =
  ensure_user.(%{
    name: "Brian Kibet",
    email: "brian@vumbuzi.local",
    password: "ChangeMe123456!",
    role: :staff,
    avatar_url:
      "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80",
    permissions: ["projects", "sprints", "notes", "notifications", "chat"]
  })

erp_project =
  upsert.(Project, [name: "ERP Delivery Hub"], %{
    name: "ERP Delivery Hub",
    description:
      "Internal ERP rollout covering delivery, reporting, and operational workflows.",
    status: :active,
    start_date: Date.add(today, -35),
    deadline: Date.add(today, 45),
    budget: money.("1250000.00"),
    created_by_id: admin_user.id
  })

field_ops_project =
  upsert.(Project, [name: "Field Ops Portal"], %{
    name: "Field Ops Portal",
    description:
      "Planning a delivery and support portal for distributed field operations and issue routing.",
    status: :planning,
    start_date: Date.add(today, -14),
    deadline: Date.add(today, 70),
    budget: money.("780000.00"),
    created_by_id: operations_admin.id
  })

service_desk_project =
  upsert.(Project, [name: "AI Service Desk"], %{
    name: "AI Service Desk",
    description:
      "A queued support workflow for triage, automation prompts, and internal request handling.",
    status: :on_hold,
    start_date: Date.add(today, -60),
    deadline: Date.add(today, 20),
    budget: money.("430000.00"),
    created_by_id: admin_user.id
  })

workflow_task =
  upsert.(Task, [title: "Map cross-team approvals", project_id: erp_project.id], %{
    title: "Map cross-team approvals",
    description: "Capture how teams' approvals intersect before the workflow is automated.",
    status: :in_progress,
    priority: :high,
    due_date: Date.add(today, 5),
    estimated_hours: money.("14.0"),
    project_id: erp_project.id,
    created_by_id: admin_user.id
  })

reporting_task =
  upsert.(Task, [title: "Prepare reporting slices", project_id: erp_project.id], %{
    title: "Prepare reporting slices",
    description:
      "Define which operational KPIs must appear in the internal dashboard and reports surfaces.",
    status: :review,
    priority: :urgent,
    due_date: Date.add(today, 1),
    estimated_hours: money.("9.0"),
    project_id: erp_project.id,
    created_by_id: delivery_staff.id
  })

kanban_task =
  upsert.(Task, [title: "Refine board states", project_id: field_ops_project.id], %{
    title: "Refine board states",
    description:
      "Agree on the backlog, active, escalation, and done states used by the field ops team.",
    status: :backlog,
    priority: :medium,
    due_date: Date.add(today, 10),
    estimated_hours: money.("6.5"),
    project_id: field_ops_project.id,
    created_by_id: automation_staff.id
  })

_automation_task =
  upsert.(Task, [title: "Reconnect reminder workers", project_id: service_desk_project.id], %{
    title: "Reconnect reminder workers",
    description: "Restore background reminder automation after the last round of worker changes.",
    status: :done,
    priority: :medium,
    due_date: Date.add(today, -7),
    estimated_hours: money.("5.0"),
    project_id: service_desk_project.id,
    created_by_id: automation_staff.id
  })

ensure_assignment.(workflow_task.id, delivery_staff.id)
ensure_assignment.(reporting_task.id, delivery_staff.id)
ensure_assignment.(reporting_task.id, automation_staff.id)
ensure_assignment.(kanban_task.id, automation_staff.id)

upsert.(
  TaskComment,
  [task_id: workflow_task.id, body: "Shared the first approvals draft with the team."],
  %{
    task_id: workflow_task.id,
    user_id: delivery_staff.id,
    body: "Shared the first approvals draft with the team."
  }
)

upsert.(
  TaskComment,
  [
    task_id: reporting_task.id,
    body: "Need a tighter view of overdue work versus project burn."
  ],
  %{
    task_id: reporting_task.id,
    user_id: admin_user.id,
    body: "Need a tighter view of overdue work versus project burn."
  }
)

upsert.(Note, [title: "ERP launch brief", created_by_id: admin_user.id], %{
  title: "ERP launch brief",
  body:
    "This rollout should make delivery and internal communication visible without forcing teams into separate tools.",
  visibility: :shared,
  project_id: erp_project.id,
  task_id: workflow_task.id,
  created_by_id: admin_user.id
})

upsert.(Note, [title: "Field ops assumptions", created_by_id: delivery_staff.id], %{
  title: "Field ops assumptions",
  body:
    "Support teams need clear escalation states, a short response loop, and a dashboard that highlights stalled work.",
  visibility: :personal,
  project_id: field_ops_project.id,
  task_id: kanban_task.id,
  created_by_id: delivery_staff.id
})

upsert.(
  Notification,
  [user_id: delivery_staff.id, message: "Reporting slice review is ready."],
  %{
    type: "task_assigned",
    message: "Reporting slice review is ready.",
    link: "/app/projects/#{erp_project.id}",
    read: false,
    user_id: delivery_staff.id
  }
)

upsert.(
  Notification,
  [user_id: automation_staff.id, message: "You were assigned to a board refinement task."],
  %{
    type: "task_assigned",
    message: "You were assigned to a board refinement task.",
    link: "/app/projects/#{field_ops_project.id}",
    read: true,
    user_id: automation_staff.id
  }
)

IO.puts("""
Seeded BetaSigma with:
- 2 admin users (full access) and 2 staff users
  - Mercy Wanjiku: default staff permissions (all workspace pages)
  - Brian Kibet: restricted to projects, sprints, notes, notifications, chat
- 3 projects
- 4 tasks with assignments, comments, and notes
- 2 notifications
""")
