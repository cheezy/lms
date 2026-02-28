defmodule LmsWeb.Admin.EmployeeLive.IndexTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures

  setup %{conn: conn} do
    company = company_fixture()
    admin = user_with_role_fixture(:company_admin, company.id)
    conn = log_in_user(conn, admin)
    scope = Lms.Accounts.Scope.for_user(admin)
    %{conn: conn, company: company, admin: admin, scope: scope}
  end

  describe "Index" do
    test "lists employees for the admin's company", %{conn: conn, company: company} do
      employee = user_with_role_fixture(:employee, company.id)
      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      assert html =~ "Employees"
      assert html =~ employee.email
    end

    test "shows empty state when no employees", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      assert html =~ "No employees yet"
    end

    test "shows invite button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      assert html =~ "Invite Employee"
    end

    test "displays employee status badge", %{conn: conn, scope: scope} do
      {_invited, _token} = invited_user_fixture(scope)
      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      assert html =~ "invited"
    end
  end

  describe "Invite Employee" do
    test "opens invite modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      view |> element("button", "Invite Employee") |> render_click()
      assert render(view) =~ "Invite a New Employee"
    end

    test "submits invitation successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      view |> element("button", "Invite Employee") |> render_click()

      view
      |> form("#invite-form", invite: %{name: "Alice Smith", email: "alice@example.com"})
      |> render_submit()

      flash = assert_redirect(view, ~p"/admin/employees")
      assert flash["info"] =~ "Invitation sent"
    end

    test "shows validation errors for invalid input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      view |> element("button", "Invite Employee") |> render_click()

      html =
        view
        |> form("#invite-form", invite: %{name: "", email: "bad"})
        |> render_submit()

      assert html =~ "can&#39;t be blank" or html =~ "must have the @ sign"
    end
  end

  describe "Authorization" do
    test "redirects non-admin users", %{conn: conn} do
      employee_company = company_fixture()
      employee = user_with_role_fixture(:employee, employee_company.id)
      conn = log_in_user(conn, employee)

      {:error, {:redirect, %{to: "/", flash: %{"error" => _}}}} =
        live(conn, ~p"/admin/employees")
    end
  end
end
