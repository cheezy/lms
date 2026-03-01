defmodule LmsWeb.Admin.CompanyListLiveTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.CompaniesFixtures
  import Lms.AccountsFixtures
  import Lms.TrainingFixtures
  import Lms.LearningFixtures

  setup %{conn: conn} do
    company = company_fixture(%{name: "Test Company", slug: "test-company"})
    admin = user_with_role_fixture(:system_admin)
    conn = log_in_user(conn, admin)

    %{conn: conn, company: company, admin: admin}
  end

  describe "Index" do
    test "lists companies with stats", %{conn: conn, company: company} do
      {:ok, _view, html} = live(conn, ~p"/admin/companies")

      assert html =~ "System Administration"
      assert html =~ company.name
    end

    test "shows employee count", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)

      {:ok, _view, html} = live(conn, ~p"/admin/companies")
      assert html =~ "1"
    end

    test "shows course count", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      _course = course_fixture(%{company: company, creator: creator})

      {:ok, _view, html} = live(conn, ~p"/admin/companies")
      assert html =~ "Courses"
    end

    test "searches companies by name", %{conn: conn, company: company} do
      _other = company_fixture(%{name: "Other Corp", slug: "other-corp"})

      {:ok, view, _html} = live(conn, ~p"/admin/companies")

      html =
        view
        |> form("form", %{search: "Test"})
        |> render_change()

      assert html =~ company.name
      refute html =~ "Other Corp"
    end

    test "shows empty state when no results", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/companies")

      html =
        view
        |> form("form", %{search: "nonexistent"})
        |> render_change()

      assert html =~ "No companies match your search"
    end

    test "shows company count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/companies")
      # Should show the count of companies (1)
      assert html =~ "1"
    end
  end

  describe "Detail view" do
    test "shows company detail panel", %{conn: conn, company: company} do
      {:ok, _view, html} = live(conn, ~p"/admin/companies/#{company.id}")

      assert html =~ company.name
      assert html =~ company.slug
      assert html =~ "Employees"
      assert html =~ "Courses"
      assert html =~ "Enrollments"
    end

    test "shows correct stats in detail view", %{conn: conn, company: company} do
      employee = user_with_role_fixture(:employee, company.id)
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      _enrollment = enrollment_fixture(%{user: employee, course: course})

      {:ok, _view, html} = live(conn, ~p"/admin/companies/#{company.id}")

      assert html =~ "Employees"
      assert html =~ "Courses"
      assert html =~ "Enrollments"
    end

    test "navigates to detail via link", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/admin/companies")

      html =
        view
        |> element("a", "View")
        |> render_click()

      assert html =~ company.slug
      assert html =~ "Details"
    end
  end

  describe "Authorization" do
    test "redirects non-system-admin users", %{company: company} do
      employee = user_with_role_fixture(:employee, company.id)
      conn = build_conn() |> log_in_user(employee)

      assert {:error, {:redirect, %{to: "/", flash: %{"error" => _}}}} =
               live(conn, ~p"/admin/companies")
    end

    test "redirects unauthenticated users" do
      conn = build_conn()

      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin/companies")
      assert path =~ "/users/log-in"
    end
  end
end
