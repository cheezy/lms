defmodule LmsWeb.Plugs.AuthorizationTest do
  use LmsWeb.ConnCase, async: true

  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures

  alias Lms.Accounts.Scope
  alias LmsWeb.Plugs.Authorization

  defp conn_with_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> assign(:current_scope, Scope.for_user(user))
    |> fetch_flash()
  end

  describe "require_role/2" do
    test "allows user with matching role", %{conn: conn} do
      company = company_fixture()
      user = user_with_role_fixture(:company_admin, company.id)

      conn =
        conn
        |> conn_with_user(user)
        |> Authorization.require_role([:company_admin, :system_admin])

      refute conn.halted
    end

    test "allows user when role matches any in the list", %{conn: conn} do
      user = user_with_role_fixture(:system_admin)

      conn =
        conn
        |> conn_with_user(user)
        |> Authorization.require_role([:company_admin, :system_admin])

      refute conn.halted
    end

    test "redirects user with non-matching role", %{conn: conn} do
      company = company_fixture()
      user = user_with_role_fixture(:employee, company.id)

      conn =
        conn
        |> conn_with_user(user)
        |> Authorization.require_role([:system_admin, :company_admin])

      assert conn.halted
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not authorized"
    end

    test "redirects when no user is logged in", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> assign(:current_scope, nil)
        |> fetch_flash()
        |> Authorization.require_role([:system_admin])

      assert conn.halted
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_company/2" do
    test "assigns company for user with company_id", %{conn: conn} do
      company = company_fixture()
      user = user_with_role_fixture(:employee, company.id)

      conn =
        conn
        |> conn_with_user(user)
        |> Authorization.fetch_current_company([])

      assert conn.assigns.current_company.id == company.id
    end

    test "assigns nil for system_admin without company", %{conn: conn} do
      user = user_with_role_fixture(:system_admin)

      conn =
        conn
        |> conn_with_user(user)
        |> Authorization.fetch_current_company([])

      assert is_nil(conn.assigns.current_company)
    end

    test "assigns nil when no user is logged in", %{conn: conn} do
      conn =
        conn
        |> assign(:current_scope, nil)
        |> Authorization.fetch_current_company([])

      assert is_nil(conn.assigns.current_company)
    end
  end

  describe "require_company_scope/2" do
    test "allows access when company_id matches user's company", %{conn: conn} do
      company = company_fixture()
      user = user_with_role_fixture(:employee, company.id)

      conn =
        conn
        |> conn_with_user(user)
        |> Map.put(:params, %{"company_id" => to_string(company.id)})
        |> Authorization.require_company_scope([])

      refute conn.halted
    end

    test "allows system_admin to access any company", %{conn: conn} do
      company = company_fixture()
      user = user_with_role_fixture(:system_admin)

      conn =
        conn
        |> conn_with_user(user)
        |> Map.put(:params, %{"company_id" => to_string(company.id)})
        |> Authorization.require_company_scope([])

      refute conn.halted
    end

    test "rejects access when company_id doesn't match", %{conn: conn} do
      company = company_fixture()
      other_company = company_fixture()
      user = user_with_role_fixture(:employee, company.id)

      conn =
        conn
        |> conn_with_user(user)
        |> Map.put(:params, %{"company_id" => to_string(other_company.id)})
        |> Authorization.require_company_scope([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not authorized"
    end

    test "uses id param when company_id is not present", %{conn: conn} do
      company = company_fixture()
      user = user_with_role_fixture(:employee, company.id)

      conn =
        conn
        |> conn_with_user(user)
        |> Map.put(:params, %{"id" => to_string(company.id)})
        |> Authorization.require_company_scope([])

      refute conn.halted
    end
  end
end
