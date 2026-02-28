defmodule LmsWeb.Employee.CourseViewerLiveTest do
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
    creator = user_with_role_fixture(:course_creator, company.id)
    course = course_fixture(%{company: company, creator: creator, status: :published})
    chapter = chapter_fixture(%{course: course})
    lesson1 = lesson_fixture(%{chapter: chapter})
    lesson2 = lesson_fixture(%{chapter: chapter})
    enrollment = enrollment_fixture(%{user: employee, course: course})

    conn = log_in_user(conn, employee)

    %{
      conn: conn,
      company: company,
      employee: employee,
      course: course,
      chapter: chapter,
      lesson1: lesson1,
      lesson2: lesson2,
      enrollment: enrollment
    }
  end

  describe "Course Viewer" do
    test "renders course title and progress", %{conn: conn, course: course} do
      {:ok, _view, html} = live(conn, ~p"/my-learning/#{course.id}")
      assert html =~ course.title
      assert html =~ "0 of 2 lessons"
    end

    test "shows lesson list in sidebar", %{
      conn: conn,
      course: course,
      lesson1: lesson1,
      lesson2: lesson2
    } do
      {:ok, _view, html} = live(conn, ~p"/my-learning/#{course.id}")
      assert html =~ lesson1.title
      assert html =~ lesson2.title
    end

    test "shows first lesson by default", %{conn: conn, course: course, lesson1: lesson1} do
      {:ok, _view, html} = live(conn, ~p"/my-learning/#{course.id}")
      assert html =~ lesson1.title
      assert html =~ "Mark as Complete"
    end

    test "shows back link to my learning", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/my-learning/#{course.id}")
      assert has_element?(view, "a[href='/my-learning']")
    end
  end

  describe "Lesson Navigation" do
    test "navigates to a lesson via sidebar", %{conn: conn, course: course, lesson2: lesson2} do
      {:ok, view, _html} = live(conn, ~p"/my-learning/#{course.id}")

      html =
        view
        |> element("button[phx-value-id='#{lesson2.id}']")
        |> render_click()

      assert html =~ lesson2.title
    end

    test "navigates to next lesson", %{conn: conn, course: course, lesson2: lesson2} do
      {:ok, view, _html} = live(conn, ~p"/my-learning/#{course.id}")

      html =
        view
        |> element("button", "Next")
        |> render_click()

      assert html =~ lesson2.title
    end

    test "navigates to previous lesson", %{
      conn: conn,
      course: course,
      lesson1: lesson1,
      lesson2: lesson2
    } do
      {:ok, view, _html} = live(conn, ~p"/my-learning/#{course.id}")

      # Go to lesson 2 first
      view
      |> element("button[phx-value-id='#{lesson2.id}']")
      |> render_click()

      # Then go back
      html =
        view
        |> element("button", "Previous")
        |> render_click()

      assert html =~ lesson1.title
    end
  end

  describe "Mark as Complete" do
    test "marks lesson as complete", %{
      conn: conn,
      course: course,
      lesson1: lesson1,
      enrollment: enrollment
    } do
      {:ok, view, _html} = live(conn, ~p"/my-learning/#{course.id}")

      html =
        view
        |> element("button", "Mark as Complete")
        |> render_click()

      assert html =~ "Completed"
      assert html =~ "1 of 2 lessons"
      assert Learning.lesson_completed?(enrollment, lesson1.id)
    end

    test "shows completed badge after marking", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/my-learning/#{course.id}")

      view
      |> element("button", "Mark as Complete")
      |> render_click()

      assert has_element?(view, ".badge-success", "Completed")
    end

    test "updates progress bar after completion", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/my-learning/#{course.id}")

      html =
        view
        |> element("button", "Mark as Complete")
        |> render_click()

      assert html =~ "50%"
    end

    test "completes enrollment when all lessons done", %{
      conn: conn,
      course: course,
      lesson2: lesson2,
      enrollment: enrollment
    } do
      {:ok, view, _html} = live(conn, ~p"/my-learning/#{course.id}")

      # Complete first lesson
      view
      |> element("button", "Mark as Complete")
      |> render_click()

      # Navigate to second lesson
      view
      |> element("button[phx-value-id='#{lesson2.id}']")
      |> render_click()

      # Complete second lesson
      html =
        view
        |> element("button", "Mark as Complete")
        |> render_click()

      assert html =~ "100%"
      assert html =~ "2 of 2 lessons"

      updated = Learning.get_enrollment!(enrollment.id)
      assert updated.completed_at != nil
    end
  end

  describe "Authorization" do
    test "redirects unauthenticated user", %{course: course} do
      conn = build_conn()
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/my-learning/#{course.id}")
      assert path =~ "/users/log-in"
    end

    test "raises when not enrolled", %{company: company, course: course} do
      other_employee = user_with_role_fixture(:employee, company.id)
      conn = build_conn() |> log_in_user(other_employee)

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/my-learning/#{course.id}")
      end
    end
  end
end
