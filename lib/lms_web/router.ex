defmodule LmsWeb.Router do
  use LmsWeb, :router

  import LmsWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LmsWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; script-src 'self' 'unsafe-inline'; img-src 'self' data:; style-src 'self' 'unsafe-inline'"
    }

    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LmsWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", LmsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:lms, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LmsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", LmsWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create

    live_session :company_registration do
      live "/companies/register", CompanyRegistrationLive
    end
  end

  scope "/", LmsWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  ## Role-based dashboard routes
  ## Each live_session uses on_mount to enforce role requirements so that
  ## only users with the appropriate role can access these pages.

  scope "/", LmsWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :admin,
      on_mount: [
        {LmsWeb.UserAuth, :ensure_authenticated},
        {LmsWeb.Plugs.AuthorizationHooks, {:require_role, [:system_admin]}}
      ] do
      live "/admin/companies", Admin.CompanyListLive
    end

    live_session :company_admin,
      on_mount: [
        {LmsWeb.UserAuth, :ensure_authenticated},
        {LmsWeb.Plugs.AuthorizationHooks, {:require_role, [:company_admin, :system_admin]}}
      ] do
      live "/dashboard", DashboardLive
      live "/admin/employees", Admin.EmployeeLive.Index
    end

    live_session :course_creator,
      on_mount: [
        {LmsWeb.UserAuth, :ensure_authenticated},
        {LmsWeb.Plugs.AuthorizationHooks,
         {:require_role, [:course_creator, :company_admin, :system_admin]}}
      ] do
      live "/courses", CourseListLive
    end

    live_session :employee,
      on_mount: [
        {LmsWeb.UserAuth, :ensure_authenticated},
        {LmsWeb.Plugs.AuthorizationHooks,
         {:require_role, [:employee, :course_creator, :company_admin, :system_admin]}}
      ] do
      live "/my-learning", Employee.MyLearningLive
    end
  end

  scope "/", LmsWeb do
    pipe_through [:browser]

    live_session :invitation,
      on_mount: [{LmsWeb.UserAuth, :mount_current_scope}] do
      live "/invitations/:token", InvitationLive.Accept
    end

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    get "/users/registration-login", UserSessionController, :registration_login
    delete "/users/log-out", UserSessionController, :delete
  end
end
