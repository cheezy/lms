defmodule LmsWeb.Courses.CourseEditorLiveTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures
  import Lms.TrainingFixtures

  alias Lms.Training

  # Minimal valid 1x1 white PNG
  defp create_test_png do
    <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 2,
      0, 0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 207, 192, 0, 0, 0,
      2, 0, 1, 226, 33, 188, 51, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130>>
  end

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

    test "refreshes selected lesson after editing its title", %{
      conn: conn,
      course: course,
      chapter: chapter
    } do
      lesson = lesson_fixture(%{chapter: chapter, title: "Original Name"})
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      # Select the lesson first
      view
      |> element("button[phx-click='select_lesson'][phx-value-id='#{lesson.id}']")
      |> render_click()

      assert has_element?(view, "[phx-hook='TipTapEditor']")

      # Now edit the title of the currently selected lesson
      view
      |> element("button[phx-click='edit_lesson_title'][phx-value-id='#{lesson.id}']")
      |> render_click()

      view
      |> form("form[phx-submit='update_lesson_title']", lesson: %{title: "Renamed Lesson"})
      |> render_submit()

      # The selected lesson header should show the updated name
      html = render(view)
      assert html =~ "Renamed Lesson"
      assert has_element?(view, "[phx-hook='TipTapEditor']")
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

  describe "Chapter CRUD error paths" do
    test "shows error when saving chapter with blank title", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      view |> element("button", "Chapter") |> render_click()

      html =
        view
        |> form("form", chapter: %{title: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end

    test "shows error when updating chapter with blank title", %{conn: conn, course: course} do
      chapter = chapter_fixture(%{course: course, title: "Good Title"})
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      view
      |> element("button[phx-click='edit_chapter'][phx-value-id='#{chapter.id}']")
      |> render_click()

      html =
        view
        |> form("form", chapter: %{title: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end
  end

  describe "Lesson CRUD error paths" do
    setup %{course: course} do
      chapter = chapter_fixture(%{course: course, title: "Chapter One"})
      %{chapter: chapter}
    end

    test "shows error when saving lesson with blank title", %{
      conn: conn,
      course: course,
      chapter: chapter
    } do
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      view
      |> element("button[phx-click='add_lesson'][phx-value-chapter-id='#{chapter.id}']")
      |> render_click()

      html =
        view
        |> form("form", lesson: %{title: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end

    test "shows error when updating lesson with blank title", %{
      conn: conn,
      course: course,
      chapter: chapter
    } do
      lesson = lesson_fixture(%{chapter: chapter, title: "Good Title"})
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      view
      |> element("button[phx-click='edit_lesson_title'][phx-value-id='#{lesson.id}']")
      |> render_click()

      html =
        view
        |> form("form", lesson: %{title: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end
  end

  describe "Content editing edge cases" do
    setup %{course: course} do
      chapter = chapter_fixture(%{course: course})
      lesson = lesson_fixture(%{chapter: chapter, title: "Content Lesson"})
      %{chapter: chapter, lesson: lesson}
    end

    test "handles invalid JSON in editor_updated gracefully", %{
      conn: conn,
      course: course,
      lesson: lesson
    } do
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      view
      |> element("button[phx-click='select_lesson'][phx-value-id='#{lesson.id}']")
      |> render_click()

      # Send invalid JSON via the hook
      view
      |> element("[phx-hook='TipTapEditor']")
      |> render_hook("editor_updated", %{"content" => "not valid json {"})

      # Should not crash - page still renders
      html = render(view)
      assert html =~ "Content Lesson"
    end
  end

  describe "Cross-chapter move with selected lesson" do
    test "refreshes selected lesson and reorders source after cross-chapter drag move", %{
      conn: conn,
      course: course
    } do
      ch1 = chapter_fixture(%{course: course, title: "Source"})
      ch2 = chapter_fixture(%{course: course, title: "Target"})
      lesson = lesson_fixture(%{chapter: ch1, title: "Movable Lesson"})
      remaining_lesson = lesson_fixture(%{chapter: ch1, title: "Stays Behind"})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      # Select the lesson first
      view
      |> element("button[phx-click='select_lesson'][phx-value-id='#{lesson.id}']")
      |> render_click()

      # Move it via drag-and-drop cross-chapter event
      render_click(view, "move_lesson_to_chapter_and_reorder", %{
        "lesson_id" => to_string(lesson.id),
        "from_chapter_id" => to_string(ch1.id),
        "to_chapter_id" => to_string(ch2.id),
        "ids" => [to_string(lesson.id)]
      })

      moved = Training.get_lesson!(lesson.id)
      assert moved.chapter_id == ch2.id

      # Source chapter's remaining lesson should be reordered
      stayed = Training.get_lesson!(remaining_lesson.id)
      assert stayed.chapter_id == ch1.id

      # Selected lesson should still be visible after move
      html = render(view)
      assert html =~ "Movable Lesson"
      assert has_element?(view, "[phx-hook='TipTapEditor']")
    end

    test "refreshes selected lesson after dropdown move", %{conn: conn, course: course} do
      ch1 = chapter_fixture(%{course: course, title: "Source Chapter"})
      ch2 = chapter_fixture(%{course: course, title: "Target Chapter"})
      lesson = lesson_fixture(%{chapter: ch1, title: "Dropdown Move"})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      # Select the lesson
      view
      |> element("button[phx-click='select_lesson'][phx-value-id='#{lesson.id}']")
      |> render_click()

      # Move via dropdown
      view
      |> element(
        "button[phx-click='move_lesson_to_chapter'][phx-value-lesson-id='#{lesson.id}'][phx-value-chapter-id='#{ch2.id}']"
      )
      |> render_click()

      moved = Training.get_lesson!(lesson.id)
      assert moved.chapter_id == ch2.id

      # Lesson should still be selected
      html = render(view)
      assert html =~ "Dropdown Move"
    end

    test "does not refresh when different lesson is selected during dropdown move", %{
      conn: conn,
      course: course
    } do
      ch1 = chapter_fixture(%{course: course, title: "Source Chapter"})
      ch2 = chapter_fixture(%{course: course, title: "Target Chapter"})
      lesson_a = lesson_fixture(%{chapter: ch1, title: "Lesson A"})
      lesson_b = lesson_fixture(%{chapter: ch1, title: "Lesson B"})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      # Select lesson A
      view
      |> element("button[phx-click='select_lesson'][phx-value-id='#{lesson_a.id}']")
      |> render_click()

      # Move lesson B to another chapter via direct event (different from selected)
      render_click(view, "move_lesson_to_chapter", %{
        "lesson-id" => to_string(lesson_b.id),
        "chapter-id" => to_string(ch2.id)
      })

      moved = Training.get_lesson!(lesson_b.id)
      assert moved.chapter_id == ch2.id

      # Lesson A should still be selected
      html = render(view)
      assert html =~ "Lesson A"
    end

    test "no-op when moving lesson to same chapter via dropdown", %{
      conn: conn,
      course: course
    } do
      ch1 = chapter_fixture(%{course: course, title: "Same Chapter"})
      lesson = lesson_fixture(%{chapter: ch1, title: "Stay Put"})

      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      # Select the lesson
      view
      |> element("button[phx-click='select_lesson'][phx-value-id='#{lesson.id}']")
      |> render_click()

      # Move to same chapter via event (simulating)
      render_click(view, "move_lesson_to_chapter", %{
        "lesson-id" => to_string(lesson.id),
        "chapter-id" => to_string(ch1.id)
      })

      # Lesson stays in same chapter
      same = Training.get_lesson!(lesson.id)
      assert same.chapter_id == ch1.id
    end
  end

  describe "Image upload" do
    setup %{course: course} do
      chapter = chapter_fixture(%{course: course})
      lesson = lesson_fixture(%{chapter: chapter, title: "Upload Lesson"})
      %{chapter: chapter, lesson: lesson}
    end

    test "ignores upload_image when no lesson is selected", %{conn: conn, course: course} do
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      # Trigger upload without selecting a lesson
      render_click(view, "upload_image")

      html = render(view)
      assert html =~ "Select a lesson to edit its content"
    end

    test "uploads an image for the selected lesson", %{
      conn: conn,
      course: course,
      lesson: lesson
    } do
      {:ok, view, _html} = live(conn, ~p"/courses/#{course.id}/editor")

      # Select the lesson first
      view
      |> element("button[phx-click='select_lesson'][phx-value-id='#{lesson.id}']")
      |> render_click()

      # Create a tiny valid PNG (1x1 pixel)
      png_content = create_test_png()

      # Simulate file input and upload
      image =
        file_input(view, "#image-upload-form", :image, [
          %{
            name: "test_image.png",
            content: png_content,
            size: byte_size(png_content),
            type: "image/png"
          }
        ])

      render_upload(image, "test_image.png")

      # With auto_upload, explicitly submit the form to trigger consume_uploaded_entries
      view
      |> element("#image-upload-form")
      |> render_submit()

      # Verify the image was created in the database
      assert [_ | _] = Training.list_lesson_images(lesson.id)
    after
      # Clean up uploaded files
      Path.wildcard("priv/static/uploads/*")
      |> Enum.each(&File.rm/1)
    end
  end

  describe "Archived course event blocking" do
    setup %{company: company} do
      course = course_fixture(%{company: company, status: :draft})
      chapter = chapter_fixture(%{course: course, title: "Archived Chapter"})
      lesson = lesson_fixture(%{chapter: chapter, title: "Archived Lesson"})
      {:ok, published} = Training.publish_course(course)
      {:ok, archived} = Training.archive_course(published)

      %{archived: archived, chapter: chapter, lesson: lesson}
    end

    test "ignores add_chapter on archived course", %{conn: conn, archived: archived} do
      {:ok, view, _html} = live(conn, ~p"/courses/#{archived.id}/editor")

      render_click(view, "add_chapter")

      refute has_element?(view, "input[name='chapter[title]']")
    end

    test "ignores edit_chapter on archived course", %{
      conn: conn,
      archived: archived,
      chapter: chapter
    } do
      {:ok, view, _html} = live(conn, ~p"/courses/#{archived.id}/editor")

      render_click(view, "edit_chapter", %{"id" => to_string(chapter.id)})

      refute has_element?(view, "input[name='chapter[title]']")
    end

    test "ignores delete_chapter on archived course", %{
      conn: conn,
      archived: archived,
      chapter: chapter
    } do
      {:ok, view, _html} = live(conn, ~p"/courses/#{archived.id}/editor")

      render_click(view, "delete_chapter", %{"id" => to_string(chapter.id)})

      html = render(view)
      assert html =~ "Archived Chapter"
    end

    test "ignores add_lesson on archived course", %{
      conn: conn,
      archived: archived,
      chapter: chapter
    } do
      {:ok, view, _html} = live(conn, ~p"/courses/#{archived.id}/editor")

      render_click(view, "add_lesson", %{"chapter-id" => to_string(chapter.id)})

      refute has_element?(view, "input[name='lesson[title]']")
    end

    test "ignores edit_lesson_title on archived course", %{
      conn: conn,
      archived: archived,
      lesson: lesson
    } do
      {:ok, view, _html} = live(conn, ~p"/courses/#{archived.id}/editor")

      render_click(view, "edit_lesson_title", %{"id" => to_string(lesson.id)})

      refute has_element?(view, "input[name='lesson[title]']")
    end

    test "ignores delete_lesson on archived course", %{
      conn: conn,
      archived: archived,
      lesson: lesson
    } do
      {:ok, view, _html} = live(conn, ~p"/courses/#{archived.id}/editor")

      render_click(view, "delete_lesson", %{"id" => to_string(lesson.id)})

      html = render(view)
      assert html =~ "Archived Lesson"
    end

    test "ignores reorder_chapters on archived course", %{
      conn: conn,
      archived: archived,
      chapter: chapter
    } do
      {:ok, view, _html} = live(conn, ~p"/courses/#{archived.id}/editor")

      render_click(view, "reorder_chapters", %{"ids" => [to_string(chapter.id)]})

      html = render(view)
      assert html =~ "Archived Chapter"
    end

    test "ignores reorder_lessons on archived course", %{
      conn: conn,
      archived: archived,
      chapter: chapter,
      lesson: lesson
    } do
      {:ok, view, _html} = live(conn, ~p"/courses/#{archived.id}/editor")

      render_click(view, "reorder_lessons", %{
        "chapter_id" => to_string(chapter.id),
        "ids" => [to_string(lesson.id)]
      })

      html = render(view)
      assert html =~ "Archived Lesson"
    end

    test "shows lesson content in read-only mode for archived course", %{
      conn: conn,
      archived: archived,
      lesson: lesson
    } do
      # Set some content on the lesson
      Training.update_lesson(lesson, %{
        content: %{
          "type" => "doc",
          "content" => [
            %{
              "type" => "paragraph",
              "content" => [%{"type" => "text", "text" => "Read only content"}]
            }
          ]
        }
      })

      {:ok, view, _html} = live(conn, ~p"/courses/#{archived.id}/editor")

      view
      |> element("button[phx-click='select_lesson'][phx-value-id='#{lesson.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Read only content"
    end

    test "renders archived lesson with nil content", %{
      conn: conn,
      archived: archived,
      lesson: lesson
    } do
      # Lesson has nil content by default
      {:ok, view, _html} = live(conn, ~p"/courses/#{archived.id}/editor")

      view
      |> element("button[phx-click='select_lesson'][phx-value-id='#{lesson.id}']")
      |> render_click()

      # Should render without crashing
      html = render(view)
      assert html =~ lesson.title
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
