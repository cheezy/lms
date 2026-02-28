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

    test "displays employee role", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      assert html =~ "employee"
    end
  end

  describe "Search" do
    test "filters employees by name", %{conn: conn, company: company} do
      emp1 = user_with_role_fixture(:employee, company.id)
      _emp2 = user_with_role_fixture(:employee, company.id)

      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      html =
        view
        |> form("#search-form", search: emp1.email)
        |> render_change()

      assert html =~ emp1.email
    end

    test "shows no results message when search matches nothing", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      html =
        view
        |> form("#search-form", search: "zzz-nonexistent-zzz")
        |> render_change()

      assert html =~ "No employees match"
    end

    test "search preserves in URL params", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      {:ok, _view, html} = live(conn, ~p"/admin/employees?search=test")
      # Page should load with search parameter
      assert html =~ "Employees"
    end
  end

  describe "Sort" do
    test "sorts by column when header clicked", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      html = view |> element("th", "Email") |> render_click()
      assert html =~ "Employees"
    end

    test "toggles sort order on second click", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      {:ok, view, _html} = live(conn, ~p"/admin/employees?sort_by=name&sort_order=asc")

      # Click name again to toggle to desc
      view |> element("th", "Name") |> render_click()
      assert_patch(view)
    end
  end

  describe "Filter" do
    test "filters by status", %{conn: conn, scope: scope, company: company} do
      _active_employee = user_with_role_fixture(:employee, company.id)
      {_invited, _token} = invited_user_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      html =
        view
        |> form("#status-filter-form", status: "invited")
        |> render_change()

      assert html =~ "invited"
    end
  end

  describe "Resend invitation" do
    test "shows resend button for invited users", %{conn: conn, scope: scope} do
      {_invited, _token} = invited_user_fixture(scope)
      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      assert html =~ "Resend"
    end

    test "does not show resend button for active users", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      refute html =~ "Resend"
    end

    test "resends invitation when clicked", %{conn: conn, scope: scope} do
      {invited, _token} = invited_user_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      view
      |> element("button[phx-click='resend_invitation'][phx-value-id='#{invited.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Invitation resent"
    end
  end

  describe "Role Management" do
    test "shows promote button for active employees", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      assert html =~ "Promote"
    end

    test "shows demote button for course creators", %{conn: conn, company: company} do
      _creator = user_with_role_fixture(:course_creator, company.id)
      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      assert html =~ "Demote"
    end

    test "does not show promote button for invited users", %{conn: conn, scope: scope} do
      {_invited, _token} = invited_user_fixture(scope)
      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      refute html =~ "Promote"
    end

    test "promotes employee to course creator", %{conn: conn, company: company} do
      employee = user_with_role_fixture(:employee, company.id)
      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      view
      |> element("button[phx-click='promote'][phx-value-id='#{employee.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "promoted to Course Creator"
    end

    test "demotes course creator to employee", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      view
      |> element("button[phx-click='demote'][phx-value-id='#{creator.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "demoted to Employee"
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
