defmodule LmsWeb.Courses.CourseEditorLiveTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures
  import Lms.TrainingFixtures

  alias Lms.Training

  setup %{conn: conn} do
    company = company_fixture()
    admin = user_with_role_fixture(:company_admin, company.id)
    conn = log_in_user(conn, admin)
    course = course_fixture(%{company: company, title: "Test Course"})
    %{conn: conn, company: company, admin: admin, course: course}
  end

  describe "Mount and rendering" do
    test "renders course editor page", %{conn: conn, course: course} do
      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/editor")
      assert html =~ "Test Course"
      assert html =~ "Course Editor"
      assert html =~ "Contents"
    end

    test "shows empty state when no chapters", %{conn: conn, course: course} do
      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/editor")
      assert html =~ "No chapters yet"
    end

    test "shows lesson selection prompt", %{conn: conn, course: course} do
      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/editor")
      assert html =~ "Select a lesson to edit its content"
    end

    test "shows back button to courses list", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")
      assert has_element?(view, "a", "Back")
    end

    test "redirects for course from another company", %{conn: conn} do
      other_company = company_fixture()
      other_course = course_fixture(%{company: other_company, title: "Other"})

      {:error, {:live_redirect, %{to: "/courses", flash: %{"error" => error}}}} =
        live(conn, ~p"/courses/#{other_course.id}/editor")

      assert error =~ "Course not found"
    end
  end

  describe "Chapter management" do
    test "adds a new chapter", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      view |> element("button", "Chapter") |> render_click()
      assert has_element?(view, "input[name='chapter[title]']")

      view
      |> form("form", chapter: %{title: "My First Chapter"})
      |> render_submit()

      html = render(view)
      assert html =~ "My First Chapter"
    end

    test "edits a chapter title", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course, title: "Original Title"})
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      view
      |> element("button[phx-click='edit_chapter'][phx-value-id='#{chapter.id}']")
      |> render_click()

      view
      |> form("form", chapter: %{title: "Updated Title"})
      |> render_submit()

      html = render(view)
      assert html =~ "Updated Title"
      refute html =~ "Original Title"
    end

    test "deletes a chapter", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course, title: "Doomed Chapter"})
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      assert render(view) =~ "Doomed Chapter"

      view
      |> element("button[phx-click='delete_chapter'][phx-value-id='#{chapter.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Chapter deleted"
      refute html =~ "Doomed Chapter"
    end

    test "cancels adding a chapter", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      view |> element("button", "Chapter") |> render_click()
      assert has_element?(view, "input[name='chapter[title]']")

      view |> element("button[phx-click='cancel_edit']") |> render_click()
      refute has_element?(view, "input[name='chapter[title]']")
    end
  end

  describe "Lesson management" do
    setup %{course: course} do
      chapter = chapter_fixture(%{course: course, title: "Chapter One"})
      %{chapter: chapter}
    end

    test "adds a new lesson to a chapter", %{conn: conn, course: course, chapter: chapter} do
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      view
      |> element("button[phx-click='add_lesson'][phx-value-chapter-id='#{chapter.id}']")
      |> render_click()

      view
      |> form("form", lesson: %{title: "Lesson Alpha"})
      |> render_submit()

      html = render(view)
      assert html =~ "Lesson Alpha"
    end

    test "selects a lesson and shows content editor", %{
      conn: conn,
      course: course,
      chapter: chapter
    } do
      lesson = lesson_fixture(%{chapter: chapter, title: "Selected Lesson"})
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      view
      |> element("button[phx-click='select_lesson'][phx-value-id='#{lesson.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Selected Lesson"
      assert has_element?(view, "[phx-hook='TipTapEditor']")
    end

    test "edits a lesson title", %{conn: conn, course: course, chapter: chapter} do
      lesson = lesson_fixture(%{chapter: chapter, title: "Old Lesson"})
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      view
      |> element("button[phx-click='edit_lesson_title'][phx-value-id='#{lesson.id}']")
      |> render_click()

      view
      |> form("form", lesson: %{title: "New Lesson"})
      |> render_submit()

      html = render(view)
      assert html =~ "New Lesson"
    end

    test "deletes a lesson", %{conn: conn, course: course, chapter: chapter} do
      lesson = lesson_fixture(%{chapter: chapter, title: "Remove Me"})
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      view
      |> element("button[phx-click='delete_lesson'][phx-value-id='#{lesson.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Lesson deleted"
      refute html =~ "Remove Me"
    end

    test "deleting selected lesson clears content editor", %{
      conn: conn,
      course: course,
      chapter: chapter
    } do
      lesson = lesson_fixture(%{chapter: chapter, title: "Active Lesson"})
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      # Select the lesson first
      view
      |> element("button[phx-click='select_lesson'][phx-value-id='#{lesson.id}']")
      |> render_click()

      assert has_element?(view, "[phx-hook='TipTapEditor']")

      # Delete it
      view
      |> element("button[phx-click='delete_lesson'][phx-value-id='#{lesson.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Select a lesson to edit its content"
    end
  end

  describe "Content editing" do
    setup %{course: course} do
      chapter = chapter_fixture(%{course: course})
      lesson = lesson_fixture(%{chapter: chapter, title: "Edit Content Lesson"})
      %{chapter: chapter, lesson: lesson}
    end

    test "saves lesson content", %{conn: conn, course: course, lesson: lesson} do
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      view
      |> element("button[phx-click='select_lesson'][phx-value-id='#{lesson.id}']")
      |> render_click()

      assert has_element?(view, "[phx-hook='TipTapEditor']")

      content_json =
        Jason.encode!(%{
          "type" => "doc",
          "content" => [
            %{
              "type" => "paragraph",
              "content" => [%{"type" => "text", "text" => "Hello"}]
            }
          ]
        })

      view
      |> element("[phx-hook='TipTapEditor']")
      |> render_hook("editor_updated", %{"content" => content_json})

      html =
        view
        |> element("button[phx-click='save_content']")
        |> render_click()

      assert html =~ "Lesson saved"
    end
  end

  describe "Chapter reordering" do
    test "reorders chapters via drag-and-drop event", %{conn: conn, course: course} do
      ch1 = chapter_fixture(%{course: course, title: "Chapter A"})
      ch2 = chapter_fixture(%{course: course, title: "Chapter B"})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      # Simulate Sortable.js reorder event (swap ch1 and ch2)
      render_click(view, "reorder_chapters", %{
        "ids" => [to_string(ch2.id), to_string(ch1.id)]
      })

      ch1_updated = Training.get_chapter!(ch1.id)
      ch2_updated = Training.get_chapter!(ch2.id)
      assert ch2_updated.position < ch1_updated.position
    end
  end

  describe "Lesson reordering" do
    test "reorders lessons within chapter via drag-and-drop event", %{
      conn: conn,
      course: course
    } do
      chapter = chapter_fixture(%{course: course})
      l1 = lesson_fixture(%{chapter: chapter, title: "Lesson 1"})
      l2 = lesson_fixture(%{chapter: chapter, title: "Lesson 2"})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      # Simulate Sortable.js reorder event (swap l1 and l2)
      render_click(view, "reorder_lessons", %{
        "chapter_id" => to_string(chapter.id),
        "ids" => [to_string(l2.id), to_string(l1.id)]
      })

      l1_updated = Training.get_lesson!(l1.id)
      l2_updated = Training.get_lesson!(l2.id)
      assert l2_updated.position < l1_updated.position
    end
  end

  describe "Move lesson between chapters" do
    test "moves lesson to another chapter via drag-and-drop", %{conn: conn, course: course} do
      ch1 = chapter_fixture(%{course: course, title: "Source Chapter"})
      ch2 = chapter_fixture(%{course: course, title: "Target Chapter"})
      lesson = lesson_fixture(%{chapter: ch1, title: "Moving Lesson"})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      # Simulate Sortable.js cross-chapter drag event
      render_click(view, "move_lesson_to_chapter_and_reorder", %{
        "lesson_id" => to_string(lesson.id),
        "from_chapter_id" => to_string(ch1.id),
        "to_chapter_id" => to_string(ch2.id),
        "ids" => [to_string(lesson.id)]
      })

      moved = Training.get_lesson!(lesson.id)
      assert moved.chapter_id == ch2.id
    end

    test "moves lesson via dropdown menu", %{conn: conn, course: course} do
      ch1 = chapter_fixture(%{course: course, title: "Source Chapter"})
      ch2 = chapter_fixture(%{course: course, title: "Target Chapter"})
      lesson = lesson_fixture(%{chapter: ch1, title: "Moving Lesson"})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      # Select the lesson first
      view
      |> element("button[phx-click='select_lesson'][phx-value-id='#{lesson.id}']")
      |> render_click()

      # Move it via dropdown
      view
      |> element(
        "button[phx-click='move_lesson_to_chapter'][phx-value-lesson-id='#{lesson.id}'][phx-value-chapter-id='#{ch2.id}']"
      )
      |> render_click()

      moved = Training.get_lesson!(lesson.id)
      assert moved.chapter_id == ch2.id
    end
  end

  describe "Sidebar toggle" do
    test "toggles chapter expand/collapse", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course, title: "Toggleable"})
      lesson = lesson_fixture(%{chapter: chapter, title: "Hidden Lesson"})

      {:ok, view, html} = live(conn, ~p"/courses/#{course.id}/editor")
      # Chapters start expanded
      assert html =~ lesson.title

      # Collapse
      view
      |> element("button[phx-click='toggle_chapter'][phx-value-id='#{chapter.id}']")
      |> render_click()

      # Lesson should no longer be visible (the container is hidden)
      refute has_element?(view, "#lesson-#{lesson.id}")

      # Expand again
      view
      |> element("button[phx-click='toggle_chapter'][phx-value-id='#{chapter.id}']")
      |> render_click()

      assert has_element?(view, "#lesson-#{lesson.id}")
    end
  end

  describe "Archived course" do
    test "shows read-only badge for archived course", %{conn: conn, company: company} do
      course = course_fixture(%{company: company, status: :draft})
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter})
      {:ok, published} = Training.publish_course(course)
      {:ok, archived} = Training.archive_course(published)

      {:ok, _view, html} = live(conn, ~p"/courses/#{archived.id}/editor")
      assert html =~ "Archived"
      assert html =~ "Read Only"
    end

    test "hides add chapter button for archived course", %{conn: conn, company: company} do
      course = course_fixture(%{company: company, status: :draft})
      chapter = chapter_fixture(%{course: course})
      lesson_fixture(%{chapter: chapter})
      {:ok, published} = Training.publish_course(course)
      {:ok, archived} = Training.archive_course(published)

      {:ok, view, _html} = live(conn, ~p"/courses/#{archived.id}/editor")
      refute has_element?(view, "button[phx-click='add_chapter']")
    end
  end

  describe "Delete chapter clears selected lesson" do
    test "clears selection when selected lesson's chapter is deleted", %{
      conn: conn,
      course: course
    } do
      chapter = chapter_fixture(%{course: course})
      lesson = lesson_fixture(%{chapter: chapter, title: "Will Be Gone"})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      # Select the lesson
      view
      |> element("button[phx-click='select_lesson'][phx-value-id='#{lesson.id}']")
      |> render_click()

      assert has_element?(view, "[phx-hook='TipTapEditor']")

      # Delete the chapter
      view
      |> element("button[phx-click='delete_chapter'][phx-value-id='#{chapter.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Select a lesson to edit its content"
    end
  end

  describe "Authorization" do
    test "redirects employee users", %{company: company} do
      employee = user_with_role_fixture(:employee, company.id)
      conn = build_conn() |> log_in_user(employee)
      course = course_fixture(%{company: company})

      {:error, {:redirect, %{to: "/", flash: %{"error" => _}}}} =
        live(conn, ~p"/courses/#{course.id}/editor")
    end

    test "allows course creators to access", %{company: company} do
      creator = user_with_role_fixture(:course_creator, company.id)
      conn = build_conn() |> log_in_user(creator)
      course = course_fixture(%{company: company})

      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/editor")
      assert html =~ "Course Editor"
    end
  end
end
