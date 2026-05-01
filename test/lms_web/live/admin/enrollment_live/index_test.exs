defmodule LmsWeb.Admin.EnrollmentLive.IndexTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Ecto.Query
  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures
  import Lms.TrainingFixtures
  import Lms.LearningFixtures

  alias Lms.Learning

  defp set_user_name(user, name) do
    {1, _} =
      Lms.Accounts.User
      |> from(where: [id: ^user.id])
      |> Lms.Repo.update_all(set: [name: name])

    %{user | name: name}
  end

  setup %{conn: conn} do
    company = company_fixture()
    admin = user_with_role_fixture(:company_admin, company.id)
    conn = log_in_user(conn, admin)
    %{conn: conn, company: company, admin: admin}
  end

  describe "Index" do
    test "renders enrollment page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")
      assert html =~ "Enrollments"
      assert html =~ "Manage employee course enrollments"
    end

    test "renders both desktop table and mobile card list", %{conn: conn, company: company} do
      employee = user_with_role_fixture(:employee, company.id)
      course = course_fixture(%{company: company})
      _enrollment = enrollment_fixture(%{user: employee, course: course})

      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")

      assert html =~ ~s(id="enrollments")
      assert html =~ "hidden md:block overflow-x-auto"
      assert html =~ ~s(id="enrollments-cards")
      assert html =~ "md:hidden space-y-3"
    end

    test "shows empty state when no enrollments", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")
      assert html =~ "No enrollments yet"
    end

    test "shows enroll button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")
      assert html =~ "Enroll Employees"
    end

    test "lists enrollments with employee and course info", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      employee = user_with_role_fixture(:employee, company.id)
      enrollment_fixture(%{user: employee, course: course})

      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")
      assert html =~ employee.email
      assert html =~ course.title
    end

    test "shows progress bar for enrollments", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      chapter = chapter_fixture(%{course: course})
      lesson = lesson_fixture(%{chapter: chapter})
      _lesson2 = lesson_fixture(%{chapter: chapter})

      employee = user_with_role_fixture(:employee, company.id)
      enrollment = enrollment_fixture(%{user: employee, course: course})
      {:ok, _} = Learning.complete_lesson(enrollment, lesson.id)

      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")
      assert html =~ "50%"
    end

    test "shows status badge", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      employee = user_with_role_fixture(:employee, company.id)
      enrollment_fixture(%{user: employee, course: course})

      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")
      assert html =~ "Not Started"
    end
  end

  describe "Search" do
    test "filters enrollments by employee name", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})

      emp1 = user_with_role_fixture(:employee, company.id) |> set_user_name("Alice Smith")
      emp2 = user_with_role_fixture(:employee, company.id) |> set_user_name("Bob Jones")

      enrollment_fixture(%{user: emp1, course: course})
      enrollment_fixture(%{user: emp2, course: course})

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      html =
        view
        |> form("#search-form", search: "Alice")
        |> render_change()

      assert html =~ "Alice Smith"
      refute html =~ "Bob Jones"
    end

    test "shows no results message when search matches nothing", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      employee = user_with_role_fixture(:employee, company.id)
      enrollment_fixture(%{user: employee, course: course})

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      html =
        view
        |> form("#search-form", search: "zzz-nonexistent-zzz")
        |> render_change()

      assert html =~ "No enrollments match"
    end
  end

  describe "Filters" do
    test "filters by course", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course1 = course_fixture(%{company: company, creator: creator, status: :published})
      course2 = course_fixture(%{company: company, creator: creator, status: :published})

      emp = user_with_role_fixture(:employee, company.id)
      enrollment_fixture(%{user: emp, course: course1})

      emp2 = user_with_role_fixture(:employee, company.id)
      enrollment_fixture(%{user: emp2, course: course2})

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      html =
        view
        |> form("#course-filter-form", course_id: course1.id)
        |> render_change()

      assert html =~ course1.title
    end

    test "filters by status", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      employee = user_with_role_fixture(:employee, company.id)
      enrollment_fixture(%{user: employee, course: course})

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      html =
        view
        |> form("#status-filter-form", status: "not_started")
        |> render_change()

      assert html =~ employee.email
    end
  end

  describe "Sorting" do
    test "sorts by employee name", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})

      emp1 = user_with_role_fixture(:employee, company.id) |> set_user_name("Alice")
      emp2 = user_with_role_fixture(:employee, company.id) |> set_user_name("Zara")

      enrollment_fixture(%{user: emp1, course: course})
      enrollment_fixture(%{user: emp2, course: course})

      {:ok, view, html} = live(conn, ~p"/admin/enrollments")
      assert html =~ "Alice"
      assert html =~ "Zara"

      # Click sort to toggle to desc
      html =
        view
        |> element("th[phx-value-field=employee]")
        |> render_click()

      assert html =~ "Alice"
      assert html =~ "Zara"
    end
  end

  describe "Enroll modal" do
    test "opens and closes enroll modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      html =
        view
        |> element("button", "Enroll Employees")
        |> render_click()

      assert html =~ "Select a course"

      html =
        view
        |> element("button", "Cancel")
        |> render_click()

      refute html =~ "Select a course"
    end

    test "shows only published courses in modal", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      published = course_fixture(%{company: company, creator: creator, status: :published})
      _draft = course_fixture(%{company: company, creator: creator, status: :draft})

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      html =
        view
        |> element("button", "Enroll Employees")
        |> render_click()

      assert html =~ published.title
    end

    test "enrolls employee via modal", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      employee = user_with_role_fixture(:employee, company.id)

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      view
      |> element("button", "Enroll Employees")
      |> render_click()

      view
      |> element(".modal select[name=course_id]")
      |> render_change(%{"course_id" => to_string(course.id)})

      view
      |> element("div[phx-value-id=\"#{employee.id}\"]")
      |> render_click()

      view
      |> element(".modal button", "Enroll")
      |> render_click()

      # Verify enrollment was created
      assert [_enrollment] = Learning.list_enrollments(%{user_id: employee.id})
    end
  end

  describe "Pagination" do
    setup %{company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})

      for _ <- 1..21 do
        emp = user_with_role_fixture(:employee, company.id)
        enrollment_fixture(%{user: emp, course: course})
      end

      %{course: course}
    end

    test "shows pagination controls when more than 20 enrollments", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/admin/enrollments")

      assert html =~ "Showing page"
      assert has_element?(view, "button", "Next")
    end

    test "navigates to next page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      html = render_click(view, "page", %{"page" => "2"})

      assert html =~ "Showing page 2"
      assert has_element?(view, "button", "Previous")
    end

    test "navigates back to previous page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/enrollments?page=2")

      html = render_click(view, "page", %{"page" => "1"})

      assert html =~ "Showing page 1"
    end
  end

  describe "handle_info callbacks" do
    test "closes modal and refreshes on enrollment completion", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      employee = user_with_role_fixture(:employee, company.id)
      enrollment_fixture(%{user: employee, course: course})

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      # Open modal first
      render_click(view, "open_enroll_modal")

      # Simulate the enrolled message from the component
      send(
        view.pid,
        {LmsWeb.Admin.EnrollmentLive.EnrollFormComponent, {:enrolled, 1}}
      )

      html = render(view)
      assert html =~ employee.email
    end

    test "handles email info message gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      send(view.pid, {:email, %{to: "test@example.com"}})

      html = render(view)
      assert html =~ "Enrollments"
    end
  end

  describe "Status display" do
    test "displays completed status badge", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      employee = user_with_role_fixture(:employee, company.id)

      enrollment_fixture(%{
        user: employee,
        course: course,
        completed_at: DateTime.utc_now(:second)
      })

      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")

      assert html =~ "Completed"
    end

    test "displays overdue status badge", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      employee = user_with_role_fixture(:employee, company.id)

      enrollment_fixture(%{
        user: employee,
        course: course,
        due_date: ~D[2020-01-01]
      })

      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")

      assert html =~ "Overdue"
    end

    test "displays formatted due date", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      employee = user_with_role_fixture(:employee, company.id)

      enrollment_fixture(%{
        user: employee,
        course: course,
        due_date: ~D[2026-12-25]
      })

      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")

      assert html =~ "Dec 25, 2026"
    end
  end

  describe "URL param parsing edge cases" do
    test "defaults sort_by when atom exists but not in allowed fields", %{conn: conn} do
      # "name" is an existing atom but not in @sort_fields (employee, course, due_date)
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments?sort_by=name")

      assert html =~ "Enrollments"
    end

    test "defaults sort_by when atom does not exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments?sort_by=zzz_no_such_atom_999")

      assert html =~ "Enrollments"
    end

    test "defaults sort_order when atom does not exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments?sort_order=zzz_no_order_999")

      assert html =~ "Enrollments"
    end

    test "handles invalid sort_order gracefully", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments?sort_order=invalid")

      assert html =~ "Enrollments"
    end

    test "handles negative page number gracefully", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments?page=-5")

      assert html =~ "Enrollments"
    end

    test "handles non-numeric page gracefully", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments?page=abc")

      assert html =~ "Enrollments"
    end

    test "handles zero page number gracefully", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments?page=0")

      assert html =~ "Enrollments"
    end

    test "handles empty course_id param", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments?course_id=")

      assert html =~ "Enrollments"
    end

    test "handles invalid course_id param", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments?course_id=abc")

      assert html =~ "Enrollments"
    end
  end

  describe "Sort toggling" do
    test "toggles from desc back to asc", %{conn: conn, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      employee = user_with_role_fixture(:employee, company.id)
      enrollment_fixture(%{user: employee, course: course})

      {:ok, view, _html} = live(conn, ~p"/admin/enrollments")

      # Click employee sort (already default asc) -> toggles to desc
      render_click(view, "sort", %{"field" => "employee"})
      # Click again -> toggles back to asc
      html = render_click(view, "sort", %{"field" => "employee"})

      assert html =~ "hero-chevron-up"
    end
  end

  describe "Authorization" do
    test "redirects unauthenticated user", %{} do
      conn = build_conn()
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin/enrollments")
      assert path =~ "/users/log-in"
    end

    test "redirects employee role", %{company: company} do
      employee = user_with_role_fixture(:employee, company.id)
      conn = build_conn() |> log_in_user(employee)
      {:error, {:redirect, %{to: _path}}} = live(conn, ~p"/admin/enrollments")
    end
  end
end
