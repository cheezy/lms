defmodule LmsWeb.Courses.CoursePreviewLiveTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures
  import Lms.TrainingFixtures

  setup %{conn: conn} do
    company = company_fixture()
    admin = user_with_role_fixture(:company_admin, company.id)
    conn = log_in_user(conn, admin)
    course = course_fixture(%{company: company, creator: admin, title: "Preview Test Course"})
    %{conn: conn, company: company, admin: admin, course: course}
  end

  describe "Mount and rendering" do
    test "renders preview page with course title", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course, title: "Chapter One"})
      lesson_fixture(%{chapter: chapter, title: "Lesson One"})

      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert html =~ "Preview Test Course"
    end

    test "shows Preview Mode badge", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter})

      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert html =~ "Preview Mode"
    end

    test "shows Back to Courses link", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert has_element?(view, "a", "Back to Courses")
    end

    test "selects first lesson by default", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course})
      lesson = lesson_fixture(%{chapter: chapter, title: "First Lesson"})
      lesson_fixture(%{chapter: chapter, title: "Second Lesson"})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert has_element?(view, "h2", lesson.title)
    end

    test "shows course description", %{conn: conn, company: company, admin: admin} do
      course =
        course_fixture(%{
          company: company,
          creator: admin,
          title: "Described Course",
          description: "A detailed description"
        })

      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter})

      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert html =~ "A detailed description"
    end

    test "does not render Mark as Complete button", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter})

      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/preview")
      refute html =~ "Mark as Complete"
    end

    test "does not render progress bar", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter})

      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/preview")
      refute html =~ "of" <> " " <> "lessons"
    end

    test "shows empty state when course has no lessons", %{conn: conn, course: course} do
      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert html =~ "This course has no lessons yet."
    end
  end

  describe "Sidebar navigation" do
    test "shows all chapters in sidebar", %{conn: conn, course: course} do
      chapter_fixture(%{course: course, title: "Alpha Chapter"})
      chapter_fixture(%{course: course, title: "Beta Chapter"})

      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert html =~ "Alpha Chapter"
      assert html =~ "Beta Chapter"
    end

    test "shows all lessons in sidebar", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter, title: "Lesson Alpha"})
      lesson_fixture(%{chapter: chapter, title: "Lesson Beta"})

      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert html =~ "Lesson Alpha"
      assert html =~ "Lesson Beta"
    end

    test "shows lesson count badge per chapter", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter})
      lesson_fixture(%{chapter: chapter})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert has_element?(view, "span.bg-base-200", "2")
    end
  end

  describe "Lesson selection" do
    test "select_lesson changes displayed lesson", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter, title: "First Lesson"})
      second = lesson_fixture(%{chapter: chapter, title: "Second Lesson"})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert has_element?(view, "h2", "First Lesson")

      view |> element("button[phx-value-id='#{second.id}']") |> render_click()
      assert has_element?(view, "h2", "Second Lesson")
    end

    test "next_lesson navigates to next lesson", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter, title: "First Lesson"})
      lesson_fixture(%{chapter: chapter, title: "Second Lesson"})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert has_element?(view, "h2", "First Lesson")

      view |> element("button", "Next") |> render_click()
      assert has_element?(view, "h2", "Second Lesson")
    end

    test "prev_lesson navigates to previous lesson", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter, title: "First Lesson"})
      second = lesson_fixture(%{chapter: chapter, title: "Second Lesson"})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/preview")

      view |> element("button[phx-value-id='#{second.id}']") |> render_click()
      assert has_element?(view, "h2", "Second Lesson")

      view |> element("button", "Previous") |> render_click()
      assert has_element?(view, "h2", "First Lesson")
    end

    test "navigates across chapters", %{conn: conn, course: course} do
      ch1 = chapter_fixture(%{course: course, title: "Chapter 1"})
      lesson_fixture(%{chapter: ch1, title: "Ch1 Lesson"})
      ch2 = chapter_fixture(%{course: course, title: "Chapter 2"})
      lesson_fixture(%{chapter: ch2, title: "Ch2 Lesson"})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert has_element?(view, "h2", "Ch1 Lesson")

      view |> element("button", "Next") |> render_click()
      assert has_element?(view, "h2", "Ch2 Lesson")
    end
  end

  describe "Lesson content rendering" do
    test "renders lesson content", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course})

      lesson_fixture(%{
        chapter: chapter,
        title: "Content Lesson",
        content: %{
          "type" => "doc",
          "content" => [
            %{
              "type" => "paragraph",
              "content" => [%{"type" => "text", "text" => "Hello preview"}]
            }
          ]
        }
      })

      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert html =~ "Hello preview"
    end
  end

  describe "Authorization" do
    test "redirects employee role", %{course: course} do
      company = company_fixture()
      employee = user_with_role_fixture(:employee, company.id)
      conn = build_conn() |> log_in_user(employee)

      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/courses/#{course.id}/preview")
    end

    test "redirects for course from another company", %{conn: conn} do
      other_company = company_fixture()
      other_creator = user_with_role_fixture(:course_creator, other_company.id)
      other_course = course_fixture(%{company: other_company, creator: other_creator})

      {:ok, conn} =
        conn
        |> live(~p"/courses/#{other_course.id}/preview")
        |> follow_redirect(conn)

      assert conn.resp_body =~ "You don&#39;t have access to this course."
    end

    test "allows course_creator role", %{course: course, company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      conn = build_conn() |> log_in_user(creator)
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter})

      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert html =~ "Preview Mode"
    end

    test "allows system_admin role", %{course: course} do
      admin = user_with_role_fixture(:system_admin)
      conn = build_conn() |> log_in_user(admin)
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter})

      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert html =~ "Preview Mode"
    end
  end

  describe "Edge cases" do
    test "course with chapters but no lessons shows empty state", %{conn: conn, course: course} do
      chapter_fixture(%{course: course, title: "Empty Chapter"})

      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert html =~ "This course has no lessons yet."
    end

    test "draft course is previewable", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter})

      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert html =~ "Preview Mode"
    end

    test "published course is previewable", %{
      conn: conn,
      company: company,
      admin: admin
    } do
      course =
        course_fixture(%{company: company, creator: admin, title: "Published Course"})

      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter})
      {:ok, _course} = Lms.Training.publish_course(course)

      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/preview")
      assert html =~ "Preview Mode"
    end
  end
end
