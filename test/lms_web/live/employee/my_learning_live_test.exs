defmodule LmsWeb.Employee.MyLearningLiveTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures
  import Lms.TrainingFixtures
  import Lms.LearningFixtures

  alias Lms.Learning

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

    test "links to course viewer", %{conn: conn, company: company, employee: employee} do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      enrollment_fixture(%{user: employee, course: course})

      {:ok, view, _html} = live(conn, ~p"/my-learning")
      assert has_element?(view, "a[href='/my-learning/#{course.id}']")
    end
  end

  describe "Sections" do
    test "shows not started course in Not Started section", %{
      conn: conn,
      company: company,
      employee: employee
    } do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      enrollment_fixture(%{user: employee, course: course})

      {:ok, _view, html} = live(conn, ~p"/my-learning")
      assert html =~ "Not Started"
      assert html =~ course.title
    end

    test "shows in-progress course with progress bar", %{
      conn: conn,
      company: company,
      employee: employee
    } do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      chapter = chapter_fixture(%{course: course})
      lesson = lesson_fixture(%{chapter: chapter})
      _lesson2 = lesson_fixture(%{chapter: chapter})

      enrollment = enrollment_fixture(%{user: employee, course: course})
      {:ok, _} = Learning.complete_lesson(enrollment, lesson.id)

      {:ok, _view, html} = live(conn, ~p"/my-learning")
      assert html =~ "In Progress"
      assert html =~ "50%"
      assert html =~ "1 of 2 lessons"
    end

    test "shows completed course with completion date", %{
      conn: conn,
      company: company,
      employee: employee
    } do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      chapter = chapter_fixture(%{course: course})
      lesson = lesson_fixture(%{chapter: chapter})

      enrollment = enrollment_fixture(%{user: employee, course: course})
      {:ok, _} = Learning.complete_lesson(enrollment, lesson.id)

      {:ok, _view, html} = live(conn, ~p"/my-learning")
      assert html =~ "Completed"
    end

    test "shows due date for courses with due date", %{
      conn: conn,
      company: company,
      employee: employee
    } do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      enrollment_fixture(%{user: employee, course: course, due_date: ~D[2026-12-31]})

      {:ok, _view, html} = live(conn, ~p"/my-learning")
      assert html =~ "Due:"
      assert html =~ "Dec 31, 2026"
    end

    test "shows no due date message when none set", %{
      conn: conn,
      company: company,
      employee: employee
    } do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      enrollment_fixture(%{user: employee, course: course})

      {:ok, _view, html} = live(conn, ~p"/my-learning")
      assert html =~ "No due date"
    end

    test "shows overdue badge for overdue enrollments", %{
      conn: conn,
      company: company,
      employee: employee
    } do
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      chapter = chapter_fixture(%{course: course})
      _lesson = lesson_fixture(%{chapter: chapter})
      enrollment_fixture(%{user: employee, course: course, due_date: ~D[2020-01-01]})

      {:ok, _view, html} = live(conn, ~p"/my-learning")
      assert html =~ "Overdue"
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
