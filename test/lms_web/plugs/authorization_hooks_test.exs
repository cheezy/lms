defmodule LmsWeb.Plugs.AuthorizationHooksTest do
  use LmsWeb.ConnCase, async: true

  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures

  alias LmsWeb.Plugs.AuthorizationHooks

  defp build_socket(assigns) do
    %Phoenix.LiveView.Socket{
      assigns: Map.merge(%{__changed__: %{}, flash: %{}}, assigns),
      redirected: nil
    }
  end

  describe "on_mount {:require_role, roles}" do
    test "continues when user has matching role" do
      company = company_fixture()
      user = user_with_role_fixture(:company_admin, company.id)
      scope = user_scope_fixture(user)
      socket = build_socket(%{current_scope: scope})

      assert {:cont, _socket} =
               AuthorizationHooks.on_mount({:require_role, [:company_admin]}, %{}, %{}, socket)
    end

    test "halts when user has non-matching role" do
      company = company_fixture()
      user = user_with_role_fixture(:employee, company.id)
      scope = user_scope_fixture(user)
      socket = build_socket(%{current_scope: scope})

      assert {:halt, socket} =
               AuthorizationHooks.on_mount({:require_role, [:system_admin]}, %{}, %{}, socket)

      assert socket.redirected
    end

    test "halts when no user in scope" do
      socket = build_socket(%{current_scope: nil})

      assert {:halt, _socket} =
               AuthorizationHooks.on_mount({:require_role, [:system_admin]}, %{}, %{}, socket)
    end
  end

  describe "on_mount :fetch_current_company" do
    test "assigns company when user has company_id" do
      company = company_fixture()
      user = user_with_role_fixture(:employee, company.id)
      scope = user_scope_fixture(user)
      socket = build_socket(%{current_scope: scope})

      assert {:cont, socket} =
               AuthorizationHooks.on_mount(:fetch_current_company, %{}, %{}, socket)

      assert socket.assigns.current_company.id == company.id
    end

    test "assigns nil company for system_admin without company" do
      user = user_with_role_fixture(:system_admin)
      scope = user_scope_fixture(user)
      socket = build_socket(%{current_scope: scope})

      assert {:cont, socket} =
               AuthorizationHooks.on_mount(:fetch_current_company, %{}, %{}, socket)

      assert is_nil(socket.assigns.current_company)
    end

    test "assigns nil when no user in scope" do
      socket = build_socket(%{current_scope: nil})

      assert {:cont, socket} =
               AuthorizationHooks.on_mount(:fetch_current_company, %{}, %{}, socket)

      assert is_nil(socket.assigns.current_company)
    end
  end

  describe "on_mount {:require_role, roles} with multiple roles" do
    test "allows user when role matches any in the list" do
      company = company_fixture()
      user = user_with_role_fixture(:course_creator, company.id)
      scope = user_scope_fixture(user)
      socket = build_socket(%{current_scope: scope})

      assert {:cont, _socket} =
               AuthorizationHooks.on_mount(
                 {:require_role, [:course_creator, :company_admin, :system_admin]},
                 %{},
                 %{},
                 socket
               )
    end

    test "sets flash error when halting" do
      company = company_fixture()
      user = user_with_role_fixture(:employee, company.id)
      scope = user_scope_fixture(user)
      socket = build_socket(%{current_scope: scope})

      assert {:halt, socket} =
               AuthorizationHooks.on_mount({:require_role, [:system_admin]}, %{}, %{}, socket)

      assert socket.redirected
    end

    test "redirects to root path when halting" do
      company = company_fixture()
      user = user_with_role_fixture(:employee, company.id)
      scope = user_scope_fixture(user)
      socket = build_socket(%{current_scope: scope})

      assert {:halt, socket} =
               AuthorizationHooks.on_mount({:require_role, [:system_admin]}, %{}, %{}, socket)

      assert {:redirect, %{to: "/"}} = socket.redirected
    end

    test "halts with empty roles list" do
      company = company_fixture()
      user = user_with_role_fixture(:company_admin, company.id)
      scope = user_scope_fixture(user)
      socket = build_socket(%{current_scope: scope})

      assert {:halt, _socket} =
               AuthorizationHooks.on_mount({:require_role, []}, %{}, %{}, socket)
    end
  end
end
