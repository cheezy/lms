defmodule LmsWeb.Plugs.AuthorizationHooks do
  @moduledoc """
  LiveView on_mount hooks for role-based access control.

  These hooks provide the same authorization guarantees as the plugs
  in `LmsWeb.Plugs.Authorization` but work with LiveView's on_mount
  callback system.

  ## Usage in router

      live_session :admin,
        on_mount: [{LmsWeb.Plugs.AuthorizationHooks, {:require_role, [:system_admin]}}] do
        live "/admin", AdminLive.Index
      end
  """

  use LmsWeb, :verified_routes

  import Phoenix.Component
  import Phoenix.LiveView

  alias Lms.Companies

  @doc """
  on_mount callback that checks the user's role or loads the current company.

  Accepts `{:require_role, roles}` where roles is a list of allowed role atoms,
  or `:fetch_current_company` to load and assign the user's company.
  """
  def on_mount({:require_role, roles}, _params, _session, socket) do
    user = socket.assigns.current_scope && socket.assigns.current_scope.user

    if user && user.role in roles do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You are not authorized to access this page.")
        |> redirect(to: ~p"/")

      {:halt, socket}
    end
  end

  def on_mount(:fetch_current_company, _params, _session, socket) do
    user = socket.assigns.current_scope && socket.assigns.current_scope.user

    company =
      if user && user.company_id do
        Companies.get_company!(user.company_id)
      end

    {:cont, assign(socket, :current_company, company)}
  end
end
