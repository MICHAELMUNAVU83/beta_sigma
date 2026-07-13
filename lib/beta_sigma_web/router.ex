defmodule BetaSigmaWeb.Router do
  use BetaSigmaWeb, :router

  import BetaSigmaWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BetaSigmaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_session do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :fetch_current_user
  end

  pipeline :require_admin do
    plug BetaSigmaWeb.Plugs.RequireRole, [:admin]
  end

  pipeline :require_internal_user do
    plug BetaSigmaWeb.Plugs.RequireRole, [:admin, :staff]
  end

  scope "/", BetaSigmaWeb do
    pipe_through :browser

    get "/", RedirectController, :login
  end

  # Other scopes may use custom stacks.
  # scope "/api", BetaSigmaWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:beta_sigma, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BetaSigmaWeb.Telemetry
    end
  end

  ## Authentication routes

  scope "/", BetaSigmaWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      layout: {BetaSigmaWeb.Layouts, :auth},
      on_mount: [{BetaSigmaWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      # Registration removed
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", BetaSigmaWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      layout: {BetaSigmaWeb.Layouts, :app},
      on_mount: [{BetaSigmaWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/app", BetaSigmaWeb do
    pipe_through [:browser, :require_authenticated_user, :require_internal_user]

    live_session :internal,
      layout: {BetaSigmaWeb.Layouts, :app},
      on_mount: [
        {BetaSigmaWeb.UserAuth, :ensure_authenticated},
        {BetaSigmaWeb.UserAuth, {:ensure_role, [:admin, :staff]}},
        {BetaSigmaWeb.UserAuth, :ensure_page_access}
      ] do
      live "/projects", ProjectsLive.Index, :index
      live "/projects/:id", ProjectsLive.Show, :show
      live "/sprints", SprintsLive.Index, :index
      live "/sprints/:id", SprintsLive.Show, :show
      live "/notes", NotesLive.Index, :index

      live "/notifications", WorkspaceLive, :notifications
      live "/chat", ChatLive.Index, :index
    end
  end

  scope "/admin", BetaSigmaWeb do
    pipe_through [:browser, :require_authenticated_user, :require_admin]

    live_session :admin_only,
      layout: {BetaSigmaWeb.Layouts, :app},
      on_mount: [
        {BetaSigmaWeb.UserAuth, :ensure_authenticated},
        {BetaSigmaWeb.UserAuth, {:ensure_role, [:admin]}},
        {BetaSigmaWeb.UserAuth, :ensure_page_access}
      ] do
      live "/users", AdminUsersLive.Index, :index
    end
  end

  scope "/", BetaSigmaWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      layout: {BetaSigmaWeb.Layouts, :auth},
      on_mount: [{BetaSigmaWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
