defmodule LmsWeb.UserAuthSignedInPathTest do
  use LmsWeb.ConnCase, async: true

  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures

  alias Lms.Accounts.Scope
  alias LmsWeb.UserAuth

  describe "signed_in_path/1" do
    test "returns /admin/companies for system_admin", %{conn: conn} do
      user = user_with_role_fixture(:system_admin)
      conn = assign(conn, :current_scope, Scope.for_user(user))
      assert UserAuth.signed_in_path(conn) == ~p"/admin/companies"
    end

    test "returns /dashboard for company_admin", %{conn: conn} do
      company = company_fixture()
      user = user_with_role_fixture(:company_admin, company.id)
      conn = assign(conn, :current_scope, Scope.for_user(user))
      assert UserAuth.signed_in_path(conn) == ~p"/dashboard"
    end

    test "returns /courses for course_creator", %{conn: conn} do
      company = company_fixture()
      user = user_with_role_fixture(:course_creator, company.id)
      conn = assign(conn, :current_scope, Scope.for_user(user))
      assert UserAuth.signed_in_path(conn) == ~p"/courses"
    end

    test "returns /my-learning for employee", %{conn: conn} do
      company = company_fixture()
      user = user_with_role_fixture(:employee, company.id)
      conn = assign(conn, :current_scope, Scope.for_user(user))
      assert UserAuth.signed_in_path(conn) == ~p"/my-learning"
    end

    test "returns / when no user scope", %{conn: conn} do
      conn = assign(conn, :current_scope, nil)
      assert UserAuth.signed_in_path(conn) == ~p"/"
    end
  end
end
