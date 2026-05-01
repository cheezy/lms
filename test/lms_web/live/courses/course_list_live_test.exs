defmodule LmsWeb.Courses.CourseListLiveTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures
  import Lms.TrainingFixtures

  setup %{conn: conn} do
    company = company_fixture()
    admin = user_with_role_fixture(:company_admin, company.id)
    conn = log_in_user(conn, admin)
    %{conn: conn, company: company, admin: admin}
  end

  describe "Index" do
    test "lists courses for the company", %{conn: conn, company: company} do
      course = course_fixture(%{company: company, title: "Elixir Basics"})
      {:ok, _view, html} = live(conn, ~p"/courses")
      assert html =~ "Elixir Basics"
      assert html =~ to_string(course.status)
    end

    test "shows empty state when no courses", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/courses")
      assert html =~ "No courses yet"
    end

    test "does not show courses from other companies", %{conn: conn} do
      other_company = company_fixture()
      course_fixture(%{company: other_company, title: "Other Company Course"})

      {:ok, _view, html} = live(conn, ~p"/courses")
      refute html =~ "Other Company Course"
    end

    test "shows new course button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/courses")
      assert html =~ "New Course"
    end
  end

  describe "Status filter" do
    test "filters courses by status", %{conn: conn, company: company} do
      course_fixture(%{company: company, title: "Draft Course", status: :draft})
      course_fixture(%{company: company, title: "Published Course", status: :published})

      {:ok, view, _html} = live(conn, ~p"/courses")

      html =
        view
        |> form("#status-filter-form", status: "published")
        |> render_change()

      assert html =~ "Published Course"
      refute html =~ "Draft Course"
    end

    test "shows no results for filter with no matches", %{conn: conn, company: company} do
      course_fixture(%{company: company, status: :draft})

      {:ok, view, _html} = live(conn, ~p"/courses")

      html =
        view
        |> form("#status-filter-form", status: "archived")
        |> render_change()

      assert html =~ "No courses match"
    end
  end

  describe "Layout toggle" do
    test "toggles between grid and list views", %{conn: conn, company: company} do
      course_fixture(%{company: company})
      {:ok, view, html} = live(conn, ~p"/courses")

      # Default is grid view
      assert html =~ "grid-cols-1"

      # Switch to list
      html =
        view
        |> element("button[phx-value-layout='list']")
        |> render_click()

      assert html =~ "courses-table"

      # Switch back to grid
      html =
        view
        |> element("button[phx-value-layout='grid']")
        |> render_click()

      assert html =~ "grid-cols-1"
    end
  end

  describe "Course actions" do
    test "publishes a draft course", %{conn: conn, company: company} do
      course = course_fixture(%{company: company, status: :draft})
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter})
      {:ok, view, _html} = live(conn, ~p"/courses")

      view
      |> element("button[phx-click='publish'][phx-value-id='#{course.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Course published successfully"
    end

    test "archives a published course as admin", %{conn: conn, company: company} do
      course = course_fixture(%{company: company, status: :published})
      {:ok, view, _html} = live(conn, ~p"/courses")

      view
      |> element("button[phx-click='archive'][phx-value-id='#{course.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Course archived successfully"
    end

    test "deletes a draft course", %{conn: conn, company: company} do
      course = course_fixture(%{company: company, title: "To Delete", status: :draft})
      {:ok, view, _html} = live(conn, ~p"/courses")

      view
      |> element("button[phx-click='delete'][phx-value-id='#{course.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Course deleted successfully"
      refute html =~ "To Delete"
    end

    test "course creator cannot see archive button", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      conn = log_in_user(conn, creator)
      course = course_fixture(%{company: company, status: :published})

      {:ok, view, _html} = live(conn, ~p"/courses")
      refute has_element?(view, "button[phx-click='archive'][phx-value-id='#{course.id}']")
    end
  end

  describe "Status filter edge cases" do
    test "handles invalid status param gracefully", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/courses?status=nonexistent")
      assert html =~ "No courses match"
    end

    test "shows all statuses when filter is empty string", %{conn: conn, company: company} do
      course_fixture(%{company: company, status: :draft, title: "Draft One"})
      course_fixture(%{company: company, status: :published, title: "Published One"})

      {:ok, _view, html} = live(conn, ~p"/courses?status=")
      assert html =~ "Draft One"
      assert html =~ "Published One"
    end
  end

  describe "Course descriptions and images" do
    test "renders course with description", %{conn: conn, company: company} do
      course_fixture(%{
        company: company,
        title: "Desc Course",
        description: "A very detailed description"
      })

      {:ok, _view, html} = live(conn, ~p"/courses")
      assert html =~ "A very detailed description"
    end

    test "renders course without description", %{conn: conn, company: company} do
      course_fixture(%{company: company, title: "No Desc Course"})

      {:ok, _view, html} = live(conn, ~p"/courses")
      assert html =~ "No Desc Course"
    end

    test "shows status badges for different statuses", %{conn: conn, company: company} do
      course_fixture(%{company: company, title: "Draft", status: :draft})
      course_fixture(%{company: company, title: "Published", status: :published})

      {:ok, _view, html} = live(conn, ~p"/courses")
      assert html =~ "badge-warning"
      assert html =~ "badge-success"
    end
  end

  describe "List view" do
    test "list view shows table with course details", %{conn: conn, company: company} do
      course_fixture(%{company: company, title: "Table Course", description: "Table desc"})
      {:ok, view, _html} = live(conn, ~p"/courses")

      # Switch to list view
      html =
        view
        |> element("button[phx-value-layout='list']")
        |> render_click()

      assert html =~ "Table Course"
      assert html =~ "courses-table"
    end
  end

  describe "Publish errors" do
    test "shows error when course has no chapters", %{conn: conn, company: company} do
      course = course_fixture(%{company: company, status: :draft, title: "Empty Course"})
      {:ok, view, _html} = live(conn, ~p"/courses")

      html =
        view
        |> element("button[phx-click='publish'][phx-value-id='#{course.id}']")
        |> render_click()

      assert html =~ "Cannot publish"
      assert html =~ "needs at least one chapter"
    end

    test "preserves status filter after publishing", %{conn: conn, company: company} do
      course = course_fixture(%{company: company, status: :draft, title: "Filter Pub Course"})
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter})

      {:ok, view, _html} = live(conn, ~p"/courses?status=draft")

      view
      |> element("button[phx-click='publish'][phx-value-id='#{course.id}']")
      |> render_click()

      assert_patch(view, ~p"/courses?status=draft")
    end
  end

  describe "List view actions" do
    test "publish button works in list view", %{conn: conn, company: company} do
      course = course_fixture(%{company: company, status: :draft, title: "List Pub Course"})
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter})
      {:ok, view, _html} = live(conn, ~p"/courses")

      view
      |> element("button[phx-value-layout='list']")
      |> render_click()

      html =
        view
        |> element("#courses-table button[phx-click='publish']")
        |> render_click()

      assert html =~ "Course published successfully"
    end

    test "archive button works in list view", %{conn: conn, company: company} do
      course_fixture(%{company: company, status: :published, title: "List Archive Course"})
      {:ok, view, _html} = live(conn, ~p"/courses")

      view
      |> element("button[phx-value-layout='list']")
      |> render_click()

      html =
        view
        |> element("#courses-table button[phx-click='archive']")
        |> render_click()

      assert html =~ "Course archived successfully"
    end

    test "delete button works in list view", %{conn: conn, company: company} do
      course_fixture(%{company: company, status: :draft, title: "List Delete Course"})
      {:ok, view, _html} = live(conn, ~p"/courses")

      view
      |> element("button[phx-value-layout='list']")
      |> render_click()

      html =
        view
        |> element("#courses-table button[phx-click='delete']")
        |> render_click()

      assert html =~ "Course deleted successfully"
    end

    test "renders course with cover image in list view", %{conn: conn, company: company} do
      course_fixture(%{
        company: company,
        title: "Cover List Course",
        cover_image: "/uploads/cover.jpg"
      })

      {:ok, view, _html} = live(conn, ~p"/courses")

      html =
        view
        |> element("button[phx-value-layout='list']")
        |> render_click()

      assert html =~ "/uploads/cover.jpg"
      assert html =~ "Cover List Course"
    end
  end

  describe "Grid view with cover image" do
    test "renders course with cover image in grid view", %{conn: conn, company: company} do
      course_fixture(%{
        company: company,
        title: "Grid Cover Course",
        cover_image: "/uploads/grid-cover.jpg"
      })

      {:ok, _view, html} = live(conn, ~p"/courses")
      assert html =~ "/uploads/grid-cover.jpg"
      assert html =~ "Grid Cover Course"
    end
  end

  describe "Authorization" do
    test "redirects unauthenticated users" do
      conn = build_conn()
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/courses")
      assert path =~ "/users/log-in"
    end

    test "redirects employee users" do
      company = company_fixture()
      employee = user_with_role_fixture(:employee, company.id)
      conn = build_conn() |> log_in_user(employee)

      {:error, {:redirect, %{to: "/", flash: %{"error" => _}}}} =
        live(conn, ~p"/courses")
    end
  end
end
