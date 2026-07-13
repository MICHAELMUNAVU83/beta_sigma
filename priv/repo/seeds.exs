alias BetaSigma.Accounts
alias BetaSigma.Notes.Note
alias BetaSigma.Pages
alias BetaSigma.Projects.{Project, Sprint, Task, TaskAssignee, TaskComment}
alias BetaSigma.Repo

confirmed_at = DateTime.utc_now() |> DateTime.truncate(:second)

# ── Helpers ────────────────────────────────────────────────────────────────────

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
    avatar_url: Map.get(attrs, :avatar_url),
    permissions: permissions,
    confirmed_at: confirmed_at
  })
  |> Repo.update!()
end

# ── Single User ────────────────────────────────────────────────────────────────

admin_user =
  ensure_user.(%{
    name: "Michael Munavu",
    email: "michaelmunavu83@gmail.com",
    password: "123456",
    role: :admin,
    avatar_url: nil
  })

staff_user =
  ensure_user.(%{
    name: "Amina Wanjiku",
    email: "staff@vumbuzi-ai.co.ke",
    password: "password1234",
    role: :staff,
    avatar_url: nil
  })

_test_user =
  ensure_user.(%{
    name: "Sean Motanya",
    email: "seanmotanya@gmail.com",
    password: "Password321!",
    role: :staff,
    avatar_url: nil
  })

# ── Operational Sample Data ───────────────────────────────────────────────────

delivery_project =
  upsert.(Project, [name: "Acacia Patient Intake Portal"], %{
    name: "Acacia Patient Intake Portal",
    description:
      "Build a patient intake and operations portal for Acacia Health Group, including structured project delivery and implementation notes.",
    status: :active,
    start_date: ~D[2026-06-01],
    deadline: ~D[2026-08-15],
    budget: Decimal.new("2200000.00"),
    created_by_id: admin_user.id
  })

sprint =
  upsert.(Sprint, [name: "Discovery and workflow mapping", start_date: ~D[2026-06-15]], %{
    created_by_id: admin_user.id,
    name: "Discovery and workflow mapping",
    cadence: :biweekly,
    start_date: ~D[2026-06-15]
  })

task =
  upsert.(Task, [project_id: delivery_project.id, title: "Map patient intake workflow"], %{
    project_id: delivery_project.id,
    sprint_id: sprint.id,
    created_by_id: admin_user.id,
    title: "Map patient intake workflow",
    description:
      "Interview reception, finance, and clinical operations teams; turn findings into a first workflow map.",
    phase: "Discovery",
    status: :in_progress,
    priority: :high,
    due_date: ~D[2026-06-30],
    estimated_hours: Decimal.new("12.0")
  })

case Repo.get_by(TaskAssignee, task_id: task.id, user_id: staff_user.id) do
  nil ->
    %TaskAssignee{}
    |> TaskAssignee.changeset(%{task_id: task.id, user_id: staff_user.id})
    |> Repo.insert!()

  task_assignee ->
    task_assignee
end

upsert.(
  TaskComment,
  [task_id: task.id, body: "Kickoff complete; waiting on Acacia's billing workflow notes."],
  %{
    task_id: task.id,
    user_id: staff_user.id,
    body: "Kickoff complete; waiting on Acacia's billing workflow notes."
  }
)

upsert.(Note, [project_id: delivery_project.id, title: "Acacia kickoff notes"], %{
  project_id: delivery_project.id,
  task_id: task.id,
  created_by_id: staff_user.id,
  title: "Acacia kickoff notes",
  body:
    "Reception needs fast capture, finance needs clean billing handoff, and management wants weekly operational reports.",
  visibility: :shared
})

IO.puts("""
Seeded BetaSigma with:
- 1 admin user: michaelmunavu83@gmail.com (password: 123456)
- 1 staff user: staff@vumbuzi-ai.co.ke (password: password1234)
- 1 delivery project with sprint, task, assignee, task comment, and note
""")
