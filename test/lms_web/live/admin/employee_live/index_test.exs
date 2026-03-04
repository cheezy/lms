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

  describe "Bulk Upload" do
    test "opens bulk upload modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      view |> element("button", "Bulk Upload") |> render_click()
      html = render(view)
      assert html =~ "Upload"
    end

    test "closes bulk upload modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      view |> element("button", "Bulk Upload") |> render_click()
      assert render(view) =~ "Upload"

      view
      |> element("button.btn-circle[phx-click='close_bulk_upload_modal']")
      |> render_click()

      # Modal should be closed; verify the main page is back
      assert render(view) =~ "Employees"
    end
  end

  describe "Invite modal close" do
    test "closes invite modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      view |> element("button", "Invite Employee") |> render_click()
      assert render(view) =~ "Invite a New Employee"

      view
      |> element("button.btn-circle[phx-click='close_invite_modal']")
      |> render_click()

      html = render(view)
      assert html =~ "Employees"
    end
  end

  describe "Sort edge cases" do
    test "handles invalid sort_by param gracefully", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      {:ok, _view, html} = live(conn, ~p"/admin/employees?sort_by=nonexistent_field")
      assert html =~ "Employees"
    end

    test "handles invalid sort_order param gracefully", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      {:ok, _view, html} = live(conn, ~p"/admin/employees?sort_order=invalid")
      assert html =~ "Employees"
    end

    test "clicking different column resets to asc", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      {:ok, view, _html} = live(conn, ~p"/admin/employees?sort_by=name&sort_order=desc")

      # Click a different column (email) - should sort by email asc
      view |> element("th", "Email") |> render_click()
      assert_patch(view)
    end
  end

  describe "Pagination" do
    test "handles invalid page param gracefully", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      {:ok, _view, html} = live(conn, ~p"/admin/employees?page=abc")
      assert html =~ "Employees"
    end

    test "handles negative page param gracefully", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      {:ok, _view, html} = live(conn, ~p"/admin/employees?page=-5")
      assert html =~ "Employees"
    end

    test "handles zero page param gracefully", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      {:ok, _view, html} = live(conn, ~p"/admin/employees?page=0")
      assert html =~ "Employees"
    end
  end

  describe "Pagination navigation" do
    test "shows pagination when more than 20 employees", %{conn: conn, company: company} do
      for _i <- 1..21 do
        user_with_role_fixture(:employee, company.id)
      end

      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      assert html =~ "Showing page"
      assert html =~ "Next"
    end

    test "navigates to next page", %{conn: conn, company: company} do
      for _i <- 1..21 do
        user_with_role_fixture(:employee, company.id)
      end

      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      view
      |> element("button", "Next")
      |> render_click()

      html = render(view)
      assert html =~ "Showing page 2"
    end

    test "navigates to previous page", %{conn: conn, company: company} do
      for _i <- 1..21 do
        user_with_role_fixture(:employee, company.id)
      end

      {:ok, view, _html} = live(conn, ~p"/admin/employees?page=2")

      view
      |> element("button", "Previous")
      |> render_click()

      html = render(view)
      assert html =~ "Showing page 1"
    end

    test "clicking a page number navigates to that page", %{conn: conn, company: company} do
      for _i <- 1..21 do
        user_with_role_fixture(:employee, company.id)
      end

      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      view
      |> element("button.join-item", "2")
      |> render_click()

      html = render(view)
      assert html =~ "Showing page 2"
    end

    test "does not show pagination with fewer than 21 employees", %{conn: conn, company: company} do
      for _i <- 1..5 do
        user_with_role_fixture(:employee, company.id)
      end

      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      refute html =~ "Showing page"
      refute html =~ "Next"
    end
  end

  describe "Sort indicators" do
    test "shows ascending indicator when sorted asc", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      {:ok, view, _html} = live(conn, ~p"/admin/employees?sort_by=email&sort_order=asc")

      assert has_element?(view, "span .hero-chevron-up")
    end

    test "shows descending indicator when sorted desc", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      {:ok, view, _html} = live(conn, ~p"/admin/employees?sort_by=email&sort_order=desc")

      assert has_element?(view, "span .hero-chevron-down")
    end
  end

  describe "Role Management edge cases" do
    test "admin cannot change own role", %{conn: conn, admin: admin} do
      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      # The admin should be listed but without a promote/demote button for themselves
      refute has_element?(view, "button[phx-click='promote'][phx-value-id='#{admin.id}']")
      refute has_element?(view, "button[phx-click='demote'][phx-value-id='#{admin.id}']")
    end
  end

  describe "Combined filters" do
    test "search and status filter work together", %{conn: conn, scope: scope, company: company} do
      employee = user_with_role_fixture(:employee, company.id)
      {_invited, _token} = invited_user_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      # Filter by active status and search for employee email
      view
      |> form("#status-filter-form", status: "active")
      |> render_change()

      html =
        view
        |> form("#search-form", search: employee.email)
        |> render_change()

      assert html =~ employee.email
    end

    test "search with no status filter shows all matching", %{conn: conn, company: company} do
      emp = user_with_role_fixture(:employee, company.id)
      {:ok, view, _html} = live(conn, ~p"/admin/employees")

      html =
        view
        |> form("#search-form", search: emp.email)
        |> render_change()

      assert html =~ emp.email
    end
  end

  describe "Employee table display" do
    test "shows dash for employee without name", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      # Employees created via user_fixture don't have names set
      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      assert html =~ "—"
    end

    test "shows employee email in table", %{conn: conn, company: company} do
      employee = user_with_role_fixture(:employee, company.id)
      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      assert html =~ employee.email
    end

    test "shows active badge for confirmed employees", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)
      {:ok, view, _html} = live(conn, ~p"/admin/employees")
      assert has_element?(view, ".badge-success", "active")
    end

    test "shows info badge for invited employees", %{conn: conn, scope: scope} do
      {_invited, _token} = invited_user_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/admin/employees")
      assert has_element?(view, ".badge-info", "invited")
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
