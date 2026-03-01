defmodule LmsWeb.DashboardLiveTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.CompaniesFixtures
  import Lms.AccountsFixtures
  import Lms.TrainingFixtures
  import Lms.LearningFixtures

  setup %{conn: conn} do
    company = company_fixture()
    admin = user_with_role_fixture(:company_admin, company.id)
    conn = log_in_user(conn, admin)

    %{conn: conn, company: company, admin: admin}
  end

  describe "Dashboard" do
    test "renders dashboard with stats", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Dashboard"
      assert html =~ "Total Employees"
      assert html =~ "Courses"
      assert html =~ "Enrollments"
      assert html =~ "Completion Rate"
    end

    test "shows correct employee count", %{conn: conn, company: company} do
      _employee1 = user_with_role_fixture(:employee, company.id)
      _employee2 = user_with_role_fixture(:employee, company.id)

      {:ok, _view, html} = live(conn, ~p"/dashboard")
      # 2 employees + 1 admin = 3 total
      assert html =~ "3"
    end

    test "shows correct course count", %{conn: conn, company: company, admin: admin} do
      _course = course_fixture(%{company: company, creator: admin, status: :published})

      {:ok, _view, html} = live(conn, ~p"/dashboard")
      assert html =~ "1 published"
    end

    test "shows enrollment stats", %{conn: conn, company: company, admin: admin} do
      employee = user_with_role_fixture(:employee, company.id)
      course = course_fixture(%{company: company, creator: admin, status: :published})
      _enrollment = enrollment_fixture(%{user: employee, course: course})

      {:ok, _view, html} = live(conn, ~p"/dashboard")
      assert html =~ "Enrollments"
    end

    test "shows overdue count when overdue enrollments exist", %{
      conn: conn,
      company: company,
      admin: admin
    } do
      employee = user_with_role_fixture(:employee, company.id)
      course = course_fixture(%{company: company, creator: admin, status: :published})

      _enrollment =
        enrollment_fixture(%{
          user: employee,
          course: course,
          due_date: Date.add(Date.utc_today(), -5)
        })

      {:ok, _view, html} = live(conn, ~p"/dashboard")
      assert html =~ "1 overdue"
    end

    test "shows no overdue when none exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")
      assert html =~ "No overdue"
    end
  end

  describe "Quick Actions" do
    test "has link to add employees", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")
      assert has_element?(view, "a[href='/admin/employees']", "Add Employee")
    end

    test "has link to create course", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")
      assert has_element?(view, "a[href='/courses/new']", "Create Course")
    end

    test "has link to manage enrollments", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")
      assert has_element?(view, "a[href='/admin/enrollments']", "Manage Enrollments")
    end
  end

  describe "Activity Feed" do
    test "shows recent enrollments", %{conn: conn, company: company, admin: admin} do
      employee = user_with_role_fixture(:employee, company.id)
      course = course_fixture(%{company: company, creator: admin, status: :published})
      _enrollment = enrollment_fixture(%{user: employee, course: course})

      {:ok, _view, html} = live(conn, ~p"/dashboard")
      assert html =~ "Recent Enrollments"
      assert html =~ course.title
    end

    test "shows empty state for enrollments", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")
      assert html =~ "No enrollments yet"
    end

    test "shows empty state for completions", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")
      assert html =~ "No completions yet"
    end
  end

  describe "Navigation" do
    test "has navigation cards", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "a[href='/admin/employees']")
      assert has_element?(view, "a[href='/courses']")
      assert has_element?(view, "a[href='/admin/enrollments']")
    end
  end

  describe "Authorization" do
    test "redirects non-company-admin users", %{company: company} do
      employee = user_with_role_fixture(:employee, company.id)
      conn = build_conn() |> log_in_user(employee)

      assert {:error, {:redirect, %{to: "/", flash: %{"error" => _}}}} =
               live(conn, ~p"/dashboard")
    end

    test "allows system_admin access" do
      admin = user_with_role_fixture(:system_admin)
      conn = build_conn() |> log_in_user(admin)

      # system_admin has no company_id, need to handle nil company_id
      {:ok, _view, html} = live(conn, ~p"/dashboard")
      assert html =~ "Dashboard"
    end
  end
end
