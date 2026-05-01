defmodule LmsWeb.Plugs.Authorization do
  @moduledoc """
  Authorization plugs for role-based access control and company scoping.

  Provides plugs to enforce role requirements and company data isolation
  across the application's routes.
  """

  use LmsWeb, :verified_routes
  use Gettext, backend: LmsWeb.Gettext

  import Plug.Conn
  import Phoenix.Controller

  alias Lms.Companies

  @doc """
  Plug that requires the current user to have one of the specified roles.

  ## Usage in router

      plug :require_role, [:system_admin, :company_admin]

  Redirects unauthorized users to the home page with a flash message.
  """
  def require_role(conn, roles) when is_list(roles) do
    user = conn.assigns.current_scope && conn.assigns.current_scope.user

    if user && user.role in roles do
      conn
    else
      conn
      |> put_flash(:error, gettext("You are not authorized to access this page."))
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  @doc """
  Plug that loads and assigns the current user's company.

  Sets `current_company` assign on the connection. System admins without
  a company will have `current_company` set to `nil`.

  Must be used after `require_authenticated_user`.
  """
  def fetch_current_company(conn, _opts) do
    user = conn.assigns.current_scope && conn.assigns.current_scope.user

    company =
      if user && user.company_id do
        Companies.get_company!(user.company_id)
      end

    assign(conn, :current_company, company)
  end

  @doc """
  Plug that ensures the current user belongs to the company identified
  by the `:company_id` or `:id` parameter in the route.

  System admins bypass this check and can access any company's data.

  Must be used after `fetch_current_company`.
  """
  def require_company_scope(conn, _opts) do
    user = conn.assigns.current_scope && conn.assigns.current_scope.user

    if user && user.role == :system_admin do
      conn
    else
      requested_company_id = get_requested_company_id(conn)
      user_company_id = user && user.company_id

      if requested_company_id && user_company_id &&
           to_string(requested_company_id) == to_string(user_company_id) do
        conn
      else
        conn
        |> put_flash(:error, gettext("You are not authorized to access this resource."))
        |> redirect(to: ~p"/")
        |> halt()
      end
    end
  end

  defp get_requested_company_id(conn) do
    conn.params["company_id"] || conn.params["id"]
  end
end
