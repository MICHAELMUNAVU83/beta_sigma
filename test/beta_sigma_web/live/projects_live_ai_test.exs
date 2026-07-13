defmodule BetaSigmaWeb.ProjectsLiveAITest do
  use BetaSigmaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import BetaSigma.AccountsFixtures

  alias BetaSigma.{Notes, Projects}

  defmodule OpenAIStub do
    def generate_project_plan(_project_attrs, _prompt, _opts \\ []) do
      {:ok,
       %{
         "document_name" => "supplier_onboarding_portal_project_document.md",
         "project_summary" =>
           "A supplier onboarding portal that lets vendors submit documents and lets internal teams review approvals in one place.",
         "markdown_brief" => """
         # Supplier Onboarding Portal

         ## Project Overview
         Build a shared portal for supplier onboarding and internal approval tracking.

         ## Technical Approach
         - Phoenix LiveView for internal workflows
         - PostgreSQL-backed document and approval state

         ## Delivery Plan
         ### Phase 1: Discovery
         - Confirm documents and approval stages

         ### Phase 3: Core Build
         - Build supplier submission and approval workflows
         """,
         "tasks" => [
           %{
             "phase" => "Discovery",
             "title" => "Map supplier onboarding workflow",
             "description" =>
               "Confirm the documents, approval stages, and reminders needed for onboarding.",
             "priority" => "high",
             "estimated_hours" => 6
           },
           %{
             "phase" => "Frontend",
             "title" => "Build supplier submission experience",
             "description" =>
               "Create the submission flow for supplier details, uploads, and status tracking.",
             "priority" => "high",
             "estimated_hours" => 14
           },
           %{
             "phase" => "Backend",
             "title" => "Create internal approval workspace",
             "description" =>
               "Add a view for admins to review supplier applications and capture approval outcomes.",
             "priority" => "medium",
             "estimated_hours" => 10
           }
         ]
       }}
    end
  end

  setup do
    previous_client = Application.get_env(:beta_sigma, :openai_client)
    Application.put_env(:beta_sigma, :openai_client, OpenAIStub)

    on_exit(fn ->
      if previous_client do
        Application.put_env(:beta_sigma, :openai_client, previous_client)
      else
        Application.delete_env(:beta_sigma, :openai_client)
      end
    end)

    :ok
  end

  test "project creation can generate starter tasks and a shared brief", %{conn: conn} do
    admin = admin_fixture()

    {:ok, view, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/app/projects")

    view
    |> element("button[phx-click=\"new_project\"]")
    |> render_click()

    form_params = %{
      "name" => "Supplier Onboarding Portal",
      "status" => "planning",
      "description" => "",
      "ai_prompt" =>
        "Create a portal where suppliers can submit onboarding documents, the operations team can review them, and reminders can be tracked."
    }

    assert {:error, {:live_redirect, %{to: redirect_path}}} =
             view
             |> form("#projects-new-project-form", project: form_params)
             |> render_submit()

    project =
      Projects.list_projects()
      |> Enum.find(&(&1.name == "Supplier Onboarding Portal"))

    assert redirect_path == ~p"/app/projects/#{project.id}"

    loaded_project = Projects.get_project!(project.id)

    assert loaded_project.description =~ "supplier onboarding portal"

    assert Enum.map(loaded_project.tasks, & &1.title) == [
             "Map supplier onboarding workflow",
             "Build supplier submission experience",
             "Create internal approval workspace"
           ]

    [generated_note] = Notes.list_notes(admin, project_id: loaded_project.id)
    assert generated_note.visibility == :shared
    assert generated_note.title == "supplier_onboarding_portal_project_document.md"
    assert generated_note.body =~ "## Project Overview"
    assert generated_note.body =~ "## Delivery Plan"
    assert Enum.map(loaded_project.tasks, & &1.phase) == ["Discovery", "Frontend", "Backend"]
  end
end
