defmodule LmsWeb.Employee.MyLearningLiveTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures
  import Lms.TrainingFixtures
  import Lms.LearningFixtures

  setup %{conn: conn} do
    company = company_fixture()
    employee = user_with_role_fixture(:employee, company.id)
    conn = log_in_user(conn, employee)
    %{conn: conn, company: company, employee: employee}
  end

  describe "Index" do
    test "renders my learning page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/my-learning")
      assert html =~ "My Learning"
    end

    test "shows empty state when no enrollments", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/my-learning")
      assert html =~ "not enrolled in any courses"
    end

    test "shows enrolled courses with progress", %{
      conn: conn,
      company: company,
      employee: employee
    } do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      enrollment_fixture(%{user: employee, course: course})

      {:ok, _view, html} = live(conn, ~p"/my-learning")
      assert html =~ course.title
      assert html =~ "0%"
    end

    test "shows progress percentage", %{conn: conn, company: company, employee: employee} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      chapter = chapter_fixture(%{course: course})
      lesson = lesson_fixture(%{chapter: chapter})
      _lesson2 = lesson_fixture(%{chapter: chapter})

      enrollment = enrollment_fixture(%{user: employee, course: course})
      {:ok, _} = Lms.Learning.complete_lesson(enrollment, lesson.id)

      {:ok, _view, html} = live(conn, ~p"/my-learning")
      assert html =~ "50%"
    end

    test "links to course viewer", %{conn: conn, company: company, employee: employee} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      enrollment_fixture(%{user: employee, course: course})

      {:ok, view, _html} = live(conn, ~p"/my-learning")
      assert has_element?(view, "a[href='/my-learning/#{course.id}']")
    end
  end

  describe "Authorization" do
    test "redirects unauthenticated user" do
      conn = build_conn()
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/my-learning")
      assert path =~ "/users/log-in"
    end
  end
end
